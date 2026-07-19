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
import 'package:stove_transaction/core/constants/nigeria_data.dart';
import 'package:stove_transaction/core/model/upload_response_model.dart';
import 'package:stove_transaction/core/router/app_navigator.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';
import 'package:stove_transaction/core/services/offline_queue_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/features/partners/partner_access_service.dart';
import 'package:stove_transaction/features/sales/models/payment_model.dart';
import 'package:stove_transaction/features/sales/models/stove_model.dart';
import 'create_sale_service.dart';
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

  // Step 3 — Location
  final selectedState = ''.obs;
  final selectedLga = ''.obs;
  final fullAddressCtrl = TextEditingController();
  final latitude = Rxn<double>();
  final longitude = Rxn<double>();
  List<String> get lgas => NigeriaData.getLgas(selectedState.value);

  // Step 4 — Partner/Retailer
  final partnerNameCtrl = TextEditingController();
  final retailerBranchCtrl = TextEditingController();

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
  final RxList<PaymentModel> paymentModels = <PaymentModel>[].obs;
  // null = full payment; non-null = installment with this model
  final selectedModel = Rxn<PaymentModel>();
  bool get isInstallment => selectedModel.value != null;
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
  final cookingFuelSourceCtrl = TextEditingController();
  final cookingLocationCtrl = TextEditingController();

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

  // Step 9 — Media
  File? stoveImage;
  String? stoveImageId;
  final stoveImageSet = false.obs;
  final stoveImageFile = Rxn<File>();
  final stoveImageUploadProgress = Rxn<double>();
  File? agreementImage;
  String? agreementImageId;
  final agreementImageSet = false.obs;
  final agreementImageFile = Rxn<File>();
  final agreementImageUploadProgress = Rxn<double>();
  bool get hasSignature => signatureController.isNotEmpty || _existingSignatureB64 != null;

  // Option lists
  final paymentMethods = ['Cash', 'Bank Transfer', 'POS', 'Mobile Money'];
  // value → display label (value is what the API expects)
  final stoveTypes = const {
    'charcoal': 'Charcoal',
    'wood_stove': 'Wood (3 stone)',
    'other': 'Other',
  };

  // Cached Google API keys (fetched from Supabase, not .env)
  String? _googlePlacesApiKey;
  String? _googleMapsApiKey;

  // Tracks whether we're in offline mode to switch the location UI
  final isOfflineMode = false.obs;

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
    // Also attempt recovery immediately in case this controller is being
    // recreated right after such a kill.
    recoverLostImage();
    transactionId.value = _generateTransactionId();
    partnerNameCtrl.text = _session.organizationName ?? '';
    retailerBranchCtrl.text = _session.organizationBranch ?? '';
    isOfflineMode.value = !_connectivity.isOnline.value;
    ever(_connectivity.isOnline, (online) {
      isOfflineMode.value = !online;
      // Went offline mid-form with no coordinate yet → grab the device position
      // in the background so the sale can be submitted without GPS friction.
      if (!online) ensureDeviceLocation();
    });
    // Offline from the start: pre-capture the current position by default so the
    // agent never has to tap "use current location" before proceeding.
    if (isOfflineMode.value) ensureDeviceLocation();
    // Recompute the Places autocomplete bias whenever state/LGA change, so
    // address search is streamlined to the selected area (mirrors the web).
    ever(selectedState, (_) => _updatePlacesBias());
    ever(selectedLga, (_) => _updatePlacesBias());
    // Payment models are decoupled from partners — load all active models for
    // every role (see docs/backend/payment-model-decoupling.md).
    _loadPaymentModels();
    if (needsPartnerPicker) {
      // Super admin & ACSL agents pick a partner first; stoves load after.
      _fetchPartnersForRole();
    } else {
      _loadStoves();
    }
    _fetchGoogleKeys();
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
    if (orgId.isNotEmpty) _loadStovesForOrg(orgId);
  }

  void _clearBranchSelection() {
    selectedOrgId.value = '';
    retailerBranchCtrl.text = '';
    availableStoves.clear();
    selectedStove.value = null;
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
    cookingFuelSourceCtrl.clear();
    cookingLocationCtrl.clear();

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

    // Reset navigation to the first step.
    currentStep.value = 0;
    if (pageController.hasClients) {
      pageController.jumpToPage(0);
    }
    _editingQueueId = null;
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
    endUserNameCtrl.text = payload['endUserName']?.toString() ?? '';
    endUserSurnameCtrl.text = payload['endUserSurname']?.toString() ?? '';
    akaCtrl.text = payload['aka']?.toString() ?? '';
    phoneCtrl.text = payload['phone']?.toString() ?? '';
    otherPhoneCtrl.text = payload['otherPhone']?.toString() ?? '';

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
    if (payload['isInstallment'] == true && payload['paymentModelId'] != null) {
      selectedModel.value =
          paymentModels.firstWhereOrNull((m) => m.id == payload['paymentModelId'].toString());
    }
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
    cookingFuelSourceCtrl.text = payload['cookingFuelSource']?.toString() ?? '';
    cookingLocationCtrl.text = payload['cookingLocation']?.toString() ?? '';

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
    if (NigeriaData.getLgas(selectedState.value).contains(sample['lga'])) {
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
    cookingFuelSourceCtrl.text = sample['cookingFuelSource'] ?? '';
    cookingLocationCtrl.text = sample['cookingLocation'] ?? '';

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
    if (_connectivity.isOnline.value) {
      final resp = await _service.getAllActivePaymentModels();
      if (resp.success && resp.data != null) {
        final raw = resp.data is List ? resp.data as List : ((resp.data as Map?))?['data'] as List? ?? [];
        // 'payment-models' returns plain models; tolerate a nested shape too.
        final list = raw.map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          return map.containsKey('payment_model') && map['payment_model'] is Map
              ? Map<String, dynamic>.from(map['payment_model'] as Map)
              : map;
        }).where((m) => m['id'] != null).toList();
        final models = list.map((e) => PaymentModel.fromJson(e)).toList();
        paymentModels.assignAll(models);
        cache.savePaymentModels(models);
      }
    } else {
      final cached = cache.getPaymentModels();
      if (cached.isNotEmpty) paymentModels.assignAll(cached);
    }
  }

  /// Called when the user picks a value from the Payment Type dropdown.
  /// [modelId] is null for full payment, or a model ID for installment.
  void selectPaymentType(String? modelId) {
    if (modelId == null) {
      // Full payment selected
      selectedModel.value = null;
      amountCtrl.clear();
      initialPaymentCtrl.clear();
      initialPaymentText.value = '';
      selectedPaymentMethod.value = '';
      clearImage('paymentProof');
    } else {
      final model = paymentModels.firstWhereOrNull((m) => m.id == modelId);
      selectedModel.value = model;
      if (model != null) {
        // Auto-fill amount with the model's fixed price
        final formatted = model.fixedPrice.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
        amountCtrl.text = formatted;
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
        final match = NigeriaData.states.firstWhereOrNull(
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
    if (endUserNameCtrl.text.trim().isEmpty) {
      errors.add(const ValidationError(step: 1, stepTitle: 'Buyer & End User', field: 'End User First Name', message: 'End user first name is required'));
    }
    if (endUserSurnameCtrl.text.trim().isEmpty) {
      errors.add(const ValidationError(step: 1, stepTitle: 'Buyer & End User', field: 'End User Surname', message: 'End user surname is required'));
    }
    if (phoneCtrl.text.trim().isEmpty) {
      errors.add(const ValidationError(step: 1, stepTitle: 'Buyer & End User', field: 'End User Phone', message: 'End user phone number is required'));
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
    if (latitude.value == null || longitude.value == null) {
      errors.add(const ValidationError(step: 2, stepTitle: 'Location', field: 'GPS Coordinates', message: 'Location is required — use the map or GPS button'));
    }

    // Step 4 — Sale Details
    final amt = double.tryParse(amountCtrl.text.replaceAll(',', ''));
    if (amt == null || amt <= 0) {
      errors.add(const ValidationError(step: 4, stepTitle: 'Sale Details', field: 'Amount', message: 'A valid sale amount is required'));
    }
    // Amount received cannot exceed the sale amount
    final receivedText = amountReceivedCtrl.text.replaceAll(',', '').trim();
    if (receivedText.isNotEmpty) {
      final received = double.tryParse(receivedText);
      if (received != null && amt != null && received > amt) {
        errors.add(const ValidationError(step: 4, stepTitle: 'Sale Details', field: 'Amount Received', message: 'Amount received cannot be greater than the sale amount'));
      }
    }
    // Step 6 — Cooking Habits (all optional — no validation)

    // Step 7 — Terms & Conditions
    if (!allTcAccepted) {
      errors.add(const ValidationError(step: 7, stepTitle: 'Terms & Conditions', field: 'Terms', message: 'All terms & conditions must be accepted'));
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
    } else if (field == 'agreement') {
      agreementImage = null;
      agreementImageId = null;
      agreementImageFile.value = null;
      agreementImageUploadProgress.value = null;
      agreementImageSet.value = false;
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
        imageQuality: 70,
        maxWidth: 1600,
        maxHeight: 1600,
        requestFullMetadata: false,
      );
    } catch (e, st) {
      // A thrown PlatformException here (camera unavailable, permission race)
      // must NOT bubble up and tear down the create-sale flow. Swallow, log,
      // and let the user retry.
      _logger.w('pickImage failed for $field: $e', error: e, stackTrace: st);
      _pendingImageField = null;
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
    }
  }

  Future<void> doSubmit() async {
    isSubmitting.value = true;
    try {
      final payload = _buildPayload();

      if (!_connectivity.isOnline.value) {
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
      // Fall back to the signature carried over from an edited queued sale.
      final sigBytes = await signatureController.toPngBytes();
      if (sigBytes != null) {
        payload['signature'] = base64Encode(sigBytes);
      } else if (_existingSignatureB64 != null) {
        payload['signature'] = _existingSignatureB64;
      }

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
        _showSuccess('Sale created successfully!');
        resetForm();
        rootNavigatorKey.currentState?.pop(true);
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

  Future<void> _saveOffline(Map<String, dynamic> payload) async {
    final images = <String, String>{};
    if (stoveImage != null) images['stove_image'] = base64Encode(await stoveImage!.readAsBytes());
    if (agreementImage != null) images['agreement_image'] = base64Encode(await agreementImage!.readAsBytes());
    if (paymentProofImage != null) images['payment_proof'] = base64Encode(await paymentProofImage!.readAsBytes());
    final sigBytes = await signatureController.toPngBytes();
    if (sigBytes != null) {
      images['signature'] = base64Encode(sigBytes);
    } else if (_existingSignatureB64 != null) {
      images['signature'] = _existingSignatureB64!;
    }

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
      'endUserName': endUserNameCtrl.text,
      'endUserSurname': endUserSurnameCtrl.text,
      'aka': akaCtrl.text,
      'phone': phoneCtrl.text,
      'otherPhone': otherPhoneCtrl.text,
      'stateBackup': selectedState.value,
      'lgaBackup': selectedLga.value,
      'addressData': {
        'fullAddress': fullAddressCtrl.text,
        'street': '',
        'city': '',
        'state': selectedState.value,
        'country': 'Nigeria',
        'latitude': latitude.value,
        'longitude': longitude.value,
      },
      'partnerName': partnerNameCtrl.text,
      'retailerBranch': retailerBranchCtrl.text,
      'amount': double.tryParse(amountCtrl.text.replaceAll(',', '')) ?? 0,
      'amountReceived': double.tryParse(amountReceivedCtrl.text.replaceAll(',', '')) ?? 0,
      'potQuantity': potQuantity.value,
      'heatRetentionDevice': heatRetentionDevice.value,
      'previousStoveType': previousStoveType.value,
      'previousStoveOther': previousStoveOtherCtrl.text,
      'mealsPerDay': mealsPerDayCtrl.text,
      'cookingFuelSource': cookingFuelSourceCtrl.text,
      'cookingLocation': cookingLocationCtrl.text,
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
      if (selectedModel.value != null) 'paymentModelId': selectedModel.value!.id,
      if (selectedModel.value != null) 'isInstallment': true,
      if (initialPaymentAmount != null && initialPaymentAmount > 0) ...{
        'initialPaymentAmount': initialPaymentAmount,
        'initialPaymentMethod': selectedPaymentMethod.value,
      },
    };

    _logger.i('=== CREATE SALE PAYLOAD ===\n${const JsonEncoder.withIndent('  ').convert(payload)}');

    return payload;
  }

  void _showError(String msg) {
    toastification.show(title: Text(msg), type: ToastificationType.error, autoCloseDuration: const Duration(seconds: 4));
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
    amountCtrl.dispose();
    amountReceivedCtrl.dispose();
    initialPaymentCtrl.dispose();
    _initialPaymentDebounce?.cancel();
    previousStoveOtherCtrl.dispose();
    mealsPerDayCtrl.dispose();
    cookingFuelSourceCtrl.dispose();
    cookingLocationCtrl.dispose();
    super.onClose();
  }
}
