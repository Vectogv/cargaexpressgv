import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/fraud_detection_service.dart';
import '../../services/logger_service.dart';

class CancelarViajeScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  final void Function(String? motivo, String? descripcion)? onConfirm;

  const CancelarViajeScreen({
    super.key,
    required this.trip,
    this.onConfirm,
  });

  @override
  State<CancelarViajeScreen> createState() => _CancelarViajeScreenState();
}

class _CancelarViajeScreenState extends State<CancelarViajeScreen> {
  String? _selectedReason;
  final _descCtrl = TextEditingController();
  bool _loading = false;

  static const Color _red = Color(0xFFDC2626);
  static const Color _redDisabled = Color(0xFFFCA5A5);
  static const Color _amberBg = Color(0xFFFFF3CD);
  static const Color _amberBorder = Color(0xFFFFEAA7);
  static const Color _amberText = Color(0xFF856404);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _divider = Color(0xFFE5E7EB);
  static const Color _inputBorder = Color(0xFFD1D5DB);
  static const Color _white = Colors.white;
  static const Color _radioActive = Color(0xFF2563EB);

  static const List<String> _reasons = [
    'Cliente no responde',
    'Dirección incorrecta',
    'Problemas con la carga',
    'Cambio de planes',
    'Emergencia',
    'Otro',
  ];

  bool get _canSubmit => _selectedReason != null && !_loading;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _white,
      appBar: _buildAppBar(),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            _buildWarningBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selecciona el motivo',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_reasons.length, (i) => _buildRadioTile(_reasons[i])),
                    if (_selectedReason != null) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Descripción (opcional)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDescriptionField(),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _white,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'Cancelar viaje',
        style: TextStyle(
          color: _textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: _textPrimary, size: 20),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: _amberBg,
        border: Border(
          bottom: BorderSide(color: _amberBorder),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: _amberText, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'El cliente será notificado. Esta acción será revisada.',
              style: const TextStyle(
                fontSize: 13,
                color: _amberText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioTile(String reason) {
    final selected = _selectedReason == reason;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _selectedReason = reason),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? _radioActive : const Color(0xFF9CA3AF),
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                reason,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return TextField(
      controller: _descCtrl,
      maxLines: 4,
      minLines: 3,
      style: const TextStyle(fontSize: 14, color: _textPrimary),
      decoration: InputDecoration(
        hintText: 'Describe el motivo (opcional)',
        hintStyle: const TextStyle(color: _textSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.all(14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _radioActive, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: _white,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _canSubmit ? _handleConfirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _red,
            foregroundColor: _white,
            disabledBackgroundColor: _redDisabled,
            disabledForegroundColor: _white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _white,
                  ),
                )
              : const Text(
                  'Cancelar viaje',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _handleConfirm() async {
    final motivo = _selectedReason;
    final descripcion = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();

    if (widget.onConfirm != null) {
      widget.onConfirm!(motivo, descripcion);
      return;
    }

    setState(() => _loading = true);
    try {
      final tripId = widget.trip['id'];
      final userId = ApiClient.instance.userId;

      if (userId != null) {
        FraudDetectionService.instance.checkCancellation(userId);
      }

      LoggerService.instance.info('Cancelando viaje $tripId, motivo: $motivo');

      await ApiClient.instance.cancelTrip(tripId, motivo: motivo);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Viaje cancelado')),
        );
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (mounted) {
        LoggerService.instance.error('Error al cancelar viaje', e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
