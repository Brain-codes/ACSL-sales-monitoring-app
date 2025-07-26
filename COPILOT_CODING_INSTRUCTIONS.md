# GitHub Copilot - Coding Instructions for Stove Transaction App

## Project Overview

This is a Flutter-based **Sales Monitoring Application** using **GetX state management** with **Supabase** as the backend. The app supports both **Admin** and **Agent** roles with offline-first capabilities.

## Architecture & Patterns

### 1. **State Management - GetX**

- **Always use GetX** for state management, dependency injection, and routing
- Controllers extend `GetxController`
- Use `.obs` for reactive variables: `var isLoading = false.obs;`
- Access reactive values with `.value`: `isLoading.value = true;`
- Use `Obx()` or `GetBuilder()` for UI updates
- Use `Get.find<ServiceName>()` for dependency injection
- Use `Get.put()` for service registration

### 2. **Project Structure**

```
lib/
├── core/                    # Core functionality
│   ├── constants/          # App colors, themes, icons
│   ├── config/            # Environment configurations
│   ├── interceptor/       # API interceptors
│   ├── model/            # Core models (ProfileModel, BaseApiResponse)
│   ├── routes/           # App routing (AppRoutes, AppPages)
│   └── services/         # Core services (SessionManager, ApiService)
├── admin/                  # Admin-specific features
│   ├── dashboard/
│   ├── sales/
│   └── sub_accounts/
├── agent/                  # Agent-specific features
├── form/                   # Form-related functionality
├── login/                  # Authentication
├── main_layout/           # Layout controllers and UI
├── shared/                # Shared widgets and services
│   ├── ui/               # Reusable UI components
│   ├── widgets/          # Custom widgets
│   └── services/         # Shared services
└── supabase_codes/        # Edge functions and SQL
```

### 3. **File Naming Conventions**

- **Controllers**: `*_controller.dart` (e.g., `login_controller.dart`)
- **Models**: `*_model.dart` (e.g., `sale_model.dart`)
- **Services**: `*_service.dart` (e.g., `session_manager.dart`)
- **UI Screens**: `*_screen.dart` (e.g., `dashboard_screen.dart`)
- **Widgets**: Descriptive names (e.g., `primary_button.dart`)

### 4. **Controller Pattern**

```dart
class ExampleController extends GetxController {
  // Services injection
  final ExampleService _service = ExampleService();
  final SessionManager _sessionManager = Get.find<SessionManager>();
  final Logger logger = Logger();

  // Reactive variables
  final isLoading = false.obs;
  final errorMessage = ''.obs;
  final dataList = <ModelName>[].obs;

  // Text controllers
  final nameController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    // Initialize data
  }

  // Methods
  void fetchData() async {
    isLoading.value = true;
    try {
      final response = await _service.getData();
      if (response.success) {
        dataList.value = response.data;
      } else {
        errorMessage.value = response.message;
      }
    } catch (e) {
      logger.e('Error: $e');
      errorMessage.value = 'An error occurred';
    }
    isLoading.value = false;
  }

  @override
  void onClose() {
    nameController.dispose();
    super.onClose();
  }
}
```

### 5. **Model Structure**

Always include:

- `fromJson()` and `toJson()` methods
- `copyWith()` method for immutability
- Optional `toString()`, `==`, and `hashCode` overrides

```dart
class ExampleModel {
  final String id;
  final String? name;
  final DateTime? createdAt;

  ExampleModel({
    required this.id,
    this.name,
    this.createdAt,
  });

  factory ExampleModel.fromJson(Map<String, dynamic> json) => ExampleModel(
    id: json["id"],
    name: json["name"],
    createdAt: json["created_at"] != null
        ? DateTime.parse(json["created_at"])
        : null,
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "created_at": createdAt?.toIso8601String(),
  };

  ExampleModel copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
  }) {
    return ExampleModel(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
```

### 6. **Service Layer Pattern**

```dart
class ExampleService {
  final SupabaseService _supabaseService;
  final Logger logger = Logger();

  ExampleService(this._supabaseService);

  Future<SupabaseApiResponse<List<ExampleModel>>> fetchData() async {
    try {
      final response = await _supabaseService.callEdgeFunction(
        'function-name',
        body: {},
        requireAuth: true,
      );

      if (response.success) {
        final List<ExampleModel> data = (response.data as List)
            .map((item) => ExampleModel.fromJson(item))
            .toList();
        return SupabaseApiResponse.success(data);
      } else {
        return SupabaseApiResponse.error(response.message);
      }
    } catch (e) {
      logger.e('Error in fetchData: $e');
      return SupabaseApiResponse.error('An unexpected error occurred');
    }
  }
}
```

### 7. **UI Widget Patterns**

- Use `StatelessWidget` with GetX controllers
- Access controllers with `Get.find<ControllerName>()`
- Use `Obx()` for reactive UI updates
- Always include loading states and error handling

```dart
class ExampleScreen extends StatelessWidget {
  final ExampleController controller = Get.find<ExampleController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Example')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }

        if (controller.errorMessage.value.isNotEmpty) {
          return Center(child: Text(controller.errorMessage.value));
        }

        return ListView.builder(
          itemCount: controller.dataList.length,
          itemBuilder: (context, index) {
            final item = controller.dataList[index];
            return ListTile(title: Text(item.name ?? ''));
          },
        );
      }),
    );
  }
}
```

### 8. **Routing Pattern**

- Define routes in `AppRoutes` class as static constants
- Use `Get.offAllNamed()` for navigation replacement
- Use `Get.toNamed()` for regular navigation
- Configure bindings in `AppPages`

```dart
// AppRoutes
abstract class AppRoutes {
  static const EXAMPLE_SCREEN = '/example-screen';
}

// AppPages
GetPage(
  name: AppRoutes.EXAMPLE_SCREEN,
  page: () => ExampleScreen(),
  binding: BindingsBuilder(() {
    Get.put(ExampleController());
  }),
),
```

### 9. **Constants and Styling**

- Use `AppColors` for color constants
- Use `TextThemes` for text styling
- Use `AppIcons` for icon paths
- Store magic numbers in constants

### 10. **Error Handling & Logging**

```dart
// Always use Logger for debugging
final Logger logger = Logger();

// Error handling pattern
try {
  // API call or operation
} on AuthException catch (e) {
  showInfoToast(message: e.message, title: 'Authentication Error');
} catch (e) {
  logger.e('Unexpected error: $e');
  showErrorToast(message: 'An unexpected error occurred', title: 'Error');
}
```

### 11. **Toast Notifications**

Use the custom toast system:

```dart
showSuccessToast(title: 'Success', message: 'Operation completed');
showInfoToast(title: 'Info', message: 'Information message');
showErrorToast(title: 'Error', message: 'Error message');
```

### 12. **Authentication & Session Management**

- Use `SessionManager` for user session data
- Check user roles with `_sessionManager.isAdmin` or `_sessionManager.isAgent`
- Store user data with `saveCompleteUserData()` method
- Handle token refresh automatically

### 13. **Offline-First Architecture**

- Use `OfflineStorageService` for local data storage
- Implement sync mechanisms with `OfflineSyncService`
- Handle offline/online states in controllers
- Store images locally before syncing

### 14. **Code Style Guidelines**

- Use `// ignore_for_file:` comments at file top for linting exceptions
- Add explanatory comments for complex logic
- Use descriptive variable names
- Follow camelCase for variables, PascalCase for classes
- Use `final` for immutable variables
- Use `const` for compile-time constants

### 15. **API Response Handling**

Always check response status and handle appropriately:

```dart
if (response.code == 200) {
  // Success handling
  showSuccessToast(title: 'Success', message: 'Operation successful');
} else {
  // Error handling
  showInfoToast(title: 'Error', message: response.message);
}
```

### 16. **Form Validation**

```dart
String? validateEmail(String? value) {
  if (value == null || value.isEmpty) {
    return 'Email cannot be empty';
  }
  if (!GetUtils.isEmail(value)) {
    return 'Enter a valid email';
  }
  return null;
}
```

### 17. **Supabase Edge Functions**

- Use TypeScript for edge functions
- Implement CORS handling with `withCors()` helper
- Use proper authentication checking
- Return structured JSON responses

## Key Dependencies

- `get`: State management and dependency injection
- `supabase_flutter`: Backend integration
- `get_storage`: Local storage
- `logger`: Logging
- `toastification`: Toast notifications
- `google_maps_flutter`: Maps integration
- `image_picker`: Image selection
- `permission_handler`: Device permissions

## Important Notes

1. **Always** use GetX patterns for state management
2. **Always** include error handling and loading states
3. **Always** dispose controllers and text controllers properly
4. **Always** use the established service layer pattern
5. **Always** follow the offline-first architecture for data operations
6. **Never** directly manipulate UI from services - use controllers
7. **Never** hardcode strings - use constants or localization
8. **Prefer** composition over inheritance
9. **Use** meaningful variable and function names
10. **Follow** the established folder structure and naming conventions

This codebase prioritizes **maintainability**, **scalability**, and **offline-first functionality** while maintaining clean architecture principles with GetX state management.
