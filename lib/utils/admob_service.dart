import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  static RewardedAd? _rewardedAd;
  static bool _isLoading = false;

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313';
    }
    throw UnsupportedError('Unsupported platform');
  }

  /// 1. Call this in main.dart to wake up the SDK
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    loadRewardedAd();
  }

  /// 2. Silently fetches the transmission in the background
  static void loadRewardedAd() {
    if (_rewardedAd != null || _isLoading) return;
    _isLoading = true;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('Transmission loaded successfully.');
          _rewardedAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (err) {
          debugPrint('Failed to load transmission: ${err.message}');
          _isLoading = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  /// 3. Plays the video instantly and returns TRUE only if fully watched
  static Future<bool> showRewardedAd() async {
    if (_rewardedAd == null) {
      debugPrint('Warning: Transmission not cached. Attempting to load.');
      loadRewardedAd();
      return false; // Tells the UI the ad wasn't ready
    }

    final completer = Completer<bool>();
    bool earnedReward = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // 🚀 Instantly queue up the next transmission!

        if (!completer.isCompleted) {
          completer.complete(earnedReward);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();

        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    // Present the video to the user
    await _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        // This fires when the video finishes, but we wait for the user
        // to actually dismiss the ad screen to resolve the Completer.
        earnedReward = true;
      },
    );

    return completer.future;
  }
}
