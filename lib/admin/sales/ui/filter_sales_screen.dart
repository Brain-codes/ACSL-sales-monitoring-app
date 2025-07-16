// ignore_for_file: prefer_const_literals_to_create_immutables, must_be_immutable

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:stove_transaction/admin/sales/model/filter_model.dart';
import 'package:stove_transaction/shared/widgets/primary_button.dart';
import 'package:stove_transaction/core/constants/app_icons.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';

class FilterSalesScreen extends StatefulWidget {
  bool hasFilter;
  SortOption? filterValue;
  final Function({
    DateRange? dateRange,
    String? state,
    String? lga,
  }) onFilterSelected;

  FilterSalesScreen({
    super.key,
    required this.hasFilter,
    required this.filterValue,
    required this.onFilterSelected,
  });

  @override
  State<FilterSalesScreen> createState() => _FilterSalesScreenState();
}

class _FilterSalesScreenState extends State<FilterSalesScreen> {
  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();

  // Static lists for State and LGA
  final List<String> states = ['Lagos', 'Abuja', 'Kano', 'Oyo'];
  final Map<String, List<String>> lgas = {
    'Lagos': ['Ikeja', 'Lekki', 'Yaba'],
    'Abuja': ['Garki', 'Wuse', 'Maitama'],
    'Kano': ['Fagge', 'Nasarawa', 'Gwale'],
    'Oyo': ['Ibadan North', 'Ibadan South', 'Ogbomosho']
  };

  String? selectedState;
  String? selectedLGA;

  List<SortOption> defaultSort = [
    SortOption(
      name: "This week",
      value: DateRange(
        start:
            DateTime.now().subtract(Duration(days: DateTime.now().weekday % 7)),
        end: DateTime.now(),
      ),
    ),
    SortOption(
      name: "Last week",
      value: DateRange(
        start:
            DateTime.now().subtract(Duration(days: DateTime.now().weekday + 7)),
        end: DateTime.now()
            .subtract(Duration(days: DateTime.now().weekday % 7 + 1)),
      ),
    ),
    SortOption(
      name: "This month",
      value: DateRange(
        start: DateTime(DateTime.now().year, DateTime.now().month, 1),
        end: DateTime.now(),
      ),
    ),
    SortOption(
      name: "Last month",
      value: DateRange(
        start: DateTime(DateTime.now().year, DateTime.now().month - 1, 1),
        end: DateTime(DateTime.now().year, DateTime.now().month, 0),
      ),
    ),
  ];

  Future<void> _pickDate(BuildContext context, bool isFrom) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        DateTime tempDate = isFrom ? fromDate : toDate;
        bool isYearMonthSelection = false; // State to toggle between views

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height *
                  0.5, // Half of the screen height
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          if (!isYearMonthSelection) {
                            setModalState(() {
                              tempDate = DateTime(tempDate.year,
                                  tempDate.month - 1, tempDate.day);
                            });
                          }
                        },
                      ),
                      GestureDetector(
                        onTap: () {
                          setModalState(() {
                            isYearMonthSelection = !isYearMonthSelection;
                          });
                        },
                        child: Text(
                          isYearMonthSelection
                              ? 'Select Year & Month'
                              : DateFormat('MMMM yyyy').format(tempDate),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: () {
                          if (!isYearMonthSelection) {
                            setModalState(() {
                              tempDate = DateTime(tempDate.year,
                                  tempDate.month + 1, tempDate.day);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isYearMonthSelection)
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              controller: ScrollController(
                                initialScrollOffset:
                                    (DateTime.now().year - tempDate.year) *
                                        50.0,
                              ),
                              itemCount: DateTime.now().year -
                                  1970 +
                                  1, // Years from 1970 to current year
                              itemBuilder: (BuildContext context, int index) {
                                final year = 1970 + index;
                                return GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      tempDate = DateTime(
                                          year, tempDate.month, tempDate.day);
                                    });
                                  },
                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    alignment: Alignment.center,
                                    child: Text(
                                      year.toString(),
                                      style: TextStyle(
                                        color: tempDate.year == year
                                            ? AppColors.primaryColor
                                            : AppColors.primaryTextColor,
                                        fontWeight: tempDate.year == year
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              controller: ScrollController(
                                initialScrollOffset:
                                    (tempDate.month - 1) * 50.0,
                              ),
                              itemCount: tempDate.year == DateTime.now().year
                                  ? DateTime.now().month
                                  : 12, // Limit months for current year
                              itemBuilder: (BuildContext context, int index) {
                                final month = index + 1;
                                return GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      tempDate = DateTime(
                                          tempDate.year, month, tempDate.day);
                                    });
                                  },
                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    alignment: Alignment.center,
                                    child: Text(
                                      DateFormat('MMMM').format(
                                          DateTime(tempDate.year, month)),
                                      style: TextStyle(
                                        color: tempDate.month == month
                                            ? AppColors.primaryColor
                                            : AppColors.primaryTextColor,
                                        fontWeight: tempDate.month == month
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: GridView.builder(
                        itemCount:
                            DateTime(tempDate.year, tempDate.month + 1, 0)
                                .day, // Get days in the month
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        itemBuilder: (BuildContext context, int index) {
                          final day = index + 1;
                          final isFutureDate =
                              DateTime(tempDate.year, tempDate.month, day)
                                  .isAfter(DateTime.now());
                          return GestureDetector(
                            onTap: () {
                              if (!isFutureDate) {
                                setModalState(() {
                                  tempDate = DateTime(
                                      tempDate.year, tempDate.month, day);
                                });
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: tempDate.day == day
                                    ? AppColors.primaryColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(1000),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                day.toString(),
                                style: TextStyle(
                                  color: isFutureDate
                                      ? AppColors.inactiveTextFormFieldColor
                                      : tempDate.day == day
                                          ? Colors.white
                                          : AppColors.primaryTextColor,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.inactiveTextFormFieldColor,
                        ),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (isYearMonthSelection) {
                            setModalState(() {
                              isYearMonthSelection = false;
                            });
                          } else {
                            setState(() {
                              if (isFrom) {
                                fromDate = tempDate;
                              } else {
                                toDate = tempDate;
                              }
                            });
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                        ),
                        child: Text(isYearMonthSelection ? 'Proceed' : 'Done'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sort & Filter',
                style: TextThemes(context).getTextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: AppColors.primaryTextColor,
                ),
              ),
              InkWell(
                onTap: () => Get.back(),
                child: SvgPicture.asset(AppIcons.closeIcon),
              ),
            ],
          ),
          const SizedBox(height: 20),

          /// Default Sort Chips
          Wrap(
            spacing: 7,
            runSpacing: 0,
            children: defaultSort.map((sortItem) {
              return ChoiceChip(
                backgroundColor: AppColors.white,
                label: Text(
                  sortItem.name,
                  style: TextThemes(context).getTextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                    color: AppColors.secondaryTextColor,
                    height: 1,
                  ),
                ),
                selected: widget.filterValue?.name == sortItem.name,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(1000),
                  side: BorderSide(
                    color: AppColors.secondaryTextColor,
                    width: 0.5,
                  ),
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      widget.filterValue = sortItem;
                      fromDate = sortItem.value.start;
                      toDate = sortItem.value.end;
                    });
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          /// Custom Date Picker
          Text('Custom Date Range',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(context, true),
                  child: _buildDateBox('From', fromDate),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(context, false),
                  child: _buildDateBox('To', toDate),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          /// State Dropdown
          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: 'Select State'),
            value: selectedState,
            items: states.map((state) {
              return DropdownMenuItem(value: state, child: Text(state));
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedState = value;
                selectedLGA = null; // Reset LGA when state changes
              });
            },
          ),
          const SizedBox(height: 10),

          /// LGA Dropdown
          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: 'Select LGA'),
            value: selectedLGA,
            items: (selectedState != null ? lgas[selectedState]! : [])
                .map<DropdownMenuItem<String>>((lga) =>
                    DropdownMenuItem<String>(value: lga, child: Text(lga)))
                .toList(),
            onChanged: (value) => setState(() => selectedLGA = value),
          ),
          const SizedBox(height: 20),

          /// Apply Button
          PrimaryButton(
            text: 'Apply',
            onPressed: () {
              widget.onFilterSelected(
                dateRange: DateRange(start: fromDate, end: toDate),
                state: selectedState,
                lga: selectedLGA,
              );
              Get.back();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDateBox(String label, DateTime date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              color: AppColors.secondaryTextColor,
              fontSize: 13,
            )),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.inactiveTextFormFieldColor),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('MMM dd, yyyy').format(date)),
              SvgPicture.asset(AppIcons.calenderIcon),
            ],
          ),
        ),
      ],
    );
  }
}
