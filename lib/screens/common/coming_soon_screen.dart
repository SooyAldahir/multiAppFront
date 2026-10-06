import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/common.dart';

/// Pantalla para módulos que aún no están disponibles en la app (ya existen en el backend).
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, required this.icon, required this.tint, required this.message});

  final String title;
  final IconData icon;
  final ModuleTint tint;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ModuleIcon(icon: icon, tint: tint, large: true),
              const SizedBox(height: 20),
              const Text('Muy pronto', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
