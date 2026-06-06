import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/storage.dart';

const whatsappChannelUrl =
    'https://whatsapp.com/channel/0029VbDh4pf2ZjCfpiccSj3Y';
const whatsappGreen = Color(0xFF25D366);

Future<void> openWhatsappChannel() => launchUrl(
      Uri.parse(whatsappChannelUrl),
      mode: LaunchMode.externalApplication,
    );

/// Muestra el invite del canal de WhatsApp si el usuario no lo ha visto.
/// Se marca como visto en cuanto se cierra el diálogo (no importa el botón).
Future<void> maybeShowWhatsappInvite(BuildContext context) async {
  if (AppStorage.instance.seenWhatsappInvite) return;
  await AppStorage.instance.setSeenWhatsappInvite(true);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _WhatsappInviteDialog(),
  );
}

class _WhatsappInviteDialog extends StatelessWidget {
  const _WhatsappInviteDialog();

  Future<void> _open(BuildContext context) async {
    await openWhatsappChannel();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: NexoTheme.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: whatsappGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: whatsappGreen.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: whatsappGreen.withValues(alpha: 0.12),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Icon(Icons.campaign_rounded,
                    size: 28, color: whatsappGreen),
              ),
              const SizedBox(height: 16),
              Text(
                'Únete al canal de Nexo',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: NexoTheme.textPrimary,
                  letterSpacing: -0.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Sigue el canal de WhatsApp para enterarte de novedades, '
                'mejoras y avisos importantes sobre Nexo.',
                style: TextStyle(
                  fontSize: 12,
                  color: NexoTheme.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _open(context),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Seguir canal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: whatsappGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: NexoTheme.textMuted,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Ahora no'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
