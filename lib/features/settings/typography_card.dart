import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexo/core/design/font_library.dart';
import 'package:nexo/core/design/motion.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/theme_controller.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/widgets/section_card.dart';

/// Elegir la fuente de toda la app, o importar una desde un archivo.
class TypographyCard extends StatefulWidget {
  const TypographyCard({super.key, required this.theme});
  final ThemeController theme;

  @override
  State<TypographyCard> createState() => _TypographyCardState();
}

class _TypographyCardState extends State<TypographyCard> {
  bool _importing = false;

  ThemeController get _theme => widget.theme;

  /// Cada opción se dibuja en su propia fuente: hay que registrarlas todas.
  void _registerAll() {
    for (final f in _theme.fonts.all) {
      _theme.fonts.ensureLoaded(f.id);
    }
  }

  Future<void> _import() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final locale = Localizations.localeOf(context).toString();
    setState(() => _importing = true);
    try {
      final List<XFile> files;
      try {
        files = await openFiles(acceptedTypeGroups: [_fontTypes(l)]);
      } catch (e) {
        debugPrint('Selector de archivos: $e');
        messenger.showSnackBar(SnackBar(content: Text(l.fontPickFailed)));
        return;
      }
      if (files.isEmpty) return;

      final max = _theme.fonts.maxBytes;
      final picked = <PickedFontFile>[];
      final tooLarge = <FontRejection>[];
      for (final f in files) {
        // Antes de leerlo: un archivo enorme elegido por error no debe
        // terminar entero en memoria.
        if (await f.length() > max) {
          tooLarge.add(FontRejection(f.name, FontImportProblem.tooLarge));
        } else {
          picked.add((name: f.name, bytes: await f.readAsBytes()));
        }
      }
      final result = picked.isEmpty
          ? const FontImport(fonts: [], rejected: [])
          : await _theme.importFonts(picked);

      final maxMb = NumberFormat('0.#', locale).format(max / (1024 * 1024));
      final lines = [
        if (result.fonts.isNotEmpty) l.fontApplied(result.fonts.last.name),
        for (final r in [...tooLarge, ...result.rejected])
          _problemText(l, r, maxMb),
      ];
      if (lines.isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(lines.join('\n'))));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _remove(FontChoice font) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await _theme.removeFont(font.id);
    messenger.showSnackBar(SnackBar(content: Text(l.fontRemoved(font.name))));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _theme,
      builder: (context, _) {
        _registerAll();
        final l = AppLocalizations.of(context);
        final active = _theme.font;
        final options = _theme.fonts.all;
        return SectionCard(
          title: l.fontsTitle,
          subtitle: l.fontsSubtitle,
          icon: Icons.text_fields_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeSwitch(
                child: KeyedSubtree(
                  key: ValueKey(active.family),
                  child: _Specimen(
                    font: active,
                    onRemove: active.kind == FontKind.imported
                        ? () => _remove(active)
                        : null,
                  ),
                ),
              ),
              if (active.variable) ...[
                const Gap(AppSpacing.md),
                _Hint(text: l.fontVariableHint),
              ],
              const Gap(AppSpacing.lg),
              LayoutBuilder(
                builder: (context, c) {
                  final cols = c.maxWidth >= 520 ? 3 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: options.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      mainAxisExtent: 68,
                    ),
                    itemBuilder: (_, i) {
                      final font = options[i];
                      return _FontTile(
                        font: font,
                        selected: font.id == active.id,
                        onTap: () => _theme.setFont(font.id),
                      );
                    },
                  );
                },
              ),
              const Gap(AppSpacing.sm),
              _ImportButton(
                busy: _importing,
                onTap: _importing ? null : _import,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Filtro del selector. En Android los gestores de archivos suelen dar a los
/// `.ttf` un tipo genérico y el filtro los escondería: allí se acepta
/// cualquier archivo y se valida al leerlo.
XTypeGroup _fontTypes(AppLocalizations l) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return XTypeGroup(label: l.fontImportFormats);
  }
  return XTypeGroup(
    label: l.fontImportFormats,
    extensions: const ['ttf', 'otf'],
    mimeTypes: const ['font/ttf', 'font/otf', 'font/sfnt'],
    uniformTypeIdentifiers: const [
      'public.truetype-ttf-font',
      'public.opentype-font',
      'public.font',
    ],
  );
}

String _problemText(AppLocalizations l, FontRejection r, String maxMb) =>
    switch (r.problem) {
      FontImportProblem.notAFont => l.fontProblemNotAFont(r.file),
      FontImportProblem.webFont => l.fontProblemWebFont(r.file),
      FontImportProblem.collection => l.fontProblemCollection(r.file),
      FontImportProblem.damaged => l.fontProblemDamaged(r.file),
      FontImportProblem.tooLarge => l.fontProblemTooLarge(r.file, maxMb),
      FontImportProblem.notSaved => l.fontProblemNotSaved(r.file),
    };

String _fontName(AppLocalizations l, FontChoice f) =>
    f.kind == FontKind.system ? l.fontSystemName : f.name;

String _kindText(AppLocalizations l, FontChoice f) => switch (f.kind) {
  FontKind.standard => l.fontKindStandard,
  FontKind.system => l.fontKindSystem,
  FontKind.bundled => l.fontKindBundled,
  FontKind.imported => l.fontKindImported(f.faces.length),
};

/// Estilo que dibuja el texto en [font] aunque la app use otra. La del
/// sistema no tiene nombre propio en la app: se toma de la tipografía de
/// Material para la plataforma.
TextStyle _faceOf(FontChoice font) {
  if (font.family != null) return TextStyle(fontFamily: font.family);
  final system = Typography.material2021(
    platform: defaultTargetPlatform,
  ).black.bodyMedium!;
  return TextStyle(
    fontFamily: system.fontFamily,
    fontFamilyFallback: system.fontFamilyFallback,
  );
}

/// La fuente activa en uso real: un título con el peso de los de la app y un
/// párrafo, para ver de un vistazo cómo quedan negrita y texto corrido.
class _Specimen extends StatelessWidget {
  const _Specimen({required this.font, this.onRemove});
  final FontChoice font;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final face = _faceOf(font);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: NexoTheme.bg,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: NexoTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Aa',
                style: face.copyWith(
                  fontSize: 40,
                  height: 1.1,
                  color: NexoTheme.primary,
                ),
              ),
              const Gap.h(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fontName(l, font),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: face.copyWith(
                        fontSize: AppFont.title,
                        fontWeight: FontWeight.w700,
                        color: NexoTheme.textPrimary,
                      ),
                    ),
                    Text(
                      _kindText(l, font),
                      style: TextStyle(
                        fontSize: AppFont.small,
                        color: NexoTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  tooltip: l.fontRemove(font.name),
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: NexoTheme.textSecondary,
                ),
            ],
          ),
          const Gap(AppSpacing.md),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.fontsPreviewTitle,
                  style: face.copyWith(
                    fontSize: AppFont.h2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: NexoTheme.textPrimary,
                  ),
                ),
                const Gap(AppSpacing.xxs),
                Text(
                  l.fontsPreviewBody,
                  style: face.copyWith(
                    fontSize: AppFont.body,
                    height: 1.4,
                    color: NexoTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FontTile extends StatelessWidget {
  const _FontTile({
    required this.font,
    required this.selected,
    required this.onTap,
  });
  final FontChoice font;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name = _fontName(l, font);
    final kind = _kindText(l, font);
    return Semantics(
      button: true,
      selected: selected,
      label: '$name, $kind',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.rMd,
        child: AnimatedContainer(
          duration: Motion.of(context, AppDurations.fast),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? NexoTheme.primary.withValues(alpha: 0.10)
                : NexoTheme.bg,
            borderRadius: AppRadii.rMd,
            border: Border.all(
              color: selected ? NexoTheme.primary : NexoTheme.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _faceOf(font).copyWith(
                        fontSize: AppFont.subtitle,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? NexoTheme.primary
                            : NexoTheme.textPrimary,
                      ),
                    ),
                    const Gap(AppSpacing.xxs),
                    Text(
                      kind,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFont.caption,
                        color: NexoTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  size: AppIcon.md,
                  color: NexoTheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Acción, no una opción más: va aparte de la grilla y a lo ancho, para que
/// su texto no se corte en pantallas angostas.
class _ImportButton extends StatelessWidget {
  const _ImportButton({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: '${l.fontImport}, ${l.fontImportFormats}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.rMd,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadii.rMd,
            border: Border.all(
              color: NexoTheme.primary.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: AppIcon.lg,
                child: busy
                    ? CircularProgressIndicator(
                        strokeWidth: 2,
                        color: NexoTheme.primary,
                      )
                    : Icon(
                        Icons.upload_file_rounded,
                        size: AppIcon.lg,
                        color: NexoTheme.primary,
                      ),
              ),
              const Gap.h(AppSpacing.sm),
              Expanded(
                child: Text(
                  l.fontImport,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFont.body,
                    fontWeight: FontWeight.w700,
                    color: NexoTheme.primary,
                  ),
                ),
              ),
              const Gap.h(AppSpacing.sm),
              Text(
                l.fontImportFormats,
                style: TextStyle(
                  fontSize: AppFont.caption,
                  color: NexoTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.info_outline_rounded,
            size: AppIcon.sm,
            color: NexoTheme.warning,
          ),
        ),
        const Gap.h(AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: AppFont.small,
              height: 1.4,
              color: NexoTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
