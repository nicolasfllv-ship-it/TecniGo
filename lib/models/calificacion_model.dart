import 'package:cloud_firestore/cloud_firestore.dart';

class CalificacionModel {
  final String tecnicoId;
  final String servicioId;
  final int calificacion;
  final String comentario;
  final Timestamp fecha;

  CalificacionModel({
    required this.tecnicoId,
    required this.servicioId,
    required this.calificacion,
    required this.comentario,
    required this.fecha,
  });

  factory CalificacionModel.fromFirestore(
      Map<String, dynamic> json,
      ) {
    return CalificacionModel(
      tecnicoId: json['tecnicoId'] ?? '',
      servicioId: json['servicioId'] ?? '',
      calificacion: json['calificacion'] ?? 0,
      comentario: json['comentario'] ?? '',
      fecha: json['fecha'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tecnicoId': tecnicoId,
      'servicioId': servicioId,
      'calificacion': calificacion,
      'comentario': comentario,
      'fecha': fecha,
    };
  }
}