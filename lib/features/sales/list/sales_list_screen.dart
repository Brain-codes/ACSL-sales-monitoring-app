import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/routes/app_routes.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';
import 'package:stove_transaction/core/services/sync_service.dart';
import 'package:stove_transaction/core/utils/formatters.dart';
import 'package:stove_transaction/core/widgets/empty_state.dart';
import 'package:stove_transaction/core/widgets/offline_banner.dart';
import 'package:stove_transaction/features/sales/models/sale_model.dart';
import 'sales_list_controller.dart';

final _dateFmt = DateFormat('d MMM yyyy');

String _fmtAmount(double? v) => formatNaira(v);
String _fmtDate(DateTime? d) => d != null ? _dateFmt.format(d) : '—';
String _fmtRole(String s) => s.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

String _fmtPaymentStatus(String s) {
  switch (s.toLowerCase()) {
    case 'paid': return 'Paid';
    case 'partially_paid': return 'Partially Paid';
    case 'unpaid': return 'Unpaid';
    default: return s;
  }
}

class SalesListScreen extends StatelessWidget {
  const SalesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(SalesListController());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales'),
        actions: [
          Obx(() => IconButton(
            tooltip: c.isTableView.value ? 'Switch to Card view' : 'Switch to Table view',
            icon: Icon(c.isTableView.value ? Icons.grid_view_rounded : Icons.table_rows_rounded),
            onPressed: c.toggleView,
          )),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'sales_list_create_sale',
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Sale'),
        onPressed: () async {
          await Get.toNamed(AppRoutes.salesCreate);
          c.fetchSales();
        },
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          _FilterRow(),
          Expanded(
            child: Obx(() {
              if (c.isLoading.value) return const Center(child: CircularProgressIndicator());
              if (c.error.value.isNotEmpty && c.sales.isEmpty && c.pendingSales.isEmpty) {
                return EmptyState(message: c.error.value, icon: Icons.error_outline, actionLabel: 'Retry', onAction: c.fetchSales);
              }
              if (c.sales.isEmpty && c.pendingSales.isEmpty) {
                return EmptyState(
                  message: 'No sales found for ${c.filterLabel.toLowerCase()}.',
                  icon: Icons.receipt_long_outlined,
                  actionLabel: 'Create Sale',
                  onAction: () => Get.toNamed(AppRoutes.salesCreate),
                );
              }
              return RefreshIndicator(
                onRefresh: c.fetchSales,
                child: Column(
                  children: [
                    if (c.pendingSales.isNotEmpty) _PendingSalesSection(sales: c.pendingSales),
                    Expanded(
                      child: c.isTableView.value
                          ? _SalesTableView(sales: c.sales)
                          : _SalesCardList(sales: c.sales),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── Pending (offline queue) sales section ────────────────────────────────────

class _PendingSalesSection extends StatelessWidget {
  final List<SaleModel> sales;
  const _PendingSalesSection({required this.sales});

  @override
  Widget build(BuildContext context) {
    final connectivity = Get.find<ConnectivityService>();
    final syncSvc = Get.find<SyncService>();
    final listCtrl = Get.find<SalesListController>();
    return Container(
      color: const Color(0xFFFFFBEB),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_upload_outlined, size: 15, color: Color(0xFFD97706)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${sales.length} sale${sales.length > 1 ? 's' : ''} pending sync',
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFD97706),
                  ),
                ),
              ),
              Obx(() {
                final online = connectivity.isOnline.value;
                final syncing = syncSvc.isSyncing.value;
                return TextButton.icon(
                  icon: syncing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD97706)))
                      : const Icon(Icons.sync, size: 16, color: Color(0xFFD97706)),
                  label: Text(
                    syncing ? 'Syncing…' : 'Sync Now',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFD97706)),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: (!online || syncing)
                      ? null
                      : () async {
                          await syncSvc.syncPendingSales();
                          await listCtrl.fetchSales();
                        },
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          ...sales.map((s) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.endUserName ?? s.transactionId,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      if (s.stoveSerialNo != null)
                        Text(s.stoveSerialNo!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      if (s.amount != null)
                        Text(_fmtAmount(s.amount), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Pending Sync',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ── Table view ────────────────────────────────────────────────────────────────

class _SalesTableView extends StatelessWidget {
  final List<SaleModel> sales;
  const _SalesTableView({required this.sales});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.brandLight),
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: AppColors.textPrimary,
          ),
          dataRowMinHeight: 48,
          dataRowMaxHeight: 64,
          columnSpacing: 20,
          border: TableBorder.all(color: const Color(0xFFE5E7EB), width: 1, borderRadius: BorderRadius.circular(8)),
          columns: const [
            DataColumn(label: Text('Customer')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('Partner')),
            DataColumn(label: Text('Amount'), numeric: true),
            DataColumn(label: Text('Serial No')),
            DataColumn(label: Text('State')),
            DataColumn(label: Text('LGA')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Date')),
          ],
          rows: sales.map((s) => DataRow(
            cells: [
              DataCell(Text(s.endUserName ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
              DataCell(Text(s.phone ?? 'N/A', style: const TextStyle(fontSize: 13))),
              DataCell(Text(s.partnerName ?? 'N/A', style: const TextStyle(fontSize: 13))),
              DataCell(Text(_fmtAmount(s.amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.brandPrimary))),
              DataCell(Text(s.stoveSerialNo ?? 'N/A', style: const TextStyle(fontSize: 12))),
              DataCell(Text(s.state ?? 'N/A', style: const TextStyle(fontSize: 13))),
              DataCell(Text(s.lga ?? 'N/A', style: const TextStyle(fontSize: 13))),
              DataCell(_StatusBadge(
                status: (s.isInstallment == true && s.paymentStatus != null)
                    ? s.paymentStatus!
                    : (s.status ?? 'pending'),
              )),
              DataCell(Text(_fmtDate(s.salesDate ?? s.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
            ],
            onSelectChanged: (_) => _showSaleDetail(context, s),
          )).toList(),
        ),
      ),
    );
  }
}

// ── Card / grid list view ──────────────────────────────────────────────────────

class _SalesCardList extends StatelessWidget {
  final List<SaleModel> sales;
  const _SalesCardList({required this.sales});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: sales.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _SaleCard(sale: sales[i]),
    );
  }
}

// ── Filter row ────────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = Get.find<SalesListController>();
    const quickFilters = [SalesFilter.all, SalesFilter.today, SalesFilter.week, SalesFilter.month];
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Obx(() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...quickFilters.map((f) {
              final selected = c.filter.value == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(_label(f)),
                  selected: selected,
                  selectedColor: AppColors.brandPrimary,
                  labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontSize: 13),
                  onSelected: (_) => c.setFilter(f),
                ),
              );
            }),
            // Custom date range chip
            if (c.filter.value == SalesFilter.custom)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InputChip(
                  avatar: const Icon(Icons.date_range_outlined, size: 16, color: Colors.white),
                  label: Text(c.filterLabel, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  backgroundColor: AppColors.brandPrimary,
                  deleteIconColor: Colors.white.withValues(alpha: 0.8),
                  onDeleted: () {
                    c.customStart.value = null;
                    c.customEnd.value = null;
                    c.setFilter(SalesFilter.all);
                  },
                  onPressed: () => _showDateRangePicker(context, c),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  avatar: const Icon(Icons.date_range_outlined, size: 16, color: AppColors.textPrimary),
                  label: const Text('Custom Range'),
                  selected: false,
                  labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  onSelected: (_) => _showDateRangePicker(context, c),
                ),
              ),
          ],
        ),
      )),
    );
  }

  String _label(SalesFilter f) {
    switch (f) {
      case SalesFilter.all: return 'All';
      case SalesFilter.today: return 'Today';
      case SalesFilter.week: return 'This Week';
      case SalesFilter.month: return 'This Month';
      case SalesFilter.custom: return 'Custom Range';
    }
  }

  void _showDateRangePicker(BuildContext context, SalesListController c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DateRangeSheet(controller: c),
    );
  }
}

class _DateRangeSheet extends StatefulWidget {
  final SalesListController controller;
  const _DateRangeSheet({required this.controller});

  @override
  State<_DateRangeSheet> createState() => _DateRangeSheetState();
}

class _DateRangeSheetState extends State<_DateRangeSheet> {
  DateTime? _start;
  DateTime? _end;
  final _dateFmt2 = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    _start = widget.controller.customStart.value;
    _end = widget.controller.customEnd.value;
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start ?? DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
      helpText: 'Select start date',
    );
    if (picked != null) {
      setState(() {
        _start = picked;
        if (_end != null && _end!.isBefore(picked)) _end = null;
      });
    }
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end ?? (_start ?? DateTime.now()),
      firstDate: _start ?? DateTime(2010),
      lastDate: DateTime.now(),
      helpText: 'Select end date',
    );
    if (picked != null) setState(() => _end = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.date_range_outlined, color: AppColors.brandPrimary, size: 22),
                    const SizedBox(width: 8),
                    const Text('Custom Date Range', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 20),
                _DatePickerTile(
                  label: 'Start Date',
                  value: _start != null ? _dateFmt2.format(_start!) : null,
                  onTap: _pickStart,
                ),
                const SizedBox(height: 12),
                _DatePickerTile(
                  label: 'End Date',
                  value: _end != null ? _dateFmt2.format(_end!) : null,
                  placeholder: _start == null ? 'Pick a start date first' : 'Select end date (optional)',
                  enabled: _start != null,
                  onTap: _pickEnd,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _start == null
                            ? null
                            : () {
                                Navigator.pop(context);
                                widget.controller.setCustomDateRange(_start!, _end);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Apply Filter'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final String label;
  final String? value;
  final String? placeholder;
  final bool enabled;
  final VoidCallback onTap;

  const _DatePickerTile({
    required this.label,
    required this.onTap,
    this.value,
    this.placeholder,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.grey.shade50,
          border: Border.all(
            color: value != null ? AppColors.brandPrimary : AppColors.borderColor,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: value != null ? AppColors.brandPrimary : AppColors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    value ?? placeholder ?? 'Select date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: value != null ? FontWeight.w600 : FontWeight.normal,
                      color: value != null ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: enabled ? AppColors.textMuted : Colors.grey.shade300),
          ],
        ),
      ),
    );
  }
}

void _showSaleDetail(BuildContext context, SaleModel sale) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SaleDetailSheet(sale: sale),
  );
}

// ── Sale card ─────────────────────────────────────────────────────────────────

class _SaleCard extends StatelessWidget {
  final SaleModel sale;
  const _SaleCard({required this.sale});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showSaleDetail(context, sale),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.brandLight, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.local_fire_department_outlined, color: AppColors.brandPrimary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sale.endUserName ?? 'Unknown Customer',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('${sale.stoveSerialNo ?? 'No serial'} · ${_fmtDate(sale.salesDate)}',
                        style: Theme.of(context).textTheme.bodySmall),
                    if (sale.state != null) ...[
                      const SizedBox(height: 2),
                      Text(sale.state!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_fmtAmount(sale.amount), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.brandPrimary)),
                  const SizedBox(height: 4),
                  _StatusBadge(
                    status: (sale.isInstallment == true && sale.paymentStatus != null)
                        ? sale.paymentStatus!
                        : (sale.status ?? 'pending'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status.toLowerCase()) {
      case 'completed':
        color = AppColors.success; label = 'Completed'; break;
      case 'paid':
        color = AppColors.success; label = 'Paid'; break;
      case 'partially_paid':
        color = const Color(0xFFD97706); label = 'Partial'; break;
      case 'unpaid':
        color = AppColors.error; label = 'Unpaid'; break;
      case 'pending':
        color = AppColors.warning; label = 'Pending'; break;
      case 'cancelled':
        color = AppColors.error; label = 'Cancelled'; break;
      default:
        color = AppColors.textMuted; label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Sale detail sheet ─────────────────────────────────────────────────────────

class _SaleDetailSheet extends StatelessWidget {
  final SaleModel sale;
  const _SaleDetailSheet({required this.sale});

  @override
  Widget build(BuildContext context) {
    final isInstallment = sale.isInstallment == true || sale.selectedModelId != null;
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
                const Icon(Icons.receipt_long_outlined, color: AppColors.brandPrimary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sale.endUserName ?? 'Sale Details',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusBadge(
                  status: (isInstallment && sale.paymentStatus != null)
                      ? sale.paymentStatus!
                      : (sale.status ?? 'pending'),
                ),
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
                  _DetailSection('Transaction', [
                    _DetailRow('Transaction ID', sale.transactionId),
                    _DetailRow('Stove Serial No', sale.stoveSerialNo ?? '—'),
                    _DetailRow('Sales Date', _fmtDate(sale.salesDate ?? sale.createdAt)),
                  ]),
                  _DetailSection('Customer', [
                    _DetailRow('End User', sale.endUserName ?? '—'),
                    if (sale.aka != null && sale.aka!.isNotEmpty) _DetailRow('Also Known As', sale.aka!),
                    _DetailRow('Phone', sale.phone ?? '—'),
                    if (sale.otherPhone != null && sale.otherPhone!.isNotEmpty) _DetailRow('Other Phone', sale.otherPhone!),
                    if (sale.contactPerson != null && sale.contactPerson!.isNotEmpty) _DetailRow('Contact Person', sale.contactPerson!),
                    if (sale.contactPhone != null && sale.contactPhone!.isNotEmpty) _DetailRow('Contact Phone', sale.contactPhone!),
                  ]),
                  _DetailSection('Location', [
                    _DetailRow('State', sale.state ?? '—'),
                    if (sale.lga != null && sale.lga!.isNotEmpty) _DetailRow('LGA', sale.lga!),
                    if (sale.address != null && sale.address!.isNotEmpty) _DetailRow('Address', sale.address!),
                    if (sale.latitude != null)
                      _DetailRow('GPS', '${sale.latitude!.toStringAsFixed(5)}, ${sale.longitude!.toStringAsFixed(5)}'),
                  ]),
                  _DetailSection('Sale', [
                    _DetailRow('Amount', _fmtAmount(sale.amount)),
                    _DetailRow('Payment Type', isInstallment ? 'Installment' : 'Full Payment'),
                    if (isInstallment && sale.paymentModelName != null)
                      _DetailRow('Payment Model', sale.paymentModelName!),
                    if (isInstallment && sale.paymentModelDurationMonths != null)
                      _DetailRow('Duration', '${sale.paymentModelDurationMonths} months'),
                    if (isInstallment && sale.paymentStatus != null)
                      _DetailRow('Payment Status', _fmtPaymentStatus(sale.paymentStatus!)),
                    if (isInstallment && sale.totalPaid != null)
                      _DetailRow('Total Paid', _fmtAmount(sale.totalPaid)),
                    if (isInstallment && sale.amount != null && sale.totalPaid != null && sale.amount! > sale.totalPaid!)
                      _DetailRow('Balance', _fmtAmount(sale.amount! - sale.totalPaid!)),
                    if (isInstallment && sale.initialPaymentAmount != null)
                      _DetailRow('Initial Payment', _fmtAmount(sale.initialPaymentAmount)),
                    if (isInstallment && sale.initialPaymentMethod != null && sale.initialPaymentMethod!.isNotEmpty)
                      _DetailRow('Payment Method', sale.initialPaymentMethod!),
                    if (sale.potQuantity != null) _DetailRow('Pots', '${sale.potQuantity}'),
                    if (sale.heatRetentionDevice != null)
                      _DetailRow('Heat Retention Device', sale.heatRetentionDevice! ? 'Yes' : 'No'),
                  ]),
                  if (sale.partnerName != null && sale.partnerName!.isNotEmpty)
                    _DetailSection('Partner', [
                      _DetailRow('Partner Name', sale.partnerName!),
                      if (sale.retailerBranch != null && sale.retailerBranch!.isNotEmpty)
                        _DetailRow('Retailer Branch', sale.retailerBranch!),
                    ]),
                  if (sale.previousStoveType != null ||
                      sale.mealsPerDay != null ||
                      sale.cookingFuelSource != null ||
                      sale.cookingLocation != null)
                    _DetailSection('Cooking Habits', [
                      if (sale.previousStoveType != null) _DetailRow('Previous Stove', sale.previousStoveType!),
                      if (sale.mealsPerDay != null) _DetailRow('Meals Per Day', sale.mealsPerDay!),
                      if (sale.cookingFuelSource != null) _DetailRow('Fuel Source', sale.cookingFuelSource!),
                      if (sale.cookingLocation != null) _DetailRow('Cooking Location', sale.cookingLocation!),
                    ]),
                  _DetailSection('Documents', [
                    _DetailRow('Stove Image', sale.stoveImageId != null ? '✓  Attached' : '—'),
                    _DetailRow('Agreement Image', sale.agreementImageId != null ? '✓  Attached' : '—'),
                    _DetailRow('Signature', sale.signatureId != null ? '✓  Captured' : '—'),
                  ]),
                  if (sale.creatorName != null)
                    _DetailSection('Recorded By', [
                      _DetailRow('Name', sale.creatorName!),
                      if (sale.creatorRole != null)
                        _DetailRow('Role', _fmtRole(sale.creatorRole!)),
                    ]),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<_DetailRow> rows;
  const _DetailSection(this.title, this.rows);

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

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
