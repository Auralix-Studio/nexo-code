import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/design/font_file.dart';
import 'package:nexo/core/design/font_library.dart';

void main() {
  final hypero = File('assets/fonts/Hypero.ttf').readAsBytesSync();

  Future<void> register(String family, List<Uint8List> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(f)));
    }
    await loader.load();
  }

  /// Píxeles oscuros al pintar una frase: más tinta, trazo más grueso.
  Future<int> ink(WidgetTester tester, String family, FontWeight weight) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: Text(
                'Horario de hoy',
                style: TextStyle(
                  fontFamily: family,
                  fontSize: 48,
                  fontWeight: weight,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final data = await tester.runAsync(() async {
      final image = await boundary.toImage();
      return image.toByteData(format: ui.ImageByteFormat.rawRgba);
    });
    final px = data!.buffer.asUint8List();
    var dark = 0;
    for (var i = 0; i < px.length; i += 4) {
      if (px[i] < 128) dark++;
    }
    return dark;
  }

  testWidgets('una fuente de un solo peso no se engorda en negrita', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await register('Hypero tal cual', [hypero]);
      await register(
        'Hypero cubierta',
        FontLibrary.coverBoldWeights([
          (weight: 400, italic: false, bytes: hypero),
        ]),
      );
    });

    final plainRegular = await ink(tester, 'Hypero tal cual', FontWeight.w400);
    final plainBold = await ink(tester, 'Hypero tal cual', FontWeight.w800);
    // Sin copia, Flutter engorda la letra: así se veían los presets.
    expect(plainBold, greaterThan(plainRegular * 1.1));

    // Con la copia, todos los pesos se ven como la Regular.
    for (final w in [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
      FontWeight.w900,
    ]) {
      expect(
        await ink(tester, 'Hypero cubierta', w),
        plainRegular,
        reason: '$w',
      );
    }
  });

  // Bahnschrift es variable y viene con Windows; en otros sistemas no está.
  final bahnschrift = File(r'C:\Windows\Fonts\bahnschrift.ttf');
  testWidgets('una fuente variable tampoco se engorda', (tester) async {
    final bytes = bahnschrift.readAsBytesSync();
    final info = FontFileInfo.parse(bytes);
    expect(info.variable, isTrue);
    await tester.runAsync(() async {
      await register('Variable tal cual', [bytes]);
      await register(
        'Variable cubierta',
        FontLibrary.coverBoldWeights([
          (weight: info.weight, italic: false, bytes: bytes),
        ]),
      );
    });
    final regular = await ink(tester, 'Variable tal cual', FontWeight.w400);
    expect(
      await ink(tester, 'Variable tal cual', FontWeight.w700),
      greaterThan(regular * 1.1),
    );
    for (final w in [FontWeight.w600, FontWeight.w800, FontWeight.w900]) {
      expect(
        await ink(tester, 'Variable cubierta', w),
        lessThanOrEqualTo(regular),
        reason: '$w',
      );
    }
  }, skip: !bahnschrift.existsSync());

  test('las copias solo cambian el peso declarado', () {
    final copy = FontFileInfo.withWeight(hypero, 800)!;
    expect(copy.length, hypero.length);
    final info = FontFileInfo.parse(copy);
    expect(info.weight, 800);
    expect(info.family, 'Hypero');
    expect(
      FontFileInfo.parse(hypero).weight,
      400,
      reason: 'no toca el original',
    );
  });
}
