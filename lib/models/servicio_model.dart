class ServicioModel {
  final String id;
  final String clienteId;
  final String emailCliente;
  final String tipoServicio;
  final String descripcion;
  final String estado;
  final double lat;
  final double lng;

  ServicioModel({
    required this.id,
    required this.clienteId,
    required this.emailCliente,
    required this.tipoServicio,
    required this.descripcion,
    required this.estado,
    required this.lat,
    required this.lng,
  });

  factory ServicioModel.fromFirestore(
      String id,
      Map<String, dynamic> json,
      ) {
    return ServicioModel(
      id: id,
      clienteId: json['clienteId'] ?? '',
      emailCliente: json['emailCliente'] ?? '',
      tipoServicio: json['tipoServicio'] ?? '',
      descripcion: json['descripcion'] ?? '',
      estado: json['estado'] ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clienteId': clienteId,
      'emailCliente': emailCliente,
      'tipoServicio': tipoServicio,
      'descripcion': descripcion,
      'estado': estado,
      'lat': lat,
      'lng': lng,
    };
  }
}