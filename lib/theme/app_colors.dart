import 'package:flutter/material.dart';

class AppColors {
  // Fondo principal: gris carbón muy oscuro, casi neutro.
  static const Color background = Color(0xFF121418);

  // Tarjetas: gris pizarra neutro, con más contraste frente al fondo.
  static const Color surface = Color(0xFF1E222A);

  // Color principal: plateado/blanco, aire de metal pulido.
  // Se sigue usando en pantallas neutras (login, registro, dashboard admin).
  static const Color primary = Color(0xFFE5E9F0);

  // Color de alerta / estado pendiente.
  static const Color accent = Color(0xFFF5A623);

  // Acentos por rol: cada lado de la app tiene su propio color,
  // manteniendo el mismo fondo oscuro y tipografía en ambos.
  static const Color clienteAccent = Color(0xFF4C8DFF); // azul
  static const Color tecnicoAccent = Color(0xFF34D399); // verde (= success)

  // Texto
  static const Color text = Color(0xFFF1F5F9);

  // Texto secundario
  static const Color subtitle = Color(0xFF9AA3AF);

  // Estados
  static const Color success = Color(0xFF34D399);
  static const Color error = Color(0xFFF87171);

  // Bordes
  static const Color border = Color(0xFF2E333C);
}