
import 'dart:io';

import 'package:engagefire/core/ads.dart';
import 'package:engagefire/core/files.dart';
import 'package:engagefire/core/pubsub.dart';
import 'package:firebase_admob/firebase_admob.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

class EngageFire {
  static Map _options;
  static FirebaseApp _app;
  static FirebaseStorage _storage;
  static FirebaseAdMob _ads;

  EngageFire() {}

  static Future<FirebaseApp> init({ 
    String name, 
    String iosGoogleAppID, 
    String androidGoogleAppID, 
    String gcmSenderID, //messaging
    String apiKey, 
    String projectID,
    // optional
    String storageBucket,
    bool enableStorage = true,
    // ads
    String admobId,
    String adUnitId,
  }) async {
    var appId = Platform.isIOS ? iosGoogleAppID : androidGoogleAppID;
    EngageFire._options = {
      'name': name, 
      'iosGoogleAppID': iosGoogleAppID, 
      'androidGoogleAppID': androidGoogleAppID, 
      'gcmSenderID': gcmSenderID, 
      'apiKey': apiKey, 
      'projectID': projectID,
      'appId': appId
    };
    EngageFire._app = await FirebaseApp.configure(
      name: name,
      options: FirebaseOptions(
        googleAppID: appId,
        gcmSenderID: gcmSenderID,
        apiKey: apiKey,
        projectID: projectID,
      ),
    );
    if (enableStorage) {
      EngageFire._storage = await EngageFiles.init(storageBucket ?? '$projectID.appspot.com', EngageFire._app);
    }
    if (admobId != null) {
      EngageFire._ads = await EngageAds.init(appId: admobId, adUnitId: adUnitId);
    }
    EngagePubsub.init(app: _app, storage: _storage, ads: _ads);
    return EngageFire._app;
  }

  static get options => _options;
  
}