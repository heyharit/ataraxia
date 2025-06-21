import 'dart:async';
import 'package:flutter/material.dart';

class VoidSignal {
  static final _controller = StreamController<void>.broadcast();
  static Stream<void> get onReconnect => _controller.stream;
  
  // The Brain calls this when the internet returns
  static void broadcast() => _controller.add(null);
}

// Any screen that needs to auto-reload just adds this mixin!
mixin VoidListener<T extends StatefulWidget> on State<T> {
  StreamSubscription? _voidSub;

  @override
  void initState() {
    super.initState();
    _voidSub = VoidSignal.onReconnect.listen((_) {
      if (mounted) onVoidReconnect();
    });
  }

  @override
  void dispose() {
    _voidSub?.cancel();
    super.dispose();
  }

  // The screen defines what to do when it hears the pulse
  void onVoidReconnect();
}