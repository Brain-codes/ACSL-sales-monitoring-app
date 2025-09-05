// ignore_for_file: prefer_const_constructors

import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for Clipboard
import 'package:logger/logger.dart';
import 'package:stove_transaction/admin/sub_accounts/controller/manage_sales_agents_controller.dart';
import 'package:stove_transaction/admin/sub_accounts/services/sales_agent_api_service.dart';
import 'package:stove_transaction/core/constants/app_icons.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/shared/components/bottom_sheet/base_bottom_sheet.dart';
import 'dart:math'; // Import for Random
import 'package:stove_transaction/shared/ui/custom_input_field.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddSalesAgentController extends GetxController {
  final AgentService _agentService = AgentService(SupabaseService());
  final formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  TextEditingController generatedPassword =
      TextEditingController(text: 'loading...');
  final RxBool isLoading = false.obs;
  final RxBool isPasswordObscured = true.obs;
  Logger logger = Logger();
  final ManageSalesAgentsController _manageSalesAgentController =
      Get.put(ManageSalesAgentsController());
  void togglePasswordVisibility() {
    isPasswordObscured.value = !isPasswordObscured.value;
  }

  String generateRandomPassword() {
    const String chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
    Random random = Random();
    return String.fromCharCodes(Iterable.generate(
        12, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  void updatePasswordFields(String password) {
    passwordController.text = password;
    Clipboard.setData(ClipboardData(text: password));
  }

  void addAgent() async {
    try {
      if (formKey.currentState!.validate()) {
        isLoading.value = true;

        final response = await _agentService.createAgent(
          fullName: nameController.text,
          email: emailController.text,
          password: passwordController.text,
        );

        logger.e(response.data);
        if (response.code == 200) {
          showSuccessToast(
            title: 'Agent Added',
            message: 'Sales agent added successfully!',
          );
          _manageSalesAgentController.fetchSalesAgents();
          // Show bottom sheet with login details before closing the add screen
          _showShareLoginDetailsBottomSheet();
        } else {
          showInfoToast(
            title: 'Add Agent Failed',
            message: response.message,
          );
        }
        isLoading.value = false;
      }
    } on AuthException catch (e) {
      Get.snackbar(
        'Error',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      showErrorToast(
        title: 'Error',
        message: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  void _showShareLoginDetailsBottomSheet() {
    final String email = emailController.text.trim();
    final String password = passwordController.text.trim();
    final String fullName = nameController.text.trim();
    final String appName = 'ACSL Sales Monitoring App';
    final String message = '''
Welcome to $appName!

Dear $fullName,

Your account has been created as a Sales Agent. Please find your login credentials below:

Email: $email
Password: $password

You can log in to the app and start managing your sales right away. For security, please change your password after your first login.

If you have any questions or need help, contact your admin.

Best regards,
ACSL Team
''';
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Share Login Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: message));
                    showSuccessToast(
                      title: 'Copied',
                      message: 'Login details copied to clipboard.',
                    );
                  },
                  icon: Icon(Icons.copy),
                  label: Text('Copy'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 18),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final Uri emailUri = Uri(
                      scheme: 'mailto',
                      path: email,
                      query:
                          'subject=Your%20Login%20Credentials%20for%20$appName&body=${Uri.encodeComponent(message)}',
                    );
                    if (await canLaunchUrl(emailUri)) {
                      await launchUrl(emailUri);
                    } else {
                      showInfoToast(
                          title: 'Error', message: 'Could not open email app.');
                    }
                  },
                  icon: Icon(Icons.email),
                  label: Text('Email'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 18),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final whatsappUrl = Uri.parse(
                        'https://wa.me/?text=${Uri.encodeComponent(message)}');
                    if (await canLaunchUrl(whatsappUrl)) {
                      await launchUrl(whatsappUrl,
                          mode: LaunchMode.externalApplication);
                    } else {
                      showInfoToast(
                          title: 'Error', message: 'Could not open WhatsApp.');
                    }
                  },
                  icon: Icon(Icons.phone, color: Colors.white),
                  label: Text('WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 18),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Share.share(message,
                        subject: 'Your Login Credentials for $appName');
                  },
                  icon: Icon(Icons.share),
                  label: Text('Other...'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 18),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Get.back();
                    Get.back(); // Close add agent screen
                  },
                  icon: Icon(Icons.check),
                  label: Text('Done'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  void showGeneratePasswordBottomSheet(
    BuildContext context,
  ) {
    generatedPassword.text = generateRandomPassword();
    // isLoading.value = false;
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        useRootNavigator: true,
        builder: (BuildContext context) {
          return BaseBottomSheet(
            title: 'Generate Password',
            subtitle: 'Generate a secure password for your sales agent',
            hasMode: false,
            items: [
              SizedBox(
                height: 10,
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 8,
                ),
                child: CustomInputField(
                  label: '',
                  controller: generatedPassword,
                  inputType: TextInputType.emailAddress,
                  focusNode: null,
                  readOnly: true,
                  numberOfLines: 1,
                  actionKeyboard: TextInputAction.next,
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: SvgPicture.asset(AppIcons.copyBtn),
                  ),
                  onSuffixIconTap: () {
                    updatePasswordFields(generatedPassword.text);
                    Get.back(); // Close the bottom sheet
                    Clipboard.setData(
                      ClipboardData(text: generatedPassword.text),
                    );
                    showInfoToast(
                      title: 'Password copied!',
                      message:
                          'The generated password has been copied to the password fields.',
                    );
                  },
                ),
              ),
              SizedBox(
                height: 20,
              ),
              SizedBox(
                height: 20,
              ),
            ],
          );
        });
  }
}
