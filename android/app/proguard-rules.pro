# Remove Stripe classes keep rules
#-keep class com.stripe.android.** { *; }
#-keep class com.stripe.android.pushProvisioning.** { *; }
#-keep class com.reactnativestripesdk.** { *; }
#-keep class com.stripe.android.pushProvisioning.EphemeralKeyUpdateListener { *; }
#-keep class com.stripe.android.pushProvisioning.PushProvisioningActivity$g { *; }
#-keep class com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args { *; }
#-keep class com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error { *; }
#-keep class com.stripe.android.pushProvisioning.PushProvisioningActivityStarter { *; }
#-keep class com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider { *; }

# Keep Play Core classes
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-keep class com.google.android.play.core.splitcompat.SplitCompatApplication { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallException { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallManager { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallManagerFactory { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallRequest$Builder { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallRequest { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallSessionState { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener { *; }
-keep class com.google.android.play.core.tasks.OnFailureListener { *; }
-keep class com.google.android.play.core.tasks.OnSuccessListener { *; }
-keep class com.google.android.play.core.tasks.Task { *; }

# Keep specific Play Core Task classes
-keep class com.google.android.play.core.tasks.OnFailureListener { *; }
-keep class com.google.android.play.core.tasks.OnSuccessListener { *; }
-keep class com.google.android.play.core.tasks.Task { *; }
-keep class com.google.android.play.core.tasks.Tasks { *; }

# Keep RevenueCat classes
-keep class com.revenuecat.** { *; }

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep Flutter classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep your app's classes
-keep class com.theholylabs.grape.** { *; }

# General Android rules
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable classes
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep R8 rules
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Keep interfaces
-keep interface com.google.android.play.core.** { *; }
-keep interface com.stripe.android.** { *; }

# Keep all classes in the tasks package
-keep class com.google.android.play.core.tasks.** { *; } 