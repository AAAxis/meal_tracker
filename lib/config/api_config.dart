class ApiConfig {
  // Replace 'YOUR_GOOGLE_MAPS_API_KEY_HERE' with your actual Google Maps API key
  // Get your API key from: https://console.cloud.google.com/
  // Enable: Places API, Geocoding API, Maps SDK for Android/iOS
  static const String googleMapsApiKey = 'AIzaSyBwM7e_SuEAU32MVxL34MPGvllkVjUiAKE';
  
  // RevenueCat Configuration
  //TO DO: add the entitlement ID from the RevenueCat dashboard that is activated upon successful in-app purchase for the duration of the purchase.
  static const String entitlementID = 'Premium';

  // Your configured offering ID from RevenueCat dashboard
  static const String defaultOfferingId = 'Sale';

  //TO DO: add your subscription terms and conditions
  static const String footerText =
      """Don't forget to add your subscription terms and conditions. 

Read more about this here: https://www.revenuecat.com/blog/schedule-2-section-3-8-b""";

  //TO DO: add the Apple API key for your app from the RevenueCat dashboard: https://app.revenuecat.com
  static const String appleApiKey = 'appl_yQARkfiLiRNZYFSfDHwyclJRltG';

  //TO DO: add the Google API key for your app from the RevenueCat dashboard: https://app.revenuecat.com
  static const String googleApiKey = 'goog_KQXGqYZeiOCBNNAFRMjYptQDtjn';

  //TO DO: add the Amazon API key for your app from the RevenueCat dashboard: https://app.revenuecat.com
  static const String amazonApiKey = 'amazon_api_key';
  
  // You can add other API keys here as needed
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
}

// App Data Singleton for managing subscription state
class AppData {
  static final AppData _appData = AppData._internal();

  bool entitlementIsActive = false;
  String appUserID = '';

  factory AppData() {
    return _appData;
  }
  AppData._internal();
}

final appData = AppData(); 