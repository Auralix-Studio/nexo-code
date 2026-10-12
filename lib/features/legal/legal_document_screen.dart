import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexo/core/config.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/widgets/empty_state.dart';

/// Documentos legales completos. Viven como texto en `assets/legal/` (uno por
/// idioma) para que se puedan revisar y versionar fuera del código.
enum LegalDoc {
  terms('terminos'),
  privacy('privacidad'),
  cookies('cookies');

  const LegalDoc(this.file);
  final String file;

  String title(AppLocalizations l) => switch (this) {
    LegalDoc.terms => l.legalTermsTitle,
    LegalDoc.privacy => l.legalPrivacyTitle,
    LegalDoc.cookies => l.legalCookiesTitle,
  };

  String subtitle(AppLocalizations l) => switch (this) {
    LegalDoc.terms => l.legalTermsSubtitle,
    LegalDoc.privacy => l.legalPrivacySubtitle,
    LegalDoc.cookies => l.legalCookiesSubtitle,
  };

  IconData get icon => switch (this) {
    LegalDoc.terms => Icons.gavel_outlined,
    LegalDoc.privacy => Icons.lock_outline,
    LegalDoc.cookies => Icons.storage_outlined,
  };

  /// Texto en el idioma pedido; si no existe, el español.
  Future<String> load(String languageCode) async {
    try {
      return await rootBundle.loadString(
        'assets/legal/${file}_$languageCode.md',
      );
    } catch (_) {
      return rootBundle.loadString('assets/legal/${file}_es.md');
    }
  }
}

sealed class LegalBlock {
  const LegalBlock(this.text);
  final String text;
}

class LegalTitle extends LegalBlock {
  const LegalTitle(super.text);
}

class LegalHeading extends LegalBlock {
  const LegalHeading(super.text);
}

class LegalParagraph extends LegalBlock {
  const LegalParagraph(super.text);
}

class LegalBullet extends LegalBlock {
  const LegalBullet(super.text);
}

/// Markdown mínimo de los documentos: `#` título, `##` sección, `- ` viñeta
/// y párrafos separados por una línea en blanco.
List<LegalBlock> parseLegalText(String src) {
  final out = <LegalBlock>[];
  final para = <String>[];
  void flush() {
    if (para.isNotEmpty) out.add(LegalParagraph(para.join(' ')));
    para.clear();
  }

  for (final raw in src.replaceAll('\r\n', '\n').split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) {
      flush();
    } else if (line.startsWith('## ')) {
      flush();
      out.add(LegalHeading(line.substring(3).trim()));
    } else if (line.startsWith('# ')) {
      flush();
      out.add(LegalTitle(line.substring(2).trim()));
    } else if (line.startsWith('- ')) {
      flush();
      out.add(LegalBullet(line.substring(2).trim()));
    } else {
      para.add(line);
    }
  }
  flush();
  return out;
}

/// `**negrita**` dentro de un párrafo.
List<TextSpan> legalSpans(String text, TextStyle bold) {
  final parts = text.split('**');
  return [
    for (var i = 0; i < parts.length; i++)
      if (parts[i].isNotEmpty)
        TextSpan(text: parts[i], style: i.isOdd ? bold : null),
  ];
}

class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({super.key, required this.doc});
  final LegalDoc doc;

  static Future<void> open(BuildContext context, LegalDoc doc) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => LegalDocumentScreen(doc: doc)),
      );

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  Future<String>? _text;
  String? _lang;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Se vuelve a leer solo si cambia el idioma, no en cada reconstrucción.
    final lang = Localizations.localeOf(context).languageCode;
    if (lang != _lang) {
      _lang = lang;
      _text = widget.doc.load(lang);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: NexoTheme.bg,
      appBar: AppBar(title: Text(widget.doc.title(l))),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _text,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || (snap.data ?? '').trim().isEmpty) {
              return Center(
                child: EmptyState(
                  icon: Icons.description_outlined,
                  title: l.legalLoadError,
                ),
              );
            }
            return _Body(blocks: parseLegalText(snap.data!));
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final List<LegalBlock> blocks;
  const _Body({required this.blocks});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final body = TextStyle(
      fontSize: AppFont.body,
      height: 1.55,
      color: NexoTheme.textSecondary,
    );
    final bold = TextStyle(
      fontWeight: FontWeight.w700,
      color: NexoTheme.textPrimary,
    );
    final version = l.termsVersionLine(
      '${LegalTerms.version}',
      MaterialLocalizations.of(context).formatFullDate(LegalTerms.updatedAt),
    );
    return SelectionArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.xl,
              AppSpacing.xxl,
              AppSpacing.huge,
            ),
            children: [
              for (final b in blocks)
                switch (b) {
                  // La versión y su fecha de vigencia van al inicio, como
                  // dicen los propios Términos.
                  LegalTitle() => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.text,
                        style: TextStyle(
                          fontSize: AppFont.h2,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          color: NexoTheme.textPrimary,
                        ),
                      ),
                      const Gap(AppSpacing.xs),
                      Text(
                        version,
                        style: TextStyle(
                          fontSize: AppFont.small,
                          color: NexoTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  LegalHeading() => Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.xl,
                      bottom: AppSpacing.sm,
                    ),
                    child: Text(
                      b.text,
                      style: TextStyle(
                        fontSize: AppFont.title,
                        fontWeight: FontWeight.w800,
                        color: NexoTheme.textPrimary,
                      ),
                    ),
                  ),
                  LegalParagraph() => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text.rich(
                      TextSpan(children: legalSpans(b.text, bold)),
                      style: body,
                    ),
                  ),
                  LegalBullet() => Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 9),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: NexoTheme.textMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const Gap.h(AppSpacing.md),
                        Expanded(
                          child: Text.rich(
                            TextSpan(children: legalSpans(b.text, bold)),
                            style: body,
                          ),
                        ),
                      ],
                    ),
                  ),
                },
            ],
          ),
        ),
      ),
    );
  }
}
