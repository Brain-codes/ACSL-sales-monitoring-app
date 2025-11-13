# Reset Password for Organization - Documentation

## 📋 Overview

The `manage-credentials` endpoint allows Super Admins to reset passwords for any organization/partner with **two flexible options**:

1. **Auto-Generate** - System creates a secure 16-character password
2. **Custom Password** - Super Admin provides their own password

---

## 🔐 Endpoint

**URL:** `https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/manage-credentials/update-password`  
**Method:** `PUT`  
**Auth Required:** Yes (Super Admin token in Authorization header)

---

## 📤 Request Formats

### Option 1: Auto-Generate Password (Recommended)

```json
{
  "partner_id": "FFB871",
  "super_admin_password": "superadmin@1234"
}
```

**System will:**
- ✅ Generate a secure 16-character password automatically
- ✅ Include uppercase, lowercase, numbers, and special characters
- ✅ Return the generated password in response

---

### Option 2: Custom Password

```json
{
  "partner_id": "FFB871",
  "super_admin_password": "superadmin@1234",
  "new_password": "MyCustomPass123!"
}
```

**Custom password must:**
- ✅ Be at least 8 characters long
- ⚠️ Be strong enough (recommended: mix of upper/lower/numbers/symbols)

---

## 📥 Response Format

### Success Response (200)

**Auto-Generated:**
```json
{
  "success": true,
  "message": "Password reset successfully for partner: FFB871",
  "newPassword": "aB3$xY9@mN2!pQ5z",
  "passwordMode": "auto-generated"
}
```

**Custom:**
```json
{
  "success": true,
  "message": "Password reset successfully for partner: FFB871",
  "newPassword": "MyCustomPass123!",
  "passwordMode": "custom"
}
```

---

### Error Responses

**400 - Missing Required Fields**
```json
{
  "success": false,
  "error": "Missing required fields: partner_id, super_admin_password"
}
```

**400 - Invalid Super Admin Password**
```json
{
  "success": false,
  "error": "Invalid Super Admin password"
}
```

**400 - Custom Password Too Short**
```json
{
  "success": false,
  "error": "Custom password must be at least 8 characters long"
}
```

**404 - Partner Not Found**
```json
{
  "success": false,
  "error": "Partner not found with ID: FFB871"
}
```

**401 - Unauthorized**
```json
{
  "success": false,
  "error": "Unauthorized"
}
```

---

## 💻 Flutter Implementation

### 1. Service Layer

```dart
import 'package:logger/logger.dart';
import 'package:stove_transaction/core/model/supabase_api_response.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';

class ManageCredentialsService {
  final SupabaseService _supabaseService;
  final Logger logger = Logger();

  ManageCredentialsService(this._supabaseService);

  /// Reset password for an organization
  /// If [customPassword] is provided, uses it. Otherwise auto-generates.
  /// Returns the new password (either custom or auto-generated)
  Future<SupabaseApiResponse<Map<String, dynamic>>> resetPassword({
    required String partnerId,
    required String superAdminPassword,
    String? customPassword, // Optional: provide custom password
  }) async {
    try {
      logger.i('Resetting password for partner: $partnerId');
      logger.i('Password mode: ${customPassword != null ? "Custom" : "Auto-generated"}');

      final body = {
        'partner_id': partnerId,
        'super_admin_password': superAdminPassword,
      };

      // Add custom password if provided
      if (customPassword != null && customPassword.trim().isNotEmpty) {
        body['new_password'] = customPassword.trim();
      }

      final response = await _supabaseService.callEdgeFunction(
        'manage-credentials/update-password',
        method: 'PUT',
        body: body,
        requireAuth: true,
      );

      if (response.success) {
        final result = {
          'newPassword': response.data['newPassword'] as String,
          'passwordMode': response.data['passwordMode'] as String,
          'message': response.data['message'] as String,
        };
        logger.i('Password reset successful for partner: $partnerId');
        return SupabaseApiResponse.success(result);
      } else {
        logger.e('Password reset failed: ${response.message}');
        return SupabaseApiResponse.error(response.message);
      }
    } catch (e) {
      logger.e('Error resetting password: $e');
      return SupabaseApiResponse.error('Failed to reset password: $e');
    }
  }

  /// Generate a secure password preview (without applying it)
  Future<SupabaseApiResponse<String>> generateSecurePassword() async {
    try {
      final response = await _supabaseService.callEdgeFunction(
        'manage-credentials/generate-password',
        method: 'POST',
        requireAuth: true,
      );

      if (response.success) {
        final password = response.data['password'] as String;
        return SupabaseApiResponse.success(password);
      } else {
        return SupabaseApiResponse.error(response.message);
      }
    } catch (e) {
      logger.e('Error generating password: $e');
      return SupabaseApiResponse.error('Failed to generate password');
    }
  }
}
```

---

### 2. Controller Layer

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/shared/services/manage_credentials_service.dart';
import 'package:stove_transaction/shared/ui/toast.dart';

class ManageCredentialsController extends GetxController {
  final ManageCredentialsService _service;
  final Logger logger = Logger();

  ManageCredentialsController(this._service);

  // Reactive state
  final isResetting = false.obs;
  final newPassword = ''.obs;
  final useCustomPassword = false.obs; // Toggle between auto-generate and custom

  // Text controllers
  final superAdminPasswordController = TextEditingController();
  final customPasswordController = TextEditingController();

  /// Reset password for a specific partner
  /// Shows dialog to choose auto-generate OR custom password
  Future<void> resetPassword(String partnerId, String partnerName) async {
    try {
      // Show password reset options dialog
      final result = await _showPasswordResetDialog(partnerId, partnerName);
      if (result == null) {
        showInfoToast(title: 'Cancelled', message: 'Password reset cancelled');
        return;
      }

      isResetting.value = true;

      final response = await _service.resetPassword(
        partnerId: partnerId,
        superAdminPassword: result['superAdminPassword'],
        customPassword: result['customPassword'], // null if auto-generate
      );

      if (response.success && response.data != null) {
        newPassword.value = response.data!['newPassword'];
        final mode = response.data!['passwordMode'];

        // Copy to clipboard
        await Clipboard.setData(ClipboardData(text: response.data!['newPassword']));

        // Show success dialog
        _showPasswordResetSuccessDialog(
          partnerId,
          partnerName,
          response.data!['newPassword'],
          mode,
        );

        showSuccessToast(
          title: 'Password Reset',
          message: 'New password copied to clipboard',
        );
      } else {
        showErrorToast(
          title: 'Reset Failed',
          message: response.message,
        );
      }
    } catch (e) {
      logger.e('Error resetting password: $e');
      showErrorToast(
        title: 'Error',
        message: 'An unexpected error occurred',
      );
    } finally {
      isResetting.value = false;
      superAdminPasswordController.clear();
      customPasswordController.clear();
      useCustomPassword.value = false;
    }
  }

  /// Show password reset options dialog
  Future<Map<String, dynamic>?> _showPasswordResetDialog(
    String partnerId,
    String partnerName,
  ) async {
    return await Get.dialog<Map<String, dynamic>>(
      AlertDialog(
        title: Text('Reset Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Partner: $partnerName'),
              Text('ID: $partnerId', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 20),
              
              // Super Admin Password
              TextField(
                controller: superAdminPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Your Super Admin Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                  helperText: 'Required for verification',
                ),
              ),
              const SizedBox(height: 20),

              // Toggle: Auto-generate OR Custom
              Obx(() => SwitchListTile(
                    title: const Text('Use Custom Password'),
                    subtitle: Text(
                      useCustomPassword.value
                          ? 'You will set the password'
                          : 'System will auto-generate',
                    ),
                    value: useCustomPassword.value,
                    onChanged: (value) => useCustomPassword.value = value,
                  )),

              const SizedBox(height: 10),

              // Custom Password Field (shown only if toggle is ON)
              Obx(() => useCustomPassword.value
                  ? TextField(
                      controller: customPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.vpn_key),
                        helperText: 'Min. 8 characters',
                      ),
                    )
                  : Container()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final superAdminPassword = superAdminPasswordController.text.trim();
              if (superAdminPassword.isEmpty) {
                showErrorToast(
                  title: 'Required',
                  message: 'Please enter your Super Admin password',
                );
                return;
              }

              String? customPassword;
              if (useCustomPassword.value) {
                customPassword = customPasswordController.text.trim();
                if (customPassword.isEmpty) {
                  showErrorToast(
                    title: 'Required',
                    message: 'Please enter a custom password',
                  );
                  return;
                }
                if (customPassword.length < 8) {
                  showErrorToast(
                    title: 'Too Short',
                    message: 'Password must be at least 8 characters',
                  );
                  return;
                }
              }

              Get.back(result: {
                'superAdminPassword': superAdminPassword,
                'customPassword': customPassword,
              });
            },
            child: const Text('Reset Password'),
          ),
        ],
      ),
    );
  }

  /// Show success dialog with new password
  void _showPasswordResetSuccessDialog(
    String partnerId,
    String partnerName,
    String newPassword,
    String mode,
  ) {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            const Text('Password Reset Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Partner: $partnerName'),
            Text('ID: $partnerId', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Chip(
              label: Text(mode == 'auto-generated' ? 'Auto-Generated' : 'Custom Password'),
              backgroundColor: mode == 'auto-generated' ? Colors.blue[100] : Colors.orange[100],
            ),
            const SizedBox(height: 16),
            const Text(
              'New Password:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      newPassword,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: newPassword));
                      showSuccessToast(
                        title: 'Copied',
                        message: 'Password copied to clipboard',
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '⚠️ Make sure to save this password. It cannot be recovered.',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Get.back(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void onClose() {
    superAdminPasswordController.dispose();
    customPasswordController.dispose();
    super.onClose();
  }
}
```

---

## 🎯 How It Works

### Auto-Generate Mode (Default)
1. Super Admin clicks "Reset Password"
2. Enters their password for verification
3. System generates 16-char secure password
4. Updates both `auth.users` and `credentials` tables
5. Returns generated password to Super Admin

### Custom Password Mode
1. Super Admin clicks "Reset Password"
2. Toggles "Use Custom Password"
3. Enters their verification password + custom password
4. System validates custom password (min 8 chars)
5. Updates both tables with custom password
6. Returns custom password in response (for confirmation)

---

## 🔒 Security Features

- ✅ **Super Admin Only** - Requires Super Admin role
- ✅ **Password Verification** - Super Admin must enter their password
- ✅ **Minimum Length** - Custom passwords must be 8+ characters
- ✅ **Secure Generation** - Auto-generated passwords use crypto.getRandomValues()
- ✅ **Dual Update** - Updates both auth system and credentials table
- ✅ **One-Time Display** - Password shown once in response

---

## ✅ Testing Examples

### Test 1: Auto-Generate Password

```bash
curl -X PUT \
  https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/manage-credentials/update-password \
  -H 'Authorization: Bearer YOUR_SUPER_ADMIN_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "partner_id": "FFB871",
    "super_admin_password": "superadmin@1234"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Password reset successfully for partner: FFB871",
  "newPassword": "aB3$xY9@mN2!pQ5z",
  "passwordMode": "auto-generated"
}
```

---

### Test 2: Custom Password

```bash
curl -X PUT \
  https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/manage-credentials/update-password \
  -H 'Authorization: Bearer YOUR_SUPER_ADMIN_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "partner_id": "FFB871",
    "super_admin_password": "superadmin@1234",
    "new_password": "MyCustomPass123!"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Password reset successfully for partner: FFB871",
  "newPassword": "MyCustomPass123!",
  "passwordMode": "custom"
}
```

---

## 📊 Database Updates

**Tables Affected:**
- `auth.users` - Updates password hash for authentication
- `credentials` - Updates plaintext password for Super Admin reference

**Fields Updated:**
- `auth.users.encrypted_password` - New password hash
- `credentials.password` - New password (plaintext)
- `credentials.updated_at` - Timestamp of update

---

**Status:** ✅ Implemented and Deployed  
**Endpoint:** `PUT /manage-credentials/update-password`  
**Supports:** Auto-Generate OR Custom Password  
**Last Updated:** November 14, 2025
