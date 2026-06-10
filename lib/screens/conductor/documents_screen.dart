import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_client.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  Map<String, dynamic>? _conductor;
  bool _loading = true;
  String? _uploadingDoc;

  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _accentOrange = Color(0xFFFF9800);
  static const Color _accentRed = Color(0xFFE53935);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  final List<_DocItem> _docs = [
    _DocItem('cedula', 'Cédula de ciudadanía', Icons.badge_outlined),
    _DocItem('licencia', 'Licencia de conducción', Icons.credit_card_outlined),
    _DocItem('foto_vehiculo', 'Foto del vehículo', Icons.directions_car_outlined),
    _DocItem('foto_conductor', 'Foto del conductor', Icons.person_outline),
  ];

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final data = await ApiClient.instance.getProfile();
      if (mounted) {
        setState(() {
          _conductor = data['conductor'] as Map<String, dynamic>?;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _fotoUrl(String docType) {
    if (_conductor == null) return null;
    switch (docType) {
      case 'cedula':
        return _conductor!['fotoCedula'] as String?;
      case 'licencia':
        return _conductor!['fotoLicencia'] as String?;
      case 'foto_vehiculo':
        return _conductor!['fotoVehiculo'] as String?;
      case 'foto_conductor':
        return _conductor!['fotoConductor'] as String?;
    }
    return null;
  }

  String _estado(String docType) {
    final global = _conductor?['estadoVerificacion'] as String? ?? 'pendiente';
    final foto = _fotoUrl(docType);
    if (foto == null || foto.isEmpty) return 'no_subido';
    return global;
  }

  Future<void> _confirmAndUpload(String docType) async {
    final picker = ImagePicker();

    while (true) {
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar documento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('¿Es correcto este documento?', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(picked.path), height: 200, width: double.infinity, fit: BoxFit.cover),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No, volver a tomar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A3C6E)),
              child: const Text('Sí, subir', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        setState(() => _uploadingDoc = docType);
        try {
          switch (docType) {
            case 'cedula':
              await ApiClient.instance.uploadDocumentCedula(File(picked.path));
            case 'licencia':
              await ApiClient.instance.uploadDocumentLicencia(File(picked.path));
            case 'foto_vehiculo':
              await ApiClient.instance.uploadDocumentVehiculo(File(picked.path));
            case 'foto_conductor':
              await ApiClient.instance.uploadDocumentDriverPhoto(File(picked.path));
          }
          await _loadStatus();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Documento subido correctamente')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')),
            );
          }
        } finally {
          if (mounted) setState(() => _uploadingDoc = null);
        }
        return;
      }
    }
  }

  void _showDocumentPreview(String docType) {
    final url = _fotoUrl(docType);
    if (url == null || url.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _docs.firstWhere((d) => d.type == docType).title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  '${ApiClient.baseUrl}$url',
                  height: 300,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 300,
                    color: const Color(0xFFF2F2F7),
                    child: const Center(child: Text('Imagen no disponible', style: TextStyle(color: Colors.black45))),
                  ),
                  loadingBuilder: (_, child, progress) => progress == null ? child : const Center(
                    child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRejectionNote() {
    final nota = _conductor?['notaRechazo'] as String?;
    if (nota == null || nota.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Motivo del rechazo'),
        content: Text(nota),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Documentos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatusBanner(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: _docs.map((doc) => _buildDocCard(doc)).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusBanner() {
    final estado = _conductor?['estadoVerificacion'] as String? ?? 'pendiente';
    if (estado == 'aprobado') {
      return Container(
        width: double.infinity,
        color: _accentGreen.withOpacity(0.12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.verified, color: _accentGreen, size: 20),
            const SizedBox(width: 8),
            const Text('Documentos aprobados', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
          ],
        ),
      );
    }
    if (estado == 'rechazado') {
      return GestureDetector(
        onTap: _showRejectionNote,
        child: Container(
          width: double.infinity,
          color: _accentRed.withOpacity(0.08),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.cancel, color: _accentRed, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Documentos rechazados. Toca para ver motivo.',
                  style: TextStyle(fontWeight: FontWeight.w600, color: _accentRed),
                ),
              ),
              Icon(Icons.chevron_right, color: _accentRed, size: 20),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildDocCard(_DocItem doc) {
    final estado = _estado(doc.type);
    final subiendo = _uploadingDoc == doc.type;
    final nota = _conductor?['notaRechazo'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _primaryDark.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(doc.icon, color: _primaryDark, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                if (estado == 'rechazado' && nota != null && nota.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(nota, style: TextStyle(fontSize: 11, color: _accentRed.withOpacity(0.7)), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                if (estado != 'no_subido') ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _showDocumentPreview(doc.type),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        '${ApiClient.baseUrl}${_fotoUrl(doc.type)}',
                        height: 56,
                        width: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: 56,
                          width: 80,
                          color: const Color(0xFFF2F2F7),
                          child: const Center(child: Icon(Icons.image, size: 24, color: Colors.black26)),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          subiendo
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
              : _buildAction(doc.type, estado),
        ],
      ),
    );
  }

  Widget _buildAction(String docType, String estado) {
    switch (estado) {
      case 'aprobado':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: _accentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 14, color: _accentGreen),
              const SizedBox(width: 4),
              Text('Aprobado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _accentGreen)),
            ],
          ),
        );
      case 'rechazado':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: _accentRed.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cancel, size: 14, color: _accentRed),
                  const SizedBox(width: 4),
                  Text('Rechazado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _accentRed)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 90,
              child: ElevatedButton(
                onPressed: () => _confirmAndUpload(docType),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentRed,
                  foregroundColor: _white,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  minimumSize: const Size(0, 28),
                ),
                child: const Text('Re-subir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        );
      case 'pendiente':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: _accentOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule, size: 14, color: _accentOrange),
              const SizedBox(width: 4),
              Text('En revisión', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _accentOrange)),
            ],
          ),
        );
      default:
        return SizedBox(
          width: 100,
          child: ElevatedButton(
            onPressed: () => _confirmAndUpload(docType),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryDark,
              foregroundColor: _white,
              padding: const EdgeInsets.symmetric(vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Subir imagen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        );
    }
  }
}

class _DocItem {
  final String type;
  final String title;
  final IconData icon;
  const _DocItem(this.type, this.title, this.icon);
}
