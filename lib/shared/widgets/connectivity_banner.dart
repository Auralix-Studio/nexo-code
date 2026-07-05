import 'package:flutter/material.dart';
import 'package:nexo/data/connectivity_service.dart';

class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key, required this.connectivity});
  final ConnectivityService connectivity;
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: connectivity,
      builder: (context, _) {
        final isOnline = connectivity.hasInternet;
        final sigma = connectivity.sigmaStatus;
        final intranet = connectivity.intranetStatus;
        final isFullyOnline =
            isOnline &&
            sigma == ServerStatus.online &&
            intranet == ServerStatus.online;
        if (isFullyOnline) {
          return const SizedBox.shrink();
        }
        final Color backgroundColor;
        final Color textColor;
        final IconData icon;
        final String message;
        if (!isOnline) {
          backgroundColor = const Color(0xFFFEE2E2);
          textColor = const Color(0xFF991B1B);
          icon = Icons.cloud_off_rounded;
          message = 'Sin conexión a internet. Mostrando datos locales.';
        } else if (sigma == ServerStatus.offline ||
            intranet == ServerStatus.offline) {
          backgroundColor = const Color(0xFFFEF3C7);
          textColor = const Color(0xFF92400E);
          icon = Icons.dns_rounded;
          final servers = <String>[];
          if (sigma == ServerStatus.offline) servers.add('SIGMA');
          if (intranet == ServerStatus.offline) servers.add('INTRANET');
          message =
              'Servidor ${servers.join(' y ')} fuera de línea. Copia local activa.';
        } else {
          backgroundColor = const Color(0xFFE0F2FE);
          textColor = const Color(0xFF075985);
          icon = Icons.wifi_tethering_error_rounded;
          message = 'Conexión degradada. La carga de datos puede tardar.';
        }
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: backgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: SafeArea(
            bottom: false,
            top: false,
            child: Row(
              children: [
                Icon(icon, color: textColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: textColor, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                  onPressed: () {
                    connectivity.checkNow();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
