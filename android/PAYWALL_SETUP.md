# Android Paywall Setup Guide

This guide explains how to set up the native Android paywall with RevenueCat integration.

## Files Added

1. **PaywallActivity.kt** - The main Android paywall activity
2. **PaywallPlugin.kt** - Bridge between Flutter and Android
3. **RevenueCatConfig.kt** - Configuration file for RevenueCat settings
4. **lib/services/paywall_service.dart** - Flutter service to communicate with native paywall (shared with iOS)

## Setup Instructions

### 1. Configure RevenueCat API Key

Edit `android/app/src/main/kotlin/com/theholylabs/kaliai/RevenueCatConfig.kt` and replace `"your_revenuecat_api_key_here"` with your actual RevenueCat API key:

```kotlin
const val API_KEY = "your_actual_api_key_here"
```

### 2. Set Up RevenueCat Dashboard

1. Create a RevenueCat account at https://app.revenuecat.com
2. Create a new app in the dashboard
3. Add your Android app package name (`com.theholylabs.kaliai`)
4. Create a product with the entitlement identifier "pro"
5. Copy your API key and update the config file

### 3. Google Play Console Setup

1. Create your subscription products in Google Play Console
2. Make sure the product IDs match what you've configured in RevenueCat
3. Add the product IDs to your RevenueCat dashboard
4. Set up your app's billing configuration

### 4. Test the Integration

1. Build and run the app on Android
2. Complete the wizard
3. Tap the "Complete" button to see the native Android paywall

## Features

- Native Android paywall using RevenueCat SDK
- Material Design UI components
- Automatic entitlement checking
- Purchase and restore functionality
- Seamless integration with Flutter app
- Error handling and user feedback

## Android-Specific Implementation

The Android paywall uses:
- **AppCompatActivity** for the base activity
- **LinearLayout** for programmatic UI creation
- **Material Design** colors and styling
- **Toast messages** for user feedback
- **Activity results** for communication with Flutter

## Customization

You can customize the paywall appearance by modifying:
- `createLayout()` method in `PaywallActivity.kt` for UI components
- Colors and styling in the layout creation
- Feature list and descriptions
- Button styles and behaviors

## Dependencies Added

The following dependencies were added to `android/app/build.gradle.kts`:

```kotlin
implementation("com.revenuecat.purchases:purchases:7.9.0")
implementation("androidx.appcompat:appcompat:1.6.1")
```

## AndroidManifest.xml Changes

The PaywallActivity was added to the manifest:

```xml
<activity 
    android:name=".PaywallActivity"
    android:launchMode="standard" 
    android:exported="false"
    android:theme="@style/Theme.AppCompat.Light.NoActionBar" />
```

## Troubleshooting

1. **Paywall doesn't appear**: Check that your API key is correct and RevenueCat is properly initialized
2. **Purchase fails**: Ensure your products are properly configured in both Google Play Console and RevenueCat
3. **Plugin errors**: Check that the method channel name matches between Kotlin and Dart code
4. **Build errors**: Make sure all dependencies are properly added to build.gradle.kts

## Production Checklist

- [ ] Replace API key with production key
- [ ] Set `DEBUG_MODE = false` in RevenueCatConfig
- [ ] Test with Google Play Console internal testing
- [ ] Verify all products work correctly
- [ ] Test restore purchases functionality
- [ ] Test on different Android versions and devices

## Platform Differences

| Feature | iOS | Android |
|---------|-----|---------|
| UI Framework | SwiftUI | Native Android Views |
| RevenueCat UI | RevenueCatUI | Custom implementation |
| Navigation | NavigationView | Activity-based |
| Styling | SwiftUI modifiers | Material Design |
| Error Handling | SwiftUI alerts | Toast messages | 