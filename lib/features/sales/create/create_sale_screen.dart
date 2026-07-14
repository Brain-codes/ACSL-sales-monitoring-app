import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'map_picker_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/nigeria_data.dart';
import 'package:stove_transaction/core/utils/formatters.dart';
import 'package:stove_transaction/core/widgets/app_text_field.dart';
import 'package:stove_transaction/core/widgets/offline_banner.dart';
import 'package:stove_transaction/core/widgets/primary_button.dart';
import 'package:stove_transaction/core/widgets/section_header.dart';
import 'create_sale_controller.dart';

class CreateSaleScreen extends StatelessWidget {
  /// When set, the form is editing this queued (pending/failed) sale instead of
  /// creating a new one.
  final int? editQueueId;
  const CreateSaleScreen({super.key, this.editQueueId});

  static const _stepTitles = [
    'Transaction Info',
    'Contact Details',
    'Location',
    'Partner Info', // hidden — skipped in navigation
    'Sale Details',
    'Stove Set',
    'Cooking Habits',
    'Terms & Conditions',
    'Documents & Signature',
  ];

  @override
  Widget build(BuildContext context) {
    final c = Get.put(CreateSaleController());
    if (editQueueId != null) {
      // Hydrate the form from the queued sale after the first frame so its
      // async load (images, partners) doesn't block the initial build.
      WidgetsBinding.instance.addPostFrameCallback((_) => c.hydrateFromQueue(editQueueId!));
    } else if (c.isEditingQueued) {
      // The persistent controller was left in edit mode from a previous, aborted
      // queued-sale edit — start this fresh create from a clean slate.
      WidgetsBinding.instance.addPostFrameCallback((_) => c.resetForm());
    }
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () => c.singleViewMode.value = !c.singleViewMode.value,
          // Triple-tap fills the form with test data (dev backdoor).
          onTap: c.onTitleTap,
          child: Obx(() => Text(
            c.singleViewMode.value ? 'Create Sale' : _stepTitles[c.currentStep.value],
          )),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _confirmExit(context),
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Obx(() => c.singleViewMode.value
              ? const SizedBox.shrink()
              : _StepProgress()),
          Obx(() => c.singleViewMode.value
              ? Expanded(child: _SingleViewForm())
              : Expanded(
                  child: PageView(
                    controller: c.pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: const [
                      _Step1Transaction(),
                      _Step2Contact(),
                      _Step3Location(),
                      _Step4Partner(),
                      _Step5SaleDetails(),
                      _Step6StoveSet(),
                      _Step7CookingHabits(),
                      _Step8Terms(),
                      _Step9Media(),
                    ],
                  ),
                )),
          Obx(() => c.singleViewMode.value
              ? _SingleViewSubmitButton()
              : _NavButtons()),
        ],
      ),
    );
  }

  void _confirmExit(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Discard Sale?'),
        content: const Text('All entered data will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop(); // close dialog
                Navigator.of(context).pop();   // leave create-sale screen
              },
              child: const Text('Discard',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final c = Get.find<CreateSaleController>();
      final current = c.currentStep.value;
      // ACSL agents see all 9 steps (partner step is visible).
      // Other roles skip step 3 (partner hidden), so map index to display number.
      final totalSteps = c.needsPartnerPicker ? 9 : 8;
      final displayStep = c.needsPartnerPicker
          ? current + 1
          : (current <= 2 ? current + 1 : current);
      return Column(
        children: [
          LinearProgressIndicator(
            value: displayStep / totalSteps,
            backgroundColor: AppColors.borderColor,
            color: AppColors.brandPrimary,
            minHeight: 4,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Step $displayStep of $totalSteps',
                    style: Theme.of(context).textTheme.bodySmall),
                Text('${(displayStep / totalSteps * 100).round()}% complete',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _NavButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = Get.find<CreateSaleController>();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.borderColor))),
      child: Obx(() => Row(
            children: [
              if (c.currentStep.value > 0)
                Expanded(
                  child: PrimaryButton(
                      label: 'Back', outline: true, onPressed: c.previousStep),
                ),
              if (c.currentStep.value > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: c.currentStep.value == 8 ? 'Submit Sale' : 'Continue',
                  loading: c.isSubmitting.value,
                  onPressed: c.currentStep.value == 8
                      ? () => _handleSubmitRequest(context, c)
                      : c.nextStep,
                ),
              ),
            ],
          )),
    );
  }
}

// ──────────────────────────── Single-view form (hidden feature) ──────────────

class _SingleViewForm extends StatelessWidget {
  const _SingleViewForm();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<CreateSaleController>();
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          KeyedSubtree(key: c.singleViewKeys[0], child: const _Step1Transaction(singleView: true)),
          KeyedSubtree(key: c.singleViewKeys[1], child: const _Step2Contact(singleView: true)),
          KeyedSubtree(key: c.singleViewKeys[4], child: const _Step5SaleDetails(singleView: true)),
          KeyedSubtree(key: c.singleViewKeys[2], child: const _Step3Location(singleView: true)),
          KeyedSubtree(key: c.singleViewKeys[5], child: const _Step6StoveSet(singleView: true)),
          KeyedSubtree(key: c.singleViewKeys[6], child: const _Step7CookingHabits(singleView: true)),
          KeyedSubtree(key: c.singleViewKeys[7], child: const _Step8Terms(singleView: true)),
          KeyedSubtree(key: c.singleViewKeys[8], child: const _Step9Media(singleView: true)),
        ],
      ),
    );
  }
}

class _SingleViewSubmitButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = Get.find<CreateSaleController>();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.borderColor))),
      child: Obx(() => PrimaryButton(
            label: 'Submit Sale',
            loading: c.isSubmitting.value,
            onPressed: () => _handleSubmitRequest(context, c),
          )),
    );
  }
}

// Orchestrates validate → show validation sheet OR preview sheet
Future<void> _handleSubmitRequest(BuildContext context, CreateSaleController c) async {
  // Offline safety net: if the agent never tapped "use current location", grab
  // the device position now (silently) so the GPS-required check doesn't block
  // an otherwise-complete offline sale.
  if (c.isOfflineMode.value && (c.latitude.value == null || c.longitude.value == null)) {
    await c.ensureDeviceLocation();
  }
  if (!context.mounted) return;
  final errors = c.validateAll();
  if (errors.isNotEmpty) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SaleValidationSheet(errors: errors),
    );
    return;
  }
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SalePreviewSheet(),
  );
}

// ──────────────────────────── STEP 1: Transaction ────────────────────────────

class _Step1Transaction extends StatefulWidget {
  final bool singleView;
  const _Step1Transaction({this.singleView = false});

  @override
  State<_Step1Transaction> createState() => _Step1TransactionState();
}

class _Step1TransactionState extends State<_Step1Transaction> {
  final _partnerSearchCtrl = TextEditingController();

  @override
  void dispose() {
    _partnerSearchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filteredPartners(CreateSaleController c) {
    final q = c.partnerSearchQuery.value.toLowerCase();
    final list = c.distinctPartners;
    if (q.isEmpty) return list;
    return list.where((p) {
      final name = (p['partner_name'] ?? p['name'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<CreateSaleController>();
    final col = _buildColumn(context, c);
    if (widget.singleView) return Padding(padding: const EdgeInsets.all(16), child: col);
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: col);
  }

  Widget _buildColumn(BuildContext context, CreateSaleController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Transaction Information'),
        Obx(() => AppTextField(
            label: 'Transaction ID',
            controller: TextEditingController(text: c.transactionId.value),
            readOnly: true)),
        const SizedBox(height: 16),

        // ── Partner picker (ACSL agents + super admin) ────────────────────
        if (c.needsPartnerPicker) ...[
          const Text('Partner *',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          const SizedBox(height: 8),
          Obx(() {
            final hasPartner = c.selectedPartnerName.value.isNotEmpty;
            if (hasPartner) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selected partner chip + change.
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.brandPrimary.withValues(alpha: 0.07),
                            border: Border.all(color: AppColors.brandPrimary),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: AppColors.brandPrimary, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  c.selectedPartnerName.value,
                                  style: const TextStyle(
                                      color: AppColors.brandPrimary,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textMuted),
                        tooltip: 'Change partner',
                        onPressed: () {
                          c.clearPartnerSelection();
                          _partnerSearchCtrl.clear();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // State (of the partner's branches).
                  const Text('State *',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    key: ValueKey('branch-state-${c.selectedPartnerName.value}'),
                    isExpanded: true,
                    initialValue: c.selectedBranchState.value.isEmpty
                        ? null
                        : c.selectedBranchState.value,
                    decoration: InputDecoration(
                      hintText: 'Select state',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: c.statesForSelectedPartner
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) c.onBranchStateSelected(v);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Branch (resolves the organization_id).
                  const Text('Branch *',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                        'branch-${c.selectedPartnerName.value}-${c.selectedBranchState.value}'),
                    isExpanded: true,
                    initialValue:
                        c.selectedOrgId.value.isEmpty ? null : c.selectedOrgId.value,
                    decoration: InputDecoration(
                      hintText: c.selectedBranchState.value.isEmpty
                          ? 'Select a state first'
                          : 'Select branch',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: c.branchesForSelectedState.map((b) {
                      final id = b['id']?.toString() ?? '';
                      final branch = (b['branch'] ?? '—').toString();
                      return DropdownMenuItem(
                        value: id,
                        child: Text(branch, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: c.selectedBranchState.value.isEmpty
                        ? null
                        : (v) {
                            if (v == null) return;
                            final branch = c.branchesForSelectedState
                                .firstWhereOrNull((b) => b['id']?.toString() == v);
                            if (branch != null) c.onBranchSelected(branch);
                          },
                  ),
                ],
              );
            }

            // No partner yet — search + distinct partner list.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _partnerSearchCtrl,
                  onChanged: (v) => c.partnerSearchQuery.value = v,
                  decoration: InputDecoration(
                    hintText: 'Search partners…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: c.isLoadingPartners.value
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.brandPrimary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                ),
                const SizedBox(height: 6),
                Obx(() {
                  final partners = _filteredPartners(c);
                  if (partners.isEmpty && !c.isLoadingPartners.value) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        c.assignedPartners.isEmpty
                            ? 'No partners assigned to your account.'
                            : 'No partners match your search.',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    );
                  }
                  return Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      border: Border.all(color: AppColors.borderColor),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: partners.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                      itemBuilder: (_, i) {
                        final name =
                            (partners[i]['partner_name'] ?? partners[i]['name'] ?? '').toString();
                        return ListTile(
                          dense: true,
                          title: Text(name,
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                          trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                          onTap: () {
                            c.onPartnerNameSelected(name);
                            _partnerSearchCtrl.clear();
                          },
                        );
                      },
                    ),
                  );
                }),
              ],
            );
          }),
          const SizedBox(height: 16),
        ],

        const SizedBox(height: 16),
        Obx(() => ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sales Date',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              subtitle:
                  Text(DateFormat('d MMMM yyyy').format(c.salesDate.value)),
              trailing: const Icon(Icons.calendar_today_outlined,
                  color: AppColors.brandPrimary),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: c.salesDate.value,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) c.salesDate.value = picked;
              },
            )),
      ],
    );
  }
}

// ──────────────────────────── STEP 2: Contact ────────────────────────────────

class _Step2Contact extends StatelessWidget {
  final bool singleView;
  const _Step2Contact({this.singleView = false});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<CreateSaleController>();
    final col = Column(
      children: [
        const SectionHeader(title: 'Buyer & End User'),
        AppTextField(
            label: 'Contact Person / Buyer',
            controller: c.contactPersonCtrl,
            required: true,
            textInputAction: TextInputAction.next),
        const SizedBox(height: 12),
        AppTextField(
            label: 'Contact Phone',
            controller: c.contactPhoneCtrl,
            keyboardType: TextInputType.phone,
            required: true,
            textInputAction: TextInputAction.next),
        const SizedBox(height: 12),
        AppTextField(
            label: 'End User First Name',
            controller: c.endUserNameCtrl,
            required: true,
            textInputAction: TextInputAction.next),
        const SizedBox(height: 12),
        AppTextField(
            label: 'End User Surname',
            controller: c.endUserSurnameCtrl,
            required: true,
            textInputAction: TextInputAction.next),
        const SizedBox(height: 12),
        AppTextField(
            label: 'End User Phone',
            controller: c.phoneCtrl,
            keyboardType: TextInputType.phone,
            required: true,
            textInputAction: TextInputAction.next),
        const SizedBox(height: 12),
        AppTextField(
            label: 'AKA',
            controller: c.akaCtrl,
            textInputAction: TextInputAction.next),
        const SizedBox(height: 12),
        AppTextField(
            label: 'Other Phone',
            controller: c.otherPhoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done),
      ],
    );
    if (singleView) return Padding(padding: const EdgeInsets.all(16), child: col);
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: col);
  }
}

// ──────────────────────────── STEP 3: Location ───────────────────────────────

class _Step3Location extends StatefulWidget {
  final bool singleView;
  const _Step3Location({this.singleView = false});

  @override
  State<_Step3Location> createState() => _Step3LocationState();
}

class _Step3LocationState extends State<_Step3Location> {
  List<Map<String, String>> _suggestions = [];
  bool _isSearching = false;
  bool _isCapturingLocation = false;
  bool _skipNextResults = false;

  Future<void> _captureCurrentLocation(CreateSaleController c) async {
    if (mounted) setState(() => _isCapturingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled. Please enable GPS.')),
          );
        }
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied.')),
            );
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission permanently denied. Enable in settings.')),
          );
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      c.latitude.value = position.latitude;
      c.longitude.value = position.longitude;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturingLocation = false);
    }
  }

  Future<void> _onAddressChanged(String value, CreateSaleController c) async {
    if (value.length < 3) {
      if (mounted) setState(() => _suggestions = []);
      return;
    }
    if (mounted) setState(() => _isSearching = true);
    final results = await c.searchPlaces(value);
    if (!mounted) return;
    if (_skipNextResults) {
      _skipNextResults = false;
      setState(() => _isSearching = false);
      return;
    }
    setState(() { _suggestions = results; _isSearching = false; });
  }

  Future<void> _onSuggestionTap(Map<String, String> s, CreateSaleController c) async {
    _skipNextResults = true;
    FocusScope.of(context).unfocus();
    setState(() => _suggestions = []);
    final details = await c.fetchPlaceDetails(s['place_id']!);
    if (details != null && mounted) {
      c.fullAddressCtrl.text = details.address;
      c.latitude.value = details.lat;
      c.longitude.value = details.lng;
    }
  }

  Widget _buildOfflineAddressSection(CreateSaleController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Residential Address *',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        const SizedBox(height: 8),
        // Offline: type the address manually + capture GPS. It is verified
        // against Google automatically when the sale syncs online.
        TextField(
          controller: c.fullAddressCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Type full address (house no., street, area)…',
            hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.brandPrimary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: _isCapturingLocation
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.gps_fixed, color: AppColors.brandPrimary),
            label: Text(_isCapturingLocation
                ? 'Capturing location...'
                : 'Use Current Location (GPS)'),
            onPressed: _isCapturingLocation ? null : () => _captureCurrentLocation(c),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.brandPrimary),
            ),
          ),
        ),
        Obx(() {
          final lat = c.latitude.value;
          final lng = c.longitude.value;
          if (lat == null || lng == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Icon(Icons.my_location, size: 13, color: AppColors.brandPrimary),
                const SizedBox(width: 5),
                Text(
                  '${lat.toStringAsFixed(5)},  ${lng.toStringAsFixed(5)}',
                  style: const TextStyle(
                    fontSize: 12, color: AppColors.brandPrimary, fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildOnlineAddressSection(CreateSaleController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Residential Address *',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: c.fullAddressCtrl,
                onChanged: (v) => _onAddressChanged(v, c),
                decoration: InputDecoration(
                  hintText: 'Search address...',
                  hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : c.fullAddressCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                c.fullAddressCtrl.clear();
                                c.latitude.value = null;
                                c.longitude.value = null;
                                setState(() => _suggestions = []);
                              },
                            )
                          : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.brandPrimary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MapPickerScreen(
                    controller: c,
                    initialLat: c.latitude.value,
                    initialLng: c.longitude.value,
                  ),
                ),
              ),
              child: Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: AppColors.brandLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: const Icon(Icons.location_pin, color: AppColors.brandPrimary, size: 24),
              ),
            ),
          ],
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              children: _suggestions.map((s) {
                final isLast = s == _suggestions.last;
                return InkWell(
                  borderRadius: isLast
                      ? const BorderRadius.vertical(bottom: Radius.circular(10))
                      : BorderRadius.zero,
                  onTap: () => _onSuggestionTap(s, c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: isLast
                          ? null
                          : const Border(bottom: BorderSide(color: AppColors.borderColor)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 17, color: AppColors.brandPrimary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(s['description']!, style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        Obx(() {
          final lat = c.latitude.value;
          final lng = c.longitude.value;
          if (lat == null || lng == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Icon(Icons.my_location, size: 13, color: AppColors.brandPrimary),
                const SizedBox(width: 5),
                Text(
                  '${lat.toStringAsFixed(5)},  ${lng.toStringAsFixed(5)}',
                  style: const TextStyle(
                    fontSize: 12, color: AppColors.brandPrimary, fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<CreateSaleController>();
    final col = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Location'),

          // ── State ─────────────────────────────────────────────────────
          const Text('State *',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          const SizedBox(height: 8),
          Obx(() => _SearchablePickerField(
                value: c.selectedState.value.isEmpty ? null : c.selectedState.value,
                hint: 'Select state',
                onTap: () async {
                  final picked = await _showSearchPicker(
                    context,
                    title: 'Select State',
                    items: NigeriaData.states,
                    selected: c.selectedState.value,
                  );
                  if (picked != null) {
                    c.selectedState.value = picked;
                    c.selectedLga.value = '';
                  }
                },
              )),

          const SizedBox(height: 16),

          // ── LGA ───────────────────────────────────────────────────────
          const Text('LGA',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          const SizedBox(height: 8),
          Obx(() {
            final stateSelected = c.selectedState.value.isNotEmpty;
            return _SearchablePickerField(
              value: c.selectedLga.value.isEmpty ? null : c.selectedLga.value,
              hint: stateSelected ? 'Select LGA' : 'Select a state first',
              enabled: stateSelected,
              onTap: stateSelected
                  ? () async {
                      final picked = await _showSearchPicker(
                        context,
                        title: 'Select LGA',
                        items: c.lgas,
                        selected: c.selectedLga.value,
                      );
                      if (picked != null) c.selectedLga.value = picked;
                    }
                  : null,
            );
          }),

          const SizedBox(height: 16),

          // ── Residential Address — switches between online (map) and offline (GPS + manual) ──
          Obx(() => c.isOfflineMode.value
              ? _buildOfflineAddressSection(c)
              : _buildOnlineAddressSection(c)),

          const SizedBox(height: 8),
        ],
      );
    if (widget.singleView) return Padding(padding: const EdgeInsets.all(16), child: col);
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: col);
  }
}

// ──────────────────────────── STEP 4: Partner ────────────────────────────────

class _Step4Partner extends StatelessWidget {
  const _Step4Partner();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<CreateSaleController>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SectionHeader(title: 'Partner / Retailer Info'),
          // When a partner was already selected on Step 1 — show read-only.
          if (c.needsPartnerPicker)
            Obx(() => AppTextField(
                label: 'Partner',
                controller: TextEditingController(text: c.partnerNameCtrl.text),
                readOnly: true))
          else
            AppTextField(
                label: 'Partner Name',
                controller: c.partnerNameCtrl,
                required: true),
          const SizedBox(height: 12),
          AppTextField(
              label: 'Retailer Branch / CSO', controller: c.retailerBranchCtrl),
        ],
      ),
    );
  }
}

// ──────────────────────────── STEP 5: Sale Details ───────────────────────────

class _Step5SaleDetails extends StatelessWidget {
  final bool singleView;
  const _Step5SaleDetails({this.singleView = false});

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<CreateSaleController>();
    final col = Obx(() {
      final model = c.selectedModel.value;
      final isInstallment = c.isInstallment;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Sale & Payment'),

          // ── Stove serial ──────────────────────────────────────────────
          const Text('Stove Serial No. *',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          const SizedBox(height: 8),
          Obx(() {
            final partnerRequired = c.needsPartnerPicker && c.selectedOrgId.value.isEmpty;
            final isLoading = c.isLoadingStoves.value;
            if (isLoading) {
              return const Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('Loading stoves…', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                ],
              );
            }
            final selected = c.selectedStove.value;
            if (partnerRequired) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.borderColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: AppColors.textMuted),
                    SizedBox(width: 8),
                    Text('Select a partner first', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                  ],
                ),
              );
            }
            if (selected != null) {
              return Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary.withValues(alpha: 0.07),
                        border: Border.all(color: AppColors.brandPrimary),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.brandPrimary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(selected.displayId, style: const TextStyle(color: AppColors.brandPrimary, fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () { c.selectedStove.value = null; c.stoveSearchQuery.value = ''; },
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    tooltip: 'Clear selection',
                  ),
                ],
              );
            }
            return Column(
              children: [
                TextFormField(
                  decoration: const InputDecoration(hintText: 'Type to search stove serial…', prefixIcon: Icon(Icons.search)),
                  textInputAction: TextInputAction.search,
                  onChanged: (v) => c.stoveSearchQuery.value = v,
                ),
                const SizedBox(height: 4),
                Obx(() {
                  final query = c.stoveSearchQuery.value;
                  if (query.isEmpty) return const SizedBox.shrink();
                  final stoves = c.filteredStoves;
                  if (stoves.isEmpty) {
                    return const Padding(padding: EdgeInsets.all(8), child: Text('No matching stoves found', style: TextStyle(color: AppColors.textMuted)));
                  }
                  return Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(color: AppColors.white, border: Border.all(color: AppColors.borderColor), borderRadius: BorderRadius.circular(8)),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: stoves.length,
                      itemBuilder: (_, i) => ListTile(
                        title: Text(stoves[i].displayId),
                        onTap: () { c.selectedStove.value = stoves[i]; c.stoveSearchQuery.value = ''; },
                      ),
                    ),
                  );
                }),
              ],
            );
          }),
          const SizedBox(height: 16),

          // Payment Type dropdown — Full Payment + any installment models
          const Text('Payment Type *',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: isInstallment ? model!.id : 'full_payment',
            isExpanded: true,
            items: [
              const DropdownMenuItem(
                value: 'full_payment',
                child: Text(
                  'Full Payment — One-time complete payment',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ...c.paymentModels.map((m) => DropdownMenuItem(
                    value: m.id,
                    child: Text(m.dropdownLabel, overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: (v) => c.selectPaymentType(v == 'full_payment' ? null : v),
            decoration: const InputDecoration(),
          ),
          const SizedBox(height: 16),

          // Installment model summary card
          if (isInstallment && model != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.06),
                border: Border.all(color: AppColors.brandPrimary.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(model.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.brandPrimary)),
                  if (model.description != null && model.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(model.description!,
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _InfoChip(label: 'Price', value: '₦${_formatCurrency(model.fixedPrice)}'),
                      const SizedBox(width: 12),
                      _InfoChip(label: 'Duration', value: '${model.durationMonths} months'),
                      const SizedBox(width: 12),
                      _InfoChip(label: 'Monthly', value: '~₦${_formatCurrency(model.monthlyPayment)}'),
                    ],
                  ),
                  if (model.minDownPayment > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          'Min. down payment: ₦${_formatCurrency(model.minDownPayment)}',
                          style: const TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Sale amount — editable even for installment (model only pre-fills it)
          AppTextField(
            label: 'Sale Amount (₦)',
            controller: c.amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsSeparatorInputFormatter()],
            required: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Amount Received (₦)',
            controller: c.amountReceivedCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsSeparatorInputFormatter()],
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 16),
        ],
      );
    });

    if (singleView) return Padding(padding: const EdgeInsets.all(16), child: col);
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: col);
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ──────────────────────────── STEP 6: Stove Set ──────────────────────────────

class _Step6StoveSet extends StatelessWidget {
  final bool singleView;
  const _Step6StoveSet({this.singleView = false});

  void _editPotQuantity(BuildContext context, CreateSaleController c) {
    final ctrl = TextEditingController(text: '${c.potQuantity.value}');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Number of Pots'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter quantity'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text);
              if (v != null && v >= 1) c.potQuantity.value = v;
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<CreateSaleController>();
    final col = Column(
      children: [
        const SectionHeader(title: 'Stove Set Information'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                          child: Text('Number of Pots',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500))),
                      Obx(() => Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: AppColors.brandPrimary),
                                onPressed: () {
                                  if (c.potQuantity.value > 1)
                                    c.potQuantity.value--;
                                },
                              ),
                              GestureDetector(
                                onTap: () => _editPotQuantity(context, c),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.brandPrimary),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('${c.potQuantity.value}',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.brandPrimary)),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline,
                                    color: AppColors.brandPrimary),
                                onPressed: () => c.potQuantity.value++,
                              ),
                            ],
                          )),
                    ],
                  ),
                  const Divider(),
                  Obx(() => SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Heat Retention Device',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500)),
                        subtitle: const Text('Included with the stove set'),
                        value: c.heatRetentionDevice.value,
                        activeColor: AppColors.brandPrimary,
                        onChanged: (v) => c.heatRetentionDevice.value = v,
                      )),
                ],
              ),
            ),
          ),
        ],
      );
    if (singleView) return Padding(padding: const EdgeInsets.all(16), child: col);
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: col);
  }
}

// ──────────────────────────── STEP 7: Cooking Habits ─────────────────────────

class _Step7CookingHabits extends StatelessWidget {
  final bool singleView;
  const _Step7CookingHabits({this.singleView = false});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<CreateSaleController>();
    final col = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Customer Cooking Habits (optional)'),
        _MapDropdownField(
            label: 'Previous Stove Type',
            options: c.stoveTypes,
            valueObs: c.previousStoveType),
        Obx(() => c.previousStoveType.value == 'other'
            ? Padding(
                padding: const EdgeInsets.only(top: 12),
                child: AppTextField(
                    label: 'Describe previous stove',
                    controller: c.previousStoveOtherCtrl,
                    textInputAction: TextInputAction.done))
            : const SizedBox.shrink()),
        const SizedBox(height: 16),
        AppTextField(
            label: 'Meals Per Day',
            controller: c.mealsPerDayCtrl,
            keyboardType: TextInputType.text,
            hint: 'e.g., 2 meals',
            textInputAction: TextInputAction.next),
        const SizedBox(height: 16),
        AppTextField(
            label: 'Cooking Fuel Source',
            controller: c.cookingFuelSourceCtrl,
            hint: 'e.g., Local market',
            textInputAction: TextInputAction.next),
        const SizedBox(height: 16),
        AppTextField(
            label: 'Cooking Location',
            controller: c.cookingLocationCtrl,
            hint: 'e.g., Outdoors, kitchen',
            textInputAction: TextInputAction.done),
      ],
    );
    if (singleView) return Padding(padding: const EdgeInsets.all(16), child: col);
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: col);
  }
}

/// Dropdown where keys are API values and map values are display labels.
class _MapDropdownField extends StatelessWidget {
  final String label;
  final Map<String, String> options;
  final RxString valueObs;
  const _MapDropdownField(
      {required this.label, required this.options, required this.valueObs});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        const SizedBox(height: 8),
        Obx(() => DropdownButtonFormField<String>(
              value: valueObs.value.isEmpty ? null : valueObs.value,
              hint: Text('Select $label'),
              items: options.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => valueObs.value = v ?? '',
              decoration: const InputDecoration(),
            )),
      ],
    );
  }
}

// ──────────────────────────── STEP 8: T&C ────────────────────────────────────

class _Step8Terms extends StatelessWidget {
  final bool singleView;
  const _Step8Terms({this.singleView = false});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<CreateSaleController>();
    final col = Column(
      children: [
        const SectionHeader(
            title: 'Terms & Conditions',
              subtitle: 'All terms must be accepted to proceed'),
          Card(
            child: Column(
              children: [
                _TcTile(
                    obs: c.tcPoaGoverned,
                    label:
                        'This sale is governed under POA (Programme of Activities)'),
                _TcTile(
                    obs: c.tcMonitoring,
                    label:
                        'I accept monitoring of stove usage for carbon accounting purposes'),
                _TcTile(
                    obs: c.tcNoResell,
                    label:
                        'I commit that this stove will not be resold to a third party'),
                _TcTile(
                    obs: c.tcEmissions,
                    label:
                        'I acknowledge the emission reduction benefits of this cookstove'),
                _TcTile(
                    obs: c.tcNoExport,
                    label:
                        'I confirm the stove will not be exported outside Nigeria'),
                _TcTile(
                    obs: c.tcDemonstration,
                    label:
                        'A proper demonstration of the stove has been given to the end user'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Obx(() => c.allTcAccepted
              ? Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [
                    Icon(Icons.check_circle,
                        color: AppColors.success, size: 18),
                    SizedBox(width: 8),
                    Text('All terms accepted',
                        style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600)),
                  ]),
                )
              : Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [
                    Icon(Icons.info_outline,
                        color: AppColors.warning, size: 18),
                    SizedBox(width: 8),
                    Text('Please accept all terms to proceed',
                        style: TextStyle(color: AppColors.warning)),
                  ]),
                )),
      ],
    );
    if (singleView) return Padding(padding: const EdgeInsets.all(16), child: col);
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: col);
  }
}

class _TcTile extends StatelessWidget {
  final RxBool obs;
  final String label;
  const _TcTile({required this.obs, required this.label});

  @override
  Widget build(BuildContext context) {
    return Obx(() => CheckboxListTile(
          value: obs.value,
          onChanged: (v) => obs.value = v ?? false,
          activeColor: AppColors.brandPrimary,
          title: Text(label, style: const TextStyle(fontSize: 13)),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ));
  }
}

// ──────────────────────────── STEP 9: Media ──────────────────────────────────

class _Step9Media extends StatelessWidget {
  final bool singleView;
  const _Step9Media({this.singleView = false});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<CreateSaleController>();
    final col = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          const SectionHeader(
              title: 'Photos & Signature',
              subtitle: 'Stove photo and signature are required'),
          _ImagePickerTile(
            label: 'Stove Photo *',
            onCamera: () => c.pickImage(ImageSource.camera, field: 'stove'),
            onGallery: () => c.pickImage(ImageSource.gallery, field: 'stove'),
            setObs: c.stoveImageSet,
            fileObs: c.stoveImageFile,
            uploadProgressObs: c.stoveImageUploadProgress,
            onClear: () => c.clearImage('stove'),
          ),
          const SizedBox(height: 12),
          // Agreement document — optional
          _ImagePickerTile(
            label: 'Agreement Document (optional)',
            onCamera: () => c.pickImage(ImageSource.camera, field: 'agreement'),
            onGallery: () =>
                c.pickImage(ImageSource.gallery, field: 'agreement'),
            setObs: c.agreementImageSet,
            fileObs: c.agreementImageFile,
            uploadProgressObs: c.agreementImageUploadProgress,
            onClear: () => c.clearImage('agreement'),
          ),
          const SizedBox(height: 16),
          const Text('Customer Signature *',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Signature(
                  controller: c.signatureController,
                  backgroundColor: AppColors.white),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Clear'),
                onPressed: () => c.signatureController.clear(),
              ),
            ],
          ),
        ],
      );
    if (singleView) return Padding(padding: const EdgeInsets.all(16), child: col);
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: col);
  }
}

class _ImagePickerTile extends StatelessWidget {
  final String label;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final RxBool setObs;
  final Rxn<File>? fileObs;
  final Rxn<double>? uploadProgressObs;
  final VoidCallback? onClear;

  const _ImagePickerTile({
    required this.label,
    required this.onCamera,
    required this.onGallery,
    required this.setObs,
    this.fileObs,
    this.uploadProgressObs,
    this.onClear,
  });

  void _openFullscreen(BuildContext context, File file) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => _FullscreenImageViewer(file: file),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final done = setObs.value;
      final file = fileObs?.value;
      final progress = uploadProgressObs?.value;
      final isUploading = progress == -1;

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: done
              ? AppColors.success.withValues(alpha: 0.05)
              : AppColors.white,
          border: Border.all(
              color: done ? AppColors.success : AppColors.borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(done ? Icons.check_circle : Icons.image_outlined,
                    color: done ? AppColors.success : AppColors.textMuted,
                    size: 22),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 13))),
                TextButton.icon(
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: const Text('Camera'),
                  onPressed: isUploading ? null : onCamera,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: const Text('Gallery'),
                  onPressed: isUploading ? null : onGallery,
                ),
              ],
            ),
            if (file != null) ...[
              const SizedBox(height: 10),
              Stack(
                children: [
                  GestureDetector(
                    onTap: () => _openFullscreen(context, file),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        file,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: onClear,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (isUploading) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  const Text('Uploading…',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
              const SizedBox(height: 4),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      );
    });
  }
}

// ──────────────────────────── Searchable picker ───────────────────────────────

/// Tappable field that opens a searchable bottom-sheet picker.
class _SearchablePickerField extends StatelessWidget {
  final String? value;
  final String hint;
  final bool enabled;
  final VoidCallback? onTap;

  const _SearchablePickerField({
    required this.hint,
    this.value,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : AppColors.borderColor.withValues(alpha: 0.3),
          border: Border.all(
            color: value != null ? AppColors.brandPrimary : AppColors.borderColor,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? hint,
                style: TextStyle(
                  fontSize: 14,
                  color: value != null ? AppColors.textPrimary : AppColors.textMuted,
                  fontWeight: value != null ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: enabled ? AppColors.textMuted : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a bottom-sheet with a search field and scrollable list of [items].
/// Returns the selected item, or null if dismissed.
Future<String?> _showSearchPicker(
  BuildContext context, {
  required String title,
  required List<String> items,
  String selected = '',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SearchPickerSheet(title: title, items: items, selected: selected),
  );
}

class _SearchPickerSheet extends StatefulWidget {
  final String title;
  final List<String> items;
  final String selected;
  const _SearchPickerSheet({required this.title, required this.items, required this.selected});

  @override
  State<_SearchPickerSheet> createState() => _SearchPickerSheetState();
}

class _SearchPickerSheetState extends State<_SearchPickerSheet> {
  final _ctrl = TextEditingController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    _ctrl.addListener(() {
      final q = _ctrl.text.toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? widget.items
            : widget.items.where((s) => s.toLowerCase().contains(q)).toList();
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.82;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => _ctrl.clear(),
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderColor),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(child: Text('No results found', style: TextStyle(color: AppColors.textMuted)))
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                    itemBuilder: (_, i) {
                      final item = _filtered[i];
                      final isSelected = item == widget.selected;
                      return ListTile(
                        title: Text(item, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: AppColors.brandPrimary, size: 20)
                            : null,
                        tileColor: isSelected ? AppColors.brandPrimary.withValues(alpha: 0.06) : null,
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FullscreenImageViewer extends StatelessWidget {
  final File file;
  const _FullscreenImageViewer({required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child:
                    const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── Validation error sheet ─────────────────────────

class _SaleValidationSheet extends StatelessWidget {
  final List<ValidationError> errors;
  const _SaleValidationSheet({required this.errors});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<CreateSaleController>();
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                const Icon(Icons.cancel_outlined, color: AppColors.error, size: 22),
                const SizedBox(width: 8),
                Text(
                  '${errors.length} issue${errors.length > 1 ? 's' : ''} to fix before submitting',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: errors.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 20),
              itemBuilder: (_, i) {
                final e = errors[i];
                final displayStep = e.step <= 2 ? e.step + 1 : e.step;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.brandLight,
                    child: Text(
                      '$displayStep',
                      style: const TextStyle(fontSize: 11, color: AppColors.brandPrimary, fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text(e.field, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(e.message, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  trailing: Text(e.stepTitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  onTap: () {
                    Navigator.of(context).pop();
                    if (c.singleViewMode.value) {
                      final key = c.singleViewKeys[e.step];
                      if (key?.currentContext != null) {
                        Scrollable.ensureVisible(
                          key!.currentContext!,
                          alignment: 0.0,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      }
                    } else {
                      c.currentStep.value = e.step;
                      c.pageController.animateToPage(
                        e.step,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── Pre-submit preview sheet ────────────────────────

class _SalePreviewSheet extends StatelessWidget {
  const _SalePreviewSheet();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<CreateSaleController>();
    final amt = double.tryParse(c.amountCtrl.text.replaceAll(',', ''));
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                const Icon(Icons.fact_check_outlined, color: AppColors.brandPrimary, size: 22),
                const SizedBox(width: 8),
                const Text('Review Before Submitting', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PreviewSection('Transaction', [
                    _PreviewRow('Transaction ID', c.transactionId.value),
                    _PreviewRow('Stove', c.selectedStove.value?.displayId ?? '—'),
                    _PreviewRow('Sales Date', DateFormat('d MMM yyyy').format(c.salesDate.value)),
                  ]),
                  _PreviewSection('Buyer & End User', [
                    _PreviewRow('Contact Person', c.contactPersonCtrl.text),
                    _PreviewRow('Contact Phone', c.contactPhoneCtrl.text),
                    _PreviewRow('First Name', c.endUserNameCtrl.text),
                    _PreviewRow('Surname', c.endUserSurnameCtrl.text),
                    _PreviewRow('End User Phone', c.phoneCtrl.text),
                    if (c.akaCtrl.text.isNotEmpty) _PreviewRow('AKA', c.akaCtrl.text),
                    if (c.otherPhoneCtrl.text.isNotEmpty) _PreviewRow('Other Phone', c.otherPhoneCtrl.text),
                  ]),
                  _PreviewSection('Location', [
                    _PreviewRow('State', c.selectedState.value),
                    if (c.selectedLga.value.isNotEmpty) _PreviewRow('LGA', c.selectedLga.value),
                    _PreviewRow('Address', c.fullAddressCtrl.text),
                    if (c.latitude.value != null)
                      _PreviewRow('GPS', '${c.latitude.value!.toStringAsFixed(5)}, ${c.longitude.value!.toStringAsFixed(5)}'),
                  ]),
                  _PreviewSection('Sale & Payment', [
                    _PreviewRow('Stove', c.selectedStove.value?.displayId ?? '—'),
                    _PreviewRow('Payment Type', c.isInstallment ? (c.selectedModel.value?.name ?? 'Installment') : 'Full Payment'),
                    _PreviewRow('Amount', formatNaira(amt)),
                    _PreviewRow('Amount Received', formatNaira(double.tryParse(c.amountReceivedCtrl.text.replaceAll(',', '')))),
                    _PreviewRow('Pots', '${c.potQuantity.value}'),
                    _PreviewRow('Heat Retention', c.heatRetentionDevice.value ? 'Yes' : 'No'),
                  ]),
                  _PreviewSection('Cooking Habits', [
                    _PreviewRow('Previous Stove', c.stoveTypes[c.previousStoveType.value] ?? c.previousStoveType.value),
                    if (c.previousStoveOtherCtrl.text.isNotEmpty)
                      _PreviewRow('Specify', c.previousStoveOtherCtrl.text),
                    _PreviewRow('Meals Per Day', c.mealsPerDayCtrl.text),
                    _PreviewRow('Fuel Source', c.cookingFuelSourceCtrl.text),
                    _PreviewRow('Cooking Location', c.cookingLocationCtrl.text),
                  ]),
                  _PreviewSection('Documents', [
                    _PreviewRow('Stove Image', c.stoveImageSet.value ? '✓  Attached' : '—'),
                    _PreviewRow('Agreement Image', c.agreementImageSet.value ? '✓  Attached' : '— (optional)'),
                    if (c.isInstallment) _PreviewRow('Payment Proof', c.paymentProofSet.value ? '✓  Attached' : '—'),
                    _PreviewRow('Signature', c.hasSignature ? '✓  Captured' : '—'),
                  ]),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.brandLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.brandPrimary.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: AppColors.brandPrimary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Please verify all details are correct. Once submitted, changes must be made by an admin.',
                            style: TextStyle(fontSize: 12, color: AppColors.brandPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Obx(() => ElevatedButton(
                    onPressed: c.isSubmitting.value
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            c.doSubmit();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: Colors.white,
                    ),
                    child: c.isSubmitting.value
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Confirm & Submit'),
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── Sheet helpers ───────────────────────────────────

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 40, height: 4,
        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  final String title;
  final List<_PreviewRow> rows;
  const _PreviewSection(this.title, this.rows);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.8),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.borderColor),
          ),
          child: Column(
            children: rows.asMap().entries.map((entry) {
              final isLast = entry.key == rows.length - 1;
              return Column(
                children: [
                  entry.value,
                  if (!isLast) const Divider(height: 1, indent: 16),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;
  const _PreviewRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
