import 'package:flutter/material.dart';
import 'package:tecnigo/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CalificarTecnicoScreen extends StatefulWidget {
  final String servicioId;
  final String tecnicoId;

  const CalificarTecnicoScreen({
    super.key,
    required this.servicioId,
    required this.tecnicoId,
  });

  @override
  State<CalificarTecnicoScreen> createState() =>
      _CalificarTecnicoScreenState();
}

class _CalificarTecnicoScreenState extends State<CalificarTecnicoScreen> {
  int calificacion = 5;
  bool enviando = false;

  final comentarioController = TextEditingController();

  Future<void> enviarCalificacion() async {
    // Evita doble envío si le dan varias veces al botón.
    if (enviando) return;

    setState(() => enviando = true);

    try {
      // Guardar la calificación
      await FirebaseFirestore.instance.collection('calificaciones').add({
        'tecnicoId': widget.tecnicoId,
        'servicioId': widget.servicioId,
        'calificacion': calificacion,
        'comentario': comentarioController.text.trim(),
        'fecha': Timestamp.now(),
      });

      // Marcar el servicio como calificado
      await FirebaseFirestore.instance
          .collection('servicios')
          .doc(widget.servicioId)
          .update({
        'calificado': true,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Gracias por tu calificación!'),
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

  Widget estrella(int numero) {
    return IconButton(
      onPressed: enviando
          ? null
          : () {
              setState(() {
                calificacion = numero;
              });
            },
      icon: Icon(
        numero <= calificacion
            ? Icons.star
            : Icons.star_border,
        color: Colors.amber,
        size: 40,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Mientras se está enviando la calificación, bloqueamos el botón
      // de "atrás" (físico o gesto) para que no se salga a medias y
      // deje la app en un estado raro.
      canPop: !enviando,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && enviando) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Espera un momento, se está enviando...'),
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Calificar técnico"),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                "¿Cómo fue el servicio?",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  estrella(1),
                  estrella(2),
                  estrella(3),
                  estrella(4),
                  estrella(5),
                ],
              ),
              const SizedBox(height: 30),
              TextField(
                controller: comentarioController,
                maxLines: 4,
                enabled: !enviando,
                decoration: const InputDecoration(
                  labelText: "Comentario (opcional)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: enviando ? null : enviarCalificacion,
                  child: enviando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppColors.background,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text("Enviar calificación"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}