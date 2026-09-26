import 'package:flutter/material.dart';
import '../../services/api/http_client.dart' show ApiException;
import '../../services/report_service.dart';

/// El cliente reporta al conductor asignado a un viaje
/// (POST /api/trips/:id/report). El backend decide la sanción: el reporte
/// nunca suspende, baja la reputación y deja la cuenta en revisión del admin
/// desde el segundo. Devuelve `true` al cerrar si el reporte se envió.
class ReportarConductorScreen extends StatefulWidget {
  /// Mapa del viaje: `Trip.toJson()` trae `_id`, los del backend `id`.
  final Map<String, dynamic> trip;

  const ReportarConductorScreen({super.key, required this.trip});

  @override
  State<ReportarConductorScreen> createState() => _ReportarConductorScreenState();
}

class _ReportarConductorScreenState extends State<ReportarConductorScreen> {
  /// Motivos aceptados por el backend para un reporte del cliente.
  static const motivos = <String, String>{
    'no_se_presento': 'El conductor no se presentó',
    'cobro_incorrecto': 'Cobro incorrecto',
    'comportamiento': 'Comportamiento inadecuado',
    'otro': 'Otro',
  };

  String _motivo = motivos.keys.first;
  final TextEditingController _descController = TextEditingController();
  bool _submitting = false;

  dynamic get _tripId => widget.trip['_id'] ?? widget.trip['id'];

  String get _aviso {
    final conductor = widget.trip['conductor'];
    final nombre = conductor is Map ? (conductor['nombre']?.toString().trim() ?? '') : '';
    final quien = nombre.isNotEmpty ? nombre : 'al conductor de este viaje';
    final a = nombre.isNotEmpty ? 'a ' : '';
    return 'Vas a reportar $a$quien.\nUn administrador revisará tu reporte.';
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final tripId = _tripId;
    if (tripId == null) {
      messenger.showSnackBar(const SnackBar(content: Text('No se encontró el viaje')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ReportService.createReport(
        tripId: tripId.toString(),
        motivo: _motivo,
        descripcion: _descController.text.trim(),
      );
      if (!mounted) return;
      navigator.pop(true);
    } on ApiException catch (e) {
      final msg = e.statusCode == 409
          ? 'Ya reportaste al conductor de este viaje.'
          : e.message;
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        centerTitle: true,
        title: const Text(
          'Reportar conductor',
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.flag_outlined,
                        color: Color(0xFFEF4444),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _aviso,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF374151),
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Motivo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _motivo,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6B7280)),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                      fontWeight: FontWeight.w400,
                    ),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    items: [
                      for (final e in motivos.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: _submitting ? null : (v) => setState(() => _motivo = v!),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Describe lo ocurrido (opcional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                maxLines: 5,
                minLines: 4,
                style: const TextStyle(fontSize: 14, color: Colors.black, height: 1.5),
                decoration: InputDecoration(
                  hintText: 'Cuéntanos qué pasó con el conductor...',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text(
                      'Enviar reporte',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
