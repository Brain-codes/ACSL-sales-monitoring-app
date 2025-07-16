import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/admin/sales/controller/manage_sales_controller.dart';
import 'package:stove_transaction/admin/sales/model/filter_model.dart';
import 'package:stove_transaction/admin/sales/model/sale_model.dart';
import 'package:stove_transaction/admin/sales/ui/filter_sales_screen.dart';
import 'package:stove_transaction/admin/sales/ui/manage_sales_card_tile.dart';
import 'package:stove_transaction/admin/sales/ui/shimmer_sale_card.dart';
import 'package:stove_transaction/admin/sales/ui/sale_details_screen.dart';
import 'package:stove_transaction/admin/sub_accounts/controller/manage_sales_agents_controller.dart';
import 'package:stove_transaction/agent/sales_form/widgets/custom_textfield.dart';
import 'package:stove_transaction/core/constants/app_icons.dart';
import 'package:stove_transaction/form/ui/user_form.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';
import 'package:stove_transaction/shared/widgets/page_header_tile.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:intl/intl.dart';

class ManageSalesScreen extends StatelessWidget {
  final bool showBackButton; // Set to true to show back button
  final ManageSalesController controller = Get.put(ManageSalesController());
  final TextEditingController searchText = TextEditingController();

  ManageSalesScreen({
    Key? key,
    this.showBackButton = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BaseAppBar(
        showBackButton: showBackButton,
        showBottomBorder: false,
        otherWidgets: InkWell(
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
                  bottom: MediaQuery.of(context).viewInsets.bottom,
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
                            dateRange: dateRange, state: state, lga: lga);
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
            padding: EdgeInsets.only(right: 15),
            decoration: BoxDecoration(
              color: AppColors.inactiveTextFormFieldColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(1000),
            ),
            child: Center(child: SvgPicture.asset(AppIcons.filterIcon)),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeaderTile(
                  title: 'Manage Sales',
                  subtitle: 'View and manage sales here.'),
              const SizedBox(height: 15),
              CustomTextField(
                inputType: TextInputType.text,
                actionKeyboard: TextInputAction.done,
                label: 'Search by Customer\'s Name',
                controller: searchText,
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
              const SizedBox(height: 10),

              /// Filter Chips
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
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Wrap(spacing: 6, runSpacing: 6, children: chips),
                      )
                    : SizedBox.shrink();
              }),

              Obx(() {
                if (controller.isLoading.value && controller.sales.isEmpty) {
                  return Expanded(
                    child: ListView.builder(
                      itemCount: 6,
                      itemBuilder: (_, __) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ShimmerSaleCard(),
                      ),
                    ),
                  );
                }

                if (controller.sales.isEmpty) {
                  return Expanded(
                    child: Center(
                        child: Text('No sales found',
                            style: TextStyle(fontSize: 18))),
                  );
                }

                return Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => controller.fetchSales(refresh: true),
                    child: ListView.builder(
                      itemCount: controller.sales.length +
                          (controller.isLoadingMore.value ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == controller.sales.length) {
                          return Center(
                              child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ));
                        }
                        final sale = controller.sales[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: () => {
                              Get.put(ManageSalesAgentsController()),
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      SaleDetailsScreen(sale: sale),
                                ),
                              )
// SaleDetailsScreen
                            },
                            // Get.to(() => SaleDetailsScreen(sale: sale)),
                            child: ManageSalesCardTile(saleData: sale),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.to(
            () => UserForm(),
          ); // Navigate to UserForm for new sale
        },
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        shape: CircleBorder(
          side: BorderSide(color: Colors.grey, width: 1),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

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
