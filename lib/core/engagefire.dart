
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
  static var _ads;

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
      EngageFire._storage = await EngageFiles.init(storageBucket ?? '$projectID.appspot.com', EngageFire._app);
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
    EngagePubsub.init(app: _app, storage: _storage, ads: _ads);
    return EngageFire._app;
  }

  static get options => _options;
  
}