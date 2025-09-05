import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';

class BaseBottomNavigation extends StatefulWidget {
  final int initialIndex;
  final List<Widget> pages;
  final List<NavItem> navItems;
  final Color backgroundColor;
  final bool hasTopBorder;
  final Color? topBorderColor;

  const BaseBottomNavigation({
    Key? key,
    required this.pages,
    required this.navItems,
    this.initialIndex = 0,
    this.backgroundColor = Colors.white,
    this.hasTopBorder = true,
    this.topBorderColor,
  }) : super(key: key);

  @override
  State<BaseBottomNavigation> createState() => _BaseBottomNavigationState();
}

class _BaseBottomNavigationState extends State<BaseBottomNavigation> {
  late int _selectedIndex;
  late ValueNotifier<int> _selectedIndexNotifier;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _selectedIndexNotifier = ValueNotifier(widget.initialIndex);
  }

  void _navigateBottomBar(int index) {
    setState(() {
      _selectedIndex = index;
      _selectedIndexNotifier.value = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _selectedIndexNotifier,
      builder: (context, value, child) {
        return Scaffold(
          body: widget.pages[_selectedIndex],
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              border: widget.hasTopBorder
                  ? Border(
                      top: BorderSide(
                          color: widget.topBorderColor ?? Colors.grey.shade300,
                          width: 2))
                  : null,
            ),
            child: SafeArea(
              bottom: false,
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: _navigateBottomBar,
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                backgroundColor: widget.backgroundColor,
                // surfaceTintColor: Colors.transparent, // ✅ Remove Material 3 tint
                selectedItemColor: AppColors.primaryColor,
                unselectedItemColor:
                    AppColors.secondaryTextColor.withOpacity(0.8),
                selectedLabelStyle: TextThemes(context).getTextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  color: AppColors.primaryColor,
                ),
                unselectedLabelStyle: TextThemes(context).getTextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  color: AppColors.secondaryTextColor.withOpacity(0.8),
                ),
                items: widget.navItems.map((item) {
                  return BottomNavigationBarItem(
                    icon: SvgPicture.asset(
                      item.iconPath,
                      color: _selectedIndex == widget.navItems.indexOf(item)
                          ? AppColors.primaryColor
                          : AppColors.secondaryTextColor.withOpacity(0.4),
                    ),
                    label: item.label,
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class NavItem {
  final String iconPath;
  final String label;

  NavItem({required this.iconPath, required this.label});
}
