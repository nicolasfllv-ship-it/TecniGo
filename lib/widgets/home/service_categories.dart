import 'package:flutter/material.dart';
import 'package:tecnigo/theme/app_colors.dart';
import 'package:tecnigo/screens/solicitar_servicio_screen.dart';

class ServiceCategories extends StatelessWidget {
  const ServiceCategories({super.key});

  @override
  Widget build(BuildContext context) {
    // El primer valor de cada tupla es el que se guarda como
    // "tipoServicio" en la base de datos (debe coincidir con las
    // categorías de solicitar_servicio_screen.dart).
    final servicios = [
      (Icons.videocam, "Cámaras de seguridad", "Cámaras de seguridad"),
      (Icons.home, "Domótica", "Domótica"),
      (Icons.vpn_key, "Control de acceso", "Control de acceso"),
      (Icons.garage, "Puertas y portones", "Puertas y portones"),
      (Icons.security, "Cercas eléctricas", "Cercas eléctricas"),
      (Icons.key, "Cerrajería", "Cerrajería"),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Servicios populares",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 15),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: servicios.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemBuilder: (_, index) {
            final servicio = servicios[index];

            return Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SolicitarServicioScreen(
                        tipoInicial: servicio.$3,
                      ),
                    ),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      servicio.$1,
                      color: AppColors.primary,
                      size: 34,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      servicio.$2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}