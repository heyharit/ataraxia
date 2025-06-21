import 'dart:async';
import 'dart:io';
import 'dart:math' as math; // 🚀 ADDED FOR RANDOMIZATION
import 'package:workmanager/workmanager.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import '../../data/models/moment.dart';
import '../../supabase/supabase_service.dart';
import 'image_composer.dart';

const String kAmbientTaskKey = "com.ataraxia.ambient_update";
const String kWidgetName = "AtaraxiaWidget";
const String kPrefAmbientEnabled = "ambient_enabled";
const String kPrefAmbientSource = "ambient_source";
const String kPrefAmbientType = "ambient_type";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final isManualSummon = inputData?['is_manual'] == true;

      if (!isManualSummon && prefs.getBool(kPrefAmbientEnabled) != true) {
        return true;
      }

      try {
        Supabase.instance.client;
      } catch (_) {
        await Supabase.initialize(
          url: 'https://thczyvmcihuuycbccpty.supabase.co',
          anonKey:
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoY3p5dm1jaWh1dXljYmNjcHR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgyNzE0NTIsImV4cCI6MjA4Mzg0NzQ1Mn0.l-wdh1qk3pJ8rQvrnfNkoTd_JiDFEIRWlN-ehPr9me4',
        );
      }

      final source = prefs.getString(kPrefAmbientSource) ?? 'today';
      Moment? payload = (source == 'today')
          ? await _fetchToday()
          : await _fetchRandomExplore();

      if (payload == null) return false;

      final targetHome = prefs.getBool('ambient_target_home') ?? true;
      final targetLock = prefs.getBool('ambient_target_lock') ?? true;
      final targetWidget = prefs.getBool('ambient_target_widget') ?? true;

      if (!targetHome && !targetLock && !targetWidget) return true;

      final type = prefs.getString(kPrefAmbientType) ?? 'both';
      final imageUrl =
          "https://ik.imagekit.io/themadbrogrammers/${payload.imageKey}";

      Future<void> widgetTask = targetWidget
          ? _updateHomeWidget(payload).catchError((e) {
              print("Widget error: $e");
            })
          : Future.value();

      Future<File?> wallpaperTask;
      if (targetHome || targetLock) {
        if (type == 'both') {
          wallpaperTask = ImageComposer.composeLockScreen(
            imageUrl: imageUrl,
            quote: payload.title,
            author: payload.author ?? "Unknown",
          );
        } else if (type == 'image') {
          wallpaperTask = _streamDownloadFile(
            imageUrl,
            'ambient_wallpaper.jpg',
          );
        } else {
          wallpaperTask = Future.value(null);
        }
      } else {
        wallpaperTask = Future.value(null);
      }

      final results = await Future.wait([widgetTask, wallpaperTask]);
      final wallpaperFile = results[1] as File?;

      if (wallpaperFile != null) {
        if (targetHome) {
          await AsyncWallpaper.setWallpaperFromFile(
            filePath: wallpaperFile.path,
            wallpaperLocation: AsyncWallpaper.HOME_SCREEN,
          );
        }

        if (targetHome && targetLock) {
          await Future.delayed(const Duration(milliseconds: 500));
        }

        if (targetLock) {
          await AsyncWallpaper.setWallpaperFromFile(
            filePath: wallpaperFile.path,
            wallpaperLocation: AsyncWallpaper.LOCK_SCREEN,
          );
        }
      }

      return true;
    } catch (e) {
      print("Ambient Ritual Error: $e");
      return false;
    }
  });
}

Future<Moment?> _fetchToday() async {
  try {
    return await SupabaseService.fetchTodayMoment();
  } catch (e) {
    print("Fetch today failed: $e");
    return null;
  }
}

// 🚀 THE FIX: True Chaos Mode
Future<Moment?> _fetchRandomExplore() async {
  try {
    final randomOffset = math.Random().nextInt(40); // Dig into random depth

    final res = await Supabase.instance.client.rpc(
      'get_void_feed',
      params: {
        'p_user_id': '00000000-0000-0000-0000-000000000000',
        'p_limit': 10,
        'p_offset': randomOffset,
      },
    );

    final list = List<Map<String, dynamic>>.from(res as List);

    // Safety fallback just in case the offset goes too deep
    if (list.isEmpty) {
      final fallback = await Supabase.instance.client
          .from('wallpapers')
          .select()
          .limit(10);
      final fallbackList = List<Map<String, dynamic>>.from(fallback as List);
      if (fallbackList.isEmpty) return null;
      fallbackList.shuffle();
      return Moment.fromJson(fallbackList.first);
    }

    list.shuffle();
    return Moment.fromJson(list.first);
  } catch (e) {
    print("Fetch random failed: $e");
    return null;
  }
}

Future<void> _updateHomeWidget(Moment moment) async {
  try {
    final imageUrl =
        "https://ik.imagekit.io/themadbrogrammers/${moment.imageKey}?tr=w-800,q-90";
    final file = await _streamDownloadFile(imageUrl, 'widget_image.jpg');

    await HomeWidget.saveWidgetData('moment_id', moment.id);
    await HomeWidget.saveWidgetData('quote_title', moment.title);
    await HomeWidget.saveWidgetData('quote_author', moment.author ?? '');
    await HomeWidget.saveWidgetData('widget_image_path', file.path);

    await HomeWidget.updateWidget(
      name: kWidgetName,
      qualifiedAndroidName: 'com.themadbrogrammers.ataraxia.AtaraxiaWidget',
    );
  } catch (e) {
    print("Widget error: $e");
    rethrow;
  }
}

Future<File> _streamDownloadFile(String url, String filename) async {
  final dir = await getTemporaryDirectory();
  final uniqueName = "${DateTime.now().millisecondsSinceEpoch}_$filename";
  final file = File('${dir.path}/$uniqueName');
  final client = http.Client();

  try {
    final request = http.Request('GET', Uri.parse(url));
    final response = await client.send(request);

    if (response.statusCode != 200) {
      throw Exception("Download failed: ${response.statusCode}");
    }

    final sink = file.openWrite();
    await response.stream.pipe(sink);
    await sink.close();

    return file;
  } finally {
    client.close();
  }
}

class AmbientManager {
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  static Future<void> schedule(int frequencyHours) async {
    await Workmanager().registerPeriodicTask(
      "ataraxia_ambient_loop",
      kAmbientTaskKey,
      frequency: Duration(hours: frequencyHours),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  static Future<void> cancel() async {
    await Workmanager().cancelAll();
  }

  static Future<void> triggerManualRefresh() async {
    await Workmanager().registerOneOffTask(
      "ataraxia_manual_task",
      kAmbientTaskKey,
      inputData: {'is_manual': true},
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }
}
