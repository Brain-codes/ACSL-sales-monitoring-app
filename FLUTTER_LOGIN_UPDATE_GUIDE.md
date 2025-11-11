# Flutter Login Update Guide - Username/Email Authentication

## 📋 Overview

Update the Flutter login screen to support **flexible authentication** where users can login with **EITHER username OR email** using the same input field.

**Key Changes:**

- Update UI label from "Email" to "Username or Email"
- Call new `login-with-credentials` edge function
- Handle both identifier types in responses
- Update error messages appropriately

---

## 🎯 Required Changes

### 1. Update Login Controller

**File:** `lib/login/controller/login_controller.dart`

#### Before:

```dart
// OLD - Direct Supabase Auth
Future<void> loginUser() async {
  if (!_validateInputs()) return;

  isLoading.value = true;
  errorMessage.value = '';

  try {
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );

    if (response.user != null) {
      // Handle successful login
      await _sessionManager.saveCompleteUserData(response.user!.id);
      Get.offAllNamed(AppRoutes.MAIN_LAYOUT);
    }
  } on AuthException catch (e) {
    errorMessage.value = e.message;
    showErrorToast(title: 'Login Failed', message: e.message);
  } catch (e) {
    logger.e('Login error: $e');
    errorMessage.value = 'An unexpected error occurred';
    showErrorToast(title: 'Error', message: 'An unexpected error occurred');
  } finally {
    isLoading.value = false;
  }
}
```

#### After:

```dart
// NEW - Using login-with-credentials edge function
Future<void> loginUser() async {
  if (!_validateInputs()) return;

  isLoading.value = true;
  errorMessage.value = '';

  try {
    final identifier = emailController.text.trim(); // Renamed from email
    final password = passwordController.text.trim();

    // Call new edge function
    final response = await _supabaseService.callEdgeFunction(
      'login-with-credentials',
      body: {
        'identifier': identifier,
        'password': password,
      },
      requireAuth: false, // This IS the authentication endpoint
    );

    if (response.success && response.data != null) {
      final userData = response.data['user'];
      final sessionData = response.data['session'];

      if (userData != null && sessionData != null) {
        // Store session manually
        await Supabase.instance.client.auth.setSession(
          sessionData['access_token'],
        );

        // Save user data
        await _sessionManager.saveCompleteUserData(userData['id']);

        // Navigate to main layout
        Get.offAllNamed(AppRoutes.MAIN_LAYOUT);

        showSuccessToast(
          title: 'Login Successful',
          message: 'Welcome back, ${userData['display_name'] ?? userData['full_name']}!',
        );
      } else {
        throw Exception('Invalid response format');
      }
    } else {
      errorMessage.value = response.message ?? 'Login failed';
      showErrorToast(
        title: 'Login Failed',
        message: response.message ?? 'Invalid username or password',
      );
    }
  } catch (e) {
    logger.e('Login error: $e');
    errorMessage.value = 'An unexpected error occurred';
    showErrorToast(
      title: 'Error',
      message: 'Unable to login. Please try again.',
    );
  } finally {
    isLoading.value = false;
  }
}

// Update validation method
bool _validateInputs() {
  if (emailController.text.trim().isEmpty) {
    errorMessage.value = 'Please enter your username or email';
    showInfoToast(
      title: 'Missing Information',
      message: 'Please enter your username or email',
    );
    return false;
  }

  if (passwordController.text.trim().isEmpty) {
    errorMessage.value = 'Please enter your password';
    showInfoToast(
      title: 'Missing Information',
      message: 'Please enter your password',
    );
    return false;
  }

  return true;
}
```

---

### 2. Update Login Screen UI

**File:** `lib/login/ui/login_screen.dart`

#### Update TextField Labels

**Before:**

```dart
// OLD Email field
TextField(
  controller: controller.emailController,
  decoration: InputDecoration(
    labelText: 'Email',
    hintText: 'Enter your email',
    prefixIcon: Icon(Icons.email_outlined),
  ),
  keyboardType: TextInputType.emailAddress,
)
```

**After:**

```dart
// NEW Identifier field (supports username OR email)
TextField(
  controller: controller.emailController, // Keep name for compatibility
  decoration: InputDecoration(
    labelText: 'Username or Email',
    hintText: 'Enter your username or email',
    prefixIcon: Icon(Icons.person_outline), // Changed from email icon
    helperText: 'You can use either your username or email address',
  ),
  keyboardType: TextInputType.text, // Changed from emailAddress
)
```

#### Update Variable Names (Optional but Recommended)

**Rename controller property:**

```dart
// In LoginController
final identifierController = TextEditingController(); // Renamed from emailController

@override
void onClose() {
  identifierController.dispose();
  passwordController.dispose();
  super.onClose();
}
```

**Update all references in login_screen.dart:**

```dart
TextField(
  controller: controller.identifierController, // Updated reference
  decoration: InputDecoration(
    labelText: 'Username or Email',
    hintText: 'Enter your username or email',
  ),
)
```

---

### 3. Update Session Manager (Optional Enhancement)

**File:** `lib/core/services/session_manager.dart`

Add method to get display identifier:

```dart
/// Get the user's login identifier (username or email)
String getLoginIdentifier() {
  final profile = currentUserProfile.value;
  if (profile == null) return '';

  // Show username if available, otherwise email
  return profile.username ?? profile.email;
}

/// Get display name for UI
String getDisplayName() {
  final profile = currentUserProfile.value;
  if (profile == null) return 'User';

  return profile.fullName ?? profile.username ?? profile.email.split('@')[0];
}
```

---

### 4. Update Profile Model

**File:** `lib/core/model/profile_model.dart`

Add username field:

```dart
class ProfileModel {
  final String id;
  final String email;
  final String? username; // NEW FIELD
  final String? fullName;
  final String role;
  final String? organizationId;
  final bool hasChangedPassword;
  final DateTime? createdAt;

  ProfileModel({
    required this.id,
    required this.email,
    this.username, // NEW
    this.fullName,
    required this.role,
    this.organizationId,
    required this.hasChangedPassword,
    this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
    id: json["id"],
    email: json["email"],
    username: json["username"], // NEW
    fullName: json["full_name"],
    role: json["role"],
    organizationId: json["organization_id"],
    hasChangedPassword: json["has_changed_password"] ?? false,
    createdAt: json["created_at"] != null
        ? DateTime.parse(json["created_at"])
        : null,
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "email": email,
    "username": username, // NEW
    "full_name": fullName,
    "role": role,
    "organization_id": organizationId,
    "has_changed_password": hasChangedPassword,
    "created_at": createdAt?.toIso8601String(),
  };

  ProfileModel copyWith({
    String? id,
    String? email,
    String? username, // NEW
    String? fullName,
    String? role,
    String? organizationId,
    bool? hasChangedPassword,
    DateTime? createdAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username, // NEW
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      organizationId: organizationId ?? this.organizationId,
      hasChangedPassword: hasChangedPassword ?? this.hasChangedPassword,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
```

---

### 5. Update Profile Display

**Example:** In any screen showing user profile

```dart
// OLD - Only showing email
Text('Email: ${profile.email}')

// NEW - Show username or email
Text(
  profile.username != null
    ? 'Username: ${profile.username}'
    : 'Email: ${profile.email}'
)

// Or show both if available
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    if (profile.username != null)
      Text('Username: ${profile.username}'),
    if (!profile.email.contains('@internal.acsl.local'))
      Text('Email: ${profile.email}'),
  ],
)
```

---

## 🎨 UI/UX Improvements

### Login Screen Help Text

Add helper widget to explain flexible login:

```dart
class LoginHelpText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: AppColors.primaryBlue,
            size: 20,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'You can login with either your username or email address',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.darkGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

**Usage in login screen:**

```dart
Column(
  children: [
    // Identifier field
    TextField(
      controller: controller.identifierController,
      decoration: InputDecoration(
        labelText: 'Username or Email',
      ),
    ),
    SizedBox(height: 8),
    LoginHelpText(), // Add help text
    SizedBox(height: 16),
    // Password field
    TextField(...),
  ],
)
```

---

## 🧪 Testing Checklist

### Manual Testing

- [ ] Login with username + password
- [ ] Login with email + password
- [ ] Invalid username shows error
- [ ] Invalid email shows error
- [ ] Incorrect password shows error
- [ ] Empty fields show validation
- [ ] Loading state shows during login
- [ ] Success toast appears on login
- [ ] Navigation to main layout works
- [ ] Session persists after app restart

### Edge Cases

- [ ] Username with underscores (e.g., `lapo_mfb_gbongan_598581`)
- [ ] Email with special characters
- [ ] Very long username/email
- [ ] Network error handling
- [ ] Session expiry handling

---

## 📝 Error Messages

Update error messages to be identifier-agnostic:

```dart
// ❌ OLD - Email-specific
'Invalid email or password'
'Please enter a valid email address'

// ✅ NEW - Generic identifier
'Invalid username or password'
'Please enter your username or email'
'Unable to login. Please check your credentials'
```

---

## 🔄 Migration Impact on Users

### Existing Users (Email-Based)

- **Impact:** None - continue using email
- **UI Change:** See "Username or Email" label
- **Functionality:** Works exactly as before

### New Users (Username-Based)

- **Impact:** See username instead of email
- **UI Change:** No email shown (internal email hidden)
- **Functionality:** Login with username

---

## 📱 Example Complete Login Screen

```dart
class LoginScreen extends StatelessWidget {
  final LoginController controller = Get.find<LoginController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset('assets/images/logo.png', height: 80),
              SizedBox(height: 32),

              // Title
              Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Enter your credentials to continue',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 32),

              // Identifier field
              TextField(
                controller: controller.identifierController,
                decoration: InputDecoration(
                  labelText: 'Username or Email',
                  hintText: 'Enter your username or email',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.text,
              ),
              SizedBox(height: 8),

              // Help text
              LoginHelpText(),
              SizedBox(height: 16),

              // Password field
              Obx(() => TextField(
                controller: controller.passwordController,
                obscureText: !controller.showPassword.value,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  prefixIcon: Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      controller.showPassword.value
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () => controller.showPassword.toggle(),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )),
              SizedBox(height: 24),

              // Error message
              Obx(() => controller.errorMessage.value.isNotEmpty
                  ? Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              controller.errorMessage.value,
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    )
                  : SizedBox.shrink()),
              SizedBox(height: 16),

              // Login button
              Obx(() => SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: controller.isLoading.value
                      ? null
                      : controller.loginUser,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: controller.isLoading.value
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## 🎯 Summary of Changes

| Component        | Change                                      | Impact                    |
| ---------------- | ------------------------------------------- | ------------------------- |
| Login Controller | Call `login-with-credentials` edge function | Core authentication logic |
| Login Screen     | Update label to "Username or Email"         | User-facing UI            |
| TextField        | Change `keyboardType` to `text`             | Input behavior            |
| Profile Model    | Add `username` field                        | Data structure            |
| Session Manager  | Add display methods                         | User info display         |
| Error Messages   | Make identifier-agnostic                    | Error handling            |
| Validation       | Accept both formats                         | Input validation          |

---

## 🚀 Deployment

1. Update code as described above
2. Test thoroughly with both username and email
3. Deploy to staging environment
4. User acceptance testing
5. Deploy to production

---

## 📞 Support

**Issues?** Check the following:

- Backend edge function deployed correctly?
- Network connectivity working?
- Session manager configured properly?
- Error messages being displayed?

**Contact:** Backend team for API-related issues

---

**Document Version:** 1.0  
**Last Updated:** 2025-01-XX  
**Status:** Ready for Implementation
