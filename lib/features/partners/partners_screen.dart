import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/widgets/empty_state.dart';
import 'package:stove_transaction/core/widgets/offline_banner.dart';
import 'package:stove_transaction/features/partners/models/partner_model.dart';
import 'partners_controller.dart';

class PartnersScreen extends StatelessWidget {
  const PartnersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(PartnersController());
    return Scaffold(
      appBar: AppBar(title: const Text('My Partners')),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: Obx(() {
              if (c.isLoading.value) return const Center(child: CircularProgressIndicator());
              if (c.error.value.isNotEmpty) {
                return EmptyState(message: c.error.value, icon: Icons.error_outline, actionLabel: 'Retry', onAction: c.fetchPartners);
              }
              if (c.partners.isEmpty) {
                return const EmptyState(message: 'No partners assigned yet.', icon: Icons.people_outline);
              }
              return RefreshIndicator(
                onRefresh: c.fetchPartners,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: c.partners.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _PartnerCard(partner: c.partners[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  final PartnerModel partner;
  const _PartnerCard({required this.partner});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.brandLight,
                  child: Text(partner.initials, style: const TextStyle(color: AppColors.brandPrimary, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(partner.partnerName, style: Theme.of(context).textTheme.titleMedium),
                      if (partner.branch.isNotEmpty || partner.state.isNotEmpty)
                        Text(
                          [if (partner.branch.isNotEmpty) partner.branch, if (partner.state.isNotEmpty) partner.state].join(' · '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChip(label: 'Allocated', value: '${partner.stovesAllocated}', color: AppColors.brandPrimary),
                const SizedBox(width: 8),
                _StatChip(label: 'Sold', value: '${partner.stovesSold}', color: AppColors.success),
              ],
            ),
            if (partner.contactPerson != null || partner.contactPhone != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.person_outline, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(partner.contactPerson ?? partner.contactPhone ?? '', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        text: TextSpan(children: [
          TextSpan(text: '$value ', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
          TextSpan(text: label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12)),
        ]),
      ),
    );
  }
}
