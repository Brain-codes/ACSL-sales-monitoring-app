import 'package:flutter/cupertino.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';

class LoadingPositionedFullScreen extends StatelessWidget {
  final String title;
  const LoadingPositionedFullScreen({
    super.key,
    this.title = '',
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white.withOpacity(0.8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoActivityIndicator(
                color: AppColors.primaryColor,
              ),
              SizedBox(
                child: title.isEmpty
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextThemes(context).getTextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                            color: AppColors.secondaryTextColor,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
