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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, size: 40, color: const Color(0xFF1565C0)),
                    const SizedBox(height: 12),
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
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

  const _AdminPanelItem(this.label, this.icon, this.onTap);
}
