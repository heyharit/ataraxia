import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class TransmissionManager {
  static const String _adHistoryKey = 'ataraxia_transmission_history';

  // 🚀 FETCH DYNAMICALLY FROM FIREBASE (With safe fallbacks)
  static int get _maxAds {
    final val = FirebaseRemoteConfig.instance.getInt('max_ads_per_window');
    return val > 0 ? val : 2; // Fallback to 2 if not set
  }

  static int get _cooldownMinutes {
    final val = FirebaseRemoteConfig.instance.getInt('ad_cooldown_minutes');
    return val > 0 ? val : 30; // Fallback to 30 if not set
  }

  /// Initialize remote config defaults (Call this in main.dart)
  static Future<void> initializeConfig() async {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: const Duration(hours: 1), // Check for updates hourly
    ));
    await remoteConfig.setDefaults(const {
      'max_ads_per_window': 2,
      'ad_cooldown_minutes': 30,
    });
    await remoteConfig.fetchAndActivate();
  }

  /// Returns true if the user is allowed to watch an ad right now
  static Future<bool> canReceiveTransmission() async {
    final history = await _getHistory();
    return history.length < _maxAds;
  }

  /// Returns the exact duration until the next ad unlocks (if locked)
  static Future<Duration?> timeUntilNextTransmission() async {
    final history = await _getHistory();
    if (history.length < _maxAds) return null;

    final oldestAd = history.first;
    final unlockTime = oldestAd.add(Duration(minutes: _cooldownMinutes));
    final remaining = unlockTime.difference(DateTime.now());
    
    return remaining.isNegative ? null : remaining;
  }

  /// Call this EXACTLY when the user finishes watching the rewarded ad
  static Future<void> recordTransmission() async {
    final history = await _getHistory();
    history.add(DateTime.now());
    
    final prefs = await SharedPreferences.getInstance();
    final stringList = history.map((d) => d.toIso8601String()).toList();
    await prefs.setStringList(_adHistoryKey, stringList);
  }

  static Future<List<DateTime>> _getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_adHistoryKey) ?? [];
    final now = DateTime.now();
    
    final validHistory = rawList
        .map((s) => DateTime.parse(s))
        .where((d) => now.difference(d).inMinutes < _cooldownMinutes)
        .toList();
        
    if (validHistory.length != rawList.length) {
      await prefs.setStringList(
        _adHistoryKey, 
        validHistory.map((d) => d.toIso8601String()).toList()
      );
    }
    
    validHistory.sort((a, b) => a.compareTo(b));
    return validHistory;
  }
}