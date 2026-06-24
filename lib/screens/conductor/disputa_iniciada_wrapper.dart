import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/socket_service_client.dart';
import 'disputa_iniciada_screen.dart';
import 'en_disputa_wrapper.dart';
import 'disputa_en_revision_screen.dart';
import 'resolucion_screen.dart';

class DisputaIniciadaWrapper extends StatefulWidget {
  final dynamic tripId;
  final dynamic disputeId;
  final String motivo;
  final String? origen;
  final String? destino;

  const DisputaIniciadaWrapper({
    super.key,
    required this.tripId,
    required this.disputeId,
    required this.motivo,
    this.origen,
    this.destino,
  });

  @override
  State<DisputaIniciadaWrapper> createState() => _DisputaIniciadaWrapperState();
}

class _DisputaIniciadaWrapperState extends State<DisputaIniciadaWrapper> {
  StreamSubscription<Map<String, dynamic>>? _updatedSub;
  StreamSubscription<Map<String, dynamic>>? _resolvedSub;

  @override
  void initState() {
    super.initState();
    _updatedSub = SocketServiceClient.instance.onDisputeUpdated.listen(_onUpdated);
    _resolvedSub = SocketServiceClient.instance.onDisputeResolved.listen(_onResolved);
  }

  void _onUpdated(Map<String, dynamic> data) {
    final id = data['id']?.toString();
    if (id != widget.disputeId?.toString()) return;
    final estado = data['estado'] as String?;
    if (estado == 'en_revision') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DisputaEnRevisionScreen(
              origen: widget.origen ?? '',
              destino: widget.destino ?? '',
            ),
          ),
        );
      });
    }
  }

  void _onResolved(Map<String, dynamic> data) {
    final id = data['id']?.toString();
    if (id != widget.disputeId?.toString()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      String resultado = 'Resuelto';
      String motivo = '';
      try {
        final dispute = await ApiClient.instance.getDispute(widget.disputeId);
        resultado = dispute['resultado'] as String? ?? 'Resuelto';
        motivo = dispute['motivo'] as String? ?? '';
      } catch (_) {}
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResolucionScreen(
            resultado: resultado,
            motivo: motivo,
            onVolverInicio: () => Navigator.popUntil(context, (r) => r.isFirst),
          ),
        ),
      );
    });
  }

  void _verDetalles() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnDisputaWrapper(
          tripId: widget.tripId,
          disputeId: widget.disputeId,
          origen: widget.origen,
          destino: widget.destino,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _updatedSub?.cancel();
    _resolvedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DisputaIniciadaScreen(
      motivo: widget.motivo,
      onVerDetalles: _verDetalles,
    );
  }
}
