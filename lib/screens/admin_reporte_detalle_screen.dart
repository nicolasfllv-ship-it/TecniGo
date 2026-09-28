import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tecnigo/theme/app_colors.dart';

class AdminReporteDetalleScreen extends StatefulWidget {
  final String servicioId;

  const AdminReporteDetalleScreen({
    super.key,
    required this.servicioId,
  });

  @override
  State<AdminReporteDetalleScreen> createState() =>
      _AdminReporteDetalleScreenState();
}

class _AdminReporteDetalleScreenState extends State<AdminReporteDetalleScreen> {
  bool _esAdmin = false;
  bool _guardando = false;
  String? _estadoRevisionSeleccionado;
  final TextEditingController _notaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _verificarAdmin();
  }

  @override
  void dispose() {
    _notaController.dispose();
    super.dispose();
  }

  Future<void> _verificarAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _esAdmin = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final esAdmin = (doc.data()?['rol'] ?? '').toString() == 'admin';
      if (mounted) setState(() => _esAdmin = esAdmin);
    } catch (e) {
      if (mounted) setState(() => _esAdmin = false);
    }
  }

  Future<void> _guardarRevision() async {
    if (_guardando) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay usuario autenticado')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      await FirebaseFirestore.instance
          .collection('servicios')
          .doc(widget.servicioId)
          .update({
        'estadoRevision': _estadoRevisionSeleccionado ?? 'pendiente',
        'notaAdmin': _notaController.text.trim(),
        'fechaRevision': Timestamp.now(),
        'adminId': user.uid,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisión guardada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del reporte')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('servicios')
            .doc(widget.servicioId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo cargar el reporte:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return const Center(child: Text('Este servicio ya no existe.'));
          }

          final datos = snapshot.data!.data()!;

          if (_esAdmin && _estadoRevisionSeleccionado == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_estadoRevisionSeleccionado == null && mounted) {
                setState(() {
                  _estadoRevisionSeleccionado =
                      (datos['estadoRevision'] ?? 'pendiente').toString();
                  _notaController.text =
                      (datos['notaAdmin'] ?? '').toString();
                });
              }
            });
          }

          final clienteId = (datos['clienteId'] ?? '').toString();
          final tecnicoId = (datos['tecnicoId'] ?? '').toString();

          return FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
            future: _leerUsuarios(clienteId, tecnicoId),
            builder: (context, userSnapshot) {
              Map<String, dynamic>? clienteData;
              Map<String, dynamic>? tecnicoData;

              if (userSnapshot.hasData) {
                final results = userSnapshot.data!;
                if (results.isNotEmpty) clienteData = results[0].data();
                if (results.length > 1) tecnicoData = results[1].data();
              }

              final clienteNombre = _textoORespaldo(
                clienteData?['nombre'],
                (datos['emailCliente'] ?? 'Sin email').toString(),
              );
              final clienteEmail = _textoORespaldo(
                clienteData?['email'],
                datos['emailCliente'],
              );
              final clienteUid = _textoORespaldo(
                clienteData?['uid'],
                clienteId,
              );

              String tecnicoNombre = 'Sin asignar';
              String tecnicoEmail = 'Sin asignar';
              String tecnicoUid = 'Sin asignar';

              if (tecnicoId.isNotEmpty) {
                tecnicoNombre = _textoORespaldo(
                  tecnicoData?['nombre'],
                  (datos['tecnicoEmail'] ?? 'Sin email').toString(),
                );
                tecnicoEmail = _textoORespaldo(
                  tecnicoData?['email'],
                  datos['tecnicoEmail'],
                );
                tecnicoUid = _textoORespaldo(tecnicoData?['uid'], tecnicoId);
              }

              final estado = (datos['estado'] ?? '').toString();
              final estadoColor = _colorEstado(estado);

              final widgets = <Widget>[
                _Seccion(titulo: 'Servicio'),
                _DetalleFila(
                  etiqueta: 'Tipo',
                  valor: _textoORespaldo(datos['tipoServicio'], 'Sin tipo'),
                ),
                _DetalleFila(
                  etiqueta: 'Descripción',
                  valor: _textoORespaldo(
                    datos['descripcion'],
                    'Sin descripción',
                  ),
                ),
                _DetalleFila(
                  etiqueta: 'Dirección',
                  valor: _textoORespaldo(datos['direccion'], 'Sin dirección'),
                ),
                _DetalleFila(
                  etiqueta: 'ID',
                  valor: widget.servicioId,
                  fontFamily: 'monospace',
                ),

                const SizedBox(height: 22),
                _Seccion(titulo: 'Fechas'),
                _DetalleFila(
                  etiqueta: 'Creación',
                  valor: _fechaLegible(datos['fecha']),
                ),
                if (datos.containsKey('fechaAceptacion') &&
                    datos['fechaAceptacion'] != null)
                  _DetalleFila(
                    etiqueta: 'Aceptación',
                    valor: _fechaLegible(datos['fechaAceptacion']),
                  ),
                if (datos.containsKey('fechaFinalizacion') &&
                    datos['fechaFinalizacion'] != null)
                  _DetalleFila(
                    etiqueta: 'Finalización',
                    valor: _fechaLegible(datos['fechaFinalizacion']),
                  ),
                _DetalleFila(
                  etiqueta: 'Reporte',
                  valor: _fechaLegible(datos['fechaReporte']),
                ),

                const SizedBox(height: 22),
                _Seccion(titulo: 'Cliente'),
                _DetalleFila(etiqueta: 'Nombre', valor: clienteNombre),
                _DetalleFila(
                  etiqueta: 'Correo',
                  valor: _textoORespaldo(clienteEmail, 'Sin correo'),
                ),
                _DetalleFila(
                  etiqueta: 'UID',
                  valor: clienteUid,
                  fontFamily: 'monospace',
                ),

                if (tecnicoId.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _Seccion(titulo: 'Técnico'),
                  _DetalleFila(etiqueta: 'Nombre', valor: tecnicoNombre),
                  _DetalleFila(
                    etiqueta: 'Correo',
                    valor: _textoORespaldo(tecnicoEmail, 'Sin correo'),
                  ),
                  _DetalleFila(
                    etiqueta: 'UID',
                    valor: tecnicoUid,
                    fontFamily: 'monospace',
                  ),

                  const SizedBox(height: 22),
                  _Seccion(titulo: 'Ubicación'),
                  if (datos.containsKey('lat') && datos.containsKey('lng')) ...[
                    _DetalleFila(
                      etiqueta: 'Latitud',
                      valor: _coordenadaLegible(datos['lat']),
                    ),
                    _DetalleFila(
                      etiqueta: 'Longitud',
                      valor: _coordenadaLegible(datos['lng']),
                    ),
                  ] else ...[
                    _DetalleFila(
                      etiqueta: 'Latitud',
                      valor: 'No disponible',
                    ),
                    _DetalleFila(
                      etiqueta: 'Longitud',
                      valor: 'No disponible',
                    ),
                  ],
                ],

                const SizedBox(height: 22),
                _Seccion(titulo: 'Reporte'),
                _DetalleFila(
                  etiqueta: 'Motivo',
                  valor: _textoORespaldo(
                    datos['motivoReporte'],
                    'Sin motivo',
                  ),
                ),
                _DetalleFila(
                  etiqueta: 'Estado actual',
                  valor: _estadoLegible(estado),
                  valorColor: estadoColor,
                  valorFontWeight: FontWeight.w600,
                ),
                _DetalleFila(
                  etiqueta: 'Calificado',
                  valor: datos['calificado'] == true ? 'Sí' : 'No',
                ),
                _DetalleFila(
                  etiqueta: 'Confirmado por cliente',
                  valor: datos['confirmadoCliente'] == true ? 'Sí' : 'No',
                ),

                const SizedBox(height: 22),
                _Seccion(titulo: 'Revisión administrativa'),
                _DetalleFila(
                  etiqueta: 'Estado de revisión',
                  valor: _estadoRevisionLegible(
                    (datos['estadoRevision'] ?? '').toString(),
                  ),
                  valorColor: _colorEstadoRevision(
                    (datos['estadoRevision'] ?? '').toString(),
                  ),
                  valorFontWeight: FontWeight.w600,
                ),
                _DetalleFila(
                  etiqueta: 'Nota del administrador',
                  valor: _textoORespaldo(datos['notaAdmin'], 'Sin nota'),
                ),
                _DetalleFila(
                  etiqueta: 'Fecha de revisión',
                  valor: _fechaLegible(datos['fechaRevision']),
                ),
                _DetalleFila(
                  etiqueta: 'Administrador',
                  valor: _textoORespaldo(datos['adminId'], 'No asignado'),
                  fontFamily: 'monospace',
                ),
              ];

              if (_esAdmin) {
                if (_estadoRevisionSeleccionado == null) {
                  widgets.add(
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                } else {
                  widgets.addAll([
                    const SizedBox(height: 22),
                    _Seccion(titulo: 'Editar revisión'),
                    DropdownButtonFormField<String>(
                      initialValue: _estadoRevisionSeleccionado,
                      decoration: const InputDecoration(
                        labelText: 'Estado de revisión',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'pendiente',
                          child: Text('Pendiente'),
                        ),
                        DropdownMenuItem(
                          value: 'revisado',
                          child: Text('Revisado'),
                        ),
                        DropdownMenuItem(
                          value: 'resuelto',
                          child: Text('Resuelto'),
                        ),
                        DropdownMenuItem(
                          value: 'descartado',
                          child: Text('Descartado'),
                        ),
                      ],
                      onChanged: _guardando
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() {
                                  _estadoRevisionSeleccionado = value;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _notaController,
                      maxLines: 4,
                      enabled: !_guardando,
                      decoration: const InputDecoration(
                        labelText: 'Nota del administrador',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _guardando ? null : _guardarRevision,
                        child: _guardando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Guardar revisión'),
                      ),
                    ),
                  ]);
                }
              }

              return ListView(
                padding: const EdgeInsets.all(20),
                children: widgets,
              );
            },
          );
        },
      ),
    );
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> _leerUsuarios(
    String clienteId,
    String tecnicoId,
  ) async {
    final futures = <Future<DocumentSnapshot<Map<String, dynamic>>>>[];
    futures.add(
      FirebaseFirestore.instance.collection('users').doc(clienteId).get(),
    );
    if (tecnicoId.isNotEmpty) {
      futures.add(
        FirebaseFirestore.instance.collection('users').doc(tecnicoId).get(),
      );
    }
    return Future.wait(futures);
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return AppColors.accent;
      case 'aceptado':
        return AppColors.clienteAccent;
      case 'en camino':
        return AppColors.clienteAccent;
      case 'trabajando':
        return AppColors.tecnicoAccent;
      case 'finalizado':
        return AppColors.success;
      case 'cancelado':
        return AppColors.error;
      default:
        return AppColors.subtitle;
    }
  }

  String _estadoLegible(String estado) {
    switch (estado) {
      case 'pendiente':
        return 'Pendiente';
      case 'aceptado':
        return 'Aceptado';
      case 'en camino':
        return 'En camino';
      case 'trabajando':
        return 'Trabajando';
      case 'finalizado':
        return 'Finalizado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return estado.isEmpty ? 'Desconocido' : estado;
    }
  }

  String _fechaLegible(dynamic valor) {
    DateTime? fecha;
    if (valor is Timestamp) {
      fecha = valor.toDate();
    } else if (valor is DateTime) {
      fecha = valor;
    }

    if (fecha == null) {
      return valor == null ? 'No disponible' : valor.toString();
    }

    String dosDigitos(int numero) => numero.toString().padLeft(2, '0');
    return '${dosDigitos(fecha.day)}/${dosDigitos(fecha.month)}/${fecha.year} '
        '${dosDigitos(fecha.hour)}:${dosDigitos(fecha.minute)}';
  }

  String _coordenadaLegible(dynamic valor) {
    if (valor is num) return valor.toDouble().toStringAsFixed(6);
    return _textoORespaldo(valor, 'No disponible');
  }

  String _textoORespaldo(dynamic valor, String respaldo) {
    final texto = (valor ?? '').toString().trim();
    return texto.isEmpty ? respaldo : texto;
  }

  Color _colorEstadoRevision(String estado) {
    switch (estado) {
      case 'pendiente':
        return AppColors.accent;
      case 'revisado':
        return AppColors.clienteAccent;
      case 'resuelto':
        return AppColors.success;
      case 'descartado':
        return AppColors.error;
      default:
        return AppColors.subtitle;
    }
  }

  String _estadoRevisionLegible(String estado) {
    switch (estado) {
      case 'pendiente':
        return 'Pendiente';
      case 'revisado':
        return 'Revisado';
      case 'resuelto':
        return 'Resuelto';
      case 'descartado':
        return 'Descartado';
      default:
        return estado.isEmpty ? 'Pendiente' : estado;
    }
  }
}

class _Seccion extends StatelessWidget {
  final String titulo;

  const _Seccion({required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        titulo,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _DetalleFila extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final Color? valorColor;
  final FontWeight? valorFontWeight;
  final String? fontFamily;

  const _DetalleFila({
    required this.etiqueta,
    required this.valor,
    this.valorColor,
    this.valorFontWeight,
    this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: const TextStyle(
              color: AppColors.subtitle,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            valor,
            style: TextStyle(
              color: valorColor,
              fontWeight: valorFontWeight,
              fontFamily: fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
