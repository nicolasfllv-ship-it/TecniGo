// Tiempo estimado (en minutos) que suele tardar cada tipo de servicio.
// Esto es un valor de referencia inicial: más adelante se puede volver
// dinámico (por ejemplo, que lo ajuste el técnico según cada caso).
class ServicioDuraciones {
  static const Map<String, int> minutosPorTipo = {
    'Cámaras de seguridad': 90,
    'Domótica': 120,
    'Control de acceso': 90,
    'Puertas y portones': 60,
    'Energía solar': 180,
    'Cercas eléctricas': 90,
    'Cerrajería': 45,
  };

  static int minutosEstimados(String tipoServicio) {
    return minutosPorTipo[tipoServicio] ?? 40;
  }
}