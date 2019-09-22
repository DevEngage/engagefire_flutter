

/* 
  TODO:
  [ ] pull targtingInfo from user profile
 */
import 'package:engagefire/core/pubsub.dart';

class EngageAds {
  static var ADS_SERVICE;
  static var APP_ID;
  static var AD_UNIT_ID;
  static List KEYWORDS;
  static String CONTENT_URL;
  static List TEST_DEVICES;
  static EngageAds instance;
  var adsInstance;

  static init({
    dynamic Ads, 
    appId,
    bannerUnitId,
    screenUnitId,
    videoUnitId,

    keywords,
    contentUrl,
    childDirected,
    testDevices,
    testing,
  }) async {
    if (Ads != null) {
      EngageAds.ADS_SERVICE = Ads;
    }
    EngageAds.AD_UNIT_ID = appId;

    return EngageAds.getInstance().adsInstance ??= EngageAds.ADS_SERVICE(
      appId,
      bannerUnitId: bannerUnitId,
      screenUnitId: screenUnitId,
      screenUnitId: videoUnitId,
      keywords: keywords ?? EngageAds.KEYWORDS,
      contentUrl: contentUrl ?? EngageAds.CONTENT_URL,
      childDirected: childDirected ?? false,
      testDevices: testDevices ?? EngageAds.TEST_DEVICES,
      testing: testing ?? false,
      listener: (event) => engagePubsub.publish(event, 'engage_ads'),
    );
  }

  showBannerAd({state, anchorOffset}) {
    return adsInstance.showBannerAd(state: state, anchorOffset: anchorOffset);
  }

  hideBannerAd() {
    return adsInstance.hideBannerAd();
  }

  showFullScreenAd({state}) {
    return adsInstance.showFullScreenAd(state: state);
  }

  hideFullScreenAd() {
    return adsInstance.hideFullScreenAd();
  }

  showVideoAd({state}) {
    return adsInstance.showVideoAd(state: state);
  }

  hideVideoAd() {
    return adsInstance.hideVideoAd();
  }

  static getInstance() {
    return EngagePubsub.instance ??= EngagePubsub();
  }

}

var engageAds = EngageAds.getInstance();