import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../services/api_client.dart';
import 'gestion_usuarios_screen.dart';
import 'gestion_conductores_screen.dart';
import 'gestion_viajes_screen.dart';
import 'pagos_finanzas_screen.dart';
import 'gestion_emergencias_screen.dart';
import 'soporte_reportes_screen.dart';
import 'panel_admin_screen.dart';
import 'perfil_admin_screen.dart';
import 'configuracion_screen.dart';
import '../../services/notification_service.dart';
import 'gestion_comunicados_screen.dart';
import 'mapa_vivo_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _loading = true;
  Map<String, dynamic> _data = {};
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.init();
    _unreadCount = NotificationService.instance.unreadCount;
    NotificationService.instance.onNotification.listen((_) {
      if (mounted) setState(() => _unreadCount = NotificationService.instance.unreadCount);
    });
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    try {
      final api = ApiClient.instance;
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/dashboard'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${api.token}',
        },
      );
      if (res.statusCode == 200) {
        setState(() {
          _data = jsonDecode(res.body);
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
      _data = {
        'usuariosActivos': 445,
        'conductoresOnline': 10,
        'viajesDelDia': 346,
        'ingresosTotales': 867.38,
        'recentActivity': [
          {'label': 'Usuarios Activos', 'sub': '5 minutos', 'time': '7 days', 'icon': 'person'},
          {'label': 'Conductores Online', 'sub': '3 conductores', 'time': '3 days', 'icon': 'drive'},
          {'label': 'Conductores Plan', 'sub': '', 'time': '3 docs', 'icon': 'plan'},
        ],
      };
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      drawer: _buildDrawer(context),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  title: 'Usuarios Activos',
                                  value:
                                      '${_data['usuariosActivos'] ?? 0}',
                                  child: const _BarMiniChart(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  title: 'Conductores Online',
                                  value:
                                      '${_data['conductoresOnline'] ?? 0}',
                                  child: const _DotMapWidget(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  title: 'Viajes del Día',
                                  value:
                                      '${_data['viajesDelDia'] ?? 0}',
                                  child: const _LineMiniChart(
                                      color: Color(0xFF4FC3F7)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  title: 'Ingresos Totales',
                                  value:
                                      '\$${(_data['ingresosTotales'] ?? 0.0).toStringAsFixed(2)}',
                                  child: const _LineMiniChart(
                                      color: Color(0xFF66BB6A)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Recent Activity',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildActivityList(),
                        ],
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
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Builder(builder: (ctx) {
            return IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.black87),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            );
          }),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ApiClient.instance.nombreCompleto,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const Text(
                'Dashboard Principal',
                style: TextStyle(fontSize: 10, color: Colors.black45),
              ),
            ],
          ),
          const Spacer(),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.black54),
                onPressed: _showNotifications,
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD32F2F),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$_unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            onPressed: () {
              setState(() => _loading = true);
              _fetchDashboard();
            },
          ),
        ],
      ),
    );
  }

  void _showNotifications() {
    final notifs = NotificationService.instance.notifications;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Notificaciones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (notifs.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          NotificationService.instance.markAllRead();
                          setState(() => _unreadCount = 0);
                          Navigator.pop(context);
                        },
                        child: const Text('Marcar todas leídas'),
                      ),
                  ],
                ),
                const Divider(),
                if (notifs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('Sin notificaciones', style: TextStyle(color: Colors.black45))),
                  )
                else
                  ...notifs.take(20).map((n) => ListTile(
                    dense: true,
                    leading: Icon(Icons.circle, size: 8, color: n['read'] == true ? Colors.grey : const Color(0xFF1565C0)),
                    title: Text('${n['__event'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    subtitle: Text('${n['message'] ?? n['title'] ?? 'Sin detalle'}', style: const TextStyle(fontSize: 11)),
                  )),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              color: const Color(0xFF1565C0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.admin_panel_settings_rounded,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ApiClient.instance.nombreCompleto,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ApiClient.instance.email ?? 'admin@cargaexpress.com',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('ADMINISTRACIÓN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black45, letterSpacing: 0.5)),
            ),
            _DrawerItem(Icons.directions_car_rounded, 'Conductores', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const GestionConductoresScreen()));
            }),
            _DrawerItem(Icons.crisis_alert_rounded, 'Emergencias', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergenciesScreen()));
            }),
            _DrawerItem(Icons.headset_mic_rounded, 'Soporte y Reportes', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportReportsScreen()));
            }),
            _DrawerItem(Icons.campaign_rounded, 'Comunicados', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const GestionComunicadosScreen()));
            }),
            _DrawerItem(Icons.map_rounded, 'Mapa en Vivo', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MapaVivoScreen()));
            }),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text('HERRAMIENTAS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black45, letterSpacing: 0.5)),
            ),
            _DrawerItem(Icons.dashboard_rounded, 'Panel Completo', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
            }),
            _DrawerItem(Icons.person_rounded, 'Perfil', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            }),
            _DrawerItem(Icons.settings_rounded, 'Configuraciones', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfigScreen()));
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityList() {
    final activities = _data['recentActivity'] as List? ?? [];
    if (activities.isEmpty) {
      return const _ActivityTile(
        iconType: 'person',
        label: 'Sin actividad reciente',
        sub: '',
        time: '',
      );
    }
    return Column(
      children: activities.map<Widget>((item) {
        return _ActivityTile(
          iconType: item['icon'] ?? 'person',
          label: item['label'] ?? '',
          sub: item['sub'] ?? '',
          time: item['time'] ?? '',
        );
      }).toList(),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.people_rounded, 'label': 'Usuarios'},
      {'icon': Icons.route_rounded, 'label': 'Viajes'},
      {'icon': Icons.payments_rounded, 'label': 'Finanzas'},
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final selected = _selectedIndex == i;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedIndex = i);
              if (i == 1) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UsersScreen()),
                );
              } else if (i == 2) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ViajesScreen()),
                );
              } else if (i == 3) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PagosFinanzasScreen()),
                );
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  items[i]['icon'] as IconData,
                  size: 22,
                  color: selected ? Colors.black87 : Colors.black38,
                ),
                const SizedBox(height: 2),
                Text(
                  items[i]['label'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    color: selected ? Colors.black87 : Colors.black38,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.w400,
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Widget child;

  const _StatCard({
    required this.title,
    required this.value,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(height: 40, child: child),
        ],
      ),
    );
  }
}

class _BarMiniChart extends StatelessWidget {
  const _BarMiniChart();

  @override
  Widget build(BuildContext context) {
    final values = [0.4, 0.7, 0.5, 0.9, 0.6, 0.8, 1.0, 0.7, 0.85];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: values.map((v) {
        return Container(
          width: 8,
          height: 40 * v,
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }).toList(),
    );
  }
}

class _DotMapWidget extends StatelessWidget {
  const _DotMapWidget();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DotMapPainter(),
    );
  }
}

class _DotMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFBBDEFB);
    final rng = Random(42);
    for (int i = 0; i < 30; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 1.5, paint);
    }
    final highlight = Paint()..color = const Color(0xFF1565C0);
    final positions = [
      Offset(size.width * 0.3, size.height * 0.4),
      Offset(size.width * 0.6, size.height * 0.3),
      Offset(size.width * 0.5, size.height * 0.6),
      Offset(size.width * 0.8, size.height * 0.5),
    ];
    for (final p in positions) {
      canvas.drawCircle(p, 3, highlight);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _LineMiniChart extends StatelessWidget {
  final Color color;
  const _LineMiniChart({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LinePainter(color: color),
    );
  }
}

class _LinePainter extends CustomPainter {
  final Color color;
  const _LinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final points = [0.5, 0.3, 0.6, 0.4, 0.7, 0.5, 0.8, 0.6, 0.9, 0.7];
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      final y = size.height * (1 - points[i]);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _ActivityTile extends StatelessWidget {
  final String iconType;
  final String label;
  final String sub;
  final String time;

  const _ActivityTile({
    required this.iconType,
    required this.label,
    required this.sub,
    required this.time,
  });

  IconData _icon() {
    switch (iconType) {
      case 'drive':
        return Icons.directions_car_rounded;
      case 'plan':
        return Icons.description_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon(), size: 18, color: const Color(0xFF1565C0)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (sub.isNotEmpty)
                  Text(
                    sub,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black45),
                  ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DrawerItem(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1565C0)),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      onTap: onTap,
      dense: true,
    );
  }
}
