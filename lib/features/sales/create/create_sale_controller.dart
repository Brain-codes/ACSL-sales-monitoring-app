import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:signature/signature.dart';
import 'package:toastification/toastification.dart';
import 'package:stove_transaction/core/constants/nigeria_data.dart';
import 'package:stove_transaction/core/model/upload_response_model.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';
import 'package:stove_transaction/core/services/offline_queue_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/features/sales/models/payment_model.dart';
import 'package:stove_transaction/features/sales/models/stove_model.dart';
import 'create_sale_service.dart';

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

class CreateSaleController extends GetxController {
  final _service = CreateSaleService();
  final _session = Get.find<SessionManager>();
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
  final selectedOrgId = ''.obs;
  final partnerSearchQuery = ''.obs;
  final RxList<Map<String, dynamic>> assignedPartners = <Map<String, dynamic>>[].obs;
  final isLoadingPartners = false.obs;

  // Step 5 — Sale Details
  final amountCtrl = TextEditingController();
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
  bool get hasSignature => signatureController.isNotEmpty;

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
    transactionId.value = _generateTransactionId();
    partnerNameCtrl.text = _session.organizationName ?? '';
    retailerBranchCtrl.text = _session.organizationBranch ?? '';
    isOfflineMode.value = !_connectivity.isOnline.value;
    ever(_connectivity.isOnline, (online) => isOfflineMode.value = !online);
    if (isAcslAgent) {
      // ACSL agents pick a partner first; stoves/models load after partner selection
      _fetchAssignedPartners();
    } else {
      _loadStoves();
      _loadPaymentModels();
    }
    _fetchGoogleKeys();
  }

  Future<void> _fetchAssignedPartners() async {
    final agentId = _session.userId;
    if (agentId == null || agentId.isEmpty) return;
    final cache = Get.find<LocalCacheService>();

    // Populate from cache immediately so offline users see something
    final cached = cache.getAssignedPartners();
    if (cached.isNotEmpty) assignedPartners.assignAll(cached);

    if (!_connectivity.isOnline.value) return;

    isLoadingPartners.value = true;
    final resp = await _service.getAssignedPartners(agentId);
    isLoadingPartners.value = false;
    if (resp.success && resp.data != null) {
      final raw = resp.data is List
          ? resp.data as List
          : ((resp.data as Map?))?['data'] as List? ?? [];
      final partners = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      assignedPartners.assignAll(partners);
      cache.saveAssignedPartners(partners);
    }
  }

  void onPartnerSelected(Map<String, dynamic> partner) {
    final orgId = partner['id']?.toString() ?? '';
    final name = partner['partner_name']?.toString() ?? partner['name']?.toString() ?? '';
    selectedOrgId.value = orgId;
    partnerNameCtrl.text = name;
    partnerSearchQuery.value = '';
    if (orgId.isNotEmpty) {
      _loadStovesForOrg(orgId);
      _loadPaymentModelsForOrg(orgId);
    }
  }

  Future<void> _loadStovesForOrg(String orgId) async {
    final cache = Get.find<LocalCacheService>();
    isLoadingStoves.value = true;

    List<StoveModel> stoves;
    if (_connectivity.isOnline.value) {
      final resp = await _service.getAvailableStovesForOrg(orgId);
      if (resp.success && resp.data != null) {
        final list = resp.data is List
            ? resp.data as List
            : ((resp.data as Map?))?['data'] as List? ?? [];
        stoves = list
            .map((e) => StoveModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((s) => s.stoveId.isNotEmpty)
            .toList();
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

  Future<void> _loadPaymentModelsForOrg(String orgId) async {
    final cache = Get.find<LocalCacheService>();

    if (_connectivity.isOnline.value) {
      final resp = await _service.getPaymentModelsForOrg(orgId);
      if (resp.success && resp.data != null) {
        final raw = resp.data is List
            ? resp.data as List
            : ((resp.data as Map?))?['data'] as List? ?? [];
        final list = raw.map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          return map.containsKey('payment_model') && map['payment_model'] is Map
              ? Map<String, dynamic>.from(map['payment_model'] as Map)
              : map;
        }).where((m) => m['id'] != null).toList();
        final models = list.map((e) => PaymentModel.fromJson(e)).toList();
        paymentModels.assignAll(models);
        cache.savePaymentModelsForOrg(orgId, models);
      } else {
        paymentModels.assignAll(cache.getPaymentModelsForOrg(orgId));
      }
    } else {
      paymentModels.assignAll(cache.getPaymentModelsForOrg(orgId));
    }
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
      final resp = await _service.getPaymentModels();
      if (resp.success && resp.data != null) {
        final raw = resp.data is List ? resp.data as List : ((resp.data as Map?))?['data'] as List? ?? [];
        // organization-payment-models returns assignment objects with a nested payment_model
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

  /// Search Places autocomplete (Nigeria-restricted).
  Future<List<Map<String, String>>> searchPlaces(String query) async {
    if (query.length < 3) return [];
    final key = _googlePlacesApiKey;
    if (key == null || key.isEmpty) return [];
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
        'input': query,
        'components': 'country:ng',
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
      case 3: return isAcslAgent ? selectedOrgId.value.isNotEmpty : partnerNameCtrl.text.isNotEmpty;
      case 4: return amountCtrl.text.isNotEmpty;
      case 5: return true;
      case 6: return true;
      case 7: return allTcAccepted;
      case 8: return stoveImageSet.value && hasSignature; // && agreementImageSet.value (agreement image no longer required)
      default: return true;
    }
  }

  List<ValidationError> validateAll() {
    final errors = <ValidationError>[];

    // Step 0 — Transaction
    if (selectedStove.value == null) {
      errors.add(const ValidationError(step: 0, stepTitle: 'Transaction Info', field: 'Stove', message: 'Please select a stove'));
    }

    // Step 1 — Contact
    if (endUserNameCtrl.text.trim().isEmpty) {
      errors.add(const ValidationError(step: 1, stepTitle: 'Contact Details', field: 'End User Name', message: 'End user name is required'));
    }
    if (phoneCtrl.text.trim().isEmpty) {
      errors.add(const ValidationError(step: 1, stepTitle: 'Contact Details', field: 'Phone Number', message: 'Phone number is required'));
    }
    if (contactPersonCtrl.text.trim().isEmpty) {
      errors.add(const ValidationError(step: 1, stepTitle: 'Contact Details', field: 'Contact Person', message: 'Contact person is required'));
    }
    if (contactPhoneCtrl.text.trim().isEmpty) {
      errors.add(const ValidationError(step: 1, stepTitle: 'Contact Details', field: 'Contact Phone', message: 'Contact phone number is required'));
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
    if (isInstallment) {
      final ip = double.tryParse(initialPaymentCtrl.text.replaceAll(',', ''));
      if (ip == null || ip <= 0) {
        errors.add(const ValidationError(step: 4, stepTitle: 'Sale Details', field: 'Initial Payment', message: 'Initial payment amount is required for installment'));
      }
      if (selectedPaymentMethod.value.isEmpty) {
        errors.add(const ValidationError(step: 4, stepTitle: 'Sale Details', field: 'Payment Method', message: 'Select a payment method for the initial payment'));
      }
      if (!paymentProofSet.value) {
        errors.add(const ValidationError(step: 4, stepTitle: 'Sale Details', field: 'Payment Proof', message: 'Payment proof image is required for installment'));
      }
    }

    // Step 6 — Cooking Habits
    if (previousStoveType.value.isEmpty) {
      errors.add(const ValidationError(step: 6, stepTitle: 'Cooking Habits', field: 'Previous Stove Type', message: 'Previous stove type is required'));
    }
    if (mealsPerDayCtrl.text.trim().isEmpty) {
      errors.add(const ValidationError(step: 6, stepTitle: 'Cooking Habits', field: 'Meals Per Day', message: 'Meals per day is required'));
    }
    if (cookingFuelSourceCtrl.text.trim().isEmpty) {
      errors.add(const ValidationError(step: 6, stepTitle: 'Cooking Habits', field: 'Cooking Fuel Source', message: 'Cooking fuel source is required'));
    }
    if (cookingLocationCtrl.text.trim().isEmpty) {
      errors.add(const ValidationError(step: 6, stepTitle: 'Cooking Habits', field: 'Cooking Location', message: 'Cooking location is required'));
    }

    // Step 7 — Terms & Conditions
    if (!allTcAccepted) {
      errors.add(const ValidationError(step: 7, stepTitle: 'Terms & Conditions', field: 'Terms', message: 'All terms & conditions must be accepted'));
    }

    // Step 8 — Media
    if (!stoveImageSet.value) {
      errors.add(const ValidationError(step: 8, stepTitle: 'Documents & Signature', field: 'Stove Image', message: 'Stove image is required'));
    }
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

  Future<void> pickImage(ImageSource source, {required String field}) async {
    final xFile = await _picker.pickImage(source: source, imageQuality: 70);
    if (xFile == null) return;
    final file = File(xFile.path);

    if (field == 'stove') {
      stoveImage = file;
      stoveImageId = null;
      stoveImageFile.value = file;
      stoveImageSet.value = true;
      if (_connectivity.isOnline.value) {
        stoveImageUploadProgress.value = -1;
        final resp = await _uploadFile(file, 'stove_image');
        stoveImageId = resp?.id;
        stoveImageUploadProgress.value = resp != null ? 1.0 : null;
      }
    } else if (field == 'agreement') {
      agreementImage = file;
      agreementImageId = null;
      agreementImageFile.value = file;
      agreementImageSet.value = true;
      if (_connectivity.isOnline.value) {
        agreementImageUploadProgress.value = -1;
        final resp = await _uploadFile(file, 'agreement_image');
        agreementImageId = resp?.id;
        agreementImageUploadProgress.value = resp != null ? 1.0 : null;
      }
    } else if (field == 'paymentProof') {
      paymentProofImage = file;
      paymentProofImageId = null;
      paymentProofFile.value = file;
      paymentProofSet.value = true;
      if (_connectivity.isOnline.value) {
        paymentProofUploadProgress.value = -1;
        final resp = await _uploadFile(file, 'payment_proof');
        paymentProofImageId = resp?.id;
        paymentProofUploadProgress.value = resp != null ? 1.0 : null;
      }
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

      // Signature goes as raw base64 in the payload (matches frontend format)
      final sigBytes = await signatureController.toPngBytes();
      if (sigBytes != null) payload['signature'] = base64Encode(sigBytes);

      if (stoveImageId != null) payload['stoveImageId'] = stoveImageId;
      if (agreementImageId != null) payload['agreementImageId'] = agreementImageId;
      if (paymentProofImageId != null) payload['initialPaymentProofImageId'] = paymentProofImageId;

      _logger.i('=== FINAL PAYLOAD (with image IDs) ===\n${const JsonEncoder.withIndent('  ').convert(payload)}');

      final resp = await _service.createSale(payload);
      if (resp.success) {
        _showSuccess('Sale created successfully!');
        Get.back(result: true);
      } else {
        _showError(resp.message);
      }
    } catch (e) {
      _logger.e('Submit error: $e');
      _showError('Failed to submit sale. Please try again.');
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
    if (sigBytes != null) images['signature'] = base64Encode(sigBytes);

    await _queue.enqueue(payload: payload, imageBase64Map: images);
    toastification.show(
      title: const Text('Sale saved offline'),
      description: const Text('It will sync automatically when you are back online.'),
      type: ToastificationType.info,
      autoCloseDuration: const Duration(seconds: 5),
    );
    Get.back(result: true);
  }

  Future<UploadResponse?> _uploadFile(File? file, String type) async {
    if (file == null) return null;
    final resp = await _service.uploadImage(file, type);
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
  void onClose() {
    pageController.dispose();
    signatureController.dispose();
    contactPersonCtrl.dispose();
    contactPhoneCtrl.dispose();
    endUserNameCtrl.dispose();
    akaCtrl.dispose();
    phoneCtrl.dispose();
    otherPhoneCtrl.dispose();
    fullAddressCtrl.dispose();
    partnerNameCtrl.dispose();
    retailerBranchCtrl.dispose();
    amountCtrl.dispose();
    initialPaymentCtrl.dispose();
    _initialPaymentDebounce?.cancel();
    previousStoveOtherCtrl.dispose();
    mealsPerDayCtrl.dispose();
    cookingFuelSourceCtrl.dispose();
    cookingLocationCtrl.dispose();
    super.onClose();
  }
}
