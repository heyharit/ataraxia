// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_native_splash/flutter_native_splash.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'app.dart';
// import 'ritual/ambient/ambient_manager.dart';
// import 'package:flutter_displaymode/flutter_displaymode.dart';

// Future<void> main() async {
//   // Ensure Flutter binding is initialized
//   WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

//   // Preserve native splash until app is fully ready
//   FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

//   try {
//     // This forces 120Hz/90Hz on capable Android devices
//     await FlutterDisplayMode.setHighRefreshRate();
//   } catch (e) {
//     // Fallback for unsupported devices
//   }

//   // Set system UI: edge-to-edge with transparent status bar
//   SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
//   SystemChrome.setSystemUIOverlayStyle(
//     const SystemUiOverlayStyle(
//       statusBarColor: Colors.transparent,
//       systemNavigationBarColor: Colors.transparent,
//       statusBarIconBrightness: Brightness.light,
//       systemNavigationBarIconBrightness: Brightness.light,
//     ),
//   );

//   // SystemChrome.setSystemUIOverlayStyle(
//   //   const SystemUiOverlayStyle(
//   //     statusBarColor: Colors.transparent,
//   //     systemNavigationBarColor: Colors.transparent,
//   //     systemNavigationBarIconBrightness: Brightness.light,
//   //   ),
//   // );
//   WidgetsBinding.instance.addPostFrameCallback((_) {
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
//   });

//   // Initialize external services in parallel
//   await Future.wait([
//     Supabase.initialize(
//       url: 'https://thczyvmcihuuycbccpty.supabase.co',
//       anonKey:
//           'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoY3p5dm1jaWh1dXljYmNjcHR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgyNzE0NTIsImV4cCI6MjA4Mzg0NzQ1Mn0.l-wdh1qk3pJ8rQvrnfNkoTd_JiDFEIRWlN-ehPr9me4',
//     ),
//     AmbientManager.initialize(),
//   ]);

//   // Tune image cache for performance
//   PaintingBinding.instance.imageCache.maximumSize = 200;
//   PaintingBinding.instance.imageCache.maximumSizeBytes = 300 << 20;

//   // Remove splash once app is ready
//   FlutterNativeSplash.remove();

//   // Run the app
//   runApp(const AtaraxiaApp());
// }

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'ritual/ambient/ambient_manager.dart';
import 'supabase/supabase_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'utils/admob_service.dart';
import 'utils/purchase_service.dart';
import 'app.dart';

Future<void> main() async {
  // 1. Bind ASAP
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // 2. Best-effort display mode (never block startup)
  try {
    await FlutterDisplayMode.setHighRefreshRate();
  } catch (_) {}

  // 3. System UI config (cheap, synchronous)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  });

  // 4. CRITICAL init ONLY (fast, required everywhere)
  await Future.wait([
    Supabase.initialize(
      url: 'https://thczyvmcihuuycbccpty.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoY3p5dm1jaWh1dXljYmNjcHR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgyNzE0NTIsImV4cCI6MjA4Mzg0NzQ1Mn0.l-wdh1qk3pJ8rQvrnfNkoTd_JiDFEIRWlN-ehPr9me4',
    ),
    Firebase.initializeApp(), // Wakes up the Remote Config engine!
    AdMobService.initialize(),
  ]);

  await PurchaseService.initialize();
  SupabaseService.initializeResonance();
  await AmbientManager.initialize();

  // 5. Image cache tuning (safe here)
  PaintingBinding.instance.imageCache.maximumSize = 200;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 300 << 20;

  // 6. REMOVE NATIVE SPLASH IMMEDIATELY
  FlutterNativeSplash.remove();

  // 7. Enter Flutter world
  runApp(const AtaraxiaApp());
}
