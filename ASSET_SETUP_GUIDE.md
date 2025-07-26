# 🎨 Asset Setup Guide for Stove Transaction App

## Current Status

✅ Folder structure created  
✅ Splash screen configuration working  
⏳ Waiting for app icon assets  
⏳ Waiting for splash screen assets

## 📁 Folder Structure Created

```
assets/
├── icons/
│   ├── app/          # Place your app icons here
│   └── ui/           # Place your UI icons here
└── images/
    ├── splash/       # Place your splash screen assets here
    ├── onboarding/   # Place your onboarding images here
    ├── illustrations/ # Place your SVG illustrations here
    └── branding/     # Place your branding assets here
```

## 🎯 Next Steps

### 1. Create App Icons in Figma

Export these files and place them in `assets/icons/app/`:

- **icon.png** (1024×1024px) - Main app icon
- **icon-foreground.png** (432×432px) - Android adaptive foreground
- **icon-background.png** (432×432px) - Android adaptive background

### 2. Create Splash Screen Assets in Figma

Export these files and place them in `assets/images/splash/`:

- **splash-icon.png** (288×288px) - Splash screen icon
- **splash-background.png** (optional) - Custom background image

### 3. Update Configuration Files

Once you have the assets, uncomment the image paths in:

- `flutter_launcher_icons.yaml`
- `flutter_native_splash.yaml`

### 4. Generate Icons and Splash Screen

Run these commands after adding your assets:

```bash
# Install/update dependencies
flutter pub get

# Generate app icons
dart run flutter_launcher_icons

# Generate splash screen
dart run flutter_native_splash:create
```

## 🎨 Figma Export Settings

### App Icons:

- **Format**: PNG
- **Scale**: 1x (use the exact pixel dimensions)
- **Background**: Transparent for foreground, solid color for background

### Splash Screen:

- **Format**: PNG
- **Scale**: 1x
- **Background**: Transparent for icon, solid/gradient for background

### UI Icons:

- **Format**: SVG (preferred) or PNG
- **Scale**: 1x, 2x, 3x for PNG
- **Background**: Transparent

## 🚀 Ready to Configure

Once you place your assets in the correct folders, I can help you:

1. Update the configuration files with the correct paths
2. Generate all icons and splash screens
3. Test the app with your new branding

## 🎯 Design Specifications Reminder

### App Icons:

- Main icon: 1024×1024px
- Adaptive foreground: 432×432px (safe zone: 66×66px center)
- Adaptive background: 432×432px

### Splash Screen:

- Icon: 288×288px
- Background: Device-specific sizes (or use solid color)

### Onboarding Images:

- Base: 375×300px
- 2x: 750×600px
- 3x: 1125×900px

## 🛠️ Current Configuration Status

- ✅ Dependencies added to pubspec.yaml
- ✅ Asset folders declared in pubspec.yaml
- ✅ Configuration files created and tested
- ✅ Folder structure ready
- ⏳ Waiting for your Figma assets

Ready when you are! 🚀
