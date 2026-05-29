import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final _cedulaCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  final _tipoVehiculoCtrl = TextEditingController();
  final _capacidadCtrl = TextEditingController();
  String? _driverPhotoPath;
  String? _vehiclePhotoPath;

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
    _cedulaCtrl.dispose();
    _placaCtrl.dispose();
    _tipoVehiculoCtrl.dispose();
    _capacidadCtrl.dispose();
    super.dispose();
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16),
                _buildBackButton(),
                SizedBox(height: 32),
                _buildHeader(),
                SizedBox(height: 32),
                _buildPhotoSection(
                  icon: Icons.person_outline,
                  label: 'Foto del conductor',
                  delay: 0.3,
                ),
                SizedBox(height: 20),
                _buildPhotoSection(
                  icon: Icons.time_to_leave_outlined,
                  label: 'Foto del vehículo',
                  delay: 0.4,
                ),
                SizedBox(height: 28),
                _buildForm(),
                SizedBox(height: 24),
                _buildButton(),
                SizedBox(height: 32),
              ],
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
              'Bienvenido al registro\nde conductor',
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

  Widget _buildPhotoSection({
    required IconData icon,
    required String label,
    required double delay,
  }) {
    final isDriver = label.contains('conductor');
    final anim = CurvedAnimation(
      parent: _animController,
      curve: Interval(delay, delay + 0.3, curve: Curves.easeOutCubic),
    );
    final path = isDriver ? _driverPhotoPath : _vehiclePhotoPath;

    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, 0.3),
          end: Offset.zero,
        ).animate(anim),
        child: GestureDetector(
          onTap: () => _pickPhoto(isDriver),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: path != null
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
                width: 1.5,
              ),
            ),
            child: path != null
                ? Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(path),
                          width: 56, height: 56, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(Icons.broken_image,
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: TextStyle(fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.8))),
                            Text('Imagen seleccionada',
                                style: TextStyle(fontSize: 11,
                                    color: Colors.greenAccent)),
                          ],
                        ),
                      ),
                      Icon(Icons.check_circle, color: Colors.green, size: 22),
                    ],
                  )
                : Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Color(0xFF1A8CFF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: Color(0xFF1A8CFF), size: 30),
                      ),
                      SizedBox(height: 12),
                      Text(label,
                          style: TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.8))),
                      SizedBox(height: 4),
                      Text('Presiona para subir imagen',
                          style: TextStyle(fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.35))),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickPhoto(bool isDriver) async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (file == null) return;
    setState(() {
      if (isDriver) {
        _driverPhotoPath = file.path;
      } else {
        _vehiclePhotoPath = file.path;
      }
    });
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
            onPressed: () {
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
            },
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
              'Continuar',
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
