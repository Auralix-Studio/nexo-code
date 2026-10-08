import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/windows_startup.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      (call) async {
        calls.add(call);
        if (call.method.startsWith('is')) return false;
        if (call.method == 'getBounds') {
          final size = calls
              .lastWhere((c) => c.method == 'setBounds')
              .arguments;
          return {
            'x': 10.0,
            'y': 10.0,
            'width': size['width'],
            'height': size['height'],
          };
        }
        return null;
      },
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.leanflutter.plugins/screen_retriever'),
      (call) async {
        final display = {
          'id': '1',
          'name': 'Test display',
          'size': {'width': 1920.0, 'height': 1080.0},
          'visiblePosition': {'dx': 0.0, 'dy': 0.0},
          'visibleSize': {'width': 1920.0, 'height': 1040.0},
          'scaleFactor': 1.0,
        };
        return switch (call.method) {
          'getAllDisplays' => {
            'displays': [display],
          },
          'getCursorScreenPoint' => {'dx': 500.0, 'dy': 500.0},
          _ => display,
        };
      },
    );
  });
  tearDown(() {
    for (final name in [
      'window_manager',
      'dev.leanflutter.plugins/screen_retriever',
    ]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(name),
        null,
      );
    }
  });

  for (final mode in ['app', 'setup', 'uninstall']) {
    test(
      '$mode is sized and centered while hidden, then waits for paint',
      () async {
        await WindowsStartup.prepare(
          isSetup: mode != 'app',
          isUninstall: mode == 'uninstall',
          backgroundColor: Colors.white,
        );
        expect(calls.any((call) => call.method == 'show'), isFalse);
        final bounds = calls
            .where((call) => call.method == 'setBounds')
            .toList();
        expect(bounds, isNotEmpty);
        final size = bounds.first.arguments as Map;
        expect(size['width'], mode == 'app' ? 1100 : 480);
        expect(size['height'], switch (mode) {
          'app' => 680,
          'uninstall' => 460,
          _ => 380,
        });
        expect(bounds.last.arguments['x'], isNotNull);
        expect(bounds.last.arguments['y'], isNotNull);

        final frame = Completer<void>();
        final shown = WindowsStartup.showAfterFrame(frame.future);
        await Future<void>.delayed(Duration.zero);
        expect(calls.any((call) => call.method == 'show'), isFalse);
        frame.complete();
        await shown;
        expect(calls.where((call) => call.method == 'show'), hasLength(1));
        expect(calls.last.method, 'show');
      },
    );
  }
}
