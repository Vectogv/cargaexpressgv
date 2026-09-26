import 'package:flutter/material.dart';
import '../../services/api/http_client.dart';
import 'admin_common.dart';
import '../../core/formato_dinero.dart';

/// Disputa tal como la devuelve GET /api/admin/disputes:
/// {id, viajeId, conductorId, clienteId, versionConductor, versionCliente,
///  soporteCliente, fotos[], estado, resultado, viaje{origen,destino,montoFinal},
///  conductor{id,nombre,placa}, cliente{id,nombre,email}, createdAt}
class Dispute {
  final String id;
  final String title;
  final String user;
  final String status;
  final String description;
  final String versionConductor;
  final String conductor;
  final String ruta;
  final num? montoFinal;
  final List<String> fotos;

  const Dispute({
    required this.id,
    required this.title,
    required this.user,
    required this.status,
    required this.description,
    this.versionConductor = '',
    this.conductor = '',
    this.ruta = '',
    this.montoFinal,
    this.fotos = const [],
  });

  factory Dispute.fromJson(Map<String, dynamic> json) {
    final viaje = json['viaje'] is Map ? json['viaje'] as Map : const {};
    final cliente = json['cliente'] is Map ? json['cliente'] as Map : const {};
    final conductor = json['conductor'] is Map ? json['conductor'] as Map : const {};
    final fotos = <String>[
      if (json['soporteCliente'] is String) json['soporteCliente'] as String,
      ...(json['fotos'] is List ? (json['fotos'] as List).whereType<String>() : const <String>[]),
    ];
    final origen = viaje['origen']?.toString() ?? '';
    final destino = viaje['destino']?.toString() ?? '';
    final monto = viaje['montoFinal'];
    return Dispute(
      id: json['id']?.toString() ?? '',
      title: 'Viaje #${json['viajeId'] ?? ''}',
      user: cliente['nombre']?.toString() ?? cliente['email']?.toString() ?? '',
      status: json['estado']?.toString() ?? 'abierta',
      description: json['versionCliente']?.toString() ?? '',
      versionConductor: json['versionConductor']?.toString() ?? '',
      conductor: [conductor['nombre'], conductor['placa']]
          .where((e) => e != null && e.toString().isNotEmpty)
          .join(' · '),
      ruta: origen.isEmpty && destino.isEmpty ? '' : '$origen → $destino',
      montoFinal: monto is num ? monto : num.tryParse('${monto ?? ''}'),
      fotos: fotos,
    );
  }
}

class DisputesScreen extends StatefulWidget {
  const DisputesScreen({super.key});

  @override
  State<DisputesScreen> createState() => _DisputesScreenState();
}

class _DisputesScreenState extends State<DisputesScreen> {
  List<Dispute> _disputes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDisputes();
  }

  Future<void> _fetchDisputes() async {
    setState(() => _isLoading = true);
    try {
      final data = await HttpClient.getList('/api/admin/disputes', auth: true);
      if (!mounted) return;
      setState(() {
        _disputes = adminMapList(data).map(Dispute.fromJson).toList();
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = adminErrorText(e);
        _isLoading = false;
      });
    }
  }

  /// PUT /api/admin/disputes/:id/resolve {resultado: favor_conductor|favor_cliente,
  /// acuerdoDePago?, montoDeuda?}
  Future<void> _resolveDispute(Dispute dispute) async {
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ResolveDialog(montoSugerido: dispute.montoFinal),
    );
    if (body == null) return;

    try {
      await HttpClient.put('/api/admin/disputes/${dispute.id}/resolve', body: body, auth: true);
      adminSnack(this, 'Disputa resuelta', color: const Color(0xFF2E7D32));
      _fetchDisputes();
    } catch (e) {
      adminSnack(this, adminErrorText(e), error: true);
    }
  }

  void _showDetail(Dispute d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            Text(d.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            if (d.ruta.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(d.ruta, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
            if (d.montoFinal != null)
              Text('Monto final: ${formatearPesos(d.montoFinal)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 16),
            _DetailBlock(title: 'Cliente: ${d.user}', text: d.description),
            _DetailBlock(title: 'Conductor: ${d.conductor}', text: d.versionConductor),
            if (d.fotos.isNotEmpty) ...[
              const Text('Soportes', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              // URLs firmadas (1 h): se resuelven con resolveMediaUrl.
              for (final f in d.fotos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AdminDocImage(f, height: 220, width: double.infinity, fit: BoxFit.contain),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'resuelta':
        return const Color(0xFF2E7D32);
      case 'en_revision':
        return const Color(0xFF1565C0);
      case 'abierta':
      default:
        return const Color(0xFFE65100);
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'resuelta':
        return const Color(0xFFE8F5E9);
      case 'en_revision':
        return const Color(0xFFE3F2FD);
      case 'abierta':
      default:
        return const Color(0xFFFFF3E0);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'resuelta':
        return Icons.check_circle_rounded;
      case 'en_revision':
        return Icons.manage_search_rounded;
      case 'abierta':
      default:
        return Icons.schedule_rounded;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'resuelta':
        return 'Resuelta';
      case 'en_revision':
        return 'En revisión';
      case 'abierta':
      default:
        return 'Abierta';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        title: const Text(
          'Disputas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1A1A2E)),
            onPressed: _fetchDisputes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchDisputes,
              child: _disputes.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(32),
                      children: [
                        Center(
                          child: Text(
                            _error ?? 'Sin disputas abiertas',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _error != null ? Colors.red : Colors.black54),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _disputes.length,
                      itemBuilder: (context, index) => _buildDisputeCard(_disputes[index]),
                    ),
            ),
    );
  }

  Widget _buildDisputeCard(Dispute dispute) {
    final color = _statusColor(dispute.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.4)]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'D-${dispute.id}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                            fontFamily: 'Courier',
                          ),
                        ),
                      ),
                      if (dispute.fotos.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.photo_library_outlined, size: 14, color: Colors.grey.shade600),
                        Text(' ${dispute.fotos.length}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _statusBg(dispute.status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_statusIcon(dispute.status), size: 12, color: color),
                            const SizedBox(width: 4),
                            Text(
                              _statusLabel(dispute.status),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    dispute.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  if (dispute.ruta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(dispute.ruta,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        'Cliente: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          dispute.user,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1A1A2E),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(Icons.description_outlined, size: 13, color: Colors.grey.shade500),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          dispute.description.isNotEmpty ? dispute.description : 'Sin versión del cliente',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF555555),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showDetail(dispute),
                          icon: const Icon(Icons.visibility_outlined, size: 14),
                          label: const Text('Ver'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF667EEA),
                            side: const BorderSide(color: Color(0xFF667EEA), width: 1),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: dispute.status == 'resuelta' ? null : () => _resolveDispute(dispute),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                          label: const Text('Resolver'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF667EEA),
                            disabledBackgroundColor: Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  final String title;
  final String text;
  const _DetailBlock({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(text.isNotEmpty ? text : 'Sin versión registrada',
              style: const TextStyle(fontSize: 13, color: Color(0xFF555555), height: 1.4)),
        ],
      ),
    );
  }
}

/// Diálogo de resolución: devuelve el body para PUT .../resolve o null.
class _ResolveDialog extends StatefulWidget {
  final num? montoSugerido;
  const _ResolveDialog({this.montoSugerido});

  @override
  State<_ResolveDialog> createState() => _ResolveDialogState();
}

class _ResolveDialogState extends State<_ResolveDialog> {
  String _resultado = 'favor_conductor';
  bool _acuerdoDePago = false;
  late final TextEditingController _montoCtrl =
      TextEditingController(text: widget.montoSugerido?.toString() ?? '');

  @override
  void dispose() {
    _montoCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final body = <String, dynamic>{'resultado': _resultado};
    if (_resultado == 'favor_conductor' && _acuerdoDePago) {
      final monto = num.tryParse(_montoCtrl.text.trim().replaceAll(',', '.'));
      if (monto == null || monto <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresa un monto de deuda válido')),
        );
        return;
      }
      body['acuerdoDePago'] = true;
      body['montoDeuda'] = monto;
    }
    Navigator.pop(context, body);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Resolver disputa'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resultado', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'favor_conductor', label: Text('Conductor')),
                ButtonSegment(value: 'favor_cliente', label: Text('Cliente')),
              ],
              selected: {_resultado},
              onSelectionChanged: (s) => setState(() => _resultado = s.first),
            ),
            if (_resultado == 'favor_conductor') ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Generar acuerdo de pago (10 días)'),
                value: _acuerdoDePago,
                onChanged: (v) => setState(() => _acuerdoDePago = v),
              ),
              if (_acuerdoDePago)
                TextField(
                  controller: _montoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Monto de la deuda',
                    border: OutlineInputBorder(),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Resolver')),
      ],
    );
  }
}
