import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'driver_home_screen.dart';

class ConductorRegisterScreen extends StatefulWidget {
  const ConductorRegisterScreen({super.key});

  @override
  State<ConductorRegisterScreen> createState() =>
      _ConductorRegisterScreenState();
}

class _ConductorRegisterScreenState extends State<ConductorRegisterScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeSlide;
  late final Animation<double> _fieldsSlide;
  late final Animation<double> _buttonScale;

  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _cedulaCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  final _tipoVehiculoCtrl = TextEditingController();
  final _capacidadCtrl = TextEditingController();

  bool _registrationSuccess = false;
  bool _loading = false;

  String _statusCedula = 'pendiente';
  String _statusLicencia = 'pendiente';
  String _statusVehiculo = 'pendiente';

  String? _notaCedula;
  String? _notaLicencia;
  String? _notaVehiculo;

  String? _pathCedula;
  String? _pathLicencia;
  String? _pathVehiculo;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );

    _fadeSlide = CurvedAnimation(
      parent: _animController,
      curve: Interval(0.0, 0.4, curve: Curves.easeOutCubic),
    );

    _fieldsSlide = CurvedAnimation(
      parent: _animController,
      curve: Interval(0.3, 0.8, curve: Curves.easeOutCubic),
    );

    _buttonScale = CurvedAnimation(
      parent: _animController,
      curve: Interval(0.7, 1.0, curve: Curves.elasticOut),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _passwordCtrl.dispose();
    _cedulaCtrl.dispose();
    _placaCtrl.dispose();
    _tipoVehiculoCtrl.dispose();
    _capacidadCtrl.dispose();
    super.dispose();
  }

  Future<void> _registrarse() async {
    if (_nombreCtrl.text.isEmpty ||
        _apellidoCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty ||
        _telefonoCtrl.text.isEmpty ||
        _passwordCtrl.text.isEmpty ||
        _cedulaCtrl.text.isEmpty ||
        _placaCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor completa todos los campos requeridos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await AuthService().register(
        nombre: _nombreCtrl.text,
        apellido: _apellidoCtrl.text,
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        telefono: _telefonoCtrl.text,
        rol: 'conductor',
        cedula: _cedulaCtrl.text,
        placa: _placaCtrl.text,
        tipoVehiculo: _tipoVehiculoCtrl.text.isNotEmpty ? _tipoVehiculoCtrl.text : null,
        capacidad: _capacidadCtrl.text.isNotEmpty ? _capacidadCtrl.text : null,
      );

      setState(() {
        _registrationSuccess = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al registrar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickDocument(String docType) async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (file == null) return;

    setState(() {
      if (docType == 'cedula') {
        _pathCedula = file.path;
        _statusCedula = 'subido';
      } else if (docType == 'licencia') {
        _pathLicencia = file.path;
        _statusLicencia = 'subido';
      } else if (docType == 'vehiculo') {
        _pathVehiculo = file.path;
        _statusVehiculo = 'subido';
      }
    });
  }

  Future<void> _finalizarRegistro() async {
    if (_statusCedula == 'pendiente' ||
        _statusLicencia == 'pendiente' ||
        _statusVehiculo == 'pendiente') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor sube todos los documentos requeridos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await Future.delayed(Duration(seconds: 1));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('estadoVerificacion', 'pendiente');

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const DriverHomeScreen(),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0A0A),
              Color(0xFF111118),
              Color(0xFF16162A),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 500),
              child: _registrationSuccess
                  ? _buildVerificationPendingView()
                  : Column(
                      key: ValueKey('registerForm'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 16),
                        _buildBackButton(),
                        SizedBox(height: 32),
                        _buildHeader(),
                        SizedBox(height: 28),
                        _buildForm(),
                        SizedBox(height: 32),
                        _buildButton(),
                        SizedBox(height: 32),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return FadeTransition(
      opacity: _fadeSlide,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, -0.3),
          end: Offset.zero,
        ).animate(_fadeSlide),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _fadeSlide,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, 0.4),
          end: Offset.zero,
        ).animate(_fadeSlide),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Registro de Conductor',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.2,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Completa tus datos para continuar.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationPendingView() {
    return Column(
      key: ValueKey('verificationPending'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 24),
        Text(
          'Verificación de Documentos',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Por favor sube una foto legible de cada uno de los siguientes documentos para verificar tu cuenta de conductor.',
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        SizedBox(height: 32),
        _buildDocUploadButton(
          documentLabel: 'Cédula de Identidad',
          status: _statusCedula,
          filePath: _pathCedula,
          nota: _notaCedula,
          onTap: () => _pickDocument('cedula'),
        ),
        SizedBox(height: 16),
        _buildDocUploadButton(
          documentLabel: 'Licencia de Conducir',
          status: _statusLicencia,
          filePath: _pathLicencia,
          nota: _notaLicencia,
          onTap: () => _pickDocument('licencia'),
        ),
        SizedBox(height: 16),
        _buildDocUploadButton(
          documentLabel: 'Foto del Vehículo',
          status: _statusVehiculo,
          filePath: _pathVehiculo,
          nota: _notaVehiculo,
          onTap: () => _pickDocument('vehiculo'),
        ),
        SizedBox(height: 32),
        _loading
            ? Center(child: CircularProgressIndicator(color: Color(0xFF1A8CFF)))
            : SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _finalizarRegistro,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1A8CFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: Color(0xFF1A8CFF).withValues(alpha: 0.4),
                  ),
                  child: Text(
                    'Finalizar y Enviar',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDocUploadButton({
    required String documentLabel,
    required String status,
    required String? filePath,
    required String? nota,
    required VoidCallback onTap,
  }) {
    Color borderColor;
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'subido':
        borderColor = Colors.blue.withValues(alpha: 0.3);
        statusColor = Colors.blueAccent;
        statusText = 'Subido - Esperando aprobación';
        statusIcon = Icons.access_time_rounded;
        break;
      case 'aprobado':
        borderColor = Colors.green.withValues(alpha: 0.3);
        statusColor = Colors.greenAccent;
        statusText = 'Aprobado';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'rechazado':
        borderColor = Colors.red.withValues(alpha: 0.3);
        statusColor = Colors.redAccent;
        statusText = 'Rechazado';
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        borderColor = Colors.white.withValues(alpha: 0.1);
        statusColor = Colors.white.withValues(alpha: 0.35);
        statusText = 'Pendiente por subir';
        statusIcon = Icons.cloud_upload_outlined;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: status == 'aprobado' ? null : onTap,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        documentLabel,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (filePath != null && status == 'subido')
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(filePath),
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  )
                else if (status != 'aprobado')
                  Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
              ],
            ),
          ),
        ),
        if (status == 'rechazado' && nota != null) ...[
          SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.redAccent, size: 14),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Nota del administrador: $nota',
                    style: TextStyle(
                      color: Colors.redAccent.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildForm() {
    return FadeTransition(
      opacity: _fieldsSlide,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, 0.3),
          end: Offset.zero,
        ).animate(_fieldsSlide),
        child: Column(
          children: [
            _buildInput(label: 'Nombre', controller: _nombreCtrl),
            SizedBox(height: 16),
            _buildInput(label: 'Apellido', controller: _apellidoCtrl),
            SizedBox(height: 16),
            _buildInput(
              label: 'Correo electrónico',
              controller: _emailCtrl,
              type: TextInputType.emailAddress,
            ),
            SizedBox(height: 16),
            _buildInput(
              label: 'Teléfono',
              controller: _telefonoCtrl,
              type: TextInputType.phone,
            ),
            SizedBox(height: 16),
            _buildInput(
              label: 'Contraseña',
              controller: _passwordCtrl,
              obscureText: true,
            ),
            SizedBox(height: 16),
            _buildInput(
              label: 'Cédula',
              controller: _cedulaCtrl,
              type: TextInputType.number,
            ),
            SizedBox(height: 16),
            _buildInput(label: 'Placa del vehículo', controller: _placaCtrl),
            SizedBox(height: 16),
            _buildInput(
              label: 'Tipo de vehículo',
              controller: _tipoVehiculoCtrl,
            ),
            SizedBox(height: 16),
            _buildInput(
              label: 'Capacidad (ej: 1.5 ton)',
              controller: _capacidadCtrl,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    TextInputType? type,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: type,
          obscureText: obscureText,
          style: TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Color(0xFF1A8CFF), width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildButton() {
    return ScaleTransition(
      scale: _buttonScale,
      child: FadeTransition(
        opacity: _buttonScale,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _registrarse,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF1A8CFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              shadowColor: Color(0xFF1A8CFF).withValues(alpha: 0.4),
            ),
            child: _loading
                ? CircularProgressIndicator(color: Colors.white)
                : Text(
                    'Registrarse',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
