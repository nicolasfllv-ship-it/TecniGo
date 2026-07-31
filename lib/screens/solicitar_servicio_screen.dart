import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tecnigo/widgets/categoria_card.dart';

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

  @override
  void initState() {
    super.initState();
    tipoServicio = widget.tipoInicial ?? "Cámaras de seguridad";
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

  Future<void> crearServicio() async {
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

      bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception("El GPS está desactivado");
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception("Permiso de ubicación denegado");
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          "Activa el permiso de ubicación desde Configuración.",
        );
      }

      Position position;
      try {
        // Precisión media (más rápida) y con límite de 10 segundos:
        // si no consigue GPS en ese tiempo, no dejamos al cliente
        // esperando indefinidamente.
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        );
      } on TimeoutException {
        // Si se agotó el tiempo, intentamos usar la última ubicación
        // conocida del celular en vez de fallar por completo.
        // (Ojo: getLastKnownPosition no existe en la versión web,
        // así que ahí simplemente no hay respaldo posible).
        Position? ultima;
        try {
          ultima = await Geolocator.getLastKnownPosition();
        } catch (_) {
          ultima = null;
        }

        if (ultima == null) {
          throw Exception(
            "No se pudo obtener tu ubicación. Verifica que el GPS/"
            "ubicación esté activado e intenta de nuevo.",
          );
        }
        position = ultima;
      }

      await FirebaseFirestore.instance.collection("servicios").add({
        "clienteId": user.uid,
        "emailCliente": user.email,
        "tipoServicio": tipoServicio,
        "descripcion": descripcionController.text.trim(),
        "estado": "pendiente",
        "fecha": Timestamp.now(),
        "lat": position.latitude,
        "lng": position.longitude,
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
                          color: Colors.white,
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