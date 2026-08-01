import 'package:flutter/material.dart';
import 'package:tecnigo/theme/app_colors.dart';

/// Esquinas tipo "mira de cámara de seguridad" — el detalle de firma
/// visual de la app. Envuelve cualquier widget y le dibuja 4 esquinas
/// en forma de L en las puntas, como el visor de una cámara CCTV.
class ScannerFrame extends StatelessWidget {
  final Widget child;
  final Color color;
  final double tamano;
  final double grosor;

  const ScannerFrame({
    super.key,
    required this.child,
    this.color = AppColors.primary,
    this.tamano = 22,
    this.grosor = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,

        // Esquina superior izquierda
        Positioned(
          top: 0,
          left: 0,
          child: _esquina(topLeft: true),
        ),
        // Esquina superior derecha
        Positioned(
          top: 0,
          right: 0,
          child: Transform.flip(
            flipX: true,
            child: _esquina(topLeft: true),
          ),
        ),
        // Esquina inferior izquierda
        Positioned(
          bottom: 0,
          left: 0,
          child: Transform.flip(
            flipY: true,
            child: _esquina(topLeft: true),
          ),
        ),
        // Esquina inferior derecha
        Positioned(
          bottom: 0,
          right: 0,
          child: Transform.flip(
            flipX: true,
            flipY: true,
            child: _esquina(topLeft: true),
          ),
        ),
      ],
    );
  }

  Widget _esquina({required bool topLeft}) {
    return SizedBox(
      width: tamano,
      height: tamano,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: tamano, height: grosor, color: color),
          Expanded(
            child: Row(
              children: [
                Container(width: grosor, height: double.infinity, color: color),
              ],
            ),
          ),
        ],
      ),
    );
  }
}