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

  /// El backend identifica la disputa como `disputaId` (dispute:resolved) o
  /// `id`; si esta pantalla no conoce el id (se abrió al sincronizar el
  /// viaje), acepta el evento.
  bool _esMiDisputa(Map<String, dynamic> data) {
    final id = (data['disputaId'] ?? data['id'])?.toString();
    final mia = widget.disputeId?.toString();
    return mia == null || id == null || id == mia;
  }

  void _onUpdated(Map<String, dynamic> data) {
    if (!_esMiDisputa(data)) return;
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
    if (!_esMiDisputa(data)) return;
    final id = widget.disputeId ?? data['disputaId'] ?? data['id'];
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // El evento ya trae resultado y mensaje; el detalle del backend los
      // completa si se puede consultar.
      final disputa = <String, dynamic>{
        'id': id,
        if (data['resultado'] != null) 'resultado': data['resultado'],
        if (data['message'] != null) 'mensaje': data['message'],
      };
      if (id != null) {
        try {
          disputa.addAll(await ApiClient.instance.getDispute(id));
        } catch (_) {}
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResolucionScreen(
            disputa: disputa,
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
