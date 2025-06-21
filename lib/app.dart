import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'ui/screens/ritual_screen.dart';
import 'ui/widgets/global_update_wrapper.dart';

class AtaraxiaApp extends StatelessWidget {
  const AtaraxiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) {
        final media = MediaQuery.of(context);

        // 🚀 We keep your immersive MediaQuery override,
        // but we wrap the incoming screen (child) with our global force-update system!
        return MediaQuery(
          data: media.copyWith(
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
            viewInsets: EdgeInsets.zero,
          ),
          child: GlobalUpdateWrapper(child: child ?? const SizedBox.shrink()),
        );
      },
      title: 'Ataraxia',
      debugShowCheckedModeBanner: false,
      theme: AtaraxiaTheme.light,
      darkTheme: AtaraxiaTheme.dark,
      themeMode: ThemeMode.system,
      home: const RitualScreen(),
    );
  }
}
