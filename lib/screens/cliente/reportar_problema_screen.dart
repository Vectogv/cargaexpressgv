import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'disputa_creada_screen.dart';
import '../../services/api_client.dart';
import '../../services/api/http_client.dart' show ApiException;
import '../../services/api/trip_service.dart';

class ReportarProblemaScreen extends StatefulWidget {
  final Map<String, dynamic>? trip;
  final String role;
  final VoidCallback onSubmitted;

  const ReportarProblemaScreen({
    super.key,
    this.trip,
    this.role = 'cliente',
    required this.onSubmitted,
  });

  @override
  State<ReportarProblemaScreen> createState() => _ReportarProblemaScreenState();
}

class _ReportarProblemaScreenState extends State<ReportarProblemaScreen> {
  String _selectedProblem = 'La carga lleg\u00f3 da\u00f1ada';
  final TextEditingController _descController = TextEditingController();
  // Cada foto se sube al elegirla (POST /api/trips/:id/dispute/support) y su
  // ruta se envía en `fotos` al crear la disputa. Los bytes sirven para la
  // miniatura local.
  final List<({String path, Uint8List bytes})?> _photos = [null, null];
  bool _uploading = false;
  bool _submitting = false;

  Future<void> _pickPhoto() async {
    if (_uploading) return;
    final messenger = ScaffoldMessenger.of(context);
    final i = _photos.indexWhere((p) => p == null);
    if (i < 0) {
      messenger.showSnackBar(const SnackBar(content: Text('M\u00e1ximo 2 fotos')));
      return;
    }
    final tripId = widget.trip?['id'] ?? widget.trip?['_id'];
    if (tripId == null) {
      messenger.showSnackBar(const SnackBar(content: Text('No hay un viaje activo')));
      return;
    }
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 75,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final path = await TripService.disputePhoto(
        tripId,
        bytes,
        'soporte_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      if (!mounted) return;
      if (path.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('No se pudo subir la foto.')));
        return;
      }
      setState(() => _photos[i] = (path: path, bytes: bytes));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error al subir la foto: ${e.toString().replaceFirst("Exception: ", "")}')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (widget.trip == null) {
      messenger.showSnackBar(const SnackBar(content: Text('No hay un viaje activo')));
      return;
    }
    if (_descController.text.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Por favor describe el problema')));
      return;
    }
    if (_uploading) {
      messenger.showSnackBar(const SnackBar(content: Text('Espera a que termine de subir la foto')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await ApiClient.instance.createDispute(
        tripId: widget.trip?['id'],
        problema: _selectedProblem,
        descripcion: _descController.text.trim(),
        fotos: [for (final p in _photos) if (p != null) p.path],
      );
      final numero = result['numero_disputa'] as String? ?? 'DSP-00001';
      final disputeId = result['id']?.toString() ?? result['_id']?.toString() ?? '';
      if (!mounted) return;
      widget.onSubmitted();
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => DisputaCreadaScreen(
            disputeNumber: numero,
            disputeId: disputeId,
          ),
        ),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  static const _problems = [
    'La carga lleg\u00f3 da\u00f1ada',
    'Conductor no se present\u00f3',
    'Cobro incorrecto',
    'Trato inadecuado',
    'Otro',
  ];

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
          'Reportar un problema',
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
                        Icons.warning_amber_rounded,
                        color: Color(0xFFEF4444),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Cu\u00e9ntanos qu\u00e9 sucedi\u00f3\npara que podamos ayudarte.',
                        style: TextStyle(
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
                'Selecciona el problema',
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
                    value: _selectedProblem,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6B7280)),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                      fontWeight: FontWeight.w400,
                    ),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    items: _problems
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedProblem = v!),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Describe el problema',
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
                  hintText: 'Describe lo que ocurri\u00f3...',
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
              const SizedBox(height: 20),
              const Text(
                'Fotos (opcional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ..._photos.map((p) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 80,
                        height: 80,
                        color: p != null ? const Color(0xFFE5E7EB) : const Color(0xFFD4C5A9),
                        child: p != null
                            ? Image.memory(p.bytes, fit: BoxFit.cover, cacheWidth: 240, errorBuilder: (_, _, _) => const Icon(Icons.broken_image, color: Color(0xFF6B7280)))
                            : CustomPaint(painter: _BoxPhotoPainter()),
                      ),
                    ),
                  )),
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                      ),
                      child: _uploading
                          ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
                          : const Icon(
                              Icons.add,
                              color: Color(0xFF6B7280),
                              size: 30,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              SizedBox(
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoxPhotoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFD4C5A9),
    );

    final boxPaint = Paint()..color = const Color(0xFFC19A6B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.1, size.height * 0.2, size.width * 0.8, size.height * 0.65),
        const Radius.circular(3),
      ),
      boxPaint,
    );

    final topPaint = Paint()..color = const Color(0xFFA0784A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.1, size.height * 0.12, size.width * 0.8, size.height * 0.12),
        const Radius.circular(3),
      ),
      topPaint,
    );

    final tapePaint = Paint()
      ..color = const Color(0xFF8B5E2E)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.2),
      Offset(size.width * 0.5, size.height * 0.85),
      tapePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.52),
      Offset(size.width * 0.9, size.height * 0.52),
      tapePaint,
    );

    final dmgPaint = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.7)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.3),
      Offset(size.width * 0.45, size.height * 0.5),
      dmgPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.45, size.height * 0.3),
      Offset(size.width * 0.25, size.height * 0.5),
      dmgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
