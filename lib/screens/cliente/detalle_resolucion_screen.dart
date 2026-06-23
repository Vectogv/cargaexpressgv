import 'package:flutter/material.dart';

class DetalleResolucionScreen extends StatelessWidget {
  final String disputeNumber;
  final String problema;
  final String resultado;
  final String reembolso;
  final String comentarioAdmin;
  final String fechaResolucion;
  final VoidCallback onVolver;

  const DetalleResolucionScreen({
    super.key,
    this.disputeNumber = 'DIS-2024-0610-0012',
    this.problema = 'La carga lleg\u00f3 da\u00f1ada',
    this.resultado = 'A favor del cliente',
    this.reembolso = '\$20.000',
    this.comentarioAdmin =
        'Despu\u00e9s de revisar las evidencias proporcionadas, '
        'se confirma que el producto presentaba da\u00f1os '
        'al momento de la entrega. Se procede con el reembolso '
        'parcial del valor acordado.',
    this.fechaResolucion = '15 de junio, 2024',
    required this.onVolver,
  });

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
          'Detalle de resoluci\u00f3n',
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionCard(
              children: [
                _InfoRow(label: 'N\u00famero de disputa', value: disputeNumber),
                const SizedBox(height: 10),
                _InfoRow(label: 'Problema reportado', value: problema),
                const SizedBox(height: 10),
                _InfoRow(label: 'Fecha de resoluci\u00f3n', value: fechaResolucion),
              ],
            ),
            const SizedBox(height: 20),
            _SectionCard(
              children: [
                const Text(
                  'Resultado',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    resultado,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF22C55E)),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE5E7EB), thickness: 1, height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Reembolso', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black)),
                    Text(
                      reembolso,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF22C55E)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionCard(
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.admin_panel_settings, color: Color(0xFF2563EB), size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Comentario del administrador',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                  ),
                  child: Text(
                    comentarioAdmin,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onVolver,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Volver al inicio',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
      ],
    );
  }
}
