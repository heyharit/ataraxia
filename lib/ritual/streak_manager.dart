import 'package:shared_preferences/shared_preferences.dart';
import '../supabase/supabase_service.dart'; // 🚀 Added to talk to the DB

class StreakManager {
  static const _lastCompletedKey = 'last_completed_ritual_date';

  static Future<bool> isContinuingStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_lastCompletedKey);
    if (last == null) return false;

    final lastDate = DateTime.parse(last);
    final today = DateTime.now();

    return _isYesterday(lastDate, today) || _isToday(lastDate, today);
  }

  // 🚀 THE FIX: Now requires the userId so it can update the database!
  static Future<void> markCompletedToday(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    await prefs.setString(_lastCompletedKey, now.toIso8601String());

    // 🚀 FIRE TO SUPABASE! This triggers your SQL function and increments the Resonance.
    try {
      await SupabaseService.updateStreak(userId);
    } catch (e) {
      // Failsafe
    }
  }

  static bool _isYesterday(DateTime a, DateTime b) {
    final d1 = DateTime(a.year, a.month, a.day);
    final d2 = DateTime(b.year, b.month, b.day);
    return d2.difference(d1).inDays == 1;
  }

  static bool _isToday(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
