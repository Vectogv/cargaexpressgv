import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import 'trip_chat_screen.dart';
import 'viaje_aceptado_screen.dart';
import 'trip_in_progress_screen.dart';

class ClienteData {
  final String nombre;
  final double rating;
  final String? avatarUrl;
  const ClienteData({
    required this.nombre,
    required this.rating,
    this.avatarUrl,
  });
}

class OfertaAceptadaScreen extends StatefulWidget {
  final String montoOferta;
  final ClienteData cliente;
  final String origen;
  final String destino;
  final String distancia;
  final String descripcionCarga;
  final Map<String, dynamic> trip;

  const OfertaAceptadaScreen({
    super.key,
    this.montoOferta = '\$55.000',
    this.cliente = const ClienteData(nombre: 'María González', rating: 4.8),
    this.origen = 'Av. Principal, Caracas',
    this.destino = 'Valencia, Zona Industrial',
    this.distancia = '28.6 km',
    this.descripcionCarga = 'Electrodomésticos, 3 cajas grandes',
    required this.trip,
  });

  @override
  State<OfertaAceptadaScreen> createState() => _OfertaAceptadaScreenState();
}

class _OfertaAceptadaScreenState extends State<OfertaAceptadaScreen> {
  bool _starting = false;
  bool _cancelling = false;

  Future<void> _iniciarViaje() async {
    final tripId = widget.trip['viajeId']?.toString()
        ?? widget.trip['tripId']?.toString()
        ?? widget.trip['id']?.toString()
        ?? widget.trip['_id']?.toString();
    if (tripId == null || tripId.isEmpty) {
      _snack('Error: ID del viaje no disponible');
      return;
    }
    setState(() => _starting = true);
    try {
      await ApiClient.instance.startTrip(tripId);
      if (!mounted) return;

      final capturedTrip = widget.trip;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (ctx) => TripInProgressScreen(
            trip: capturedTrip,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}'),
        ));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _cancelarViaje() async {
    final tripId = widget.trip['viajeId']?.toString()
        ?? widget.trip['tripId']?.toString()
        ?? widget.trip['id']?.toString()
        ?? widget.trip['_id']?.toString();
    if (tripId == null || tripId.isEmpty) {
      _snack('Error: ID del viaje no disponible');
      return;
    }
    setState(() => _cancelling = true);
    try {
      await ApiClient.instance.cancelTrip(tripId, motivo: 'Cancelado por el conductor');
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}'),
        ));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  void _mostrarTelefono() {
    final cliente = widget.trip['cliente'] as Map<String, dynamic>?;
    final telefono = cliente?['telefono'] as String?;
    if (telefono == null || telefono.isEmpty) {
      _snack('No hay número de teléfono disponible');
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.cliente.nombre),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.phone, size: 48, color: Color(0xFF2563EB)),
          const SizedBox(height: 12),
          Text(telefono, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _abrirChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TripChatScreen(trip: widget.trip)),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return ViajeAceptadoScreen(
      nombreCliente: widget.cliente.nombre,
      ratingCliente: widget.cliente.rating,
      avatarUrl: widget.cliente.avatarUrl,
      origen: widget.origen,
      destino: widget.destino,
      precioAcordado: widget.montoOferta,
      isStarting: _starting,
      isCancelling: _cancelling,
      onLlamar: _mostrarTelefono,
      onMensaje: _abrirChat,
      onIniciarViaje: _iniciarViaje,
      onCancelarViaje: _cancelarViaje,
    );
  }
}
