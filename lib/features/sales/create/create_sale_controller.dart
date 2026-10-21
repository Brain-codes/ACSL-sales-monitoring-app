import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:signature/signature.dart';
import 'package:toastification/toastification.dart';
import 'package:stove_transaction/core/model/upload_response_model.dart';
import 'package:stove_transaction/core/router/app_navigator.dart';
import 'package:stove_transaction/core/model/sale_field_dictionary.dart';
import 'package:stove_transaction/core/services/sale_dictionary_service.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';
import 'package:stove_transaction/core/services/geo_data_service.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';
import 'package:stove_transaction/core/services/offline_queue_service.dart';
import 'package:stove_transaction/core/services/permission_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/utils/phone_utils.dart';
import 'package:stove_transaction/features/partners/partner_access_service.dart';
import 'package:stove_transaction/features/sales/models/payment_model.dart';
import 'package:stove_transaction/features/sales/models/sale_model.dart';
import 'package:stove_transaction/features/sales/models/stove_model.dart';
import 'create_sale_service.dart';
import 'buyer_rule_messages.dart';
import 'create_sale_test_data.dart';

class ValidationError {
  final int step;
  final String stepTitle;
  final String field;
  final String message;
  const ValidationError({
    required this.step,
    required this.stepTitle,
    required this.field,
    required this.message,
  });
}

class CreateSaleController extends GetxController with WidgetsBindingObserver {
  final _service = CreateSaleService();
  final _session = Get.find<SessionManager>();
  final _partnerAccess = PartnerAccessService();
  final _connectivity = Get.find<ConnectivityService>();
  final _queue = Get.find<OfflineQueueService>();
  final _logger = Logger();
  final _picker = ImagePicker();

  final pageController = PageController();
  final signatureController = SignatureController(penStrokeWidth: 2, penColor: Colors.black);

  final currentStep = 0.obs;
  final isSubmitting = false.obs;
  final isLoadingStoves = false.obs;
  final singleViewMode = true.obs;

  /// When set, this form is editing an existing queued (offline/failed) sale
  /// rather than creating a new one — submitting updates that queue row.
  int? _editingQueueId;
  bool _hydrated = false;

  /// When set, this form is editing an already-SYNCED sale (server row id).
  /// Submitting calls update-sale. Edits to synced sales are online-only:
  /// unlike a fresh create, they are never queued offline.
  final editingSaleId = RxnString();
  bool get isEditingSale => editingSaleId.value != null;

  /// The sale id whose data has actually been loaded into the form fields.
  /// [editingSaleId] is set eagerly (synchronously, on first build) purely to
  /// lock UI fields before hydration completes — it must NOT be reused as the
  /// "already hydrated" guard below, or opening sale B right after cancelling
  /// an edit of sale A sees editingSaleId already pointing at B and skips
  /// hydration entirely, leaving A's data on screen.
  String? _hydratedSaleId;

  /// Signature carried over from a queued sale being edited. Strokes can't be
  /// restored into the pad, so we keep the original PNG and reuse it unless the
  /// user draws a new one.
  String? _existingSignatureB64;

  /// True while the form is editing a queued sale (vs. a fresh create).
  bool get isEditingQueued => _editingQueueId != null;

  // Step 1 — Transaction
  final transactionId = ''.obs;
  final selectedStove = Rxn<StoveModel>();
  final salesDate = DateTime.now().obs;
  final RxList<StoveModel> availableStoves = <StoveModel>[].obs;
  final stoveSearchQuery = ''.obs;

  // Step 2 — Contact
  final contactPersonCtrl = TextEditingController();
  final contactPhoneCtrl = TextEditingController();
  final endUserNameCtrl = TextEditingController();
  final endUserSurnameCtrl = TextEditingController();
  final akaCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final otherPhoneCtrl = TextEditingController();

  // ── "Same as end user" ──────────────────────────────────────────────────
  // When on, the Contact Person / Buyer and Contact Phone are auto-filled from
  // the end-user's name and phone, and kept in sync as those fields change —
  // mirroring the web form. Purely local, so it behaves identically offline.
  final sameAsEndUser = false.obs;

  void setSameAsEndUser(bool value) {
    sameAsEndUser.value = value;
    if (value) _syncContactFromEndUser();
  }

  /// Called from the end-user name fields' onChanged so the contact fields
  /// mirror keystrokes live while "same as end user" is ticked.
  void onEndUserIdentityChanged(String _) {
    _syncContactFromEndUser();
    // A name change can turn the same customer into a family member (or back).
    _scheduleBuyerCheck();
  }

  void _syncContactFromEndUser() {
    if (!sameAsEndUser.value) return;
    final fullName = [endUserNameCtrl.text.trim(), endUserSurnameCtrl.text.trim()]
        .where((s) => s.isNotEmpty)
        .join(' ');
    contactPersonCtrl.text = fullName;
    contactPhoneCtrl.text = phoneCtrl.text;
  }

  // ── End-user phone: the phone and buyer rule (1.0.19) ──────────────────
  //
  // Same phone + same customer (buyer key) → refused, red error, blocks
  // submit. Same phone, different name → allowed: a family shares one phone,
  // so a yellow note and one confirmation. Runs entirely on local data (the
  // cached phones/keys plus the offline queue), so it behaves the same
  // offline. The server re-checks on submit and is the final authority.
  // See docs/contractor/sales-mobile-phone-buyer-rule.md (sales-web repo).

  /// Set when this customer is already registered on this number. Blocks
  /// submit ([validateAll]). Null otherwise.
  final phoneDuplicateError = RxnString();

  /// Set when the number is on another sale but the name differs. Never
  /// blocks submit; asks for one confirmation instead.
  final phoneSharedNote = RxnString();

  Timer? _phoneCheckDebounce;

  /// True while the end-user phone is unusable — i.e. the same customer.
  bool get hasEndUserPhoneProblem => phoneDuplicateError.value != null;

  /// Debounced so a fast typist triggers one check, not twelve.
  void onEndUserPhoneChanged(String value) {
    // Live-mirror into Contact Phone when "same as end user" is on.
    _syncContactFromEndUser();
    _scheduleBuyerCheck();
  }

  void _scheduleBuyerCheck() {
    _phoneCheckDebounce?.cancel();
    final trimmed = phoneCtrl.text.trim();
    if (trimmed.length < 6) {
      phoneDuplicateError.value = null;
      phoneSharedNote.value = null;
      return;
    }
    _phoneCheckDebounce = Timer(const Duration(milliseconds: 300), () {
      checkEndUserPhoneDuplicate(trimmed);
    });
  }

  /// Checks the number and the name against synced and queued sales.
  Future<void> checkEndUserPhoneDuplicate(String value) async {
    final cache = Get.find<LocalCacheService>();
    final titles = cache.getBuyerKeyTitles();
    final tail = BuyerKey.phoneTail(value);
    final key = _currentBuyerKey(titles, phone: value);

    var pendingPhones = <String>{};
    var pendingKeys = <String>{};
    try {
      pendingPhones =
          await _queue.getPendingEndUserPhones(excludeId: _editingQueueId);
      pendingKeys = await _queue.getPendingBuyerKeys(titles,
          excludeId: _editingQueueId);
    } catch (_) {
      // Queue unreadable — fall through to the cached sets rather than blocking.
    }

    final result = classifyPhoneCheck(
      tail: tail,
      key: key,
      knownPhones: {...cache.getEndUserPhones(), ...pendingPhones},
      knownKeys: {...cache.getBuyerKeys(), ...pendingKeys},
      originalKey: _editingOriginalBuyerKey,
      originalTail: _editingOriginalPhoneKey,
    );
    phoneDuplicateError.value =
        result == PhoneCheck.sameBuyer ? BuyerRuleMessages.e1 : null;
    phoneSharedNote.value =
        result == PhoneCheck.shared ? BuyerRuleMessages.n1 : null;
  }

  String _currentBuyerKey(List<String> titles, {String? phone}) =>
      BuyerKey.compute(
        phone ?? phoneCtrl.text,
        endUserNameCtrl.text,
        endUserSurnameCtrl.text,
        null,
        titles,
      );

  /// The tail a sale being edited started with — its own number is not "in use".
  String? _editingOriginalPhoneKey;

  /// The buyer key a sale being edited started with — it never matches itself.
  String? _editingOriginalBuyerKey;

  void _rememberEditingOriginals() {
    _editingOriginalPhoneKey = PhoneUtils.normalizePhone(phoneCtrl.text);
    _editingOriginalBuyerKey =
        _currentBuyerKey(Get.find<LocalCacheService>().getBuyerKeyTitles());
    phoneDuplicateError.value = null;
    phoneSharedNote.value = null;
  }

  // Step 3 — Location
  final selectedState = ''.obs;
  final selectedLga = ''.obs;
  final fullAddressCtrl = TextEditingController();
  /// City/town/village. Goes inside `addressData.city`, which the app used to
  /// send as a hardcoded empty string. Mandatory from 2026-09-11.
  final cityCtrl = TextEditingController();
  final latitude = Rxn<double>();
  final longitude = Rxn<double>();
  List<String> get lgas =>
      Get.find<GeoDataService>().getLgas(selectedState.value);

  /// Centralized states list (geo-data cache → bundled fallback).
  List<String> get states => Get.find<GeoDataService>().states;

  // Step 4 — Partner/Retailer
  final partnerNameCtrl = TextEditingController();
  final retailerBranchCtrl = TextEditingController();

  /// The agent who sold the stove, as written on the agreement.
  ///
  /// Defaults to the signed-in person and stays editable: the person typing is
  /// not always the person who made the sale. `created_by` on the server keeps
  /// naming whoever made the record, so this never overwrites the audit trail.
  /// Mandatory from 2026-09-11.
  final salesAgentNameCtrl = TextEditingController();

  // ACSL agent: partner picker state
  bool get isAcslAgent => _session.isAcslAgent || _session.isAcslAgentManager;
  bool get isSuperAdmin => _session.role == 'super_admin';

  /// Roles that must pick a partner before selecting a stove.
  bool get needsPartnerPicker => isAcslAgent || isSuperAdmin;

  final selectedOrgId = ''.obs; // resolves to the selected BRANCH's org id
  final partnerSearchQuery = ''.obs;
  final RxList<Map<String, dynamic>> assignedPartners = <Map<String, dynamic>>[].obs;
  final isLoadingPartners = false.obs;

  // Partner -> State -> Branch cascade. `assignedPartners` holds one row per
  // branch (org), grouped by partner_name.
  final selectedPartnerName = ''.obs;
  final selectedBranchState = ''.obs;

  /// Distinct partners (one entry per partner_name).
  List<Map<String, dynamic>> get distinctPartners {
    final seen = <String, Map<String, dynamic>>{};
    for (final p in assignedPartners) {
      final name = (p['partner_name'] ?? p['name'] ?? '').toString();
      if (name.isNotEmpty) seen.putIfAbsent(name, () => p);
    }
    return seen.values.toList();
  }

  List<Map<String, dynamic>> get _branchesForPartner => assignedPartners
      .where((p) =>
          (p['partner_name'] ?? p['name'] ?? '').toString() == selectedPartnerName.value)
      .toList();

  /// States where the selected partner has a branch.
  List<String> get statesForSelectedPartner => (_branchesForPartner
          .map((b) => (b['state'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort());

  /// Branches of the selected partner within the selected state.
  List<Map<String, dynamic>> get branchesForSelectedState => _branchesForPartner
      .where((b) => (b['state'] ?? '').toString() == selectedBranchState.value)
      .toList();

  // Step 5 — Sale & Payment
  final amountCtrl = TextEditingController();
  final amountReceivedCtrl = TextEditingController();
  /// Every active sales model, cached globally. Never fetched per partner — a
  /// partner only carries the IDs, which we resolve against this list.
  final RxList<PaymentModel> paymentModels = <PaymentModel>[].obs;

  /// Sales model IDs the selected partner is entitled to, as delivered on the
  /// partner row by `manage-organizations`. `null` when no partner is picked
  /// yet or the backend could not tell us.
  final Rxn<List<String>> orgPaymentModelIds = Rxn<List<String>>();

  /// The models offered at point of sale: the global catalogue narrowed to the
  /// selected partner's entitlements. Pure lookup against already-cached data,
  /// so it works identically online and offline.
  ///
  /// A partner with NO assignments gets EVERY active model — the sync only
  /// covers partners the external app has sent, so restricting an unassigned
  /// partner to nothing would block sales rather than protect them. Only an
  /// explicit list restricts. `create-sale` applies the identical rule; if
  /// these diverge, the picker offers models the server then rejects.
  List<PaymentModel> get visiblePaymentModels {
    final ids = orgPaymentModelIds.value;
    if (ids == null || ids.isEmpty) return paymentModels;
    final allowed = ids.toSet();
    return paymentModels.where((m) => allowed.contains(m.id)).toList();
  }

  // null = full payment; non-null = installment with this model
  final selectedModel = Rxn<PaymentModel>();

  /// Payment type, as an explicit choice the user makes.
  ///
  /// The app used to infer this: a payment model meant installment, no model
  /// meant cash, and a cash sale therefore never sent `isInstallment` at all.
  /// Now it is its own control (Cash purchase / Installment purchase) and
  /// `isInstallment` is always sent. The payload keys do not change:
  /// `isInstallment` plus `paymentModelId` for the model.
  final isInstallmentSale = false.obs;

  bool get isInstallment => isInstallmentSale.value;

  /// Switches payment type, clearing the model when moving back to cash so a
  /// stale model cannot ride along on a cash sale.
  void setInstallmentSale(bool value) {
    isInstallmentSale.value = value;
    if (!value) selectedModel.value = null;
  }

  /// A full payment settles the whole sale amount up front, so sale amount and
  /// amount received are the same figure — the form asks for it once and
  /// mirrors it into both. Editing a synced sale keeps both fields visible so
  /// we never silently rewrite historical figures.
  bool get isSingleAmountField => !isEditingSale && !isInstallment;
  final initialPaymentCtrl = TextEditingController();
  final initialPaymentText = ''.obs;
  Timer? _initialPaymentDebounce;

  void onInitialPaymentChanged(String v) {
    _initialPaymentDebounce?.cancel();
    _initialPaymentDebounce = Timer(
      const Duration(milliseconds: 400),
      () => initialPaymentText.value = v,
    );
  }
  final selectedPaymentMethod = ''.obs;
  File? paymentProofImage;
  String? paymentProofImageId;
  final paymentProofSet = false.obs;
  final paymentProofFile = Rxn<File>();
  final paymentProofUploadProgress = Rxn<double>();

  // Step 6 — Stove Set
  final potQuantity = 1.obs;
  final heatRetentionDevice = false.obs;

  // Step 7 — Cooking Habits
  final previousStoveType = ''.obs;
  final previousStoveOtherCtrl = TextEditingController();
  final mealsPerDayCtrl = TextEditingController();
  // Choices, not free text: these carry dictionary option VALUES (`collect`,
  // `semi_indoor`), never the words on screen. The server used to guess-map
  // typed text ("market" -> purchase, "kitchen" -> indoor); it no longer has to.
  final cookingFuelSource = ''.obs;
  final cookingLocation = ''.obs;

  // Step 8 — T&C
  final tcPoaGoverned = false.obs;
  final tcMonitoring = false.obs;
  final tcNoResell = false.obs;
  final tcEmissions = false.obs;
  final tcNoExport = false.obs;
  final tcDemonstration = false.obs;
  bool get allTcAccepted =>
      tcPoaGoverned.value && tcMonitoring.value && tcNoResell.value &&
      tcEmissions.value && tcNoExport.value && tcDemonstration.value;

  void setAllTc(bool v) {
    tcPoaGoverned.value = v;
    tcMonitoring.value = v;
    tcNoResell.value = v;
    tcEmissions.value = v;
    tcNoExport.value = v;
    tcDemonstration.value = v;
  }

  // Step 9 — Media
  File? stoveImage;
  String? stoveImageId;
  final stoveImageSet = false.obs;
  final stoveImageFile = Rxn<File>();
  final stoveImageUploadProgress = Rxn<double>();
  // Remote preview for an existing sale's stove/agreement photo (edit mode) —
  // no local File exists for these until the user replaces them.
  final existingStoveImageUrl = Rxn<String>();
  File? agreementImage;
  String? agreementImageId;
  final agreementImageSet = false.obs;
  final agreementImageFile = Rxn<File>();
  final agreementImageUploadProgress = Rxn<double>();
  final existingAgreementImageUrl = Rxn<String>();
  bool get hasSignature =>
      signatureController.isNotEmpty ||
      signatureImageFile.value != null ||
      _existingSignatureB64 != null;
  String? get existingSignatureB64 => _existingSignatureB64;

  /// Signature drawing is LOCKED by default; the pad only captures strokes once
  /// the user toggles this on. Prevents accidental marks while scrolling the
  /// form up/down on a touch screen.
  final signatureDrawEnabled = false.obs;

  /// An uploaded signature image (an alternative to drawing on the pad). When
  /// set, its bytes are carried in [_existingSignatureB64] and sent as the
  /// signature, and this file is shown as a preview.
  final signatureImageFile = Rxn<File>();

  /// Bumped whenever signature state changes (draw end, upload, clear) so Obx
  /// widgets re-read [hasSignature] — the pad controller itself is not an Rx.
  final signatureRevision = 0.obs;

  /// Pick a signature image from the gallery instead of drawing it. Routed
  /// through [pickImage] so it gets the same downscale/compress + lost-capture
  /// recovery that keeps low-memory devices from crashing.
  Future<void> pickSignatureImage() => pickImage(ImageSource.gallery, field: 'signature');

  /// Capture a signature photo with the camera. Uses the identical
  /// memory-safe capture path as the stove photo.
  Future<void> takeSignaturePhoto() => pickImage(ImageSource.camera, field: 'signature');

  /// Resolve the signature to raw base64 for the payload/queue. Priority:
  /// a freshly drawn signature, then a captured/uploaded image, then a
  /// signature carried over from an edited queued sale.
  Future<String?> _resolveSignatureB64() async {
    final sigBytes = await signatureController.toPngBytes();
    if (sigBytes != null) return base64Encode(sigBytes);
    final file = signatureImageFile.value;
    if (file != null) return base64Encode(await file.readAsBytes());
    return _existingSignatureB64;
  }

  /// Clears both a drawn signature and any uploaded signature image.
  void clearSignature() {
    signatureController.clear();
    _existingSignatureB64 = null;
    signatureImageFile.value = null;
    signatureRevision.value++;
  }

  // Option lists
  final paymentMethods = ['Cash', 'Bank Transfer', 'POS', 'Mobile Money'];

  // ─────────────────────── The sale field dictionary ────────────────────────
  //
  // The agreement's wording, the choices and the day each field becomes
  // mandatory all come from `GET /functions/v1/sale-dictionary` at run time.
  // Nothing here is typed into the app: an administrator can relabel a field,
  // retire a choice or move a mandatory date without a release.
  //
  // Held as an Rx so the form redraws if the refresh lands after the screen is
  // already open. Null only on a cold first install with no network AND no
  // bundled seed, in which case the fallbacks below keep the form usable.

  final dictionary = Rxn<SaleFieldDictionary>();

  /// The agreement's wording for [key], falling back to [fallback] when the
  /// dictionary has not loaded or does not carry the field.
  String dictLabel(String key, String fallback) =>
      dictionary.value?.labelFor(key, fallback: fallback) ?? fallback;

  /// Whether [key] is required for THIS sale, judged by the sale's own date.
  ///
  /// A record is judged by the rules of its own day, so back-dating a sale to
  /// before a rule came in correctly relaxes that rule for it.
  bool dictRequired(String key) =>
      dictionary.value?.isRequired(key, salesDate.value) ?? false;

  /// The choices for [key]. Empty until the dictionary loads, which is why the
  /// widgets below fall back to their seeded list rather than an empty menu.
  List<SaleFieldOption> dictOptions(String key) =>
      dictionary.value?.optionsFor(key) ?? const [];

  /// Choices for [key] as value→label, for the existing dropdown widgets.
  ///
  /// [seed] is used only while the dictionary is still loading. When a stored
  /// [current] value is no longer on the live list it is appended, so a record
  /// holding a retired choice keeps it instead of silently blanking on edit.
  Map<String, String> dictOptionMap(
    String key, {
    Map<String, String> seed = const {},
    String? current,
  }) {
    final live = dictOptions(key);
    final map = live.isEmpty
        ? Map<String, String>.from(seed)
        : {for (final o in live) o.value: o.label};
    if (current != null && current.isNotEmpty && !map.containsKey(current)) {
      map[current] = current;
    }
    return map;
  }

  /// Seed lists, used ONLY until the dictionary answers.
  ///
  /// These mirror the dictionary's values (`firewood`, `charcoal`, `lpg`), not
  /// the older `wood_stove` the app used to send — the server used to map that
  /// by rule, and no longer has to.
  static const _seedStoveTypes = {
    'firewood': 'Firewood',
    'charcoal': 'Charcoal',
    'lpg': 'LPG',
  };
  static const _seedFuelSources = {
    'collect': 'Collect it',
    'purchase': 'Purchase it',
  };
  static const _seedCookingLocations = {
    'indoor': 'Indoor',
    'outdoor': 'Outdoor',
    'semi_indoor': 'Semi-indoor',
  };

  Map<String, String> get stoveTypes => dictOptionMap('previous_stove_type',
      seed: _seedStoveTypes, current: previousStoveType.value);
  Map<String, String> get fuelSources => dictOptionMap('cooking_fuel_source',
      seed: _seedFuelSources, current: cookingFuelSource.value);
  Map<String, String> get cookingLocations => dictOptionMap('cooking_location',
      seed: _seedCookingLocations, current: cookingLocation.value);

  /// Pot quantities as ints, from the dictionary's `0` / `1` / `2`.
  List<int> get potQuantities {
    final live = dictOptions('pot_quantity');
    if (live.isEmpty) return const [0, 1, 2];
    final parsed = live
        .map((o) => int.tryParse(o.value))
        .whereType<int>()
        .toList();
    return parsed.isEmpty ? const [0, 1, 2] : parsed;
  }

  // Cached Google API keys (fetched from Supabase, not .env)
  String? _googlePlacesApiKey;
  String? _googleMapsApiKey;

  // Tracks whether we're in offline mode to switch the location UI
  final isOfflineMode = false.obs;

  /// Once the connection drops — or proves itself unstable — mid-sale we LATCH
  /// into offline mode and STAY there for the rest of this sale, even if the
  /// network returns.
  ///
  /// Reacting to every transition is actively harmful on the flapping 2G/edge
  /// links this app runs on: the address section swaps under the agent's
  /// fingers, and `doSubmit` can commit to a live upload on a link that dies a
  /// second later, stranding them on a timeout. Latching keeps the form
  /// predictable and makes submit instant (queue + background sync).
  ///
  /// The agent leaves offline mode only by explicitly tapping the action on the
  /// "connection is stable" prompt — never automatically.
  bool _offlineLatched = false;
  bool get offlineLatched => _offlineLatched;

  /// Set when a latched-offline sale regains a genuinely STABLE connection, so
  /// the UI can offer a switch back. Cleared once acted on or re-latched.
  final showBackOnlinePrompt = false.obs;

  // Keys for single-view scroll-to-section on validation error
  final singleViewKeys = <int, GlobalKey>{
    0: GlobalKey(), 1: GlobalKey(), 2: GlobalKey(),
    4: GlobalKey(), 5: GlobalKey(), 6: GlobalKey(),
    7: GlobalKey(), 8: GlobalKey(),
  };

  @override
  void onInit() {
    super.onInit();
    // Observe app lifecycle so we can pull back a camera capture that Android
    // discarded when it killed the process mid-shot (see recoverLostImage).
    WidgetsBinding.instance.addObserver(this);
    // Keep [hasSignature]-driven Obx widgets in sync — the pad controller isn't
    // an Rx, so we bump a revision each time a stroke finishes.
    signatureController.onDrawEnd = () => signatureRevision.value++;
    // Keep Contact Person / Phone mirrored to the end-user details while the
    // "same as end user" box is ticked (matches the web form's auto-fill).
    endUserNameCtrl.addListener(_syncContactFromEndUser);
    endUserSurnameCtrl.addListener(_syncContactFromEndUser);
    phoneCtrl.addListener(_syncContactFromEndUser);
    // Full payment collects one amount that serves as both sale amount and
    // amount received; installments keep the two independent.
    amountCtrl.addListener(_syncAmountReceivedForFullPayment);
    amountReceivedCtrl.addListener(_dropInstallmentWhenPaidInFull);
    // Also attempt recovery immediately in case this controller is being
    // recreated right after such a kill.
    recoverLostImage();
    transactionId.value = _generateTransactionId();
    // The sale form's wording, choices and mandatory dates. The cached or
    // bundled copy resolves immediately so the form has labels on first paint;
    // the refresh lands later and the Obx widgets redraw if anything moved.
    _loadDictionary();
    // The agent who sold the stove defaults to the signed-in person, editable.
    salesAgentNameCtrl.text = _session.userName ?? '';
    partnerNameCtrl.text = _session.organizationName ?? '';
    retailerBranchCtrl.text = _session.organizationBranch ?? '';
    isOfflineMode.value = !_connectivity.isOnline.value;
    if (isOfflineMode.value) _offlineLatched = true;

    ever(_connectivity.isOnline, (online) {
      // Dropping latches us offline for the rest of this sale. We deliberately
      // do NOT flip back when `online` returns true — see [_offlineLatched].
      if (!online) _latchOffline();
      // Online-ness is decided by an active probe that may resolve AFTER init,
      // so the first catalogue load can have run against a false "offline".
      // Retry the moment we know we're online and still have nothing.
      if (online && paymentModels.isEmpty) _loadPaymentModels();
    });

    // A link that keeps bouncing is unusable even while it reads "online" —
    // latch before it can thrash the form or strand a submit.
    ever(_connectivity.isFlapping, (flapping) {
      if (flapping) _latchOffline();
    });

    // Only OFFER the switch back once the connection is genuinely settled
    // (consecutive healthy probes + no recent drops), never on a bare reconnect.
    ever(_connectivity.isStable, (stable) {
      if (stable && _offlineLatched && !isSubmitting.value) {
        showBackOnlinePrompt.value = true;
      }
    });
    // Offline from the start: pre-capture the current position by default so the
    // agent never has to tap "use current location" before proceeding.
    if (isOfflineMode.value) ensureDeviceLocation();
    // Recompute the Places autocomplete bias whenever state/LGA change, so
    // address search is streamlined to the selected area (mirrors the web).
    ever(selectedState, (_) => _updatePlacesBias());
    ever(selectedLga, (_) => _updatePlacesBias());
    // The full catalogue is loaded and cached once; the picker is then narrowed
    // to the selected partner's entitlements in memory. Sales models are tied to
    // a partner again, sourced from the external sync — never fetched per
    // partner (see docs/backend/payment-model-decoupling.md).
    _loadPaymentModels();
    if (needsPartnerPicker) {
      // Super admin & ACSL agents pick a partner first; stoves load after.
      _fetchPartnersForRole();
    } else {
      // Org-scoped roles sell for their own partner — resolve its entitlements
      // from the cached partner rows.
      _applyOwnOrganizationPaymentModels();
      _loadStoves();
    }
    _fetchGoogleKeys();
  }

  /// Resolves the signed-in user's own partner entitlements for roles that do
  /// not use the partner picker. Cache-only — no network call, so it behaves
  /// the same offline. If the org isn't in the cached rows the list stays
  /// `null` (unknown) and every model remains selectable.
  void _applyOwnOrganizationPaymentModels() =>
      _applyPaymentModelsForOrgId(_session.organizationId);

  /// Re-resolves entitlements for the org already selected, against the current
  /// `assignedPartners`. Used after a partner refresh replaces stale rows.
  void _reapplyPaymentModelsForSelectedOrg() {
    final orgId = selectedOrgId.value;
    if (orgId.isEmpty) return;
    final row = assignedPartners.firstWhereOrNull(
      (p) => p['id']?.toString() == orgId,
    );
    if (row != null) _applyPartnerPaymentModels(row);
  }

  /// Looks an organization up in the cached partner rows and applies its sales
  /// model entitlements. Used when we hold an org ID but not the row itself
  /// (own-org roles, and restoring a queued draft).
  void _applyPaymentModelsForOrgId(String? orgId) {
    if (orgId == null || orgId.isEmpty) return;
    final cached = Get.find<LocalCacheService>().getAssignedPartners();
    final row = cached.firstWhereOrNull((p) => p['id']?.toString() == orgId);
    if (row != null) _applyPartnerPaymentModels(row);
  }

  /// Partner picker source: super admin = all orgs; ACSL agents/managers = their
  /// assigned partners + assigned-state partners. Direct-table filtered.
  Future<void> _fetchPartnersForRole() async {
    final userId = _session.userId;
    if (userId == null || userId.isEmpty) return;
    final cache = Get.find<LocalCacheService>();

    final cached = cache.getAssignedPartners();
    if (cached.isNotEmpty) assignedPartners.assignAll(cached);
    if (!_connectivity.isOnline.value) return;

    isLoadingPartners.value = true;
    try {
      final rows = await _partnerAccess.partnersForUser(
        userId: userId,
        role: _session.role,
      );
      assignedPartners.assignAll(rows);
      cache.saveAssignedPartners(rows);
      // The cached rows shown while this was in flight may predate
      // `payment_model_ids` (cached before the field existed), which reads as
      // "unknown" and shows every model. Re-apply from the fresh rows so a
      // partner picked during the fetch gets its real entitlements.
      _reapplyPaymentModelsForSelectedOrg();
    } catch (_) {
      // keep cached list on failure
    } finally {
      isLoadingPartners.value = false;
    }
  }

  /// Step 1 of the cascade — pick a partner by name. Resets the state/branch
  /// selection below it. Auto-advances when there is only one state.
  void onPartnerNameSelected(String name) {
    selectedPartnerName.value = name;
    partnerNameCtrl.text = name;
    partnerSearchQuery.value = '';
    selectedBranchState.value = '';
    _clearBranchSelection();
    final states = statesForSelectedPartner;
    if (states.length == 1) onBranchStateSelected(states.first);
  }

  /// Step 2 — pick the partner's state. Auto-advances when only one branch.
  void onBranchStateSelected(String state) {
    selectedBranchState.value = state;
    _clearBranchSelection();
    final branches = branchesForSelectedState;
    if (branches.length == 1) onBranchSelected(branches.first);
  }

  /// Step 3 — pick the branch; this resolves the organization_id and loads stoves.
  void onBranchSelected(Map<String, dynamic> branch) {
    final orgId = branch['id']?.toString() ?? '';
    selectedOrgId.value = orgId;
    retailerBranchCtrl.text = (branch['branch'] ?? '').toString();
    _applyPartnerPaymentModels(branch);
    if (orgId.isNotEmpty) _loadStovesForOrg(orgId);
  }

  /// Reads the partner's sales model IDs off the org row. Absent key (an older
  /// cached row, or a backend that failed to look them up) leaves the list
  /// `null` so the seller still sees every model rather than none.
  void _applyPartnerPaymentModels(Map<String, dynamic> org) {
    final raw = org['payment_model_ids'];
    orgPaymentModelIds.value = raw is List
        ? raw.map((e) => e.toString()).toList()
        : null;
    _dropSelectedModelIfNotAllowed();
    _refreshCatalogueIfIdsUnknown();
  }

  /// The sync mints sales models on the fly, so a partner can reference a model
  /// that did not exist when this catalogue was cached — leaving the picker
  /// wrongly empty. Refresh once when we meet an unknown ID and we're online.
  /// Offline we keep the cached list; there is nothing better to be had.
  bool _refreshedForUnknownIds = false;
  Future<void> _refreshCatalogueIfIdsUnknown() async {
    final ids = orgPaymentModelIds.value;
    if (ids == null || ids.isEmpty) return;
    if (_refreshedForUnknownIds || !_connectivity.isOnline.value) return;

    final known = paymentModels.map((m) => m.id).toSet();
    if (ids.every(known.contains)) return;

    _refreshedForUnknownIds = true;
    await _loadPaymentModels();
    _dropSelectedModelIfNotAllowed();
  }

  /// No catalogue at all — a load failure, not a partner problem. Blaming the
  /// partner's models here sends you hunting in entirely the wrong place.
  bool get paymentCatalogueEmpty => paymentModels.isEmpty;

  /// The partner is assigned models that aren't in the catalogue we DO have —
  /// they're inactive, or newer than our cache. Distinct from having none
  /// assigned (which now means "all models") and from an empty catalogue.
  bool get partnerModelsUnresolved {
    final ids = orgPaymentModelIds.value;
    return ids != null &&
        ids.isNotEmpty &&
        paymentModels.isNotEmpty &&
        visiblePaymentModels.isEmpty;
  }

  /// A model chosen for a previous partner must not survive into this one.
  void _dropSelectedModelIfNotAllowed() {
    final current = selectedModel.value;
    if (current == null) return;
    if (!visiblePaymentModels.any((m) => m.id == current.id)) {
      selectPaymentType(null);
    }
  }

  void _clearBranchSelection() {
    selectedOrgId.value = '';
    retailerBranchCtrl.text = '';
    availableStoves.clear();
    selectedStove.value = null;
    orgPaymentModelIds.value = null;
    _dropSelectedModelIfNotAllowed();
  }

  /// Reset the whole partner cascade (the "change partner" action).
  void clearPartnerSelection() {
    selectedPartnerName.value = '';
    partnerNameCtrl.clear();
    selectedBranchState.value = '';
    _clearBranchSelection();
    partnerSearchQuery.value = '';
  }

  Future<void> _loadStovesForOrg(String orgId) async {
    final cache = Get.find<LocalCacheService>();
    isLoadingStoves.value = true;

    List<StoveModel> stoves;
    if (_connectivity.isOnline.value) {
      // Page through EVERY available stove for this org. A partner can hold
      // thousands; a single call returns only the first page (max 500), which
      // is exactly why a specific stove id visible on the web was missing here.
      const pageSize = 500;
      final all = <StoveModel>[];
      var offset = 0;
      var ok = false;
      while (true) {
        final resp = await _service.getAvailableStovesForOrg(orgId, limit: pageSize, offset: offset);
        if (!resp.success || resp.data == null) break;
        ok = true;
        final data = resp.data;
        final list = data is List
            ? data
            : ((data as Map?))?['data'] as List? ?? [];
        all.addAll(list
            .map((e) => StoveModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((s) => s.stoveId.isNotEmpty));

        final total = data is Map
            ? int.tryParse('${(data['pagination'] as Map?)?['total']}')
            : null;
        offset += pageSize;
        if (list.length < pageSize) break;
        if (total != null && offset >= total) break;
      }
      if (ok) {
        stoves = all;
        cache.saveStovesForOrg(orgId, stoves);
      } else {
        stoves = cache.getStovesForOrg(orgId);
      }
    } else {
      stoves = cache.getStovesForOrg(orgId);
    }

    final pendingIds = await _queue.getPendingStoveIds();
    availableStoves.assignAll(
      pendingIds.isEmpty
          ? stoves
          : stoves.where((s) => !pendingIds.contains(s.stoveId)).toList(),
    );
    isLoadingStoves.value = false;
  }


  Future<void> _fetchGoogleKeys() async {
    final cache = Get.find<LocalCacheService>();
    final cached = cache.getGoogleKeys();
    if (cached != null) {
      _googlePlacesApiKey = cached['placesKey'];
      _googleMapsApiKey = cached['mapsKey'];
    }
    if (!_connectivity.isOnline.value) return;
    final resp = await _service.getGoogleKeys();
    if (resp.success && resp.data != null) {
      final data = Map<String, dynamic>.from(resp.data as Map);
      _googlePlacesApiKey = data['placesKey'] as String?;
      _googleMapsApiKey = data['mapsKey'] as String?;
      cache.saveGoogleKeys(_googlePlacesApiKey ?? '', _googleMapsApiKey ?? '');
    }
  }

  String _generateTransactionId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(6, (i) => chars[(now ~/ (i + 1)) % chars.length]).join();
  }

  /// Wipes every field back to a pristine state and issues a fresh transaction
  /// ID, so the next sale starts clean. Called after a successful submit — the
  /// controller instance is reused, so without this the old values linger.
  void resetForm() {
    // A brand-new transaction for the next sale.
    transactionId.value = _generateTransactionId();

    // Step 1 — Transaction / stove
    selectedStove.value = null;
    stoveSearchQuery.value = '';
    salesDate.value = DateTime.now();

    // Step 2 — Contact
    sameAsEndUser.value = false;
    contactPersonCtrl.clear();
    contactPhoneCtrl.clear();
    endUserNameCtrl.clear();
    endUserSurnameCtrl.clear();
    akaCtrl.clear();
    phoneCtrl.clear();
    otherPhoneCtrl.clear();

    // Step 3 — Location
    selectedState.value = '';
    selectedLga.value = '';
    fullAddressCtrl.clear();
    latitude.value = null;
    longitude.value = null;

    // Step 4 — Partner cascade. Super admin / ACSL pick every time; other roles
    // keep their own org defaults.
    if (needsPartnerPicker) {
      clearPartnerSelection();
    } else {
      partnerNameCtrl.text = _session.organizationName ?? '';
      retailerBranchCtrl.text = _session.organizationBranch ?? '';
    }

    // Step 5 — Sale & Payment
    amountCtrl.clear();
    amountReceivedCtrl.clear();
    selectedModel.value = null;
    isInstallmentSale.value = false;
    initialPaymentCtrl.clear();
    initialPaymentText.value = '';
    selectedPaymentMethod.value = '';
    clearImage('paymentProof');

    // Step 6 — Stove set
    potQuantity.value = 1;
    heatRetentionDevice.value = false;

    // Step 7 — Cooking habits
    previousStoveType.value = '';
    previousStoveOtherCtrl.clear();
    mealsPerDayCtrl.clear();
    cookingFuelSource.value = '';
    cookingLocation.value = '';
    cityCtrl.clear();
    salesAgentNameCtrl.text = _session.userName ?? '';

    // Step 8 — Terms
    tcPoaGoverned.value = false;
    tcMonitoring.value = false;
    tcNoResell.value = false;
    tcEmissions.value = false;
    tcNoExport.value = false;
    tcDemonstration.value = false;

    // Step 9 — Media + signature
    clearImage('stove');
    clearImage('agreement');
    signatureController.clear();
    _existingSignatureB64 = null;
    signatureImageFile.value = null;
    signatureDrawEnabled.value = false;
    signatureRevision.value++;

    // Reset navigation to the first step.
    currentStep.value = 0;
    if (pageController.hasClients) {
      pageController.jumpToPage(0);
    }
    _editingQueueId = null;
    editingSaleId.value = null;
    _editingOriginalPhoneKey = null;
    _editingOriginalBuyerKey = null;
    phoneSharedNote.value = null;
    _hydrated = false;
    _hydratedSaleId = null;
  }

  /// Loads a queued (pending/failed) sale back into the form for editing.
  /// Submitting afterwards updates that same queue row (see [_editingQueueId]).
  Future<void> hydrateFromQueue(int queueId) async {
    if (_hydrated && _editingQueueId == queueId) return;
    final row = await _queue.getById(queueId);
    if (row == null) return;
    _hydrated = true;
    _editingQueueId = queueId;

    final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;

    transactionId.value = payload['transactionId']?.toString() ?? transactionId.value;

    // Contact / end user
    contactPersonCtrl.text = payload['contactPerson']?.toString() ?? '';
    contactPhoneCtrl.text = payload['contactPhone']?.toString() ?? '';
    // endUserName is stored combined ("first surname"); split it back so the
    // first-name / surname fields repopulate. Legacy drafts may still carry a
    // separate endUserSurname — honour it when present.
    final queuedFullName = (payload['endUserName']?.toString() ?? '').trim();
    final queuedSurname = payload['endUserSurname']?.toString();
    if (queuedSurname != null && queuedSurname.isNotEmpty) {
      endUserNameCtrl.text = queuedFullName;
      endUserSurnameCtrl.text = queuedSurname;
    } else {
      final parts = queuedFullName.isEmpty ? <String>[] : queuedFullName.split(RegExp(r'\s+'));
      endUserNameCtrl.text = parts.isNotEmpty ? parts.first : '';
      endUserSurnameCtrl.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }
    akaCtrl.text = payload['aka']?.toString() ?? '';
    phoneCtrl.text = payload['phone']?.toString() ?? '';
    otherPhoneCtrl.text = payload['otherPhone']?.toString() ?? '';
    // A queued sale being edited already owns its phone and name — remember
    // them so the check doesn't flag the draft against itself.
    _rememberEditingOriginals();

    // Location
    selectedState.value = payload['stateBackup']?.toString() ?? '';
    selectedLga.value = payload['lgaBackup']?.toString() ?? '';
    final addr = payload['addressData'] is Map
        ? Map<String, dynamic>.from(payload['addressData'] as Map)
        : <String, dynamic>{};
    fullAddressCtrl.text = addr['fullAddress']?.toString() ?? '';
    latitude.value = (addr['latitude'] as num?)?.toDouble();
    longitude.value = (addr['longitude'] as num?)?.toDouble();

    // Partner / branch
    partnerNameCtrl.text = payload['partnerName']?.toString() ?? '';
    retailerBranchCtrl.text = payload['retailerBranch']?.toString() ?? '';
    if (payload['partnerName'] != null) {
      selectedPartnerName.value = payload['partnerName'].toString();
    }
    if (payload['organizationId'] != null) {
      selectedOrgId.value = payload['organizationId'].toString();
      _applyPaymentModelsForOrgId(selectedOrgId.value);
    }

    // Stove — reconstruct enough for display/submit.
    if (payload['stoveId'] != null) {
      selectedStove.value = StoveModel(
        stoveId: payload['stoveId'].toString(),
        serialNo: payload['stoveSerialNo']?.toString(),
        organizationId: payload['organizationId']?.toString(),
      );
    }

    // Sale & payment
    amountCtrl.text = _fmtAmountInput(payload['amount']);
    amountReceivedCtrl.text = _fmtAmountInput(payload['amountReceived']);
    isInstallmentSale.value = payload['isInstallment'] == true;
    if (payload['isInstallment'] == true && payload['paymentModelId'] != null) {
      selectedModel.value =
          paymentModels.firstWhereOrNull((m) => m.id == payload['paymentModelId'].toString());
    }
    // A draft saved before full payment collapsed to a single field can carry a
    // received figure below the amount. The form would then show only the
    // amount while submitting the stale figure, so realign it now.
    _syncAmountReceivedForFullPayment();
    if (payload['initialPaymentAmount'] != null) {
      initialPaymentCtrl.text = _fmtAmountInput(payload['initialPaymentAmount']);
      initialPaymentText.value = initialPaymentCtrl.text;
    }
    selectedPaymentMethod.value = payload['initialPaymentMethod']?.toString() ?? '';

    // Stove set
    potQuantity.value = (payload['potQuantity'] as num?)?.toInt() ?? 1;
    heatRetentionDevice.value = payload['heatRetentionDevice'] == true;

    // Cooking habits
    previousStoveType.value = payload['previousStoveType']?.toString() ?? '';
    previousStoveOtherCtrl.text = payload['previousStoveOther']?.toString() ?? '';
    mealsPerDayCtrl.text = payload['mealsPerDay']?.toString() ?? '';
    cookingFuelSource.value = payload['cookingFuelSource']?.toString() ?? '';
    cookingLocation.value = payload['cookingLocation']?.toString() ?? '';
    cityCtrl.text =
        (payload['addressData'] is Map ? payload['addressData']['city'] : null)
                ?.toString() ??
            '';
    salesAgentNameCtrl.text = payload['salesAgentName']?.toString() ?? '';

    // Terms
    final terms = payload['termsAccepted'] is Map
        ? Map<String, dynamic>.from(payload['termsAccepted'] as Map)
        : <String, dynamic>{};
    tcPoaGoverned.value = terms['poaGoverned'] == true;
    tcMonitoring.value = terms['monitoring'] == true;
    tcNoResell.value = terms['noResell'] == true;
    tcEmissions.value = terms['emissionReductions'] == true;
    tcNoExport.value = terms['noExport'] == true;
    tcDemonstration.value = terms['demonstration'] == true;

    // Images / signature (stored as base64 in the queue row).
    final imagesRaw = row['images'] as String?;
    if (imagesRaw != null) {
      try {
        final imgs = Map<String, dynamic>.from(jsonDecode(imagesRaw) as Map);
        final stoveFile = await _b64ToTempFile(imgs['stove_image'] as String?, 'stove');
        if (stoveFile != null) {
          stoveImage = stoveFile;
          stoveImageFile.value = stoveFile;
          stoveImageSet.value = true;
        }
        final agrFile = await _b64ToTempFile(imgs['agreement_image'] as String?, 'agreement');
        if (agrFile != null) {
          agreementImage = agrFile;
          agreementImageFile.value = agrFile;
          agreementImageSet.value = true;
        }
        final proofFile = await _b64ToTempFile(imgs['payment_proof'] as String?, 'proof');
        if (proofFile != null) {
          paymentProofImage = proofFile;
          paymentProofFile.value = proofFile;
          paymentProofSet.value = true;
        }
        _existingSignatureB64 = imgs['signature'] as String?;
      } catch (e) {
        _logger.w('Failed to decode queued images: $e');
      }
    }
  }

  /// Loads an already-synced sale into the form for editing. Fetches full detail
  /// (address, signature, terms) via get-sale, then submitting calls update-sale
  /// (online only — see [_submitEdit]).
  Future<void> hydrateFromSale(SaleModel listSale) async {
    if (_hydratedSaleId == listSale.id) return;
    _hydratedSaleId = listSale.id;
    _hydrated = true;
    editingSaleId.value = listSale.id;

    // Pull full detail; fall back to the list row if the fetch fails.
    SaleModel sale = listSale;
    try {
      final resp = await _service.getSale(listSale.id);
      if (resp.success && resp.data != null) {
        final raw = resp.data;
        if (raw is Map) {
          final inner = raw['sale'] ?? raw['data'] ?? raw;
          if (inner is Map) {
            sale = SaleModel.fromJson(Map<String, dynamic>.from(inner));
          }
        }
      }
    } catch (e) {
      _logger.w('get-sale for edit failed: $e');
    }

    transactionId.value = sale.transactionId;
    salesDate.value = sale.salesDate ?? DateTime.now();

    // Prefer the parts the server holds; only fall back to splitting the joined
    // name for an older record saved before the app sent them.
    //
    // Re-guessing the split is what used to swap surname and aka on edit: a
    // one-word name put everything in the first name, a three-word one put two
    // words in the surname, and neither matched what was stored. The server now
    // keeps the parts, so this guesses only when it must.
    final storedFirst = (sale.endUserFirstName ?? '').trim();
    final storedSurname = (sale.endUserSurname ?? '').trim();
    if (storedFirst.isNotEmpty || storedSurname.isNotEmpty) {
      endUserNameCtrl.text = storedFirst;
      endUserSurnameCtrl.text = storedSurname;
    } else {
      final fullName = (sale.endUserName ?? '').trim();
      final parts =
          fullName.isEmpty ? <String>[] : fullName.split(RegExp(r'\s+'));
      endUserNameCtrl.text = parts.isNotEmpty ? parts.first : '';
      endUserSurnameCtrl.text =
          parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }
    akaCtrl.text = sale.aka ?? '';
    phoneCtrl.text = sale.phone ?? '';
    contactPersonCtrl.text = sale.contactPerson ?? '';
    contactPhoneCtrl.text = sale.contactPhone ?? '';
    otherPhoneCtrl.text = sale.otherPhone ?? '';
    // Editing a sale owns its phone and name — never flag it against itself.
    _rememberEditingOriginals();
    // Detect whether the contact person actually IS the end user (matches web
    // behaviour) so the "Same as end user" checkbox reflects saved data instead
    // of always starting unticked on edit.
    // Recomposed from the two fields above, whichever way they were filled.
    final fullName = [endUserNameCtrl.text.trim(), endUserSurnameCtrl.text.trim()]
        .where((p) => p.isNotEmpty)
        .join(' ');
    sameAsEndUser.value = contactPersonCtrl.text.trim() == fullName &&
        contactPhoneCtrl.text.trim() == phoneCtrl.text.trim();
    phoneDuplicateError.value = null;

    // Location — canonicalized to the geo catalogue's casing so the pickers show
    // the saved values (mirrors web normalizeSaleLocation).
    final loc = _canonicalizeLocation(sale.state, sale.lga);
    selectedState.value = loc.$1;
    selectedLga.value = loc.$2;
    fullAddressCtrl.text = sale.address ?? '';
    latitude.value = sale.latitude;
    longitude.value = sale.longitude;

    // Partner / branch — read-only in edit mode. selectedOrgId must still be
    // populated even though the picker itself is locked: validateAll() requires
    // it for super admin / ACSL agents, and it's otherwise only ever set via
    // the (hidden-in-edit) branch picker.
    partnerNameCtrl.text = sale.partnerName ?? '';
    retailerBranchCtrl.text = sale.retailerBranch ?? '';
    selectedPartnerName.value = sale.partnerName ?? '';
    selectedOrgId.value = sale.organizationId ?? '';

    // Stove — locked in edit mode.
    if (sale.stoveSerialNo != null || sale.stoveId != null) {
      selectedStove.value = StoveModel(
        stoveId: sale.stoveId ?? sale.stoveSerialNo ?? '',
        serialNo: sale.stoveSerialNo,
      );
    }

    // Amount (locked) + amount received. The collected figure lives in
    // `total_paid` server-side (there is no `amount_received` column — see
    // SaleModel.paidAmount), so read it through that fallback or the amount
    // received field ends up blank/zero even though a real value was saved.
    amountCtrl.text = _fmtAmountInput(sale.amount);
    amountReceivedCtrl.text = _fmtAmountInput(sale.paidAmount);

    // Payment model — locked in edit mode.
    final pmId = sale.paymentModelId ?? sale.selectedModelId;
    isInstallmentSale.value = sale.isInstallment == true;
    if (sale.isInstallment == true && pmId != null) {
      selectedModel.value = paymentModels.firstWhereOrNull((m) => m.id == pmId);
    }

    // Stove set.
    potQuantity.value = sale.potQuantity ?? 1;
    heatRetentionDevice.value = sale.heatRetentionDevice ?? false;

    // Cooking habits.
    previousStoveType.value = sale.previousStoveType ?? '';
    previousStoveOtherCtrl.text = sale.previousStoveOther ?? '';
    mealsPerDayCtrl.text = sale.mealsPerDay ?? '';
    cookingFuelSource.value = sale.cookingFuelSource ?? '';
    cookingLocation.value = sale.cookingLocation ?? '';
    cityCtrl.text = sale.city ?? '';
    // Falls back to the signed-in person only when the record carries no seller
    // — an older sale saved before the app sent this field.
    salesAgentNameCtrl.text = sale.salesAgentName ?? _session.userName ?? '';

    // Terms.
    final terms = sale.termsAccepted ?? const {};
    tcPoaGoverned.value = terms['poaGoverned'] == true;
    tcMonitoring.value = terms['monitoring'] == true;
    tcNoResell.value = terms['noResell'] == true;
    tcEmissions.value = terms['emissionReductions'] == true;
    tcNoExport.value = terms['noExport'] == true;
    tcDemonstration.value = terms['demonstration'] == true;

    // Existing image ids preserved so an untouched edit keeps its photos.
    stoveImageId = sale.stoveImageId;
    agreementImageId = sale.agreementImageId;
    stoveImageSet.value = sale.stoveImageId != null;
    agreementImageSet.value = sale.agreementImageId != null;
    existingStoveImageUrl.value = sale.stoveImageUrl;
    existingAgreementImageUrl.value = sale.agreementImageUrl;

    // Existing signature (base64) reused unless the user re-signs/uploads.
    _existingSignatureB64 = sale.signature;
    signatureRevision.value++;
  }

  /// Canonicalize a persisted state/LGA to the geo catalogue's exact casing so
  /// the strict-match pickers render the saved values. Returns (state, lga).
  (String, String) _canonicalizeLocation(String? rawState, String? rawLga) {
    final geo = Get.find<GeoDataService>();
    var state = (rawState ?? '').trim();
    final matchState =
        geo.states.firstWhereOrNull((s) => s.toLowerCase() == state.toLowerCase());
    if (matchState != null) state = matchState;

    var lga = (rawLga ?? '').trim();
    if (state.isNotEmpty && lga.isNotEmpty) {
      final matchLga = geo
          .getLgas(state)
          .firstWhereOrNull((l) => l.toLowerCase() == lga.toLowerCase());
      if (matchLga != null) lga = matchLga;
    }
    return (state, lga);
  }

  String _fmtAmountInput(dynamic v) {
    final n = (v as num?)?.toDouble();
    if (n == null || n == 0) return '';
    return n.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  Future<File?> _b64ToTempFile(String? b64, String tag) async {
    if (b64 == null || b64.isEmpty) return null;
    try {
      final bytes = base64Decode(b64);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/edit_${tag}_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      return file;
    } catch (_) {
      return null;
    }
  }

  // ── Developer test-autofill backdoor ──────────────────────────────────────
  // Triple-tapping the "Create Sale" title fills the whole form from a rotating
  // set of sample Nigerian sales so a submit can be tested without retyping.
  // Gated by LocalCacheService.devAutofillEnabled (toggle in Profile).

  int _testDataIndex = 0;
  int _titleTapCount = 0;
  DateTime? _lastTitleTap;

  bool get devAutofillEnabled =>
      Get.find<LocalCacheService>().devAutofillEnabled;

  /// Counts rapid taps on the app-bar title; three within 1.2s triggers the
  /// test-autofill backdoor (when enabled).
  void onTitleTap() {
    if (!devAutofillEnabled) return;
    final now = DateTime.now();
    if (_lastTitleTap == null ||
        now.difference(_lastTitleTap!) > const Duration(milliseconds: 1200)) {
      _titleTapCount = 0;
    }
    _lastTitleTap = now;
    _titleTapCount++;
    if (_titleTapCount >= 3) {
      _titleTapCount = 0;
      applyTestData();
    }
  }

  /// Fills every field from the next sample sale. Images are populated from a
  /// bundled asset; the signature must still be drawn by hand.
  Future<void> applyTestData() async {
    if (!devAutofillEnabled) return;
    final sample = kSampleSales[_testDataIndex % kSampleSales.length];
    _testDataIndex++;

    // Contact / end user
    contactPersonCtrl.text = sample['contactPerson'] ?? '';
    contactPhoneCtrl.text = sample['contactPhone'] ?? '';
    endUserNameCtrl.text = sample['endUserName'] ?? '';
    endUserSurnameCtrl.text = sample['endUserSurname'] ?? '';
    akaCtrl.text = sample['aka'] ?? '';
    phoneCtrl.text = sample['phone'] ?? '';
    otherPhoneCtrl.text = sample['otherPhone'] ?? '';

    // Location — set state/LGA (must exist in NigeriaData) + a coordinate so
    // GPS validation passes. Real vs vague addresses exercise map matching.
    selectedState.value = sample['state'] ?? '';
    if (Get.find<GeoDataService>()
        .getLgas(selectedState.value)
        .contains(sample['lga'])) {
      selectedLga.value = sample['lga'];
    }
    fullAddressCtrl.text = sample['fullAddress'] ?? '';
    final coord = _sampleCoordinate(selectedState.value);
    latitude.value = coord.$1;
    longitude.value = coord.$2;

    // Partner cascade / stove. Super admin & ACSL agents must pick from the
    // loaded partner list; other roles pick from their org's stoves.
    if (needsPartnerPicker) {
      final partners = distinctPartners;
      if (partners.isNotEmpty) {
        onPartnerNameSelected(
            (partners.first['partner_name'] ?? partners.first['name'] ?? '').toString());
        final states = statesForSelectedPartner;
        if (states.isNotEmpty && selectedBranchState.value.isEmpty) {
          onBranchStateSelected(states.first);
        }
        final branches = branchesForSelectedState;
        if (branches.isNotEmpty && selectedOrgId.value.isEmpty) {
          onBranchSelected(branches.first);
        }
        // Stoves load asynchronously after the branch is chosen.
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }
    if (availableStoves.isNotEmpty) {
      selectedStove.value = availableStoves.first;
    }

    // Sale & payment — full payment, amount + received.
    selectedModel.value = null;
    isInstallmentSale.value = false;
    amountCtrl.text = (sample['amount'] ?? 0).toString();
    amountReceivedCtrl.text = (sample['amountReceived'] ?? sample['amount'] ?? 0).toString();
    selectedPaymentMethod.value = 'Cash';

    // Stove set
    potQuantity.value = (sample['potQuantity'] as int?) ?? 1;
    heatRetentionDevice.value = (sample['heatRetentionDevice'] as bool?) ?? false;

    // Cooking habits (optional)
    previousStoveType.value = sample['previousStoveType'] ?? '';
    previousStoveOtherCtrl.text = sample['previousStoveOther'] ?? '';
    mealsPerDayCtrl.text = sample['mealsPerDay'] ?? '';
    cookingFuelSource.value = sample['cookingFuelSource'] ?? '';
    cookingLocation.value = sample['cookingLocation'] ?? '';
    cityCtrl.text = sample['city'] ?? '';
    salesAgentNameCtrl.text = _session.userName ?? '';

    // Accept all terms
    tcPoaGoverned.value = true;
    tcMonitoring.value = true;
    tcNoResell.value = true;
    tcEmissions.value = true;
    tcNoExport.value = true;
    tcDemonstration.value = true;

    // Images from a bundled asset (stove + agreement). Signature drawn by hand.
    final assetFile = await _assetToTempFile('assets/images/save80_logo.png');
    if (assetFile != null) {
      stoveImage = assetFile;
      stoveImageId = null;
      stoveImageFile.value = assetFile;
      stoveImageSet.value = true;
      agreementImage = assetFile;
      agreementImageId = null;
      agreementImageFile.value = assetFile;
      agreementImageSet.value = true;
    }

    _showSuccess('Test data filled — draw a signature, then submit.');
  }

  /// Approximate center coordinate per state so autofilled sales land in a
  /// plausible spot. Falls back to Lagos.
  (double, double) _sampleCoordinate(String state) {
    const centers = <String, (double, double)>{
      'Lagos': (6.5244, 3.3792),
      'Kano': (12.0022, 8.5919),
      'Oyo': (7.3775, 3.9470),
      'Rivers': (4.8156, 7.0498),
      'FCT': (9.0765, 7.3986),
      'Enugu': (6.5244, 7.5106),
    };
    return centers[state] ?? (6.5244, 3.3792);
  }

  /// Copies a bundled asset to a temp file so it can be used where the form
  /// expects a picked [File].
  Future<File?> _assetToTempFile(String assetPath) async {
    try {
      final bytes = await rootBundle.load(assetPath);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/test_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      return file;
    } catch (e) {
      _logger.w('Test asset load failed: $e');
      return null;
    }
  }

  Future<void> _loadStoves() async {
    isLoadingStoves.value = true;
    final cache = Get.find<LocalCacheService>();
    List<StoveModel> stoves;
    if (_connectivity.isOnline.value) {
      final resp = await _service.getAvailableStoves();
      if (resp.success && resp.data != null) {
        final list = resp.data is List ? resp.data as List : ((resp.data as Map?))?['data'] as List? ?? [];
        stoves = list
            .map((e) => StoveModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((s) => s.stoveId.isNotEmpty)
            .toList();
        cache.saveStoves(stoves);
      } else {
        stoves = cache.getStoves();
      }
    } else {
      stoves = cache.getStoves();
    }
    // Exclude stoves that are already sold in pending offline queue
    final pendingIds = await _queue.getPendingStoveIds();
    if (pendingIds.isNotEmpty) {
      stoves = stoves.where((s) => !pendingIds.contains(s.stoveId)).toList();
    }
    availableStoves.assignAll(stoves);
    isLoadingStoves.value = false;
  }

  Future<void> _loadPaymentModels() async {
    final cache = Get.find<LocalCacheService>();

    // Seed from cache FIRST, always. The online check below relies on an active
    // network probe that often hasn't resolved at init, so gating the cache read
    // on "offline" used to leave the catalogue empty on a fast connection.
    final cached = cache.getPaymentModels();
    if (cached.isNotEmpty && paymentModels.isEmpty) {
      paymentModels.assignAll(cached);
    }

    if (!_connectivity.isOnline.value) return;

    try {
      final resp = await _service.getAllActivePaymentModels();
      if (!resp.success || resp.data == null) {
        // Keep whatever the cache gave us rather than blanking the picker.
        return;
      }
      final raw = resp.data is List ? resp.data as List : ((resp.data as Map?))?['data'] as List? ?? [];
      // 'payment-models' returns plain models; tolerate a nested shape too.
      final list = raw.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        return map.containsKey('payment_model') && map['payment_model'] is Map
            ? Map<String, dynamic>.from(map['payment_model'] as Map)
            : map;
      }).where((m) => m['id'] != null).toList();
      final models = list.map((e) => PaymentModel.fromJson(e)).toList();
      // An empty response is almost always a transient auth/network fault; a
      // real catalogue is never empty. Don't overwrite good cached data with it.
      if (models.isEmpty && paymentModels.isNotEmpty) return;
      paymentModels.assignAll(models);
      cache.savePaymentModels(models);
    } catch (_) {
      // Cached list stands; the connectivity listener retries when we're back.
    }
  }

  // Guards the two amount listeners against re-entering each other.
  bool _syncingAmounts = false;

  /// Full payment shows one amount field; keep the received figure identical to
  /// it so the payload stays consistent with what the user was shown.
  void _syncAmountReceivedForFullPayment() {
    if (_syncingAmounts || !isSingleAmountField) return;
    if (amountReceivedCtrl.text == amountCtrl.text) return;
    _syncingAmounts = true;
    amountReceivedCtrl.text = amountCtrl.text;
    _syncingAmounts = false;
  }

  /// An installment sale settled in full at the point of sale isn't an
  /// installment sale — fall back to full payment, keeping the amount entered.
  void _dropInstallmentWhenPaidInFull() {
    if (_syncingAmounts || !isInstallment || isEditingSale) return;
    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '')) ?? 0;
    final received = double.tryParse(amountReceivedCtrl.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0 || received < amount) return;
    selectPaymentType(null, keepAmount: true);
  }

  /// Called when the user picks a value from the Payment Type dropdown.
  /// [modelId] is null for full payment, or a model ID for installment.
  /// [keepAmount] retains the sale amount already entered instead of clearing
  /// it — used when an installment collapses into a full payment.
  void selectPaymentType(String? modelId, {bool keepAmount = false}) {
    if (modelId == null) {
      // Full payment selected
      selectedModel.value = null;
      isInstallmentSale.value = false;
      if (keepAmount) {
        _syncAmountReceivedForFullPayment();
      } else {
        amountCtrl.clear();
        amountReceivedCtrl.clear();
      }
      initialPaymentCtrl.clear();
      initialPaymentText.value = '';
      selectedPaymentMethod.value = '';
      clearImage('paymentProof');
    } else {
      final model = paymentModels.firstWhereOrNull((m) => m.id == modelId);
      selectedModel.value = model;
      isInstallmentSale.value = true;
      if (model != null) {
        // Auto-fill amount with the model's fixed price
        final formatted = model.fixedPrice.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
        amountCtrl.text = formatted;
        // The model fixes the sale amount; the received figure now means the
        // initial payment, so it has to be entered fresh.
        amountReceivedCtrl.clear();
        initialPaymentCtrl.clear();
        initialPaymentText.value = '';
        selectedPaymentMethod.value = '';
        clearImage('paymentProof');
      }
    }
  }

  // ── Address / map helpers ─────────────────────────────────────────────────

  // Autocomplete bias derived from the selected state/LGA. Center is geocoded
  // from "LGA, State, Nigeria"; radius is tighter for an LGA, wider for state.
  double? _biasLat;
  double? _biasLng;
  int _biasRadius = 0;

  /// Geocode the selected state/LGA to a center point used to bias address
  /// search. Mirrors the web GooglePlacesInput locationBias behaviour.
  Future<void> _updatePlacesBias() async {
    final state = selectedState.value.trim();
    final lga = selectedLga.value.trim();
    if (state.isEmpty) {
      _biasLat = null;
      _biasLng = null;
      _biasRadius = 0;
      return;
    }
    final key = _googleMapsApiKey ?? _googlePlacesApiKey;
    if (key == null || key.isEmpty) return;
    final address = [lga, state, 'Nigeria'].where((s) => s.isNotEmpty).join(', ');
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'address': address,
        'region': 'ng',
        'key': key,
      });
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final results = body['results'] as List? ?? [];
        // Ignore a stale response if the selection changed while awaiting.
        if (state != selectedState.value.trim() || lga != selectedLga.value.trim()) {
          return;
        }
        if (results.isNotEmpty) {
          final loc = ((results[0] as Map)['geometry'] as Map?)?['location'] as Map?;
          if (loc != null) {
            _biasLat = (loc['lat'] as num).toDouble();
            _biasLng = (loc['lng'] as num).toDouble();
            // Tighter radius when an LGA is chosen, wider for state-only.
            _biasRadius = lga.isNotEmpty ? 20000 : 60000;
            return;
          }
        }
      }
      _biasLat = null;
      _biasLng = null;
      _biasRadius = 0;
    } catch (e) {
      _logger.e('Places bias geocode error: $e');
      _biasLat = null;
      _biasLng = null;
      _biasRadius = 0;
    }
  }

  /// Search Places autocomplete (Nigeria-restricted, biased to selected area).
  Future<List<Map<String, String>>> searchPlaces(String query) async {
    if (query.length < 3) return [];
    final key = _googlePlacesApiKey;
    if (key == null || key.isEmpty) return [];
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
        'input': query,
        'components': 'country:ng',
        if (_biasLat != null && _biasLng != null) 'location': '$_biasLat,$_biasLng',
        if (_biasLat != null && _biasLng != null) 'radius': '$_biasRadius',
        'key': key,
      });
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return (body['predictions'] as List? ?? [])
            .map((p) => {'description': p['description'] as String, 'place_id': p['place_id'] as String})
            .toList();
      }
    } catch (e) {
      _logger.e('Places search error: $e');
    }
    return [];
  }

  /// Fetch place details (lat/lng + state) and apply to form fields.
  Future<({double lat, double lng, String address})?>
      fetchPlaceDetails(String placeId) async {
    final key = _googlePlacesApiKey;
    if (key == null || key.isEmpty) return null;
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
        'place_id': placeId,
        'fields': 'geometry,formatted_address,address_components',
        'key': key,
      });
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final result = body['result'] as Map<String, dynamic>?;
        if (result != null) {
          final loc = (result['geometry'] as Map?)?['location'] as Map?;
          final address = result['formatted_address'] as String? ?? '';
          if (loc != null) {
            final lat = (loc['lat'] as num).toDouble();
            final lng = (loc['lng'] as num).toDouble();
            _applyStateFromComponents(result['address_components'] as List? ?? []);
            return (lat: lat, lng: lng, address: address);
          }
        }
      }
    } catch (e) {
      _logger.e('Place details error: $e');
    }
    return null;
  }

  /// Reverse geocode a lat/lng to a human-readable address string.
  Future<String?> reverseGeocode(double lat, double lng) async {
    final key = _googleMapsApiKey ?? _googlePlacesApiKey;
    if (key == null || key.isEmpty) return null;
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'latlng': '$lat,$lng',
        'key': key,
      });
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final results = body['results'] as List? ?? [];
        if (results.isNotEmpty) {
          _applyStateFromComponents((results[0] as Map)['address_components'] as List? ?? []);
          return (results[0] as Map)['formatted_address'] as String?;
        }
      }
    } catch (e) {
      _logger.e('Reverse geocode error: $e');
    }
    return null;
  }

  void _applyStateFromComponents(List components) {
    for (final c in components) {
      final types = (c['types'] as List?)?.cast<String>() ?? [];
      if (types.contains('administrative_area_level_1')) {
        final stateName = (c['long_name'] as String? ?? '').replaceAll(' State', '').trim();
        final match = Get.find<GeoDataService>().states.firstWhereOrNull(
          (s) => s.toLowerCase() == stateName.toLowerCase(),
        );
        if (match != null) {
          selectedState.value = match;
          selectedLga.value = '';
        }
      }
    }
  }

  /// True once we've captured the device's position for this offline sale, so
  /// the location UI can show "GPS auto-filled from your current position".
  final autoGpsCaptured = false.obs;

  /// Pin the form to offline mode for the rest of this sale. Idempotent, so the
  /// repeated drops of a flapping link don't re-trigger the GPS capture.
  void _latchOffline() {
    final alreadyOffline = isOfflineMode.value;
    _offlineLatched = true;
    isOfflineMode.value = true;
    // A pending "you're stable again" offer is stale the moment we drop.
    showBackOnlinePrompt.value = false;
    // Went offline mid-form with no coordinate yet → grab the device position in
    // the background so the sale can be submitted without GPS friction.
    if (!alreadyOffline) ensureDeviceLocation();
  }

  /// Leave latched offline mode. Only ever called from an explicit user action
  /// on the "stable connection" prompt — never automatically.
  void switchToOnline() {
    _offlineLatched = false;
    showBackOnlinePrompt.value = false;
    isOfflineMode.value = !_connectivity.isOnline.value;
    // The catalogue may have been skipped while we were offline.
    if (paymentModels.isEmpty) _loadPaymentModels();
  }

  /// Dismiss the offer without leaving offline mode. It will be re-offered if
  /// the connection drops and settles again.
  void dismissBackOnlinePrompt() => showBackOnlinePrompt.value = false;

  /// Silently captures the device's current GPS position and fills lat/lng —
  /// NO dialogs, snackbars or errors. Used offline so a field agent who forgets
  /// to tap "use current location" still submits a valid coordinate instead of
  /// being blocked by the "GPS required" validation. If a coordinate is already
  /// set (map pick / manual capture) or permission/GPS is unavailable, it's a
  /// no-op. [force] re-captures even if a coordinate exists.
  Future<void> ensureDeviceLocation({bool force = false}) async {
    if (!force && latitude.value != null && longitude.value != null) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 12));
      latitude.value = pos.latitude;
      longitude.value = pos.longitude;
      autoGpsCaptured.value = true;
    } catch (e) {
      // Best-effort only: never surface an error here. If it fails, the typed
      // address still carries the sale; the 0,0 fallback covers the rest.
      _logger.w('Silent GPS capture failed: $e');
    }
  }

  void confirmMapLocation({required double lat, required double lng, required String address}) {
    latitude.value = lat;
    longitude.value = lng;
    fullAddressCtrl.text = address;
  }

  List<StoveModel> get filteredStoves {
    if (stoveSearchQuery.value.isEmpty) return availableStoves;
    final q = stoveSearchQuery.value.toLowerCase();
    return availableStoves.where((s) => s.displayId.toLowerCase().contains(q)).toList();
  }

  bool canProceed(int step) {
    switch (step) {
      case 0: return selectedStove.value != null;
      case 1: return endUserNameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty;
      case 2: return selectedState.value.isNotEmpty && fullAddressCtrl.text.isNotEmpty;
      case 3: return needsPartnerPicker ? selectedOrgId.value.isNotEmpty : partnerNameCtrl.text.isNotEmpty;
      case 4: return amountCtrl.text.isNotEmpty;
      case 5: return true;
      case 6: return true;
      case 7: return allTcAccepted;
      case 8: return hasSignature; // stove & agreement images now optional
      default: return true;
    }
  }

  /// Resolves the dictionary, then refreshes it in the background.
  ///
  /// A failure at either step leaves the previous copy in place: the form must
  /// stay usable with no signal, which is the ordinary case in the field.
  Future<void> _loadDictionary() async {
    final service = Get.find<SaleDictionaryService>();
    dictionary.value = await service.ensureLoaded();
    final fresh = await service.refresh();
    if (fresh != null) dictionary.value = fresh;
  }

  /// Adds an error when a dictionary-owned field is required for this sale and
  /// is empty.
  ///
  /// The message uses the agreement's wording, so what the form refuses and
  /// what the paper says are the same words. [fallbackLabel] only shows if the
  /// dictionary has not loaded.
  void _requireFromDictionary(
    List<ValidationError> errors, {
    required String key,
    required String value,
    required int step,
    required String stepTitle,
    required String fallbackLabel,
  }) {
    if (!dictRequired(key)) return;
    if (value.trim().isNotEmpty) return;
    final label = dictLabel(key, fallbackLabel);
    errors.add(ValidationError(
      step: step,
      stepTitle: stepTitle,
      field: label,
      message: '$label is required',
    ));
  }

  List<ValidationError> validateAll() {
    final errors = <ValidationError>[];

    // Partner -> State -> Branch (super admin & ACSL agents must pick a branch).
    if (needsPartnerPicker && selectedOrgId.value.isEmpty) {
      errors.add(const ValidationError(step: 0, stepTitle: 'Transaction Info', field: 'Partner', message: 'Select a partner, state and branch'));
    }

    // Step 1 — Buyer & End User
    if (contactPersonCtrl.text.trim().isEmpty) {
      errors.add(const ValidationError(step: 1, stepTitle: 'Buyer & End User', field: 'Contact Person', message: 'Contact person / buyer is required'));
    }
    if (contactPhoneCtrl.text.trim().isEmpty) {
      errors.add(const ValidationError(step: 1, stepTitle: 'Buyer & End User', field: 'Contact Phone', message: 'Contact phone number is required'));
    }
    // Required-ness comes from the dictionary's mandatoryFrom, judged against
    // THIS sale's date — so the 2026-09-11 and 2027-01-05 waves switch
    // themselves on with no release, and a back-dated draft is judged by the
    // rules of its own day. The labels are the agreement's wording.
    _requireFromDictionary(
      errors,
      key: 'end_user_first_name',
      value: endUserNameCtrl.text,
      step: 1,
      stepTitle: 'Buyer & End User',
      fallbackLabel: 'First name',
    );
    _requireFromDictionary(
      errors,
      key: 'end_user_surname',
      value: endUserSurnameCtrl.text,
      step: 1,
      stepTitle: 'Buyer & End User',
      fallbackLabel: 'Surname',
    );
    if (phoneCtrl.text.trim().isEmpty) {
      errors.add(const ValidationError(step: 1, stepTitle: 'Buyer & End User', field: 'End User Phone', message: 'End user phone number is required'));
    } else if (phoneDuplicateError.value != null) {
      // Re-stated at submit as well as inline: the inline flag can be scrolled
      // past, and a duplicate is rejected by the server anyway.
      errors.add(ValidationError(step: 1, stepTitle: 'Buyer & End User', field: 'End User Phone', message: phoneDuplicateError.value!));
    }

    // Step 4 — Sale & Payment
    if (selectedStove.value == null) {
      errors.add(const ValidationError(step: 4, stepTitle: 'Sale & Payment', field: 'Stove', message: 'Please select a stove'));
    }

    // Step 2 — Location
    if (selectedState.value.isEmpty) {
      errors.add(const ValidationError(step: 2, stepTitle: 'Location', field: 'State', message: 'State is required'));
    }
    if (fullAddressCtrl.text.trim().isEmpty) {
      errors.add(const ValidationError(step: 2, stepTitle: 'Location', field: 'Address', message: 'Full address is required'));
    }
    _requireFromDictionary(
      errors,
      key: 'city',
      value: cityCtrl.text,
      step: 2,
      stepTitle: 'Location',
      fallbackLabel: 'City/town/village',
    );
    _requireFromDictionary(
      errors,
      key: 'sales_agent_name',
      value: salesAgentNameCtrl.text,
      step: 0,
      stepTitle: 'Transaction Info',
      fallbackLabel: "Sales agent's name",
    );
    _requireFromDictionary(
      errors,
      key: 'previous_stove_type',
      value: previousStoveType.value,
      step: 7,
      stepTitle: 'Cooking Habits',
      fallbackLabel: 'Baseline stove',
    );
    _requireFromDictionary(
      errors,
      key: 'cooking_fuel_source',
      value: cookingFuelSource.value,
      step: 7,
      stepTitle: 'Cooking Habits',
      fallbackLabel: 'Fuel source',
    );
    _requireFromDictionary(
      errors,
      key: 'cooking_location',
      value: cookingLocation.value,
      step: 7,
      stepTitle: 'Cooking Habits',
      fallbackLabel: 'Cooking location',
    );
    _requireFromDictionary(
      errors,
      key: 'pot_quantity',
      value: '${potQuantity.value}',
      step: 6,
      stepTitle: 'Stove Set',
      fallbackLabel: 'Pots quantity',
    );
    // GPS is OPTIONAL. A raw address (not on Google Maps) can be typed manually
    // and submitted without coordinates — they default to 0,0 in _buildPayload.

    // Step 4 — Sale Details
    final amt = double.tryParse(amountCtrl.text.replaceAll(',', ''));
    if (amt == null || amt <= 0) {
      errors.add(const ValidationError(step: 4, stepTitle: 'Sale Details', field: 'Amount', message: 'A valid sale amount is required'));
    }
    // Amount received cannot exceed the sale amount
    final receivedText = amountReceivedCtrl.text.replaceAll(',', '').trim();
    final received = receivedText.isEmpty ? null : double.tryParse(receivedText);
    if (received != null && amt != null && received > amt) {
      errors.add(const ValidationError(step: 4, stepTitle: 'Sale Details', field: 'Amount Received', message: 'Amount received cannot be greater than the sale amount'));
    }

    // M6 — a part payment on a cash sale must name a payment plan.
    //
    // The server's outright path sets total_paid to the FULL amount, so a cash
    // sale saved with less than the full sum collected is recorded as paid in
    // full and the shortfall disappears from every report. The web's bench
    // applies the same rule at the form: no payment plan is only allowed when
    // the money collected settles the sale.
    //
    // Refused here, on the field, rather than at submit — once it reaches the
    // server the figure is already wrong.
    if (!isInstallmentSale.value &&
        amt != null &&
        amt > 0 &&
        received != null &&
        received + 0.005 < amt) {
      errors.add(const ValidationError(
        step: 4,
        stepTitle: 'Sale & Payment',
        field: 'Payment type',
        message:
            'This is a part payment, so it needs an installment plan. Either '
            'collect the full amount or switch to Installment purchase.',
      ));
    }
    // Step 6 — Cooking Habits (all optional — no validation)

    // The CPA block. Required from 2026-09-11 by the dictionary; the app has
    // always asked for it, so this only ever relaxes for a back-dated draft.
    if (!allTcAccepted && dictRequired('terms_accepted')) {
      final label = dictLabel('terms_accepted', 'CPA (Terms and Conditions)');
      errors.add(ValidationError(
          step: 7,
          stepTitle: 'Terms & Conditions',
          field: label,
          message: 'All $label consents must be accepted'));
    }

    // Step 8 — Media
    // Stove image is now OPTIONAL (agreement image already was). A sale can be
    // submitted without any photo; the backend records it as incomplete/pending.
    // Agreement image no longer required
    // if (!agreementImageSet.value) {
    //   errors.add(const ValidationError(step: 8, stepTitle: 'Documents & Signature', field: 'Agreement Image', message: 'Agreement image is required'));
    // }
    if (!hasSignature) {
      errors.add(const ValidationError(step: 8, stepTitle: 'Documents & Signature', field: 'Signature', message: 'Customer signature is required'));
    }

    return errors;
  }

  void nextStep() {
    if (!canProceed(currentStep.value)) {
      _showError('Please complete all required fields before proceeding.');
      return;
    }
    if (currentStep.value < 8) {
      // For ACSL agents step 3 (Partner) is shown, so navigate normally.
      // For all others step 3 is hidden — skip from 2 → 4.
      final next = (!isAcslAgent && currentStep.value == 2) ? 4 : currentStep.value + 1;
      currentStep.value = next;
      pageController.animateToPage(next, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void previousStep() {
    if (currentStep.value > 0) {
      final prev = (!isAcslAgent && currentStep.value == 4) ? 2 : currentStep.value - 1;
      currentStep.value = prev;
      pageController.animateToPage(prev, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void clearImage(String field) {
    if (field == 'stove') {
      stoveImage = null;
      stoveImageId = null;
      stoveImageFile.value = null;
      stoveImageUploadProgress.value = null;
      stoveImageSet.value = false;
      existingStoveImageUrl.value = null;
    } else if (field == 'agreement') {
      agreementImage = null;
      agreementImageId = null;
      agreementImageFile.value = null;
      agreementImageUploadProgress.value = null;
      agreementImageSet.value = false;
      existingAgreementImageUrl.value = null;
    } else if (field == 'paymentProof') {
      paymentProofImage = null;
      paymentProofImageId = null;
      paymentProofFile.value = null;
      paymentProofUploadProgress.value = null;
      paymentProofSet.value = false;
    }
  }

  /// Which image field a camera capture is currently in flight for. Needed so
  /// [recoverLostImage] can route an OS-recovered photo back to the right slot
  /// after the process was killed mid-capture (see below).
  String? _pendingImageField;

  Future<void> pickImage(ImageSource source, {required String field}) async {
    // No app-level camera permission is requested here by design. image_picker
    // launches the system camera app (ACTION_IMAGE_CAPTURE), which carries its
    // own permission — and the app no longer declares CAMERA in the manifest,
    // so there is nothing to grant. Gating here was the source of the recurring
    // "camera access is blocked" false negative. The gallery picker likewise
    // carries its own grant. Genuine failures are caught below.
    _pendingImageField = field;
    XFile? xFile;
    try {
      xFile = await _picker.pickImage(
        source: source,
        // Downscale + compress at capture time. Full-resolution camera frames
        // on modern phones are 12-50MP; decoding them into memory on a
        // low-RAM/older device is what makes Android kill the app right after
        // "accept" (issue: APK crashes after taking the stove photo). Capping
        // the long edge and requesting no EXIF metadata keeps the bitmap small
        // and avoids the photo-library metadata permission path that also
        // crashes on some OEM ROMs.
        imageQuality: 60,
        maxWidth: 1280,
        maxHeight: 1280,
        requestFullMetadata: false,
      );
    } catch (e, st) {
      // A thrown PlatformException here (camera unavailable, permission race)
      // must NOT bubble up and tear down the create-sale flow — but it must not
      // be silent either. Returning without a word is what made a failing
      // camera look like a dead button with no explanation.
      _logger.w('pickImage failed for $field: $e', error: e, stackTrace: st);
      _pendingImageField = null;
      if (source == ImageSource.camera) {
        // The camera couldn't open — most often because it's genuinely blocked.
        // Offer the direct route to Settings plus the gallery fallback.
        _showCameraBlockedDialog();
      } else {
        _showError('Could not open the gallery. Please try again.');
      }
      return;
    }
    _pendingImageField = null;
    if (xFile == null) return;
    _attachPickedImage(File(xFile.path), field);
  }

  /// Recover a photo that was captured just before Android killed the app to
  /// reclaim memory. When the process is destroyed while the camera activity is
  /// in the foreground, [ImagePicker.pickImage]'s Future never completes — the
  /// result is instead cached by the plugin and must be pulled back with
  /// [retrieveLostData] once the app is recreated. Without this, the user's
  /// "APK restarted after accepting the stove photo" and lost the capture.
  Future<void> recoverLostImage() async {
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty) return;
      final file = response.file;
      if (file == null) return;
      // Fall back to 'stove' — the only camera field that ever caused the crash
      // and by far the most common capture — if we lost track of the target.
      _attachPickedImage(File(file.path), _pendingImageField ?? 'stove');
      _pendingImageField = null;
    } catch (e) {
      _logger.w('retrieveLostData failed: $e');
    }
  }

  void _attachPickedImage(File file, String field) {
    // Attach only — do NOT upload here. Pick-time uploads were the source of the
    // never-ending "Uploading…" spinner: on a weak/dropped connection the upload
    // request hangs with no timeout and the progress bar rolls forever. The file
    // now simply shows as "attached" instantly; the actual upload happens at
    // submit (online) or during offline-queue sync. Same UX online and offline.
    if (field == 'stove') {
      stoveImage = file;
      stoveImageId = null;
      stoveImageFile.value = file;
      stoveImageUploadProgress.value = null;
      stoveImageSet.value = true;
    } else if (field == 'agreement') {
      agreementImage = file;
      agreementImageId = null;
      agreementImageFile.value = file;
      agreementImageUploadProgress.value = null;
      agreementImageSet.value = true;
    } else if (field == 'paymentProof') {
      paymentProofImage = file;
      paymentProofImageId = null;
      paymentProofFile.value = file;
      paymentProofUploadProgress.value = null;
      paymentProofSet.value = true;
    } else if (field == 'signature') {
      // A captured/uploaded signature image. Its bytes are encoded to base64 at
      // submit time (see _resolveSignatureB64), so there is nothing to upload.
      signatureImageFile.value = file;
      signatureController.clear();
      signatureRevision.value++;
    }
  }

  Future<void> doSubmit() async {
    // Editing an already-synced sale takes a separate, online-only path.
    if (isEditingSale) {
      await _submitEdit();
      return;
    }
    isSubmitting.value = true;
    try {
      final payload = _buildPayload();

      // Respect the latch, not just the instantaneous link state. On a flapping
      // connection the probe can read "online" at this exact moment and then die
      // mid-upload, leaving the agent on a spinner. Queuing is instant and the
      // sale is never lost — SyncService pushes it once the link is genuinely up.
      if (isOfflineMode.value || !_connectivity.isOnline.value) {
        await _saveOffline(payload);
        return;
      }

      // Upload any images not yet uploaded (e.g. picked while offline)
      if (stoveImageId == null && stoveImage != null) {
        stoveImageUploadProgress.value = -1;
        final resp = await _uploadFile(stoveImage, 'stove_image');
        stoveImageId = resp?.id;
        stoveImageUploadProgress.value = resp != null ? 1.0 : null;
      }
      if (agreementImageId == null && agreementImage != null) {
        agreementImageUploadProgress.value = -1;
        final resp = await _uploadFile(agreementImage, 'agreement_image');
        agreementImageId = resp?.id;
        agreementImageUploadProgress.value = resp != null ? 1.0 : null;
      }
      if (paymentProofImageId == null && paymentProofImage != null) {
        paymentProofUploadProgress.value = -1;
        final resp = await _uploadFile(paymentProofImage, 'payment_proof');
        paymentProofImageId = resp?.id;
        paymentProofUploadProgress.value = resp != null ? 1.0 : null;
      }

      // Signature goes as raw base64 in the payload (matches frontend format).
      final sig = await _resolveSignatureB64();
      if (sig != null) payload['signature'] = sig;

      if (stoveImageId != null) payload['stoveImageId'] = stoveImageId;
      if (agreementImageId != null) payload['agreementImageId'] = agreementImageId;
      if (paymentProofImageId != null) payload['initialPaymentProofImageId'] = paymentProofImageId;

      _logger.i('=== FINAL PAYLOAD (with image IDs) ===\n${const JsonEncoder.withIndent('  ').convert(payload)}');

      final resp = await _service.createSale(payload);
      if (resp.success) {
        // If this was an edit of a queued sale, remove that row now it synced.
        if (_editingQueueId != null) {
          await _queue.deleteById(_editingQueueId!);
        }
        // Reserve the phone locally right away. Waiting for the next full sync
        // would leave a window where this number still looks free.
        final cache = Get.find<LocalCacheService>();
        cache.addEndUserPhone(PhoneUtils.normalizePhone(payload['phone']?.toString()));
        cache.addBuyerKey(BuyerKey.ofPayload(payload, cache.getBuyerKeyTitles()));
        final shared = sharedTransactionIds(resp.data);
        _showSuccess(shared.isEmpty
            ? 'Sale created successfully!'
            : 'Sale created successfully! ${BuyerRuleMessages.s1(shared)}');
        resetForm();
        rootNavigatorKey.currentState?.pop(true);
      } else if (resp.errorCode == BuyerRuleMessages.sameBuyerCode) {
        // Same customer: never queued. A queued sale being edited keeps its
        // row untouched; the agent fixes the name or phone and resubmits.
        _showSameBuyerRefusal(resp.message);
      } else {
        _showError(resp.message);
      }
    } catch (e) {
      _logger.e('Submit error: $e');
      // Online submit failed (upload timeout, dropped connection, server error).
      // Don't lose the sale — queue it offline so it syncs later, exactly like a
      // sale created while offline. The agent keeps moving; nothing re-typed.
      try {
        await _saveOffline(_buildPayload());
      } catch (e2) {
        _logger.e('Offline fallback save failed: $e2');
        _showError('Failed to submit sale. Please try again.');
      }
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Update path for an already-synced sale. Online-only by decision: unlike a
  /// fresh create, an edit is never queued offline.
  Future<void> _submitEdit() async {
    if (isOfflineMode.value || !_connectivity.isOnline.value) {
      _showError('Editing a sale requires an internet connection. '
          'Reconnect and try again.');
      return;
    }
    isSubmitting.value = true;
    try {
      final payload = _buildPayload();

      // Upload any newly-picked images (re-picking clears the id so it re-uploads).
      if (stoveImageId == null && stoveImage != null) {
        stoveImageUploadProgress.value = -1;
        final resp = await _uploadFile(stoveImage, 'stove_image');
        stoveImageId = resp?.id;
        stoveImageUploadProgress.value = resp != null ? 1.0 : null;
      }
      if (agreementImageId == null && agreementImage != null) {
        agreementImageUploadProgress.value = -1;
        final resp = await _uploadFile(agreementImage, 'agreement_image');
        agreementImageId = resp?.id;
        agreementImageUploadProgress.value = resp != null ? 1.0 : null;
      }

      final sig = await _resolveSignatureB64();
      if (sig != null) payload['signature'] = sig;
      if (stoveImageId != null) payload['stoveImageId'] = stoveImageId;
      if (agreementImageId != null) payload['agreementImageId'] = agreementImageId;

      final resp = await _service.updateSale(editingSaleId.value!, payload);
      if (resp.success) {
        _showSuccess('Sale updated successfully!');
        resetForm();
        rootNavigatorKey.currentState?.pop(true);
      } else if (resp.errorCode == BuyerRuleMessages.sameBuyerCode) {
        _showSameBuyerRefusal(resp.message);
      } else {
        _showError(resp.message);
      }
    } catch (e) {
      _logger.e('Update sale error: $e');
      _showError('Failed to update sale. Please try again.');
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> _saveOffline(Map<String, dynamic> payload) async {
    final images = <String, String>{};
    if (stoveImage != null) images['stove_image'] = base64Encode(await stoveImage!.readAsBytes());
    if (agreementImage != null) images['agreement_image'] = base64Encode(await agreementImage!.readAsBytes());
    if (paymentProofImage != null) images['payment_proof'] = base64Encode(await paymentProofImage!.readAsBytes());
    final sig = await _resolveSignatureB64();
    if (sig != null) images['signature'] = sig;

    if (_editingQueueId != null) {
      // Editing a previously-queued sale — update that row in place instead of
      // creating a duplicate, and clear any prior sync error.
      await _queue.updateQueued(_editingQueueId!, payload: payload, imageBase64Map: images);
    } else {
      await _queue.enqueue(payload: payload, imageBase64Map: images);
    }
    toastification.show(
      title: const Text('Sale saved offline'),
      description: const Text('It will sync automatically when you are back online.'),
      type: ToastificationType.info,
      autoCloseDuration: const Duration(seconds: 5),
    );
    resetForm();
    rootNavigatorKey.currentState?.pop(true);
  }

  Future<UploadResponse?> _uploadFile(File? file, String type) async {
    if (file == null) return null;
    final resp = await _service
        .uploadImage(file, type)
        // Never let a stalled upload hang submit indefinitely; on timeout we
        // treat it as a failed upload (caller decides how to proceed).
        .timeout(const Duration(seconds: 45), onTimeout: () => throw TimeoutException('upload'));
    if (resp.success && resp.data != null) {
      final raw = Map<String, dynamic>.from(resp.data as Map);
      // Response may be { upload: { id, url } } or { id, url } directly
      final uploadMap = raw['upload'] is Map
          ? Map<String, dynamic>.from(raw['upload'] as Map)
          : raw;
      return UploadResponse.fromJson(uploadMap);
    }
    return null;
  }

  Map<String, dynamic> _buildPayload() {
    final initialPaymentAmount = double.tryParse(initialPaymentCtrl.text.replaceAll(',', ''));
    final payload = {
      'transactionId': transactionId.value,
      'stoveSerialNo': selectedStove.value?.displayId ?? '',
      'stoveId': selectedStove.value?.stoveId,
      'salesDate': salesDate.value.toIso8601String().substring(0, 10),
      'contactPerson': contactPersonCtrl.text,
      'contactPhone': contactPhoneCtrl.text,
      // The name goes BOTH ways, on purpose.
      //
      // The joined name stays because the web side has not yet said it can go.
      // The two parts stop the server guessing where the surname ends: it
      // composes the joined name from them before its own required-field check
      // (create-sale/index.ts:190-194) and writes end_user_first_name /
      // end_user_surname only when a part actually arrives (:598-603).
      //
      // An older comment here said the split caused the surname to be dropped.
      // That was true against the server of the day; the current function
      // handles both, so the parts are safe to send.
      'endUserName': [endUserNameCtrl.text.trim(), endUserSurnameCtrl.text.trim()]
          .where((s) => s.isNotEmpty)
          .join(' '),
      'endUserFirstName': endUserNameCtrl.text.trim(),
      'endUserSurname': endUserSurnameCtrl.text.trim(),
      'aka': akaCtrl.text,
      'phone': phoneCtrl.text,
      'otherPhone': otherPhoneCtrl.text,
      'stateBackup': selectedState.value,
      'lgaBackup': selectedLga.value,
      'addressData': {
        'fullAddress': fullAddressCtrl.text,
        'street': '',
        // Was hardcoded empty, so every sale sent a blank city. Mandatory from
        // 2026-09-11.
        'city': cityCtrl.text.trim(),
        'state': selectedState.value,
        'country': 'Nigeria',
        // GPS optional — default to 0,0 when the address was typed manually.
        'latitude': latitude.value ?? 0,
        'longitude': longitude.value ?? 0,
      },
      'partnerName': partnerNameCtrl.text,
      'retailerBranch': retailerBranchCtrl.text,
      // Who sold the stove, as written on the agreement. The server keeps
      // naming the record's creator separately in created_by.
      //
      // Omitted rather than sent empty while editing: an update that carried a
      // blank here would overwrite a seller the server already holds. The
      // server treats a missing key as "unchanged" and an empty one as "clear".
      if (!isEditingSale || salesAgentNameCtrl.text.trim().isNotEmpty)
        'salesAgentName': salesAgentNameCtrl.text.trim(),
      'amount': double.tryParse(amountCtrl.text.replaceAll(',', '')) ?? 0,
      'amountReceived': double.tryParse(amountReceivedCtrl.text.replaceAll(',', '')) ?? 0,
      'potQuantity': potQuantity.value,
      'heatRetentionDevice': heatRetentionDevice.value,
      'previousStoveType': previousStoveType.value,
      'previousStoveOther': previousStoveOtherCtrl.text,
      'mealsPerDay': mealsPerDayCtrl.text,
      // Dictionary option VALUES (`collect`, `semi_indoor`), never the labels.
      'cookingFuelSource': cookingFuelSource.value,
      'cookingLocation': cookingLocation.value,
      'termsAccepted': {
        'poaGoverned': tcPoaGoverned.value,
        'monitoring': tcMonitoring.value,
        'noResell': tcNoResell.value,
        'emissionReductions': tcEmissions.value,
        'noExport': tcNoExport.value,
        'demonstration': tcDemonstration.value,
      },
      'agentId': _session.userId,
      'platform': 'mobile',
      if (selectedOrgId.value.isNotEmpty) 'organizationId': selectedOrgId.value,
      // installment fields
      // Payment type is now an explicit choice, so isInstallment is ALWAYS sent.
      // It used to be omitted entirely for a cash sale, which left the server
      // inferring the type from the presence of a model.
      'isInstallment': isInstallmentSale.value,
      if (selectedModel.value != null) 'paymentModelId': selectedModel.value!.id,
      if (initialPaymentAmount != null && initialPaymentAmount > 0) ...{
        'initialPaymentAmount': initialPaymentAmount,
        'initialPaymentMethod': selectedPaymentMethod.value,
      },
    };

    _logger.i('=== CREATE SALE PAYLOAD ===\n${const JsonEncoder.withIndent('  ').convert(payload)}');

    return payload;
  }

  /// Transaction ids of other sales on this number, from a create-sale 200's
  /// `shares_phone_with`. Unnamed sales (null id) are left out.
  static List<String> sharedTransactionIds(dynamic body) {
    if (body is! Map || body['shares_phone_with'] is! List) return const [];
    return (body['shares_phone_with'] as List)
        .whereType<Map>()
        .map((e) => e['transaction_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
  }

  /// Server refused: same customer. The message is long and must be read,
  /// so it goes under the field (blocking resubmit until phone or name
  /// changes) and into a dialog that stays until closed — not a toast.
  void _showSameBuyerRefusal(String message) {
    phoneSharedNote.value = null;
    phoneDuplicateError.value = message;
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) {
      _showError(message);
      return;
    }
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Not saved'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('OK')),
        ],
      ),
    );
  }

  void _showError(String msg) {
    toastification.show(title: Text(msg), type: ToastificationType.error, autoCloseDuration: const Duration(seconds: 4));
  }

  /// Camera was permanently denied — a toast can't fix that, so offer a direct
  /// jump to the OS settings screen (the only place the block can be lifted),
  /// plus the gallery/upload fallback.
  void _showCameraBlockedDialog() {
    // This app uses MaterialApp.router (not GetMaterialApp), so Get.dialog has
    // no navigator — use the router's root context for showDialog.
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) {
      _showError('Camera access is blocked. Enable it in your device Settings, '
          'or upload from your gallery instead.');
      return;
    }
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Camera access is blocked'),
        content: const Text(
          'Camera permission is turned off for this app. Enable it in Settings '
          'to take a photo, or upload from your gallery instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              Get.find<PermissionService>().openSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String msg) {
    toastification.show(title: Text(msg), type: ToastificationType.success, autoCloseDuration: const Duration(seconds: 3));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning to the foreground after a camera capture is exactly when the
    // OS may have killed & recreated us — try to recover the lost photo.
    if (state == AppLifecycleState.resumed) recoverLostImage();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    pageController.dispose();
    signatureController.dispose();
    contactPersonCtrl.dispose();
    contactPhoneCtrl.dispose();
    endUserNameCtrl.dispose();
    endUserSurnameCtrl.dispose();
    akaCtrl.dispose();
    phoneCtrl.dispose();
    otherPhoneCtrl.dispose();
    fullAddressCtrl.dispose();
    partnerNameCtrl.dispose();
    retailerBranchCtrl.dispose();
    amountCtrl.removeListener(_syncAmountReceivedForFullPayment);
    amountReceivedCtrl.removeListener(_dropInstallmentWhenPaidInFull);
    amountCtrl.dispose();
    amountReceivedCtrl.dispose();
    initialPaymentCtrl.dispose();
    _initialPaymentDebounce?.cancel();
    _phoneCheckDebounce?.cancel();
    previousStoveOtherCtrl.dispose();
    mealsPerDayCtrl.dispose();
    cityCtrl.dispose();
    salesAgentNameCtrl.dispose();
    super.onClose();
  }
}
