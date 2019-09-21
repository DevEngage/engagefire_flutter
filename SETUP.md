## firebase_auth 0.14.0+5
Android integration #
Enable the Google services by configuring the Gradle scripts as such.

Add the classpath to the [project]/android/build.gradle file.
dependencies {
  // Example existing classpath
  classpath 'com.android.tools.build:gradle:3.2.1'
  // Add the google services classpath
  classpath 'com.google.gms:google-services:4.3.0'
}
Add the apply plugin to the [project]/android/app/build.gradle file.
// ADD THIS AT THE BOTTOM
apply plugin: 'com.google.gms.google-services'
Note: If this section is not completed you will get an error like this:

java.lang.IllegalStateException:
Default FirebaseApp is not initialized in this process [package name].
Make sure to call FirebaseApp.initializeApp(Context) first.

## cloud_firestore 0.12.9+4
To use this plugin:

Using the Firebase Console, add an Android app to your project: Follow the assistant, download the generated google-services.json file and place it inside android/app. Next, modify the android/build.gradle file and the android/app/build.gradle file to add the Google services plugin as described by the Firebase assistant. Ensure that your android/build.gradle file contains the maven.google.com as described here.
Using the Firebase Console, add an iOS app to your project: Follow the assistant, download the generated GoogleService-Info.plist file, open ios/Runner.xcworkspace with Xcode, and within Xcode place the file inside ios/Runner. Don't follow the steps named "Add Firebase SDK" and "Add initialization code" in the Firebase assistant.
Add cloud_firestore as a dependency in your pubspec.yaml file.


## firebase_messaging 5.1.5

dependencies {
  // Example existing classpath
  classpath 'com.android.tools.build:gradle:3.2.1'
  // Add the google services classpath
  classpath 'com.google.gms:google-services:4.3.0'
}
Add the apply plugin to the [project]/android/app/build.gradle file.
// ADD THIS AT THE BOTTOM
apply plugin: 'com.google.gms.google-services'
Note: If this section is not completed you will get an error like this:

java.lang.IllegalStateException:
Default FirebaseApp is not initialized in this process [package name].
Make sure to call FirebaseApp.initializeApp(Context) first.
Note: When you are debugging on Android, use a device or AVD with Google Play services. Otherwise you will not be able to authenticate.

(optional, but recommended) If want to be notified in your app (via onResume and onLaunch, see below) when the user clicks on a notification in the system tray include the following intent-filter within the <activity> tag of your android/app/src/main/AndroidManifest.xml:
  <intent-filter>
      <action android:name="FLUTTER_NOTIFICATION_CLICK" />
      <category android:name="android.intent.category.DEFAULT" />
  </intent-filter>

  ### android background
  Optionally handle background messages #
Background message handling is intended to be performed quickly. Do not perform long running tasks as they may not be allowed to finish by the Android system. See Background Execution Limits for more.

By default background messaging is not enabled. To handle messages in the background:

Add an Application.java class to your app

 package io.flutter.plugins.firebasemessagingexample;

 import io.flutter.app.FlutterApplication;
 import io.flutter.plugin.common.PluginRegistry;
 import io.flutter.plugin.common.PluginRegistry.PluginRegistrantCallback;
 import io.flutter.plugins.GeneratedPluginRegistrant;
 import io.flutter.plugins.firebasemessaging.FlutterFirebaseMessagingService;

 public class Application extends FlutterApplication implements PluginRegistrantCallback {
   @Override
   public void onCreate() {
     super.onCreate();
     FlutterFirebaseMessagingService.setPluginRegistrant(this);
   }

   @Override
   public void registerWith(PluginRegistry registry) {
     GeneratedPluginRegistrant.registerWith(registry);
   }
 }
Set name property of application in AndroidManifest.xml

 <application android:name=".Application" ...>
Define a top level Dart method to handle background messages

 Future<dynamic> myBackgroundMessageHandler(Map<String, dynamic> message) {
   if (message.containsKey('data')) {
     // Handle data message
     final dynamic data = message['data'];
   }

   if (message.containsKey('notification')) {
     // Handle notification message
     final dynamic notification = message['notification'];
   }

   // Or do other work.
 }
Note: the protocol of data and notification are in line with the fields defined by a RemoteMessage.

Set onBackgroundMessage handler when calling configure

 _firebaseMessaging.configure(
       onMessage: (Map<String, dynamic> message) async {
         print("onMessage: $message");
         _showItemDialog(message);
       },
       onBackgroundMessage: myBackgroundMessageHandler,
       onLaunch: (Map<String, dynamic> message) async {
         print("onLaunch: $message");
         _navigateToItemDetail(message);
       },
       onResume: (Map<String, dynamic> message) async {
         print("onResume: $message");
         _navigateToItemDetail(message);
       },
     );
Note: configure should be called early in the lifecycle of your application so that it can be ready to receive messages as early as possible. See the example app for a demonstration.

### iOS Integration

To integrate your plugin into the iOS part of your app, follow these steps:

Generate the certificates required by Apple for receiving push notifications following this guide in the Firebase docs. You can skip the section titled "Create the Provisioning Profile".

Using the Firebase Console add an iOS app to your project: Follow the assistant, download the generated GoogleService-Info.plist file, open ios/Runner.xcworkspace with Xcode, and within Xcode place the file inside ios/Runner. Don't follow the steps named "Add Firebase SDK" and "Add initialization code" in the Firebase assistant.

In Xcode, select Runner in the Project Navigator. In the Capabilities Tab turn on Push Notifications and Background Modes, and enable Background fetch and Remote notifications under Background Modes.

Follow the steps in the "Upload your APNs certificate" section of the Firebase docs.

### Receiving Messages #
Messages are sent to your Flutter app via the onMessage, onLaunch, and onResume callbacks that you configured with the plugin during setup. Here is how different message types are delivered on the supported platforms:

App in Foreground	App in Background	App Terminated
Notification on Android	onMessage	Notification is delivered to system tray. When the user clicks on it to open app onResume fires if click_action: FLUTTER_NOTIFICATION_CLICK is set (see below).	Notification is delivered to system tray. When the user clicks on it to open app onLaunch fires if click_action: FLUTTER_NOTIFICATION_CLICK is set (see below).
Notification on iOS	onMessage	Notification is delivered to system tray. When the user clicks on it to open app onResume fires.	Notification is delivered to system tray. When the user clicks on it to open app onLaunch fires.
Data Message on Android	onMessage	onMessage while app stays in the background.	not supported by plugin, message is lost
Data Message on iOS	onMessage	Message is stored by FCM and delivered to app via onMessage when the app is brought back to foreground.	Message is stored by FCM and delivered to app via onMessage when the app is brought back to foreground.
Additional reading: Firebase's About FCM Messages.

Notification messages with additional data #
It is possible to include additional data in notification messages by adding them to the "data"-field of the message.

On Android, the message contains an additional field data containing the data. On iOS, the data is directly appended to the message and the additional data-field is omitted.

To receive the data on both platforms:

Future<void> _handleNotification (Map<dynamic, dynamic> message, bool dialog) async {
    var data = message['data'] ?? message;
    String expectedAttribute = data['expectedAttribute'];
    /// [...]
}


## file_picker 1.4.1
 Android
All set. You are good to go.

 iOS
Based on the location of the files that you are willing to pick paths, you may need to add some keys to your iOS app's Info.plist file, located in <project root>/ios/Runner/Info.plist:

UIBackgroundModes with the fetch and remote-notifications keys - Required if you'll be using the FileType.ANY or FileType.CUSTOM. Describe why your app needs to access background taks, such downloading files (from cloud services). This is called Required background modes, with the keys App download content from network and App downloads content in response to push notifications respectively in the visual editor (since both methods aren't actually overriden, not adding this property/keys may only display a warning, but shouldn't prevent its correct usage).

<key>UIBackgroundModes</key>
<array>
   <string>fetch</string>
   <string>remote-notification</string>
</array>
NSAppleMusicUsageDescription - Required if you'll be using the FileType.AUDIO. Describe why your app needs permission to access music library. This is called Privacy - Media Library Usage Description in the visual editor.

<key>NSAppleMusicUsageDescription</key>
<string>Explain why your app uses music</string>
NSPhotoLibraryUsageDescription - Required if you'll be using the FileType.IMAGE or FileType.VIDEO. Describe why your app needs permission for the photo library. This is called Privacy - Photo Library Usage Description in the visual editor.

<key>NSPhotoLibraryUsageDescription</key>
<string>Explain why your app uses photo library</string>
Note: Any iOS version below 11.0, will require an Apple Developer Program account to enable CloudKit and make it possible to use the document picker (which happens when you select FileType.ALL, FileType.CUSTOM or any other option with getMultiFilePath()). You can read more about it here.


## firebase_admob 0.9.0+7
AndroidManifest changes #
AdMob 17 requires the App ID to be included in the AndroidManifest.xml. Failure to do so will result in a crash on launch of your app. The line should look like:

<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="[ADMOB_APP_ID]"/>
where [ADMOB_APP_ID] is your App ID. You must pass the same value when you initialize the plugin in your Dart code.

See https://goo.gl/fQ2neu for more information about configuring AndroidManifest.xml and setting up your App ID.

Info.plist changes #
Admob 7.42.0 requires the App ID to be included in Info.plist. Failure to do so will result in a crash on launch of your app. The lines should look like:

<key>GADApplicationIdentifier</key>
<string>[ADMOB_APP_ID]</string>
where [ADMOB_APP_ID] is your App ID. You must pass the same value when you initialize the plugin in your Dart code.

See https://developers.google.com/admob/ios/quick-start#update_your_infoplist for more information about configuring Info.plist and setting up your App ID.

Android #
Starting in version 17.0.0, if you are an AdMob publisher you are now required to add your AdMob app ID in your AndroidManifest.xml file. Once you find your AdMob app ID in the AdMob UI, add it to your manifest adding the following tag:

<manifest>
    <application>
        <!-- TODO: Replace with your real AdMob app ID -->
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-################~##########"/>
    </application>
</manifest>
Failure to add this tag will result in the app crashing at app launch with a message starting with "The Google Mobile Ads SDK was initialized incorrectly."

On Android, this value must be the same as the App ID value set in your AndroidManifest.xml.

iOS #
Starting in version 7.42.0, you are required to add your AdMob app ID in your Info.plist file under the Runner directory. You can add it using Xcode or edit the file manually:

<dict>
	<key>GADApplicationIdentifier</key>
	<string>ca-app-pub-################~##########</string>
</dict>
Failure to add this tag will result in the app crashing at app launch with a message including "GADVerifyApplicationID."


## image_picker 0.6.1+4
iOS #
Add the following keys to your Info.plist file, located in <project root>/ios/Runner/Info.plist:

NSPhotoLibraryUsageDescription - describe why your app needs permission for the photo library. This is called Privacy - Photo Library Usage Description in the visual editor.
NSCameraUsageDescription - describe why your app needs access to the camera. This is called Privacy - Camera Usage Description in the visual editor.
NSMicrophoneUsageDescription - describe why your app needs access to the microphone, if you intend to record videos. This is called Privacy - Microphone Usage Description in the visual editor.
Android #
No configuration required - the plugin should work out of the box.

