# 🔧 ACSL Secondary Sales & Monitoring App – Project Rules

This file defines the **development standards** and **technical decisions** that must be followed across the codebase for consistency, performance, and maintainability.

---

## 📦 1. Framework & Dependencies

- **Flutter Version:** `>=2.18.2 <3.0.0`
- **Architecture:** Mobile-only (Android & iOS, small screens only)
- **State Management:** GetX (`get: ^4.6.6`)
- **Local Storage:** Hive + hive_flutter
- **Networking:** `http`
- **Routing:** Named routes using GetX (`Get.toNamed()`)

---

## 📁 2. Folder Structure (Screen-Based)

Each screen or module follows this structure:

```
feature_name/
│
├── controller/
│   └── feature_controller.dart
├── model/
│   └── feature_model.dart
├── services/
│   └── feature_service.dart
├── ui/
│   └── feature_screen.dart
└── widgets/
    └── reusable_widget.dart
```

Shared or global components can go under a `shared/` folder.

---

## 🎨 3. UI & Design Standards

- Theme: **Light mode only**
- **Primary Color:** `#07522E` (use for buttons, icons, accents)
- Use **Material 3 visual style**: clean padding, elevation, and spacing
- All components should have:
  - Rounded corners
  - Adequate spacing/margins
  - Clear section headers
  - Subtle shadows or card-like containers

### 🎯 UI Design Principle

> **UI should feel like a mature, modern, real-world product.**

This means:

- Clean layouts with proper information hierarchy (titles, labels, dividers)
- Form inputs grouped into logical sections using cards or containers
- Tap targets large enough for mobile users
- Feedback for all interactions (button presses, form validation, error messages)
- A consistent look across all screens (color, typography, padding)
- Thoughtful use of icons, imagery, and spacing to avoid clutter

The design should not feel like a prototype or a student app — it should feel like a polished product ready for real use in 2025.

Examples of good design practice:

- Card-based layouts for grouped content
- Full-width buttons with large, legible labels
- Toasts/snackbars instead of `print()` statements
- Using whitespace to reduce visual noise

---

## 🧠 4. Feature Behavior Standards

- Each screen must use a `GetX` controller with observable states
- Use `RefreshIndicator` on screens with dynamic data
- Input forms must validate required fields before enabling submission
- Image pickers, signature pads, and geolocation capture must use clearly labeled buttons and previews
- If offline, data must be stored locally (Hive box) and flagged for sync later
- Show offline sync banners when unsynced data exists

---

## 🧼 5. Code Reusability & Cleanliness

- All reusable UI components must be placed in the `widgets/` folder
- No hardcoded styles; use constants for:
  - Text styles (`TextThemes`)
  - Colors (`AppColors`)
  - Padding/margin values
- Variable and class names must be descriptive (e.g. `stoveLocation`, `userFullName`)
- Avoid business logic inside UI files — keep it in the controller or service

---

## 🧪 6. Testing Standards

- Automated widget or unit testing is optional (not enforced yet)
- Emphasis is on:
  - Reliable manual testing
  - Clean UI flow
  - Offline behavior consistency

---

## 🚫 7. Forbidden Practices

- ❌ No `print()` for debugging (use logs or `Get.snackbar`)
- ❌ No use of Dio, Riverpod, Bloc, or Provider
- ❌ No desktop/tablet-specific layouts
- ❌ Avoid placing logic-heavy code in UI
- ❌ Don’t clutter screens — keep the interface intuitive

---

## 🛑 8. Special Comments in Code

To help maintain existing work and ensure safe incremental updates, follow these rules when generating or modifying widgets/components:

### `//IGNORE`

- 🔒 **Do not modify this widget or class at all.**
- Skip any suggestion, replacement, or update, even if the structure looks outdated or inefficient.

### `//IGNORE AND ONLY IMPROVE`

- 🔧 You may **make light improvements** such as:
  - Layout spacing
  - Icon or color correction
  - Typography cleanup
  - Adding missing null-safety, error-handling, etc.
- 🚫 Do not refactor or rename the component.
- 🚫 Don’t change its logic or structure unless it’s broken or unreadable.
- ✅ This allows the AI to enhance UI consistency without overriding developer intention.

---

## ✅ 9. Post-Update Quality Checks (Mandatory)

After any significant AI-generated update (especially UI or logic):

1. you are to Run:
   ```bash
   flutter analyze
   Check for errors ignore infos and warning
   ```

✅ AI should automatically fix issues before outputting final code.

Optionally test on:

bash
Copy
Edit
flutter run -d edge
To visually verify layout and hot-reload behavior.

Prefer small-screen mode when running on browser.

## 📌 Final Notes

This project must deliver a **production-ready mobile app** that balances usability, maintainability, and visual polish.

The app is being built with **offline-first logic**, clean UI/UX patterns, and proper architectural separation.

If in doubt, always:

- Prioritize simplicity over cleverness
- Break down features by role (admin vs agent)
- Stick to these rules unless approved otherwise
