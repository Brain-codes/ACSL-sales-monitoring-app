import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/shared/services/helpers.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AvatarCircularImageInitials extends StatefulWidget {
  String profileImage;
  String name;
  double width;
  double height;

  AvatarCircularImageInitials({
    super.key,
    required this.profileImage,
    required this.name,
    this.width = 47,
    this.height = 47,
  });

  @override
  State<AvatarCircularImageInitials> createState() =>
      _AvatarCircularImageInitialsState();
}

class _AvatarCircularImageInitialsState
    extends State<AvatarCircularImageInitials> {
  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        height: widget.width,
        width: widget.height,
        child: widget.profileImage != null &&
                widget.profileImage!.endsWith('.svg')
            ? FutureBuilder<http.Response>(
                future: http.get(Uri.parse(widget.profileImage!)),
                builder: (BuildContext context,
                    AsyncSnapshot<http.Response> snapshot) {
                  if (snapshot.hasData && snapshot.data!.statusCode == 200) {
                    return Container(
                      color: AppColors.primaryColor,
                      child: SvgPicture.network(
                        widget.profileImage,
                        fit: BoxFit.cover,
                        placeholderBuilder: (BuildContext context) =>
                            CircularProgressIndicator(), // Placeholder for loading
                      ),
                    );
                  } else {
                    return Container(
                      height: widget.width,
                      width: widget.height,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.faintPrimaryColor,
                          width: 1,
                        ),
                        color: AppColors.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          Helpers().generateAvatarName(widget.name),
                          style: TextThemes(context).getTextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            letterSpacing: -2,
                          ),
                        ),
                      ),
                    );
                  }
                },
              )
            : CachedNetworkImage(
                imageUrl: widget.profileImage ?? '',
                fit: BoxFit.cover,
                errorWidget: (context, url, error) {
                  if (error is http.Response && error.statusCode == 403) {
                    return Container(
                      height: widget.width,
                      width: widget.height,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.faintPrimaryColor,
                          width: 1,
                        ),
                        color: AppColors.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                           Helpers().generateAvatarName(widget.name),
                          style: TextThemes(context).getTextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            letterSpacing: -2,
                          ),
                        ),
                      ),
                    );
                  } else {
                    return Container(
                      height: widget.width,
                      width: widget.height,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.faintPrimaryColor,
                          width: 1,
                        ),
                        color: AppColors.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                           Helpers().generateAvatarName(widget.name),
                          style: TextThemes(context).getTextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            letterSpacing: -2,
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
      ),
    );
  }
}
