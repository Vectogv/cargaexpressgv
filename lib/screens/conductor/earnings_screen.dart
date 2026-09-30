import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/api_client.dart';
import '../../services/api/http_client.dart' show ApiException;
import '../../services/api/payment_service.dart';
import 'aviso_cuenta_pago.dart' show formatoDinero, numeroDe;
import '../../core/formato_dinero.dart';
import '../shared/ui_compartida.dart';

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
  // Ganancias de la semana en curso, para las barras por día.
  List<Map<String, dynamic>> _semana = [];
  int _histTotal = 0;
  int _histPage = 0;

  bool _loading = true;
  bool _loadingMore = false;
  bool _uploading = false;
  bool _downloadingPdf = false;


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
        ApiClient.instance.getEarningsHistory(periodo: 'semana', page: 1, limit: 100),
      ]);
      final historyData = results[4];
      if (mounted) {
        setState(() {
          _earnings = results[0];
          _stats = results[1];
          _today = results[2];
          _debt = results[3];
          _history = (historyData['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _semana = (results[5]['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
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

  /// Descargas pública de Android: en 11+ se crea sin permiso, en 10 lo
  /// permite `requestLegacyExternalStorage` y en 9 o menos pide el permiso.
  Future<void> _guardarEnDescargas(String nombre, List<int> bytes) async {
    final file = File('/storage/emulated/0/Download/$nombre');
    try {
      await file.writeAsBytes(bytes, flush: true);
    } on FileSystemException {
      if (!await Permission.storage.request().isGranted) {
        throw Exception('Permite el acceso al almacenamiento para guardar el PDF en Descargas');
      }
      await file.writeAsBytes(bytes, flush: true);
    }
  }

  Future<void> _downloadPdf(String periodo, String label) async {
    if (_downloadingPdf) return;
    setState(() => _downloadingPdf = true);
    try {
      final bytes = await ApiClient.instance.getEarningsPdf(periodo: periodo);
      final a = DateTime.now();
      String dd(int n) => n.toString().padLeft(2, '0');
      final nombre = 'CargaExpress_ganancias_${periodo}_${a.year}-${dd(a.month)}-${dd(a.day)}_${dd(a.hour)}${dd(a.minute)}.pdf';
      await _guardarEnDescargas(nombre, bytes);
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('PDF guardado en Descargas'),
            content: Text('Reporte de ganancias ($label):\n$nombre\n\nÁbrelo desde Archivos → Descargas.'),
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
      // image_picker la recomprime a JPEG → extensión .jpg.
      await PaymentService.uploadProof(bytes: bytes, filename: 'comprobante_${DateTime.now().millisecondsSinceEpoch}.jpg');
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
        // 422: ya hay un comprobante en revisión o la deuda quedó en cero:
        // se trae el estado real para que el botón no siga ahí.
        if (e is ApiException && e.statusCode == 422) {
          try {
            final debt = await ApiClient.instance.getDebt();
            if (mounted) setState(() => _debt = debt);
          } catch (_) {}
        }
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
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
                      // Espacio para la barra de navegación del teléfono: el
                      // botón "Subir comprobante" quedaba tapado e inalcanzable.
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Con deuda, lo primero es cómo pagarla ("Ver cómo
                          // pagar" abre esta pantalla).
                          if (_tieneDeuda) ...[
                            _buildSectionTitle('Deuda'),
                            const SizedBox(height: 8),
                            _buildDebtCard(),
                            const SizedBox(height: 16),
                          ],
                          _buildTodayCard(),
                          const SizedBox(height: 16),
                          _buildSectionTitle('Esta semana'),
                          const SizedBox(height: 8),
                          _buildSemanaCard(),
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
                          if (!_tieneDeuda) ...[
                            const SizedBox(height: 16),
                            _buildSectionTitle('Deuda'),
                            const SizedBox(height: 8),
                            _buildDebtCard(),
                          ],
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
      padding: const EdgeInsets.only(top: 44, left: 16, right: 16, bottom: 14),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: ColoresApp.borde))),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new, size: 20, color: ColoresApp.textoOscuro),
          ),
          const SizedBox(width: 12),
          const Text('Ganancias', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: ColoresApp.textoOscuro)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ColoresApp.textoOscuro));
  }

  Widget _buildTodayCard() {
    final viajesHoy = (_today?['viajesHoy'] as num?)?.toInt() ?? 0;
    final horasOnline = (_today?['horasOnline'] as num?)?.toDouble() ?? 0;
    final gananciasHoy = (_today?['gananciasHoy'] as num?) ?? 0;
    final netaHoy = (_today?['netaHoy'] as num?) ?? 0;
    final calificacion = (_today?['calificacion'] as num?) ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: ColoresApp.azulOscuro, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hoy', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(_pesos(netaHoy), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, fontFeatures: cifrasTabulares)),
          const SizedBox(height: 4),
          Text('$viajesHoy viajes completados · neto', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _todayStat('${horasOnline.toStringAsFixed(1)}h', 'Online'),
              _todayStat(_pesos(gananciasHoy), 'Bruto'),
              _todayStat(calificacion > 0 ? calificacion.toStringAsFixed(1) : '--', 'Rating'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _todayStat(String value, String label) {
    return Column(children: [
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, fontFeatures: cifrasTabulares)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
    ]);
  }

  /// Barras L–D con el neto de cada día de la semana en curso; la de hoy en azul.
  Widget _buildSemanaCard() {
    final porDia = List<double>.filled(7, 0);
    for (final g in _semana) {
      final dt = DateTime.tryParse(g['createdAt'] as String? ?? '')?.toLocal();
      if (dt != null) porDia[dt.weekday - 1] += (montoDe(g['montoNeto']) ?? 0).toDouble();
    }
    final maximo = porDia.fold<double>(0, (m, v) => v > m ? v : m);
    final hoy = DateTime.now().weekday - 1;
    const dias = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final semana = _periodo(_earnings?['semana'] as Map<String, dynamic>?);
    return TarjetaBlanca(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_pesos(semana['neto']), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ColoresApp.textoOscuro, fontFeatures: cifrasTabulares)),
          const Text('neto esta semana', style: TextStyle(fontSize: 12, color: ColoresApp.textoSecundario)),
          const SizedBox(height: 14),
          SizedBox(
            height: 72,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: maximo > 0 ? 4 + 52 * porDia[i] / maximo : 4,
                            decoration: BoxDecoration(
                              color: i == hoy ? ColoresApp.azul : const Color(0xFFDCE6F8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(dias[i], style: TextStyle(fontSize: 11, fontWeight: i == hoy ? FontWeight.w700 : FontWeight.w500, color: i == hoy ? ColoresApp.azul : ColoresApp.textoSecundario)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
    return TarjetaBlanca(
      radio: 14,
      child: Column(
        children: [
          // Montos grandes en columnas angostas: se encogen, nunca se parten ni
          // se truncan (un monto truncado se lee como otra cifra).
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_pesos(p['neto']), maxLines: 1, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: ColoresApp.azulOscuro, fontFeatures: cifrasTabulares)),
          ),
          const SizedBox(height: 2),
          Text('neto', style: TextStyle(fontSize: 10, color: ColoresApp.textoSecundario)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('Bruto ${_pesos(p['bruto'])}', maxLines: 1, style: TextStyle(fontSize: 11, color: ColoresApp.textoSecundario, fontFeatures: cifrasTabulares)),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('Comisión -${_pesos(p['comision'])}', maxLines: 1, style: TextStyle(fontSize: 11, color: Colors.red.shade400, fontFeatures: cifrasTabulares)),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: ColoresApp.textoSecundario, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTotalRow() {
    final viajes = (_stats?['viajes'] as num?)?.toInt() ?? 0;
    final calificacion = (_stats?['calificacion'] as num?) ?? 0;
    final total = _periodo(_earnings?['total'] as Map<String, dynamic>?);
    return TarjetaBlanca(
      radio: 14,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(Icons.route_outlined, '$viajes', 'Viajes\ncompletados'),
          _statItem(Icons.star_rounded, calificacion > 0 ? calificacion.toStringAsFixed(1) : '--', 'Calificación'),
          _statItem(Icons.monetization_on_outlined, _pesos(total['neto']), 'Total\nacumulado'),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    // Expanded: sin ancho fijo el FittedBox de abajo no tendría contra qué encogerse.
    return Expanded(child: Column(children: [
      Icon(icon, color: ColoresApp.azulOscuro, size: 22),
      const SizedBox(height: 6),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(value, maxLines: 1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ColoresApp.textoOscuro, fontFeatures: cifrasTabulares)),
      ),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 9, color: ColoresApp.textoSecundario), textAlign: TextAlign.center),
    ]));
  }

  Widget _buildHistoryCard() {
    if (_history.isEmpty) {
      return const TarjetaBlanca(
        radio: 14,
        padding: EdgeInsets.all(20),
        child: Text('Aún no hay ganancias registradas', style: TextStyle(color: ColoresApp.textoSecundario)),
      );
    }
    return Column(
        children: [
          for (final h in _history) Padding(padding: const EdgeInsets.only(bottom: 8), child: _historyItem(h)),
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
        if (dt != null) {
          final d = dt.toLocal();
          fechaTxt = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} · '
              '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
        }
      } catch (_) {}
    }
    return TarjetaBlanca(
      radio: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  origen.isNotEmpty && destino.isNotEmpty ? '$origen → $destino' : 'Viaje #${h['viajeId']}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColoresApp.textoOscuro),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  fechaTxt.isNotEmpty ? fechaTxt : (h['id']?.toString() ?? ''),
                  style: const TextStyle(fontSize: 11, color: ColoresApp.textoSecundario, fontFeatures: cifrasTabulares),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+${_pesos(neto)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ColoresApp.verde, fontFeatures: cifrasTabulares)),
              Text('comisión ${_pesos(comision)}', style: const TextStyle(fontSize: 10, color: ColoresApp.textoSecundario, fontFeatures: cifrasTabulares)),
              Text('bruto ${_pesos(bruto)}', style: const TextStyle(fontSize: 10, color: ColoresApp.textoSecundario, fontFeatures: cifrasTabulares)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPdfCard() {
    if (_downloadingPdf) {
      return const TarjetaBlanca(
        radio: 14,
        padding: EdgeInsets.all(16),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('Generando PDF...'),
        ]),
      );
    }
    return TarjetaBlanca(
      radio: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Descargar reporte en PDF', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ColoresApp.textoOscuro)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: BotonSecundario(texto: 'Todo', alto: 44, onPressed: () => _downloadPdf('todo', 'Todo'))),
            const SizedBox(width: 8),
            Expanded(child: BotonSecundario(texto: 'Semana', alto: 44, onPressed: () => _downloadPdf('semana', 'Semana'))),
            const SizedBox(width: 8),
            Expanded(child: BotonSecundario(texto: 'Mes', alto: 44, onPressed: () => _downloadPdf('mes', 'Mes'))),
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

  bool get _tieneDeuda {
    final monto = numeroDe(_debt?['montoDeuda']) ?? 0;
    final estado = _debt?['estadoCuenta'] as String?;
    return monto > 0 || (estado != null && estado != 'activa');
  }

  /// "Paga antes del 08/10/2026" con la fecha límite real del backend
  /// (antes decía un "plazo de 15 días" fijo que no coincidía con el inicio).
  String? _fechaLimiteTexto(dynamic raw) {
    final f = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (f == null) return null;
    String dos(int n) => n.toString().padLeft(2, '0');
    return 'Paga antes del ${dos(f.day)}/${dos(f.month)}/${f.year}';
  }

  Widget _buildDebtCard() {
    final monto = numeroDe(_debt?['montoDeuda']) ?? 0;
    final dias = numeroDe(_debt?['diasRestantes'])?.toInt() ?? 0;
    final estado = _debt?['estadoCuenta'] as String?;
    // Monto del comprobante en revisión (null si no hay uno).
    final comprobante = numeroDe(_debt?['montoComprobante']);
    final nequiNumero = _debt?['nequiNumero'] as String?;
    final nequiNombre = _debt?['nequiNombre'] as String?;
    final sinDeuda = (monto <= 0) && (estado == null || estado == 'activa');

    if (sinDeuda) {
      return const TarjetaBlanca(
        radio: 14,
        padding: EdgeInsets.all(16),
        child: Row(children: [
          Icon(Icons.check_circle_outline, color: ColoresApp.verde, size: 20),
          SizedBox(width: 10),
          Expanded(child: Text('No tienes deudas pendientes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ColoresApp.textoOscuro))),
        ]),
      );
    }

    final estadoColor = estado == 'suspension_por_pago' ? ColoresApp.rojo : ColoresApp.naranjaTexto;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColoresApp.naranjaBorde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.account_balance_wallet_outlined, color: estadoColor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Deuda pendiente', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ColoresApp.textoOscuro)),
                Text(_estadoCuentaLabel(estado), style: TextStyle(fontSize: 11, color: ColoresApp.textoSecundario)),
              ]),
            ),
            Text(_pesos(monto), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: estadoColor, fontFeatures: cifrasTabulares)),
          ]),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: ColoresApp.naranjaFondo, borderRadius: BorderRadius.circular(10)),
            child: Text(
              '${_fechaLimiteTexto(_debt?['deudaFechaLimite']) ?? 'Tienes un plazo para pagar tu deuda'} '
              '(restan $dias día${dias == 1 ? '' : 's'}). '
              'Pasado ese plazo tu cuenta podría ser suspendida.',
              style: const TextStyle(fontSize: 12, color: ColoresApp.naranjaAviso, height: 1.4),
            ),
          ),
          if (estado == 'esperando_confirmacion' && comprobante != null && comprobante > 0) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: ColoresApp.azulTenue, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'Comprobante en revisión por ${formatoDinero(comprobante)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ColoresApp.azulOscuro),
                ),
                if (monto > comprobante) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Tu deuda actual es ${formatoDinero(monto)}: los ${formatoDinero(monto - comprobante)} adicionales '
                    'son comisiones de viajes terminados mientras se revisa el comprobante. '
                    'Seguirán pendientes cuando se apruebe el pago.',
                    style: const TextStyle(fontSize: 12, color: ColoresApp.azulOscuro, height: 1.4),
                  ),
                ],
              ]),
            ),
          ],
          if (nequiNumero != null && nequiNumero.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Paga por Nequi: ${nequiNombre != null ? '$nequiNombre — ' : ''}$nequiNumero',
              style: const TextStyle(fontSize: 12, color: ColoresApp.textoOscuro),
            ),
          ],
          if (puedeSubirComprobante(_debt)) ...[
            const SizedBox(height: 12),
            BotonPrincipal(
              texto: _uploading ? 'Subiendo...' : 'Subir comprobante de pago',
              icono: Icons.upload_file,
              cargando: _uploading,
              color: ColoresApp.naranja,
              alto: 48,
              onPressed: _uploading ? null : _uploadProof,
            ),
          ],
        ],
      ),
    );
  }

  /// "$12.000" (los montos del backend pueden venir como texto decimal).
  String _pesos(dynamic v) => formatearPesos(montoDe(v) ?? 0);
}
