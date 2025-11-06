import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// Removed unused import

import 'package:stove_transaction/admin/sales/controller/sales_controller.dart';
import 'package:stove_transaction/admin/sales/controller/update_sale_controller.dart';
import 'package:stove_transaction/admin/sales/model/sale_model.dart';
import 'package:stove_transaction/admin/sales/ui/update_sale_screen.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/app_icons.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/shared/components/bottom_sheet/bottom_sheet_item.dart';
import 'package:stove_transaction/shared/components/bottom_sheet/option_bottom_sheet.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';

class SaleDetailsScreen extends StatelessWidget {
  final SaleModel sale;

  const SaleDetailsScreen({Key? key, required this.sale}) : super(key: key);

  void _salesMoreOption(BuildContext context, SaleModel saleData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return OptionBottomSheet(
          title: saleData.stoveSerialNo ?? 'Options',
          subtitle: 'Select an action you\'d like to perform',
          hasClose: true,
          items: [
            // TODO: Uncomment this when ready to implement assign agent feature
            // BottomSheetItem(
            //   icon: AppIcons.profile,
            //   title: 'Assign Agent',
            //   subtitle: 'Assign this sales to one of your agents',
            //   onTap: () {},
            // ),
            BottomSheetItem(
              icon: AppIcons.editPenIcon,
              title: 'Update Sales Data',
              subtitle: 'Update details of your this sale',
              onTap: () {
                Get.back(); // Close bottom sheet

                // Remove existing controller if it exists to ensure fresh state
                if (Get.isRegistered<UpdateSaleController>()) {
                  Get.delete<UpdateSaleController>();
                }

                Get.to(() => UpdateSaleScreen(), arguments: {'sale': saleData});
              },
            ),
            BottomSheetItem(
              icon: AppIcons.trashIconFilled,
              title: 'Delete Sale',
              subtitle: 'What happens after this prompt?',
              onTap: () async {},
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: BaseAppBar(
        otherWidgets: GestureDetector(
          onTap: () => _salesMoreOption(context, sale),
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Transform.rotate(
              angle: 90 * 3.14 / 180, // Rotate the icon 90 degrees
              child: SvgPicture.asset(
                AppIcons.moreIcon,
                color: AppColors.primaryColor,
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFFCDCDCD),
                    width: 0.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),
            // Sale ID and Status
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildHeaderSection(context),
            ),

            const SizedBox(height: 16),

            // End-User Information
            _buildInfoCard(
              context,
              title: 'End-User Information',
              children: [
                _buildDetailRow('Full Name', sale.endUserName ?? 'N/A'),
                if (sale.aka != null && sale.aka!.isNotEmpty)
                  _buildDetailRow('Also Known As', sale.aka!),
                _buildDetailRow('Phone Number', sale.phone ?? 'N/A'),
                if (sale.otherPhone != null && sale.otherPhone!.isNotEmpty)
                  _buildDetailRow('Other Number', sale.otherPhone!),
                if (sale.contactPerson != null &&
                    sale.contactPerson!.isNotEmpty)
                  _buildDetailRow('Contact Person', sale.contactPerson!),
                if (sale.contactPhone != null && sale.contactPhone!.isNotEmpty)
                  _buildDetailRow('Contact Phone', sale.contactPhone!),
              ],
            ),

            const SizedBox(height: 16),

            // Transaction Details
            _buildInfoCard(
              context,
              title: 'Transaction Details',
              children: [
                _buildDetailRow(
                    'Transaction ID', sale.transactionId ?? sale.id),
                _buildDetailRow(
                    'Amount', 'NGN ${sale.amount.toStringAsFixed(2)}'),
                _buildDetailRow(
                  'Date',
                  sale.salesDate != null
                      ? '${sale.salesDate!.day} ${_getMonthName(sale.salesDate!.month)}, ${sale.salesDate!.year}'
                      : 'N/A',
                ),
                _buildDetailRow('Created By', sale.createdBy ?? 'N/A'),
              ],
            ),

            const SizedBox(height: 16),

            // Stove Details & Location
            _buildInfoCard(
              context,
              title: 'Stove Details & Location',
              children: [
                _buildDetailRow(
                    'Stove Serial Number', sale.stoveSerialNo ?? 'N/A'),
                _buildDetailRow('Address', sale.address?.fullAddress ?? 'N/A'),
                _buildDetailRow('City', sale.address?.city ?? 'N/A'),
                _buildDetailRow('State', sale.address?.state ?? 'N/A'),
                _buildDetailRow('Country', sale.address?.country ?? 'N/A'),
                if (sale.address?.latitude != null &&
                    sale.address?.longitude != null)
                  _buildDetailRow(
                    'Coordinates',
                    'Lat - ${sale.address!.latitude}, Lon - ${sale.address!.longitude}',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Map Preview
            if (sale.address?.latitude != null &&
                sale.address?.longitude != null)
              _buildMapPreview(context),

            const SizedBox(height: 16),

            // Attachments
            _buildAttachmentsSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusBackgroundColor(sale.status ?? 'N/A'),
                border: Border.all(
                    color: _getStatusBorderColor(sale.status ?? 'N/A'), width: 0.5),
                borderRadius: BorderRadius.circular(200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    sale.status ?? 'N/A',
                    style: TextThemes(context).getTextStyle(
                      fontSize: 14,
                      color: _getStatusTextColor(sale.status ?? 'N/A'),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildDateInfo(context, 'Sale Date', sale.salesDate),
                const SizedBox(height: 10),
                _buildDateInfo(context, 'Created At', sale.createdAt),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Sale ID: ${sale.id}',
          overflow: TextOverflow.ellipsis,
          style: TextThemes(context).getTextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          sale.endUserName ?? 'N/A',
          overflow: TextOverflow.ellipsis,
          style: TextThemes(context).getTextStyle(
            color: AppColors.secondaryTextColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDateInfo(BuildContext context, String title, DateTime? date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          title,
          textAlign: TextAlign.end,
          style: TextThemes(context).getTextStyle(
            fontSize: 11,
            color: AppColors.secondaryTextColor,
          ),
        ),
        Text(
          date != null
              ? '${date.day} ${_getMonthName(date.month)}, ${date.year}'
              : 'N/A',
          textAlign: TextAlign.end,
          style: TextThemes(context).getTextStyle(
            fontSize: 13,
            color: AppColors.primaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 15),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.06),
            border: Border(
              top: BorderSide(
                color: const Color(0xFFCDCDCD),
                width: 0.5,
              ),
              bottom: BorderSide(
                color: const Color(0xFFCDCDCD),
                width: 0.5,
              ),
            ),
          ),
          child: Flex(
            direction: Axis.horizontal,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextThemes(context).getTextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SvgPicture.asset(
                AppIcons.userIcon,
              )
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: children,
          ),
        )
        // ...children,
      ],
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextThemes(Get.context!).getTextStyle(
              fontSize: 11,
              color: AppColors.secondaryTextColor,
            ),
          ),
          Text(
            value,
            style: TextThemes(Get.context!).getTextStyle(
              fontSize: 13,
              color: AppColors.primaryTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPreview(BuildContext context) {
    final latitude = sale.address!.latitude!;
    final longitude = sale.address!.longitude!;
    final location = LatLng(latitude, longitude);

    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16),
          width: double.infinity,
          child: Text(
            'MAP PREVIEW',
            textAlign: TextAlign.end,
            style: TextThemes(context).getTextStyle(
              fontSize: 13,
              color: AppColors.primaryTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: 10),
        Container(
          clipBehavior: Clip.hardEdge,
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.bgGrey,
            border: Border.all(
              color: const Color(0xFFCDCDCD),
              width: 0.5,
            ),
          ),
          child: GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              // Map is created, no need to store controller since we don't need to control it
            },
            initialCameraPosition: CameraPosition(
              target: location,
              zoom: 16.0, // Good zoom level to see the location clearly
            ),
            markers: {
              Marker(
                markerId: const MarkerId('stove_location'),
                position: location,
                infoWindow: InfoWindow(
                  title: 'Stove Location',
                  snippet: sale.address?.fullAddress ?? 'Location address',
                ),
              ),
            },
            // Disable user interactions to make it non-draggable
            scrollGesturesEnabled: false,
            zoomGesturesEnabled: false,
            tiltGesturesEnabled: false,
            rotateGesturesEnabled: false,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapType: MapType.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentsSection(BuildContext context) {
    final hasStoveImage = sale.stoveImageId != null;
    final hasAgreementImage = sale.agreementImageId != null;
    final hasSignature = sale.signature != null && sale.signature!.isNotEmpty;

    if (!hasStoveImage && !hasAgreementImage && !hasSignature) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 15),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.06),
            border: Border(
              top: BorderSide(
                color: const Color(0xFFCDCDCD),
                width: 0.5,
              ),
              bottom: BorderSide(
                color: const Color(0xFFCDCDCD),
                width: 0.5,
              ),
            ),
          ),
          child: Flex(
            direction: Axis.horizontal,
            children: [
              Expanded(
                child: Text(
                  'Attachments',
                  style: TextThemes(context).getTextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SvgPicture.asset(
                AppIcons.userIcon,
              )
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (hasStoveImage)
          _buildAttachmentItem(context, 'Stove Image', sale.stoveImageId!),
        if (hasAgreementImage)
          _buildAttachmentItem(
              context, 'Agreement Document', sale.agreementImageId!),
        if (hasSignature)
          _buildAttachmentItem(context, 'Signature', sale.signature!),
      ],
    );
  }

  Widget _buildAttachmentItem(
      BuildContext context, String title, dynamic attachment) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            width: double.infinity,
            child: Text(
              title.toUpperCase(),
              textAlign: TextAlign.start,
              style: TextThemes(context).getTextStyle(
                fontSize: 13,
                color: AppColors.primaryTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            height: 10,
          ),
          Container(
            clipBehavior: Clip.hardEdge,
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
                color: AppColors.bgGrey,
                border: Border.all(
                  color: const Color(0xFFCDCDCD),
                  width: 0.5,
                )),
            child: _buildAttachmentImage(attachment),
          )
        ],
      ),
    );
  }

  Widget _buildAttachmentImage(dynamic attachment) {
    if (attachment is String) {
      // This is a base64 signature
      try {
        final bytes = base64Decode(attachment);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Text(
                'Error loading signature',
                style: TextThemes(Get.context!).getTextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryTextColor,
                ),
              ),
            );
          },
        );
      } catch (e) {
        return Center(
          child: Text(
            'Invalid signature format',
            style: TextThemes(Get.context!).getTextStyle(
              fontSize: 12,
              color: AppColors.secondaryTextColor,
            ),
          ),
        );
      }
    } else if (attachment != null && attachment.url != null) {
      // This is an image with URL (stove image or agreement document)
      return Image.network(
        attachment.url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Text(
              'Error loading image',
              style: TextThemes(Get.context!).getTextStyle(
                fontSize: 12,
                color: AppColors.secondaryTextColor,
              ),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      );
    } else {
      return Center(
        child: Text(
          'No attachment available',
          style: TextThemes(Get.context!).getTextStyle(
            fontSize: 12,
            color: AppColors.secondaryTextColor,
          ),
        ),
      );
    }
  }
}

Color _getStatusBackgroundColor(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
      return Color(0xFF238126).withOpacity(0.1);
    case 'pending':
      return Colors.yellow.withOpacity(0.1);
    case 'failed':
      return Colors.red.withOpacity(0.1);
    default:
      return Colors.grey.withOpacity(0.1);
  }
}

Color _getStatusBorderColor(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
      return Color(0xFF238126);
    case 'pending':
      return Colors.yellow;
    case 'failed':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

Color _getStatusTextColor(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
      return Color(0xFF238126);
    case 'pending':
      return Colors.yellow;
    case 'Failed':
      return Colors.red;
    default:
      return Colors.grey;
  }
}
