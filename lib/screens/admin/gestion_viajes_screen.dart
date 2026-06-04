import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/api_client.dart';

class ViajesScreen extends StatefulWidget {
  const ViajesScreen({super.key});

  @override
  State<ViajesScreen> createState() => _ViajesScreenState();
}

class _ViajesScreenState extends State<ViajesScreen> {
  int _selectedIndex = 1;
  bool _loading = true;
  List<Map<String, dynamic>> _viajes = [];
  String _filtro = 'todos';

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${ApiClient.instance.token}',
  };

  @override
  void initState() {
    super.initState();
    _fetchViajes();
  }

  Future<void> _fetchViajes() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/trips'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          _viajes = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      } else {
        _useFallback();
      }
    } catch (_) {
      _useFallback();
    }
  }

  void _useFallback() {
    setState(() {
      _viajes = [
        {
          'id': 1,
          'tipo': 'Status',
          'fecha': '14 de. 23. 2023',
          'pasajeros': 15,
          'estado': 'En Curso',
          'conductor': 'Nasser Nemes',
          'showMap': true,
          'origen': 'Bogotá Centro',
          'destino': 'Aeropuerto El Dorado',
          'lat': 4.7110,
          'lng': -74.0721,
        },
        {
          'id': 2,
          'tipo': 'Fecha',
          'fecha': '11 de. 23. 2023',
          'pasajeros': 28,
          'estado': 'En Envío',
          'conductor': 'Denver Names',
          'conductorEstado': 'En Curso',
          'showMap': false,
          'origen': 'Suba',
          'destino': 'Chapinero',
        },
        {
          'id': 3,
          'tipo': 'Status',
          'fecha': '15 de. 23. 2023',
          'pasajeros': 31,
          'estado': 'Finalizado',
          'conductor': 'Laura Mora',
          'showMap': false,
          'origen': 'Usaquén',
          'destino': 'Kennedy',
        },
        {
          'id': 4,
          'tipo': 'Fecha',
          'fecha': '16 de. 23. 2023',
          'pasajeros': 9,
          'estado': 'Pendiente',
          'conductor': 'Mario Gómez',
          'showMap': false,
          'origen': 'Bosa',
          'destino': 'Fontibón',
        },
      ];
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_filtro == 'todos') return _viajes;
    return _viajes
        .where((v) =>
            (v['estado'] as String).toLowerCase() ==
            _filtro.toLowerCase())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildFiltros(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtrados.isEmpty
                      ? const Center(
                          child: Text('Sin viajes',
                              style: TextStyle(color: Colors.black45)))
                      : RefreshIndicator(
                          onRefresh: _fetchViajes,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            itemCount: _filtrados.length,
                            itemBuilder: (_, i) => _ViajeCard(
                              viaje: _filtrados[i],
                              isLast: i == _filtrados.length - 1,
                            ),
                          ),
                        ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: const Color(0xFFF2F3F7),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left,
                color: Colors.black87, size: 26),
            onPressed: () => Navigator.maybePop(context),
          ),
          const Text(
            'VIAJES / SERVICIOS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            icon:
                const Icon(Icons.refresh, color: Colors.black45, size: 20),
            onPressed: _fetchViajes,
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    final filtros = [
      {'key': 'todos', 'label': 'Todos'},
      {'key': 'En Curso', 'label': 'En Curso'},
      {'key': 'En Envío', 'label': 'En Envío'},
      {'key': 'Pendiente', 'label': 'Pendiente'},
      {'key': 'Finalizado', 'label': 'Finalizado'},
    ];
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filtros.length,
        itemBuilder: (_, i) {
          final selected = _filtro == filtros[i]['key'];
          return GestureDetector(
            onTap: () => setState(() => _filtro = filtros[i]['key']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? Colors.black87 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  if (!selected)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                    ),
                ],
              ),
              child: Text(
                filtros[i]['label']!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.black54,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.route_rounded, 'label': 'Viajes'},
      {'icon': Icons.directions_car_rounded, 'label': 'Drivers'},
      {'icon': Icons.person_rounded, 'label': 'Perfil'},
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final selected = _selectedIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedIndex = i),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(items[i]['icon'] as IconData,
                    size: 22,
                    color: selected ? Colors.black87 : Colors.black38),
                const SizedBox(height: 2),
                Text(
                  items[i]['label'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    color: selected ? Colors.black87 : Colors.black38,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (selected)
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _ViajeCard extends StatelessWidget {
  final Map<String, dynamic> viaje;
  final bool isLast;

  const _ViajeCard({required this.viaje, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                _TimelineDot(estado: viaje['estado'] ?? ''),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: const Color(0xFFE0E0E0),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                viaje['tipo'] ?? '',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                viaje['fecha'] ?? '',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black45),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.people_outline,
                                      size: 12, color: Colors.black38),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${viaje['pasajeros'] ?? 0} Pasajeros',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black45),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _EstadoBadge(estado: viaje['estado'] ?? ''),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFFE0E0E0),
                          child: Text(
                            _initials(viaje['conductor'] ?? ''),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          viaje['conductor'] ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        if (viaje['conductorEstado'] != null)
                          _EstadoBadge(
                              estado: viaje['conductorEstado'] ?? ''),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: _RutaRow(
                      origen: viaje['origen'] ?? '',
                      destino: viaje['destino'] ?? '',
                    ),
                  ),
                  if (viaje['showMap'] == true) ...[
                    const SizedBox(height: 10),
                    _MapaEstatico(
                      lat: viaje['lat'] ?? 4.711,
                      lng: viaje['lng'] ?? -74.072,
                    ),
                  ],
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _TimelineDot extends StatelessWidget {
  final String estado;
  const _TimelineDot({required this.estado});

  Color get _color {
    switch (estado.toLowerCase()) {
      case 'en curso':
        return const Color(0xFF1E88E5);
      case 'en envío':
        return const Color(0xFFFB8C00);
      case 'finalizado':
        return const Color(0xFF43A047);
      case 'pendiente':
        return const Color(0xFFE53935);
      default:
        return Colors.black38;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: _color, width: 2),
      ),
      child: Center(
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  final String estado;
  const _EstadoBadge({required this.estado});

  Color get _color {
    switch (estado.toLowerCase()) {
      case 'en curso':
        return const Color(0xFF1E88E5);
      case 'en envío':
        return const Color(0xFFFB8C00);
      case 'finalizado':
        return const Color(0xFF43A047);
      case 'pendiente':
        return const Color(0xFFE53935);
      default:
        return Colors.black38;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        estado,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}

class _RutaRow extends StatelessWidget {
  final String origen;
  final String destino;
  const _RutaRow({required this.origen, required this.destino});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E88E5),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                  width: 1.5,
                  height: 16,
                  color: const Color(0xFFBDBDBD)),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: const Color(0xFF43A047), width: 2),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(origen,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                const SizedBox(height: 8),
                Text(destino,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapaEstatico extends StatelessWidget {
  final double lat;
  final double lng;
  const _MapaEstatico({required this.lat, required this.lng});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 130,
          child: CustomPaint(
            painter: _MapPainter(),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.location_on,
                            color: Colors.white, size: 18),
                      ),
                      CustomPaint(
                        painter: _PinTailPainter(),
                        size: const Size(10, 6),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 6,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                      style: const TextStyle(
                          fontSize: 9, color: Colors.black54),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFE8F0E8),
    );

    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final roadPaint2 = Paint()
      ..color = const Color(0xFFF5F5DC)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    for (double y = 20; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), roadPaint);
    }
    for (double x = 25; x < size.width; x += 35) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), roadPaint2);
    }

    final buildingPaint = Paint()..color = const Color(0xFFD7E4D0);
    final buildings = [
      Rect.fromLTWH(10, 10, 20, 16),
      Rect.fromLTWH(40, 10, 28, 16),
      Rect.fromLTWH(80, 10, 18, 16),
      Rect.fromLTWH(10, 40, 24, 16),
      Rect.fromLTWH(48, 40, 20, 16),
      Rect.fromLTWH(80, 40, 30, 16),
      Rect.fromLTWH(10, 70, 18, 16),
      Rect.fromLTWH(40, 70, 26, 16),
      Rect.fromLTWH(78, 70, 22, 16),
      Rect.fromLTWH(size.width - 60, 10, 20, 16),
      Rect.fromLTWH(size.width - 30, 40, 18, 16),
      Rect.fromLTWH(size.width - 50, 70, 24, 16),
    ];
    for (final b in buildings) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(b, const Radius.circular(3)),
          buildingPaint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _PinTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.black87);
  }

  @override
  bool shouldRepaint(_) => false;
}
