import 'package:flutter/material.dart';
import '../services/trip_service.dart';
import '../models/trip.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final _tripService = TripService();
  List<Trip> _trips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final trips = await _tripService.getHistory(limit: 50);
      if (mounted) setState(() { _trips = trips; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(String? raw) {
    if (raw == null) return '---';
    try {
      final dt = DateTime.parse(raw);
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day}/${dt.month} $h:$m';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Historial de viajes',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A8CFF)))
          : _trips.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 64,
                          color: Colors.white.withValues(alpha: 0.15)),
                      SizedBox(height: 16),
                      Text('Sin viajes realizados',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _trips.length,
                  itemBuilder: (_, i) => _buildTripCard(_trips[i]),
                ),
    );
  }

  Widget _buildTripCard(Trip trip) {
    final icon = trip.estado == 'finalizado' || trip.estado == 'completado'
        ? Icons.check_circle
        : trip.estado == 'cancelado'
            ? Icons.cancel
            : Icons.local_shipping;
    final color = trip.estado == 'finalizado' || trip.estado == 'completado'
        ? Colors.green
        : trip.estado == 'cancelado'
            ? Colors.red
            : const Color(0xFF1A8CFF);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              SizedBox(width: 8),
              Expanded(
                child: Text(trip.carga ?? 'Carga',
                    style: TextStyle(color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
              if (trip.precioFinal != null)
                Text('\$${trip.precioFinal!.toStringAsFixed(0)}',
                    style: TextStyle(color: const Color(0xFF1A8CFF),
                        fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 10),
          _infoRow(Icons.trip_origin, 'Origen', trip.origenDireccion),
          SizedBox(height: 6),
          _infoRow(Icons.location_on, 'Destino', trip.destinoDireccion),
          if (trip.precioEstimado != null && trip.precioFinal == null) ...[
            SizedBox(height: 6),
            _infoRow(Icons.monetization_on, 'Precio estimado',
                '\$${trip.precioEstimado!.toStringAsFixed(0)}'),
          ],
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule, size: 14,
                  color: Colors.white.withValues(alpha: 0.35)),
              SizedBox(width: 4),
              Text(_formatDate(trip.createdAt),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11)),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_estadoLabel(trip.estado),
                    style: TextStyle(color: color, fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.35)),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 10)),
              Text(value,
                  style: TextStyle(color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  String _estadoLabel(String estado) {
    switch (estado) {
      case 'pendiente': return 'PENDIENTE';
      case 'aceptado': return 'ACEPTADO';
      case 'en_curso': return 'EN CURSO';
      case 'completado': return 'COMPLETADO';
      case 'finalizado': return 'FINALIZADO';
      case 'cancelado': return 'CANCELADO';
      default: return estado.toUpperCase();
    }
  }
}
