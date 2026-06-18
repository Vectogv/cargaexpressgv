import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_client.dart';
import '../../services/api/trip_service.dart';
import '../../services/logger_service.dart';

class DisputeScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  final String role;
  const DisputeScreen({super.key, required this.trip, required this.role});

  @override
  State<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends State<DisputeScreen> {
  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);

  final _descCtrl = TextEditingController();
  String? _selectedType;
  bool _submitting = false;
  List<String> _photoUrls = [];
  bool _uploading = false;

  static const List<Map<String, dynamic>> _disputeTypes = [
    {'id': 'carga_daniada', 'label': 'Carga da\u00f1ada', 'icon': Icons.inventory_2_outlined},
    {'id': 'cliente_ausente', 'label': 'Cliente ausente', 'icon': Icons.person_off_outlined},
    {'id': 'problema_conductor', 'label': 'Problemas con el conductor', 'icon': Icons.person_outline},
    {'id': 'diferencia_pago', 'label': 'Diferencias de pago', 'icon': Icons.payments_outlined},
    {'id': 'incidente_viaje', 'label': 'Incidentes durante el viaje', 'icon': Icons.warning_amber_outlined},
    {'id': 'otro', 'label': 'Otro', 'icon': Icons.more_horiz},
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
      if (file == null) return;
      setState(() => _uploading = true);
      final bytes = await file.readAsBytes();
      final url = await TripService.disputePhoto(
        widget.trip['id'],
        bytes,
        'dispute_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      if (url.isNotEmpty) {
        setState(() => _photoUrls.add(url));
      }
    } catch (e) {
      LoggerService.instance.error('Error adding dispute photo', e);
      if (mounted) _snack('Error al subir foto');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submitDispute() async {
    if (_selectedType == null) {
      _snack('Selecciona un tipo de disputa');
      return;
    }
    if (_descCtrl.text.trim().isEmpty) {
      _snack('Describe el problema');
      return;
    }
    setState(() => _submitting = true);
    try {
      final typeLabel = _disputeTypes.firstWhere((t) => t['id'] == _selectedType)['label'] as String;
      await ApiClient.instance.disputeTrip(
        widget.trip['id'],
        motivo: typeLabel,
        descripcion: '${_descCtrl.text.trim()}\nFotos: ${_photoUrls.join(", ")}',
      );
      if (mounted) {
        _snack('Disputa registrada. El administrador la revisar\u00e1.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _snack('Error al enviar: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final origen = t['origen'] as Map<String, dynamic>?;
    final destino = t['destino'] as Map<String, dynamic>?;
    final cliente = t['cliente'] as Map<String, dynamic>?;
    final conductor = t['conductor'] as Map<String, dynamic>?;
    final nombre = widget.role == 'conductor'
        ? (cliente?['nombre'] ?? 'Cliente')
        : (conductor?['nombre'] ?? 'Conductor');

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _textDark,
        elevation: 0,
        title: const Text('Abrir disputa', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'La disputa ser\u00e1 revisada por un administrador.',
                    style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            const Text('Informaci\u00f3n del viaje', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ID: ${t['id']}', style: TextStyle(fontSize: 12, color: _textGrey)),
                  const SizedBox(height: 4),
                  Text('$nombre', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  if (origen != null) Text('Origen: ${origen['direccion'] ?? ''}', style: TextStyle(fontSize: 12, color: _textGrey)),
                  if (destino != null) Text('Destino: ${destino['direccion'] ?? ''}', style: TextStyle(fontSize: 12, color: _textGrey)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Tipo de disputa', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            ..._disputeTypes.map((type) => RadioListTile<String>(
              title: Row(children: [
                Icon(type['icon'] as IconData, size: 20, color: _primaryDark),
                const SizedBox(width: 10),
                Text(type['label'] as String, style: const TextStyle(fontSize: 14)),
              ]),
              value: type['id'] as String,
              groupValue: _selectedType,
              onChanged: (v) => setState(() => _selectedType = v),
              dense: true,
              contentPadding: EdgeInsets.zero,
            )),
            const SizedBox(height: 16),
            const Text('Descripci\u00f3n', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe lo sucedido...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Evidencias (fotos)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._photoUrls.map((url) => Container(
                    width: 80, height: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                    ),
                  )),
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _uploading
                      ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                      : IconButton(
                          icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF1A3C6E)),
                          onPressed: _addPhoto,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submitDispute,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enviar disputa', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
