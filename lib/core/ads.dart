
import 'package:firebase_admob/firebase_admob.dart';

/* 
  TODO:
  [ ] pull targtingInfo from user profile
 */
class EngageAds {
  static var APP_ID;
  static var ADMOD;
  static var AD_UNIT_ID;
  var adUnitId;
  MobileAdTargetingInfo targetingInfo;
  BannerAd myBanner;
  InterstitialAd myInterstitial;

  EngageAds({this.adUnitId, initialTargetData}) {
    if (initialTargetData) setTargetData();
  }

  static init({appId, adUnitId, initialTargetData = true}) async {
    EngageAds.AD_UNIT_ID = adUnitId;
    EngageAds.APP_ID = appId;
    return EngageAds.ADMOD ??= await FirebaseAdMob.instance.initialize(appId: appId ?? EngageAds.APP_ID);
  }

  setTargetData({List<String> keywords, contentUrl, birthday, childDirected = false, designedForFamilies = false, MobileAdGender gender }) {
    targetingInfo = MobileAdTargetingInfo(
      keywords: keywords,
      contentUrl: contentUrl,
      birthday: birthday,
      childDirected: childDirected,
      designedForFamilies: designedForFamilies,
      gender: gender, // or MobileAdGender.female, MobileAdGender.unknown
      testDevices: <String>[], // Android emulators are considered test devices
    );
  }

  setBanner() {
    myBanner = BannerAd(
      // Replace the testAdUnitId with an ad unit id from the AdMob dash.
      // https://developers.google.com/admob/android/test-ads
      // https://developers.google.com/admob/ios/test-ads
      adUnitId: adUnitId ?? EngageAds.AD_UNIT_ID ?? BannerAd.testAdUnitId,
      size: AdSize.smartBanner,
      targetingInfo: targetingInfo,
      listener: (MobileAdEvent event) {
        print("BannerAd event is $event");
      },
    );
  }

  setInterstitial() {
    myInterstitial = InterstitialAd(
      // Replace the testAdUnitId with an ad unit id from the AdMob dash.
      // https://developers.google.com/admob/android/test-ads
      // https://developers.google.com/admob/ios/test-ads
      adUnitId: adUnitId ?? EngageAds.AD_UNIT_ID ?? InterstitialAd.testAdUnitId,
      targetingInfo: targetingInfo,
      listener: (MobileAdEvent event) {
        print("InterstitialAd event is $event");
      },
    );
  }

  setRewardVideo() {
    RewardedVideoAd.instance.load(adUnitId: adUnitId, targetingInfo: targetingInfo);
  }

  showRewardVideo() {
    RewardedVideoAd.instance.show();
  }

}