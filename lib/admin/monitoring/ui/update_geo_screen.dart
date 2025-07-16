import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';

class UpdateGeoScreen extends StatelessWidget {
  UpdateGeoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BaseAppBar(title: "Update Stove Geo-Coordinations"),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: 7, // Mock number of stoves
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryColor,
                child: Text(
                  'S${index + 1}',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              title: Text('Stove ID: STV00${200 + index}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Location: Lat: 12.34, Lon: 56.78'),
                  Text('Landmark: Landmark ${index + 1}'),
                ],
              ),
              trailing: ElevatedButton(
                onPressed: () {
                  showSuccessToast(
                    message:
                        'Update Geo for Stove STV00${200 + index} (dummy action)',
                    title: 'Action',
                  );
                },
                child: const Text('Update'),
              ),
              onTap: () {
                // Handle stove tap
              },
            ),
          );
        },
      ),
    );
  }
}
