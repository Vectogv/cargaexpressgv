import 'package:flutter/material.dart';
import 'gestion_disputas_screen.dart';
import 'configuracion_screen.dart';
import 'gestion_backups_screen.dart';
import 'reportes_moderadores_screen.dart';
import 'perfil_admin_screen.dart';
import 'soporte_reportes_screen.dart';
import 'gestion_emergencias_screen.dart';
import 'gestion_comunicados_screen.dart';
import 'mapa_vivo_screen.dart';
import 'gestion_encuestas_screen.dart';
import 'gestion_conductores_screen.dart';
import 'gestion_usuarios_screen.dart';
import 'gestion_viajes_screen.dart';
import 'pagos_finanzas_screen.dart';
import '../../services/api_client.dart';
import '../user/auth_screen.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _AdminPanelItem('Soporte y Reportes', Icons.headset_mic_rounded, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportReportsScreen()));
      }),
      _AdminPanelItem('Emergencias', Icons.crisis_alert_rounded, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergenciesScreen()));
      }),
      _AdminPanelItem('Disputas', Icons.gavel_rounded, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DisputesScreen()));
      }),
      _AdminPanelItem('Configuración', Icons.settings_rounded, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfigScreen()));
      }),
      _AdminPanelItem('Backups', Icons.backup_rounded, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupsScreen()));
      }),
      _AdminPanelItem('Reportes Moderadores', Icons.shield_rounded, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ModeratorReportsScreen()));
      }),
      _AdminPanelItem('Perfil Admin', Icons.person_rounded, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
      }),
      _AdminPanelItem('Comunicados', Icons.campaign_rounded, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const GestionComunicadosScreen()));
      }),
      _AdminPanelItem('Mapa en Vivo', Icons.map_rounded, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MapaVivoScreen()));
      }),
      _AdminPanelItem('Encuestas', Icons.poll_rounded, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const GestionEncuestasScreen()));
      }),
      _AdminPanelItem('Conductores', Icons.drive_eta_rounded, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const GestionConductoresScreen()));
      }),
      _AdminPanelItem('Usuarios', Icons.people_rounded, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen()));
      }),
      _AdminPanelItem('Viajes', Icons.route_rounded, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ViajesScreen()));
      }),
      _AdminPanelItem('Pagos', Icons.payments_rounded, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PagosFinanzasScreen()));
      }),
      _AdminPanelItem('Cerrar sesión', Icons.logout, () async {
        await ApiClient.instance.logout();
        if (!context.mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (_) => false,
        );
      }, isDestructive: true),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        backgroundColor: const Color(0xFFF2F3F7),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return GestureDetector(
              onTap: item.onTap,
              child: Container(
                decoration: BoxDecoration(
                  color: item.isDestructive ? Colors.red.shade50 : Colors.white,
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, size: 40,
                        color: item.isDestructive
                            ? Colors.red
                            : const Color(0xFF1565C0)),
                    const SizedBox(height: 12),
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: item.isDestructive
                            ? Colors.red
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AdminPanelItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  const _AdminPanelItem(this.label, this.icon, this.onTap,
      {this.isDestructive = false});
}
