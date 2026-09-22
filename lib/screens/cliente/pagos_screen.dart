import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api/payment_service.dart';

class PagosScreen extends StatefulWidget {
  const PagosScreen({super.key});

  @override
  State<PagosScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends State<PagosScreen> {
  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  Map<String, dynamic>? _deuda;
  bool _loading = true;
  bool _uploading = false;
  String? _error;
  String? _proofMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final deuda = await PaymentService.getDebtInfo();
      if (mounted) {
        setState(() { _deuda = deuda; _loading = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _error = e.toString().replaceFirst('Exception: ', ''); });
      }
    }
  }

  Future<void> _uploadProof() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 75,
    );
    if (picked == null || !mounted) return;
    setState(() { _uploading = true; _proofMessage = null; });
    try {
      final bytes = await picked.readAsBytes();
      // image_picker la recomprime a JPEG → extensión .jpg.
      await PaymentService.uploadProof(bytes: bytes, filename: 'comprobante_${DateTime.now().millisecondsSinceEpoch}.jpg');
      if (!mounted) return;
      setState(() {
        _proofMessage = 'Comprobante recibido. El administrador lo verificar\u00e1 en breve.';
        _deuda?['estadoCuenta'] = 'esperando_confirmacion';
        _uploading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _proofMessage = 'Error al subir el comprobante: ${e.toString().replaceFirst("Exception: ", "")}';
        });
      }
    }
  }

  String _estadoLabel(String? estado) {
    switch (estado) {
      case 'suspension_por_pago':
        return 'Suspensi\u00f3n por pago pendiente';
      case 'esperando_confirmacion':
        return 'Comprobante en revisi\u00f3n';
      case 'al_dia':
        return 'Al d\u00eda';
      default:
        return estado ?? 'Al d\u00eda';
    }
  }

  String _currency(dynamic value) {
    final n = (value is num) ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0.0;
    return '\$${n.toStringAsFixed(0)}';
  }

  String? _formatDate(dynamic ts) {
    final dt = DateTime.tryParse(ts?.toString() ?? '');
    if (dt == null) return null;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
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
        title: const Text('Pagos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null || _deuda == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No se pudo cargar tu estado de cuenta', style: TextStyle(fontSize: 15, color: Colors.black54)),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    final deuda = _deuda!;
    final dias = (deuda['diasRestantes'] as num?)?.toInt() ?? 0;
    final estado = deuda['estadoCuenta'] as String?;
    final monto = deuda['montoDeuda'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildEstadoCard(estado, dias, monto),
        const SizedBox(height: 16),
        _buildNequiCard(deuda),
        const SizedBox(height: 16),
        if (_proofMessage != null) _buildProofMessage(),
        if (estado == 'suspension_por_pago') ...[
          const SizedBox(height: 16),
          _buildUploadCard(),
        ],
        const SizedBox(height: 16),
        _buildSection('M\u00e9todos de pago', [
          _buildMethodCard(
            Icons.account_balance_wallet,
            'Efectivo',
            'Pago al conductor',
          ),
          _buildMethodCard(
            Icons.phone_android,
            'Nequi',
            deuda['nequiNombre'] != null
                ? '${deuda['nequiNombre']} ${deuda['nequiNumero']}'
                : 'Transferencia electr\u00f3nica',
          ),
        ]),
      ],
    );
  }

  Widget _buildEstadoCard(String? estado, int dias, dynamic monto) {
    final suspendido = estado == 'suspension_por_pago';
    final color = suspendido ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(suspendido ? Icons.warning_amber_rounded : Icons.verified_outlined, color: color),
              const SizedBox(width: 8),
              Text('Estado de cuenta', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textGrey)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(_estadoLabel(estado), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currency(monto),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 4),
          Text(
            dias > 0
                ? '$dias d\u00eda${dias == 1 ? '' : 's'} restante${dias == 1 ? '' : 's'} para pagar'
                : 'Pago vencido',
            style: TextStyle(fontSize: 13, color: dias > 0 ? _textGrey : color, fontWeight: FontWeight.w600),
          ),
          if (_formatDate(_deuda?['deudaFechaLimite']) != null) ...[
            const SizedBox(height: 4),
            Text('Fecha l\u00edmite: ${_formatDate(_deuda?['deudaFechaLimite'])}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ],
      ),
    );
  }

  Widget _buildNequiCard(Map<String, dynamic> deuda) {
    final numero = deuda['nequiNumero'] as String?;
    final nombre = deuda['nequiNombre'] as String?;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _primaryDark.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.phone_android, size: 24, color: _primaryDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Paga por Nequi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  numero != null ? '$nombre\u2022$numero' : 'Nequi no configurado a\u00fan',
                  style: const TextStyle(fontSize: 13, color: _textGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProofMessage() {
    final isError = _proofMessage!.startsWith('Error');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (isError ? Colors.red : Colors.green).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red : Colors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_proofMessage!, style: TextStyle(fontSize: 13, color: isError ? Colors.red.shade800 : Colors.green.shade800)),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard() {
    final uploading = _uploading;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          const Text(
            'Tienes una suspensi\u00f3n por pago. Para reactivar tu cuenta sube el comprobante de la transferencia (imagen JPG/PNG).',
            style: TextStyle(fontSize: 13, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
              onPressed: uploading ? null : _uploadProof,
              icon: uploading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_file),
              label: Text(uploading ? 'Subiendo...' : 'Subir comprobante de pago'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textGrey)),
        ),
        Container(
          decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(14)),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildMethodCard(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: _primaryDark.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 22, color: _primaryDark),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: _textGrey)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {},
    );
  }
}