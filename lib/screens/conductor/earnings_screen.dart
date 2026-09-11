import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_client.dart';
import '../../services/api/payment_service.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  Map<String, dynamic>? _earnings;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _today;
  Map<String, dynamic>? _debt;
  List<Map<String, dynamic>> _history = [];
  int _histTotal = 0;
  int _histPage = 0;

  bool _loading = true;
  bool _loadingMore = false;
  bool _uploading = false;
  bool _downloadingPdf = false;

  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiClient.instance.getEarnings(),
        ApiClient.instance.getDriverStats(),
        ApiClient.instance.getTodayStats(),
        ApiClient.instance.getDebt(),
        ApiClient.instance.getEarningsHistory(page: 1, limit: 10),
      ]);
      final historyData = results[4];
      if (mounted) {
        setState(() {
          _earnings = results[0];
          _stats = results[1];
          _today = results[2];
          _debt = results[3];
          _history = (historyData['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _histTotal = (historyData['total'] as num?)?.toInt() ?? _history.length;
          _histPage = 1;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreHistory() async {
    if (_loadingMore || _history.length >= _histTotal) return;
    setState(() => _loadingMore = true);
    try {
      final data = await ApiClient.instance.getEarningsHistory(page: _histPage + 1, limit: 10);
      if (mounted) {
        setState(() {
          _history.addAll((data['data'] as List?)?.cast<Map<String, dynamic>>() ?? []);
          _histTotal = (data['total'] as num?)?.toInt() ?? _history.length;
          _histPage++;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo cargar más historial')));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _downloadPdf(String periodo, String label) async {
    if (_downloadingPdf) return;
    setState(() => _downloadingPdf = true);
    try {
      final bytes = await ApiClient.instance.getEarningsPdf(periodo: periodo);
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/ganancias_${periodo}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(bytes);
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('PDF generado'),
            content: Text('Reporte de ganancias ($label) guardado en:\n${file.path}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al descargar PDF: ${e.toString().replaceFirst("Exception: ", "")}')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  Future<void> _uploadProof() async {
    if (_uploading) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      await PaymentService.uploadProof(bytes: bytes, filename: picked.name);
      if (mounted) {
        setState(() {
          _debt = Map<String, dynamic>.from(_debt ?? {});
          _debt!['estadoCuenta'] = 'esperando_confirmacion';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comprobante enviado. El administrador lo verificará en breve.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir comprobante: ${e.toString().replaceFirst("Exception: ", "")}')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async { setState(() => _loading = true); await _loadData(); },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTodayCard(),
                          const SizedBox(height: 12),
                          _buildPeriodRow(),
                          const SizedBox(height: 12),
                          _buildTotalRow(),
                          const SizedBox(height: 16),
                          _buildSectionTitle('Historial de ganancias'),
                          const SizedBox(height: 8),
                          _buildHistoryCard(),
                          const SizedBox(height: 12),
                          _buildPdfCard(),
                          const SizedBox(height: 16),
                          _buildSectionTitle('Deuda'),
                          const SizedBox(height: 8),
                          _buildDebtCard(),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _white,
      padding: const EdgeInsets.only(top: 44, left: 16, right: 16, bottom: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Ganancias', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)));
  }

  Widget _buildTodayCard() {
    final viajesHoy = (_today?['viajesHoy'] as num?)?.toInt() ?? 0;
    final horasOnline = (_today?['horasOnline'] as num?)?.toDouble() ?? 0;
    final gananciasHoy = (_today?['gananciasHoy'] as num?) ?? 0;
    final netaHoy = (_today?['netaHoy'] as num?) ?? 0;
    final calificacion = (_today?['calificacion'] as num?) ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A3C6E), Color(0xFF1565C0)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hoy', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${_formatAmount(netaHoy)}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('neto', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _todayStat('$viajesHoy', 'Viajes'),
              _todayStat('${horasOnline.toStringAsFixed(1)}h', 'Online'),
              _todayStat('\$${_formatAmount(gananciasHoy)}', 'Bruto'),
              _todayStat(calificacion > 0 ? calificacion.toStringAsFixed(1) : '--', 'Rating'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _todayStat(String value, String label) {
    return Column(children: [
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
    ]);
  }

  Map<String, dynamic> _periodo(Map<String, dynamic>? map) {
    final m = map;
    if (m == null) return {};
    return {
      'bruto': (m['montoBruto'] as num?) ?? 0,
      'neto': (m['montoNeto'] as num?) ?? 0,
      'comision': (m['comision'] as num?) ?? 0,
    };
  }

  Widget _buildPeriodRow() {
    final hoy = _periodo(_earnings?['hoy'] as Map<String, dynamic>?);
    final semana = _periodo(_earnings?['semana'] as Map<String, dynamic>?);
    final mes = _periodo(_earnings?['mes'] as Map<String, dynamic>?);
    return Row(
      children: [
        Expanded(child: _buildPeriodCard('Hoy', hoy)),
        const SizedBox(width: 8),
        Expanded(child: _buildPeriodCard('Semana', semana)),
        const SizedBox(width: 8),
        Expanded(child: _buildPeriodCard('Mes', mes)),
      ],
    );
  }

  Widget _buildPeriodCard(String label, Map<String, dynamic> p) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Text('\$${_formatAmount(p['neto'])}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _primaryDark)),
          const SizedBox(height: 2),
          Text('neto', style: TextStyle(fontSize: 10, color: _textGrey)),
          const SizedBox(height: 4),
          Text('\$${_formatAmount(p['bruto'])}', style: TextStyle(fontSize: 11, color: _textGrey)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: _textGrey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTotalRow() {
    final viajes = (_stats?['viajes'] as num?)?.toInt() ?? 0;
    final calificacion = (_stats?['calificacion'] as num?) ?? 0;
    final total = _periodo(_earnings?['total'] as Map<String, dynamic>?);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(Icons.route_outlined, '$viajes', 'Viajes\ncompletados'),
          _statItem(Icons.star_rounded, calificacion > 0 ? calificacion.toStringAsFixed(1) : '--', 'Calificación'),
          _statItem(Icons.monetization_on_outlined, '\$${_formatAmount(total['neto'])}', 'Total\nacumulado'),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Column(children: [
      Icon(icon, color: _primaryDark, size: 22),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 9, color: _textGrey), textAlign: TextAlign.center),
    ]);
  }

  Widget _buildHistoryCard() {
    if (_history.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(14)),
        child: const Text('Aún no hay ganancias registradas', style: TextStyle(color: Colors.black45)),
      );
    }
    return Container(
      decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          ..._history.map((h) => _historyItem(h)),
          if (_history.length < _histTotal)
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _loadingMore ? null : _loadMoreHistory,
                child: _loadingMore
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Cargar más'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _historyItem(Map<String, dynamic> h) {
    final viaje = h['viaje'] as Map<String, dynamic>?;
    final origen = viaje?['origen'] as String? ?? '';
    final destino = viaje?['destino'] as String? ?? '';
    final bruto = (h['montoBruto'] as num?) ?? 0;
    final comision = (h['comision'] as num?) ?? 0;
    final neto = (h['montoNeto'] as num?) ?? 0;
    final fecha = h['createdAt'] as String? ?? '';
    String fechaTxt = '';
    if (fecha.isNotEmpty) {
      try {
        final dt = DateTime.tryParse(fecha);
        if (dt != null) fechaTxt = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {}
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  origen.isNotEmpty && destino.isNotEmpty ? '$origen → $destino' : 'Viaje #${h['viajeId']}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  fechaTxt.isNotEmpty ? fechaTxt : (h['id']?.toString() ?? ''),
                  style: TextStyle(fontSize: 11, color: _textGrey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${_formatAmount(neto)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _primaryDark)),
              Text('comisión \$${_formatAmount(comision)}', style: TextStyle(fontSize: 10, color: _textGrey)),
              Text('bruto \$${_formatAmount(bruto)}', style: TextStyle(fontSize: 10, color: _textGrey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPdfCard() {
    if (_downloadingPdf) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(14)),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('Generando PDF...'),
        ]),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Descargar reporte en PDF', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => _downloadPdf('todo', 'Todo'), child: const Text('Todo'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () => _downloadPdf('semana', 'Semana'), child: const Text('Semana'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () => _downloadPdf('mes', 'Mes'), child: const Text('Mes'))),
          ]),
        ],
      ),
    );
  }

  String _estadoCuentaLabel(String? estado) {
    switch (estado) {
      case 'suspension_por_pago': return 'Cuenta suspendida por pago';
      case 'esperando_confirmacion': return 'Comprobante en revisión';
      case 'activa': return 'Cuenta activa';
      default: return estado ?? 'Sin deuda';
    }
  }

  Widget _buildDebtCard() {
    final monto = (_debt?['montoDeuda'] as num?) ?? 0;
    final dias = (_debt?['diasRestantes'] as num?)?.toInt() ?? 0;
    final estado = _debt?['estadoCuenta'] as String?;
    final nequiNumero = _debt?['nequiNumero'] as String?;
    final nequiNombre = _debt?['nequiNombre'] as String?;
    final sinDeuda = (monto <= 0) && (estado == null || estado == 'activa');

    if (sinDeuda) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(14)),
        child: const Row(children: [
          Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50), size: 20),
          SizedBox(width: 10),
          Expanded(child: Text('No tienes deudas pendientes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
        ]),
      );
    }

    final estadoColor = estado == 'suspension_por_pago' ? Colors.red.shade700 : Colors.orange.shade800;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.account_balance_wallet_outlined, color: estadoColor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Deuda pendiente', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text(_estadoCuentaLabel(estado), style: TextStyle(fontSize: 11, color: _textGrey)),
              ]),
            ),
            Text('\$${_formatAmount(monto)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: estadoColor)),
          ]),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10)),
            child: Text(
              'Tienes un plazo de 15 días para pagar tu deuda (restan $dias día${dias == 1 ? '' : 's'}). '
              'Pasado ese plazo tu cuenta podría ser suspendida.',
              style: TextStyle(fontSize: 12, color: const Color(0xFFBF360C), height: 1.4),
            ),
          ),
          if (nequiNumero != null && nequiNumero.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Paga por Nequi: ${nequiNombre != null ? '$nequiNombre — ' : ''}$nequiNumero',
              style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A2E)),
            ),
          ],
          if (estado == 'suspension_por_pago') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _uploading ? null : _uploadProof,
                icon: _uploading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_file, size: 18),
                label: Text(_uploading ? 'Subiendo...' : 'Subir comprobante de pago'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatAmount(num amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}k';
    }
    return amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2);
  }
}