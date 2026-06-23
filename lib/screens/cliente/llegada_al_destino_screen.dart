import 'package:flutter/material.dart';

class LlegadaAlDestinoScreen extends StatelessWidget {
  final Map<String, dynamic> conductor;
  final Map<String, dynamic> trip;
  final VoidCallback onVerDetalle;

  const LlegadaAlDestinoScreen({
    super.key,
    required this.conductor,
    required this.trip,
    required this.onVerDetalle,
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
          'Llegada al destino',
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          _MapSection(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DriverCard(conductor: conductor),
                  const SizedBox(height: 16),
                  const Text(
                    'El conductor ha llegado al destino.\nPor favor verifica tu carga.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4B5563),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Foto de evidencia',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _EvidencePhoto(fotoUrl: trip['fotoEntrega'] as String?),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: onVerDetalle,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Ver detalle',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      color: const Color(0xFFE8EDF2),
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(double.infinity, 220),
            painter: _MapGridPainter(),
          ),
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_shipping,
                color: Color(0xFF2563EB),
                size: 24,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 28,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  CustomPaint(
                    size: const Size(12, 8),
                    painter: _PinTailPainter(color: const Color(0xFFEF4444)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCDD5DE)
      ..strokeWidth = 0.8;

    for (final y in [45.0, 90.0, 135.0, 180.0]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (final x in [
      size.width * 0.15,
      size.width * 0.35,
      size.width * 0.60,
      size.width * 0.80,
    ]) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    final blockPaint = Paint()..color = const Color(0xFFD1E8D0);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.15, 45, size.width * 0.2, 45), blockPaint);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.60, 90, size.width * 0.2, 45), blockPaint);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.35, 135, size.width * 0.25, 45), blockPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DriverCard extends StatelessWidget {
  final Map<String, dynamic> conductor;
  const _DriverCard({required this.conductor});

  @override
  Widget build(BuildContext context) {
    final nombre = conductor['nombre'] as String? ?? 'Conductor';
    final rating = (conductor['rating'] as num?)?.toStringAsFixed(1) ?? '0.0';

    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE5E7EB),
            border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
          ),
          child: const ClipOval(
            child: Icon(Icons.person, size: 32, color: Color(0xFF9CA3AF)),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nombre,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star, color: Color(0xFFFBBF24), size: 16),
                const SizedBox(width: 4),
                Text(
                  rating,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _EvidencePhoto extends StatelessWidget {
  final String? fotoUrl;
  const _EvidencePhoto({this.fotoUrl});

  @override
  Widget build(BuildContext context) {
    if (fotoUrl != null && fotoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          fotoUrl!,
          width: double.infinity,
          height: 160,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildMockPhoto(),
        ),
      );
    }
    return _buildMockPhoto();
  }

  Widget _buildMockPhoto() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: 160,
        color: const Color(0xFFD1D5DB),
        child: CustomPaint(painter: _EvidencePainter()),
      ),
    );
  }
}

class _EvidencePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF93C5FD), const Color(0xFFBFDBFE)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.5));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.5), skyPaint);

    final groundPaint = Paint()..color = const Color(0xFF9CA3AF);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5),
      groundPaint,
    );

    final truckPaint = Paint()..color = const Color(0xFFF9FAFB);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.05, size.height * 0.25, size.width * 0.55, size.height * 0.45),
        const Radius.circular(4),
      ),
      truckPaint,
    );

    final cabinPaint = Paint()..color = const Color(0xFF374151);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.6, size.height * 0.35, size.width * 0.2, size.height * 0.35),
        const Radius.circular(4),
      ),
      cabinPaint,
    );

    final windowPaint = Paint()..color = const Color(0xFF93C5FD);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.62, size.height * 0.37, size.width * 0.14, size.height * 0.14),
        const Radius.circular(2),
      ),
      windowPaint,
    );

    final wheelPaint = Paint()..color = const Color(0xFF111827);
    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.73), size.height * 0.08, wheelPaint);
    canvas.drawCircle(Offset(size.width * 0.42, size.height * 0.73), size.height * 0.08, wheelPaint);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.73), size.height * 0.07, wheelPaint);

    final box1 = Paint()..color = const Color(0xFFD97706);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.72, size.height * 0.28, size.width * 0.12, size.height * 0.22),
        const Radius.circular(2),
      ),
      box1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.82, size.height * 0.34, size.width * 0.14, size.height * 0.16),
        const Radius.circular(2),
      ),
      box1..color = const Color(0xFFF59E0B),
    );

    final linePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width * 0.78, size.height * 0.28),
      Offset(size.width * 0.78, size.height * 0.5),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
