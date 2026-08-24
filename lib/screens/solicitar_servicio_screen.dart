import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tecnigo/theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tecnigo/widgets/categoria_card.dart';
import 'direccion_picker_screen.dart';

class SolicitarServicioScreen extends StatefulWidget {
  final String? tipoInicial;

  const SolicitarServicioScreen({super.key, this.tipoInicial});

  @override
  State<SolicitarServicioScreen> createState() =>
      _SolicitarServicioScreenState();
}

class _SolicitarServicioScreenState
    extends State<SolicitarServicioScreen> {
  final descripcionController = TextEditingController();

  late String tipoServicio;
  bool enviando = false;

  UbicacionElegida? _ubicacion;

  @override
  void initState() {
    super.initState();
    tipoServicio = widget.tipoInicial ?? "Cámaras de seguridad";
  }

  @override
  void dispose() {
    descripcionController.dispose();
    super.dispose();
  }

  // Las mismas 6 categorías que se muestran en el Home, para que el
  // cliente pueda elegir cualquiera de ellas también aquí.
  final categorias = const [
    ("Cámaras de seguridad", "Cámaras de seguridad",
        "Instalación y mantenimiento de CCTV",
        Icons.videocam, Colors.blue),
    ("Domótica", "Domótica",
        "Automatización del hogar u oficina",
        Icons.home, Colors.green),
    ("Control de acceso", "Control de acceso",
        "Peatonal y vehicular",
        Icons.vpn_key, Colors.orange),
    ("Puertas y portones", "Puertas y portones",
        "Instalación y mantenimiento",
        Icons.garage, Colors.purple),
    ("Energía solar", "Energía solar",
        "Paneles solares y soluciones renovables",
        Icons.wb_sunny, Colors.teal),
    ("Cercas eléctricas", "Cercas eléctricas",
        "Seguridad perimetral",
        Icons.security, Colors.lightBlue),
    ("Cerrajería", "Cerrajería",
        "Cerraduras y cerraduras inteligentes",
        Icons.key, Colors.brown),
  ];

  Future<void> _elegirUbicacion() async {
    final resultado = await Navigator.push<UbicacionElegida>(
      context,
      MaterialPageRoute(builder: (_) => const DireccionPickerScreen()),
    );

    if (resultado != null) {
      setState(() => _ubicacion = resultado);
    }
  }

  Future<void> crearServicio() async {
    if (_ubicacion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige la ubicación del servicio')),
      );
      return;
    }

    setState(() => enviando = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      // No dejamos pedir un servicio nuevo si ya tiene uno activo
      // (pendiente o en curso), para evitar solicitudes duplicadas.
      final activos = await FirebaseFirestore.instance
          .collection('servicios')
          .where('clienteId', isEqualTo: user.uid)
          .where('estado',
              whereIn: ['pendiente', 'aceptado', 'en camino', 'trabajando'])
          .limit(1)
          .get();

      if (activos.docs.isNotEmpty) {
        throw Exception(
          'Ya tienes un servicio activo. Espera a que termine antes '
          'de pedir otro.',
        );
      }

      await FirebaseFirestore.instance.collection("servicios").add({
        "clienteId": user.uid,
        "emailCliente": user.email,
        "tipoServicio": tipoServicio,
        "descripcion": descripcionController.text.trim(),
        "direccion": _ubicacion!.direccion,
        "estado": "pendiente",
        "fecha": Timestamp.now(),
        "lat": _ubicacion!.lat,
        "lng": _ubicacion!.lng,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Solicitud creada correctamente"),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
        ),
      );
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Solicitar servicio"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Text(
              "¿Qué servicio necesitas?",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            ...categorias.map(
              (c) => CategoriaCard(
                titulo: c.$2,
                subtitulo: c.$3,
                icono: c.$4,
                color: c.$5,
                seleccionado: tipoServicio == c.$1,
                onTap: () {
                  setState(() {
                    tipoServicio = c.$1;
                  });
                },
              ),
            ),

            const SizedBox(height: 25),

            Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _elegirUbicacion,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: AppColors.clienteAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _ubicacion?.direccion ??
                              'Toca para elegir la ubicación',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _ubicacion == null
                                ? AppColors.subtitle
                                : AppColors.text,
                            fontWeight: _ubicacion == null
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.subtitle),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: descripcionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Describe el problema",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: enviando ? null : crearServicio,
                child: enviando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: AppColors.background,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        "Enviar solicitud",
                        style: TextStyle(fontSize: 18),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}