import 'package:flutter/material.dart';
import 'package:tecnigo/services/current_user_service.dart';
import 'package:tecnigo/theme/app_colors.dart';

class ClienteHeader extends StatefulWidget {
  const ClienteHeader({super.key});

  @override
  State<ClienteHeader> createState() => _ClienteHeaderState();
}

class _ClienteHeaderState extends State<ClienteHeader> {
  final CurrentUserService _usuario = CurrentUserService.instance;

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
  }

  Future<void> _cargarUsuario() async {
    await _usuario.cargar();

    if (mounted) {
      setState(() {});
    }
  }

  String obtenerSaludo() {
    final hora = DateTime.now().hour;

    if (hora < 12) {
      return 'Buenos días';
    } else if (hora < 18) {
      return 'Buenas tardes';
    } else {
      return 'Buenas noches';
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = (_usuario.nombre ?? '').isNotEmpty
        ? _usuario.nombre!
        : 'Usuario';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${obtenerSaludo()} 👋',
          style: const TextStyle(
            fontSize: 18,
            color: AppColors.subtitle,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          nombre,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          '¿Qué necesitas hoy?',
          style: TextStyle(
            fontSize: 18,
            color: AppColors.subtitle,
          ),
        ),
      ],
    );
  }
}