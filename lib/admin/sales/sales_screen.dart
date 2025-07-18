// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:stove_transaction/admin/sales/model/filter_model.dart';
import 'package:stove_transaction/admin/sales/ui/empty_sales_screen.dart';
import 'package:stove_transaction/admin/sales/ui/filter_sales_screen.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/form/ui/user_form.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';
import 'package:stove_transaction/admin/sales/controller/manage_sales_controller.dart';
import 'package:stove_transaction/admin/sales/ui/sales_list_tile.dart';
import 'package:stove_transaction/admin/sales/ui/shimmer_sale_card.dart';
import 'package:stove_transaction/admin/sales/ui/sale_details_screen.dart';
import 'package:stove_transaction/agent/sales_form/widgets/custom_textfield.dart';
import 'package:stove_transaction/core/constants/app_icons.dart';

class SalesScreen extends StatelessWidget {
  final bool showBackArrow;
  const SalesScreen({
    Key? key,
    this.showBackArrow = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ManageSalesController controller = Get.put(ManageSalesController());
    final SessionManager _sessionManager = Get.find<SessionManager>();

    return Scaffold(
      appBar: !controller.isAdmin.value
          ? null
          : BaseAppBar(
              showBackButton: showBackArrow,
              title: controller.isAdmin.value ? "All Sales" : "My Sales",
            ),
      body: Obx(() {
        if (controller.isAdmin.value) {
          // Admin View
          return ListView.builder(
            itemCount: controller.sales.length,
            itemBuilder: (context, index) {
              final sale = controller.sales[index];
              return SalesListTile(
                sale: sale,
                onTap: () {
                  Get.to(() => SaleDetailsScreen(sale: sale));
                },
              );
            },
          );
        } else if (controller.isAgent.value) {
          // Agent View
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hi, ${_sessionManager.userName ?? 'Agent'}',
                        style: TextThemes(context).getTextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 25,
                          color: AppColors.primaryTextColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Color.fromARGB(255, 156, 55, 0),
                          borderRadius: BorderRadius.circular(1000),
                          border: Border.all(
                            color: AppColors.white,
                            width: 0.2,
                          ),
                        ),
                        child: Text(
                          'AU',
                          style: TextThemes(context).getTextStyle(
                            fontSize: 14,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 30),
                  Text(
                    'Sales Data',
                    style: TextThemes(context).getTextStyle(
                      fontSize: 15,
                      color: AppColors.secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 5.0),
                  Expanded(
                    child: Column(
                      children: [
                        // Search Bar
                        Flex(
                          direction: Axis.horizontal,
                          children: [
                            Expanded(
                              child: CustomTextField(
                                inputType: TextInputType.text,
                                actionKeyboard: TextInputAction.done,
                                label: 'Search by Customer\'s Name',
                                controller: controller.searchText,
                                prefixIcon: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: SvgPicture.asset(AppIcons.searchIcon,
                                      fit: BoxFit.scaleDown),
                                ),
                                onChanged: (value) {
                                  controller.endUserNameFilter.value = value;
                                },
                              ),
                            ),
                            SizedBox(width: 10),
                            // Filter Button
                            InkWell(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.white,
                                  isScrollControlled: true,
                                  isDismissible: true,
                                  enableDrag: true,
                                  barrierColor: Colors.black.withOpacity(0.5),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(20),
                                      topRight: Radius.circular(20),
                                    ),
                                  ),
                                  builder: (context) => Padding(
                                    padding: EdgeInsets.only(
                                      bottom: MediaQuery.of(context)
                                          .viewInsets
                                          .bottom,
                                    ),
                                    child: Wrap(
                                      children: [
                                        FilterSalesScreen(
                                          hasFilter: false,
                                          filterValue: null,
                                          onFilterSelected: ({
                                            DateRange? dateRange,
                                            String? state,
                                            String? lga,
                                          }) {
                                            controller.applyFilters(
                                                dateRange: dateRange,
                                                state: state,
                                                lga: lga);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryColor,
                                  borderRadius: BorderRadius.circular(1000),
                                  border: Border.all(
                                    color: AppColors.white,
                                    width: 0.2,
                                  ),
                                ),
                                child: Center(
                                  child: SvgPicture.asset(
                                    AppIcons.filterIcon,
                                    colorFilter: ColorFilter.mode(
                                      AppColors.white,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Filter Chips
                        Obx(() {
                          List<Widget> chips = [];

                          if (controller.dateRangeFilter.value != null) {
                            final range = controller.dateRangeFilter.value!;
                            chips.add(_buildFilterChip(
                              'Date: ${DateFormat('MMM dd').format(range.start)} - ${DateFormat('MMM dd').format(range.end)}',
                              () => controller.clearFilter('date'),
                            ));
                          }
                          if (controller.selectedState.value.isNotEmpty) {
                            chips.add(_buildFilterChip(
                              'State: ${controller.selectedState.value}',
                              () => controller.clearFilter('state'),
                            ));
                          }
                          if (controller.selectedLGA.value.isNotEmpty) {
                            chips.add(_buildFilterChip(
                              'LGA: ${controller.selectedLGA.value}',
                              () => controller.clearFilter('lga'),
                            ));
                          }

                          return chips.isNotEmpty
                              ? Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: chips),
                                )
                              : SizedBox.shrink();
                        }),

                        // Sales List
                        Expanded(
                          child: Obx(() {
                            if (controller.isLoading.value &&
                                controller.sales.isEmpty) {
                              return ListView.builder(
                                itemCount: 6,
                                itemBuilder: (_, __) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: ShimmerSaleCard(),
                                ),
                              );
                            }

                            if (controller.sales.isEmpty) {
                              return EmptySalesScreen();
                            }

                            return RefreshIndicator(
                              onRefresh: () async =>
                                  controller.fetchSales(refresh: true),
                              child: ListView.builder(
                                itemCount: controller.sales.length +
                                    (controller.isLoadingMore.value ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == controller.sales.length) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  final sale = controller.sales[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: SalesListTile(
                                      sale: sale,
                                      onTap: () {
                                        Get.to(() =>
                                            SaleDetailsScreen(sale: sale));
                                      },
                                    ),
                                  );
                                },
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          return const Center(child: Text('Unknown Role'));
        }
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.to(() => UserForm());
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // Helper method for building filter chips
  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Chip(
      label: Text(label, style: TextStyle(fontSize: 12)),
      deleteIcon: Icon(Icons.close, size: 16),
      onDeleted: onRemove,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(1000),
        side: BorderSide(width: 0.5, color: Colors.grey),
      ),
    );
  }
}
