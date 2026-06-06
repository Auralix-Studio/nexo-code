import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// ============================================================================
//  Fallback de español para los textos del SDK cuando el locale es quechua.
//
//  ESTO ES UN PUENTE, NO LA SOLUCIÓN DEFINITIVA.
//
//  Contexto: el paquete oficial `flutter_localizations` trae traducciones de
//  los widgets Material/Cupertino para unos 80 idiomas (en, es, fr, pt, zh,
//  ja, ko, ar, ru, hi, etc.). **Quechua no está incluido**, ni hay un PR
//  oficial pendiente — es decisión de Google. Sin un puente, cualquier
//  diálogo, date picker, scrollbar tooltip o widget que llame a
//  `MaterialLocalizations.of(context)` lanza un crash al cambiar a `qu`.
//
//  Lo que hace este archivo:
//    Cuando el locale es `qu`, devolvemos los textos en español del SDK.
//    Resultado:
//      - Toda la UI propia de Nexo (claves de los archivos .arb) sigue
//        mostrándose en quechua (con fallback a español por clave faltante).
//      - Los textos NATIVOS del SDK (botones "Aceptar"/"Cancelar" de los
//        date pickers, semánticos de accesibilidad, etc.) salen en español.
//
//  TODO (solución de raíz, requiere hablante de runa simi técnico):
//    1. Implementar `MaterialLocalizationsQu` traduciendo a quechua las ~150
//       cadenas del SDK que viven en `GlobalMaterialLocalizations`. Lista
//       completa: https://api.flutter.dev/flutter/material/MaterialLocalizations-class.html
//    2. Igual para `CupertinoLocalizationsQu` (~80 cadenas).
//    3. Reemplazar estos delegates puente por los nuevos.
//    4. Validar con hablante nativo antes de marcar como definitivo.
//
//  Mientras tanto, este puente es lo que permite a Nexo soportar quechua sin
//  romperse. NO ELIMINAR hasta que existan los delegates Qu reales.
// ============================================================================

const Locale _fallbackLocale = Locale('es');

class QuechuaMaterialDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const QuechuaMaterialDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'qu';

  @override
  Future<MaterialLocalizations> load(Locale _) =>
      GlobalMaterialLocalizations.delegate.load(_fallbackLocale);

  @override
  bool shouldReload(QuechuaMaterialDelegate old) => false;
}

class QuechuaCupertinoDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const QuechuaCupertinoDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'qu';

  @override
  Future<CupertinoLocalizations> load(Locale _) =>
      GlobalCupertinoLocalizations.delegate.load(_fallbackLocale);

  @override
  bool shouldReload(QuechuaCupertinoDelegate old) => false;
}

class QuechuaWidgetsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const QuechuaWidgetsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'qu';

  @override
  Future<WidgetsLocalizations> load(Locale _) =>
      GlobalWidgetsLocalizations.delegate.load(_fallbackLocale);

  @override
  bool shouldReload(QuechuaWidgetsDelegate old) => false;
}
