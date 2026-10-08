import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// The native runner stays hidden until Dart has sized and painted the window.
class WindowsStartup {
  static Future<void> prepare({
    bool isSetup = false,
    bool isUninstall = false,
    required Color backgroundColor,
  }) async {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: isSetup
            ? Size(480, isUninstall ? 460 : 380)
            : const Size(1100, 680),
        minimumSize: Size(480, isSetup ? 340 : 500),
        maximumSize: isSetup ? const Size(480, 700) : null,
        titleBarStyle: TitleBarStyle.hidden,
        center: true,
        backgroundColor: backgroundColor,
      ),
    );
  }

  static Future<void> showAfterFrame(Future<void> firstFrame) async {
    await firstFrame;
    await windowManager.show();
  }
}
