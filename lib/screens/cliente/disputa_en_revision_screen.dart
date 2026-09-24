import 'dart:async';

import 'package:flutter/material.dart';
import 'resolucion_screen.dart';
import '../../services/api_client.dart';
import '../../services/socket_service_client.dart';

class DisputaEnRevisionScreen extends StatefulWidget {
  final String disputeId;

  const DisputaEnRevisionScreen({super.key, required this.disputeId});

  @override
  State<DisputaEnRevisionScreen> createState() => _DisputaEnRevisionScreenState();
}

/// Etiqueta de los estados de disputa del backend (abierta, en_revision,
/// resuelta).
String etiquetaEstadoDisputa(String? estado) {
  switch (estado) {
    case 'abierta':
      return 'Abierta';
    case 'en_revision':
      return 'En revisión';
    case 'resuelta':
      return 'Resuelta';
    default:
      return estado == null || estado.isEmpty ? 'En revisión' : estado;
  }
}

class _DisputaEnRevisionScreenState extends State<DisputaEnRevisionScreen> {
  Map<String, dynamic>? _dispute;
  bool _loading = true;
  bool _navigating = false;
  String? _error;
  StreamSubscription<Map<String, dynamic>>? _updatedSub;
  StreamSubscription<Map<String, dynamic>>? _resolvedSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    // dispute:updated trae `id`; dispute:resolved trae `disputaId`.
    void siEsEsta(Map<String, dynamic> data) {
      final id = (data['disputaId'] ?? data['id'])?.toString();
      if (id == widget.disputeId && mounted) _load(silencioso: true);
    }

    _updatedSub = SocketServiceClient.instance.onDisputeUpdated.listen(siEsEsta);
    _resolvedSub = SocketServiceClient.instance.onDisputeResolved.listen(siEsEsta);
  }

  @override
  void dispose() {
    _updatedSub?.cancel();
    _resolvedSub?.cancel();
    super.dispose();
  }

  /// [silencioso]: recarga sin ocultar la pantalla (socket y deslizar).
  Future<void> _load({bool silencioso = false}) async {
    if (!mounted) return;
    if (!silencioso) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await ApiClient.instance.getDispute(widget.disputeId);
      if (mounted) {
        setState(() {
          _dispute = data;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (silencioso && _dispute != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No se pudo actualizar la disputa. Intenta de nuevo.')));
        return;
      }
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text('Error al cargar disputa', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 16),
                ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
              ],
            ),
          ),
        ),
      );
    }

    final numero = _dispute?['numero']?.toString() ?? widget.disputeId;
    final estadoRaw = _dispute?['estado']?.toString();
    final estado = etiquetaEstadoDisputa(estadoRaw);
    // Estados del backend: abierta, en_revision, resuelta.
    final esResuelta = estadoRaw == 'resuelta';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _load(silencioso: true),
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        Text(
                          esResuelta ? 'Disputa resuelta' : 'Disputa en revisi\u00f3n',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black),
                          textAlign: TextAlign.center,
                        ),
                        const Spacer(flex: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            estado,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B)),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          esResuelta
                              ? 'Revisamos la disputa y ya\nhay una decisi\u00f3n.'
                              : 'Nuestro equipo est\u00e1 revisando\nla disputa.',
                          style: const TextStyle(fontSize: 16, color: Color(0xFF4B5563), height: 1.6),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          esResuelta
                              ? 'Toca "Ver resoluci\u00f3n" para ver el resultado.'
                              : 'Te notificaremos cuando\nhaya una resoluci\u00f3n.',
                          style: const TextStyle(fontSize: 16, color: Color(0xFF4B5563), height: 1.6),
                          textAlign: TextAlign.center,
                        ),
                        const Spacer(flex: 3),
                        const Divider(color: Color(0xFFE5E7EB), thickness: 1, height: 1),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'N\u00famero de disputa',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  numero,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Estado',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  estado,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFFE5E7EB), thickness: 1, height: 1),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: _navigating
                                ? null
                                : () async {
                                    setState(() => _navigating = true);
                                    try {
                                      if (esResuelta) {
                                        await Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ResolucionScreen(disputa: _dispute ?? const {}),
                                          ),
                                        );
                                      } else {
                                        Navigator.of(context).popUntil((route) => route.isFirst);
                                      }
                                    } finally {
                                      if (mounted) setState(() => _navigating = false);
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              esResuelta ? 'Ver resoluci\u00f3n' : 'Volver al inicio',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
