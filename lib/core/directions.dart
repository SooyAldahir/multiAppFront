import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/common.dart';
import 'theme.dart';

/// Muestra las apps de navegación disponibles y abre la ruta hacia el destino.
/// La navegación paso a paso la hace Google Maps, Waze o Apple Maps.
Future<void> showDirections(BuildContext context, {required double lat, required double lon, required String label}) async {
  final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  final options = <(String, IconData, Uri)>[
    (
      'Google Maps',
      Icons.map_outlined,
      Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': '$lat,$lon'}),
    ),
    (
      'Waze',
      Icons.navigation_outlined,
      Uri.https('waze.com', '/ul', {'ll': '$lat,$lon', 'navigate': 'yes'}),
    ),
    if (isIOS)
      (
        'Apple Maps',
        Icons.explore_outlined,
        Uri.https('maps.apple.com', '/', {'daddr': '$lat,$lon', 'q': label}),
      ),
  ];

  final uri = await showModalBottomSheet<Uri>(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CÓMO LLEGAR', style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            for (final (name, icon, link) in options)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(icon, color: AppColors.primary),
                title: Text('Abrir en $name', style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(context, link),
              ),
          ],
        ),
      ),
    ),
  );
  if (uri == null) return;

  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showMessage(context, 'No se pudo abrir la app de mapas', error: true);
}
