class UsuarioModel {
  final String uid;
  final String nombre;
  final String email;
  final String rol;

  UsuarioModel({
    required this.uid,
    required this.nombre,
    required this.email,
    required this.rol,
  });

  factory UsuarioModel.fromFirestore(Map<String, dynamic> json) {
    return UsuarioModel(
      uid: json['uid'] ?? '',
      nombre: json['nombre'] ?? '',
      email: json['email'] ?? '',
      rol: json['rol'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nombre': nombre,
      'email': email,
      'rol': rol,
    };
  }
}