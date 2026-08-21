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
  final motivoController = TextEditingController();

  // null = todavía no responde si el servicio se hizo o no.
  // true = sí se hizo (sigue al flujo normal de calificar).
  // false = hubo un problema (pide describirlo, no muestra estrellas).
  bool? _seHizoElServicio;

  @override
  void dispose() {
    comentarioController.dispose();
    motivoController.dispose();
    super.dispose();
  }

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

      // Marcar el servicio como calificado y confirmado por el cliente.
      await FirebaseFirestore.instance
          .collection('servicios')
          .doc(widget.servicioId)
          .update({
        'calificado': true,
        'confirmadoCliente': true,
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

  Future<void> enviarReporte() async {
    if (enviando) return;

    if (motivoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuéntanos brevemente qué pasó')),
      );
      return;
    }

    setState(() => enviando = true);

    try {
      // No se crea una calificación de estrellas: se marca el servicio
      // como reportado, para que quede pendiente de revisión del admin.
      await FirebaseFirestore.instance
          .collection('servicios')
          .doc(widget.servicioId)
          .update({
        'calificado': true,
        'confirmadoCliente': false,
        'reportado': true,
        'motivoReporte': motivoController.text.trim(),
        'fechaReporte': Timestamp.now(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gracias, vamos a revisar lo que pasó'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
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

  Widget _pasoConfirmar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "¿El técnico realizó el servicio?",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Antes de calificar, confírmanos que el trabajo se hizo.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.subtitle),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Sí, todo bien'),
            onPressed: () => setState(() => _seHizoElServicio = true),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            icon: const Icon(Icons.report_problem_outlined),
            label: const Text('No, hubo un problema'),
            onPressed: () => setState(() => _seHizoElServicio = false),
          ),
        ),
      ],
    );
  }

  Widget _pasoCalificar() {
    return Column(
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
    );
  }

  Widget _pasoReportarProblema() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.report_problem_outlined,
            color: AppColors.error, size: 42),
        const SizedBox(height: 14),
        const Text(
          "Cuéntanos qué pasó",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Vamos a revisar el servicio antes de darlo por cerrado.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.subtitle),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: motivoController,
          maxLines: 5,
          enabled: !enviando,
          decoration: const InputDecoration(
            labelText: "¿Qué pasó?",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: enviando ? null : enviarReporte,
            child: enviando
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text("Enviar reporte"),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Mientras se está enviando, bloqueamos el botón de "atrás"
      // (físico o gesto) para que no se salga a medias y deje la app
      // en un estado raro.
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
          child: _seHizoElServicio == null
              ? _pasoConfirmar()
              : _seHizoElServicio == true
                  ? _pasoCalificar()
                  : _pasoReportarProblema(),
        ),
      ),
    );
  }
}