import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  // Use Google test IDs in debug, real IDs in release
  static const _bannerId = kDebugMode
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-7355481459096015/1406439832';
  static const _interstitialId = kDebugMode
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-7355481459096015/4132675526';

  static BannerAd? _bannerAd;
  static InterstitialAd? _interstitialAd;
  static bool _interstitialReady = false;

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadInterstitial();
  }

  // ── Banner ────────────────────────────────────────────────────────────────
  static BannerAd createBanner() {
    _bannerAd = BannerAd(
      adUnitId: _bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed: $error');
          ad.dispose();
        },
      ),
    )..load();
    return _bannerAd!;
  }

  static void disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
  }

  // ── Interstitial ──────────────────────────────────────────────────────────
  static void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialReady = false;
              _loadInterstitial(); // preload next
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _interstitialReady = false;
              _loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (_) {
          _interstitialReady = false;
        },
      ),
    );
  }

  static void showInterstitial() {
    if (_interstitialReady && _interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialReady = false;
    }
  }
}
