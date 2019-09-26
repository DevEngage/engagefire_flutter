
import 'dart:io';

import 'package:engagefire/core/ads.dart';
import 'package:engagefire/core/files.dart';
import 'package:engagefire/core/pubsub.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'auth.dart';

class EngageFire {
  static Map _options;
  static FirebaseApp _app;
  static EngageAuth _auth;
  static EngageFiles _storage;
  static EngageAds _ads;

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
    dynamic Ads,
    String androidAdAppId,
    String iosAdAppId,
    String androidBannerUnitId,
    String iosBannerUnitId,
    String androidScreenUnitId,
    String iosScreenUnitId,
    String androidVideoUnitId,
    String iosVideoUnitId,

    List keywords,
    List testDevices,
    bool testing,
    String childDirected,
    String contentUrl,

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
      EngageFire._storage = EngageFiles(storageBucket ?? '$projectID.appspot.com', EngageFire._app);
    }
    if (Ads != null) {
      EngageFire._ads = await EngageAds.init(
        Ads: Ads, 
        appId: Platform.isIOS ? iosAdAppId : androidAdAppId,
        bannerUnitId: Platform.isIOS ? iosBannerUnitId : androidBannerUnitId,
        screenUnitId: Platform.isIOS ? iosScreenUnitId : androidScreenUnitId,
        videoUnitId: Platform.isIOS ? iosVideoUnitId : androidVideoUnitId,

        keywords: keywords,
        testDevices: testDevices,
        contentUrl: contentUrl,
        childDirected: childDirected,
        testing:testing,
      );
    }
    EngageFire._auth = await EngageAuth.init();
    EngagePubsub.init(app: _app, storage: _storage, ads: _ads, auth: _auth);
    return EngageFire._app;
  }

  static get options => _options;
  static FirebaseApp get app => EngageFire._app;
  static EngageAuth get auth => EngageFire._auth;
  static EngageFiles get storage => EngageFire._storage;
  static EngageAds get ads => EngageFire._ads;
  
}