import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/socket_service_client.dart';
import 'en_disputa_screen.dart';
import 'mi_version_screen.dart';
import 'disputa_en_revision_screen.dart';
import 'resolucion_screen.dart';

class EnDisputaWrapper extends StatefulWidget {
  final dynamic tripId;
  final dynamic disputeId;
  final String? origen;
  final String? destino;
  final bool inicialResuelta;

  const EnDisputaWrapper({
    super.key,
    required this.tripId,
    required this.disputeId,
    this.origen,
    this.destino,
    this.inicialResuelta = false,
  });

  @override
  State<EnDisputaWrapper> createState() => _EnDisputaWrapperState();
}

class _EnDisputaWrapperState extends State<EnDisputaWrapper> {
  StreamSubscription<Map<String, dynamic>>? _updatedSub;
  StreamSubscription<Map<String, dynamic>>? _resolvedSub;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _updatedSub = SocketServiceClient.instance.onDisputeUpdated.listen(_onUpdated);
    _resolvedSub = SocketServiceClient.instance.onDisputeResolved.listen(_onResolved);
    if (widget.inicialResuelta) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchAndShowResolucion());
    }
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetchAndShowResolucion();
    });
  }

  Future<void> _fetchAndShowResolucion() async {
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
  }

  void _enviarMiVersion() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MiVersionScreen(
          onSubmit: (descripcion) async {
            if (_enviando) return;
            _enviando = true;
            try {
              await ApiClient.instance.submitVersion(widget.disputeId, descripcion);
              if (mounted) {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DisputaEnRevisionScreen(
                      origen: widget.origen ?? '',
                      destino: widget.destino ?? '',
                    ),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al enviar: $e')),
                );
              }
            } finally {
              _enviando = false;
            }
          },
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
    return EnDisputaScreen(
      onEnviarMiVersion: _enviarMiVersion,
    );
  }
}
