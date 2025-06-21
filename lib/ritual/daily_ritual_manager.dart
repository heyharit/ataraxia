import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/moment.dart';
import '../supabase/supabase_service.dart';
import 'dart:convert';

class DailyRitualManager {
  static const _dateKey = 'last_ritual_date';
  static const _cachedMomentKey = 'cached_daily_moment';

  static Future<Moment> loadTodayMoment() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();

    final cachedDate = prefs.getString(_dateKey);
    final cachedRaw = prefs.getString(_cachedMomentKey);

    if (cachedDate == today && cachedRaw != null) {
      return Moment.fromJson(Map<String, dynamic>.from(jsonDecode(cachedRaw)));
    }

    try {
      final moment = await SupabaseService.fetchTodayMoment();

      await prefs.setString(_dateKey, today);
      await prefs.setString(_cachedMomentKey, jsonEncode(moment.toJson()));

      return moment;
    } catch (_) {
      const imageKey = 'moments/winter/ataraxia.png';
      return Moment(
        wallpaperId: 'fallback',
        id: 'fallback',
        slug: slugFromImageKey(imageKey),
        title: 'Silence is also a ritual.',
        quote: '',
        author: null,
        // imageKey: '',
        imageKey: 'wallpapers/ataraxia.png',
        time: TimeOfDayMoment.morning,
        tags: [],
      );
    }
  }

  // static String _todayString() {
  //   final now = DateTime.now();
  //   return '${now.year}-${now.month}-${now.day}';
  // }
  static String _todayString() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }
}
