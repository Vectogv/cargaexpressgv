import 'package:flutter/material.dart';

class ResumenViajeData {
  final String origen;
  final String destino;
  final String distanciaTotal;
  final String duracionTotal;
  final String precioAcordado;
  final String comision;
  final String porcentajeComision;
  final String gananciaTotal;
  final String pagoRecibido;

  const ResumenViajeData({
    required this.origen,
    required this.destino,
    required this.distanciaTotal,
    required this.duracionTotal,
    required this.precioAcordado,
    required this.comision,
    required this.porcentajeComision,
    required this.gananciaTotal,
    required this.pagoRecibido,
  });
}

class ResumenViajeScreen extends StatelessWidget {
  final ResumenViajeData data;
  final VoidCallback? onVolverInicio;

  const ResumenViajeScreen({
    super.key,
    this.data = const ResumenViajeData(
      origen: 'Av. Principal, Caracas',
      destino: 'Valencia, Zona Industrial',
      distanciaTotal: '28.6 km',
      duracionTotal: '38 min',
      precioAcordado: '\$55.000',
      comision: '- \$5.500',
      porcentajeComision: '10%',
      gananciaTotal: '\$49.500',
      pagoRecibido: 'Efectivo',
    ),
    this.onVolverInicio,
  });

  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _green = Color(0xFF16A34A);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _divider = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: _buildResumenList(),
            ),
          ),
          _buildBottomButton(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'Resumen del viaje',
        style: TextStyle(
          color: Color(0xFF111827),
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF111827), size: 20),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }

  Widget _buildResumenList() {
    final rows = [
      _RowData(label: 'Origen', value: data.origen),
      _RowData(label: 'Destino', value: data.destino),
      _RowData(label: 'Distancia total', value: data.distanciaTotal),
      _RowData(label: 'Duración total', value: data.duracionTotal),
      _RowData(label: 'Precio acordado', value: data.precioAcordado),
      _RowData(
          label: 'Comisión (${data.porcentajeComision})',
          value: data.comision,
          valueColor: _textSecondary),
      _RowData(
          label: 'Ganancia total',
          value: data.gananciaTotal,
          labelColor: _green,
          valueColor: _green,
          bold: true),
      _RowData(label: 'Pago recibido', value: data.pagoRecibido),
    ];

    return Column(
      children: List.generate(rows.length * 2 - 1, (i) {
        if (i.isOdd) {
          return const Divider(
              color: _divider, height: 1, indent: 20, endIndent: 20);
        }
        return _buildRow(rows[i ~/ 2]);
      }),
    );
  }

  Widget _buildRow(_RowData row) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.label,
            style: TextStyle(
              fontSize: 14,
              color: row.labelColor ?? _textSecondary,
              fontWeight:
                  row.bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              row.value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                color: row.valueColor ?? _textPrimary,
                fontWeight:
                    row.bold ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onVolverInicio,
          style: OutlinedButton.styleFrom(
            foregroundColor: _accentBlue,
            disabledForegroundColor: const Color(0xFFD1D5DB),
            padding: const EdgeInsets.symmetric(vertical: 15),
            side: const BorderSide(color: _divider, width: 1.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text(
            'Volver al inicio',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _RowData {
  final String label;
  final String value;
  final Color? labelColor;
  final Color? valueColor;
  final bool bold;

  const _RowData({
    required this.label,
    required this.value,
    this.labelColor,
    this.valueColor,
    this.bold = false,
  });
}
