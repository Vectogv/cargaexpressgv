import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_client.dart';
import '../services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _edadCtrl = TextEditingController();
  final _cedulaCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = await UserService().getProfile();
      _nombreCtrl.text = user.nombre;
      _apellidoCtrl.text = user.apellido;
      _emailCtrl.text = user.email;
      _telefonoCtrl.text = user.telefono ?? '';
      _edadCtrl.text = user.edad?.toString() ?? '';
      _avatarUrl = user.avatar;
      final data = await ApiClient().get('/users/profile');
      if (data['conductor'] != null) {
        _cedulaCtrl.text = data['conductor']['cedula'] ?? '';
        _placaCtrl.text = data['conductor']['placa'] ?? '';
      }
    } catch (_) {
      _nombreCtrl.text = 'Carlos';
      _apellidoCtrl.text = 'Mendoza';
      _emailCtrl.text = 'carlos@email.com';
      _telefonoCtrl.text = '+58 412 123 4567';
      _edadCtrl.text = '32';
      _cedulaCtrl.text = 'V-12.345.678';
      _placaCtrl.text = 'ABC-123';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await UserService().updateProfile(
        nombre: _nombreCtrl.text,
        apellido: _apellidoCtrl.text,
        email: _emailCtrl.text,
        telefono: _telefonoCtrl.text,
        edad: int.tryParse(_edadCtrl.text),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Perfil actualizado'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _edadCtrl.dispose();
    _cedulaCtrl.dispose();
    _placaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Perfil', style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF1A8CFF)))
          : SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            SizedBox(height: 8),
            _buildAvatar(),
            SizedBox(height: 32),
            _buildSection('Información personal', [
              _buildRow(
                _buildField('Nombre', _nombreCtrl),
                _buildField('Apellido', _apellidoCtrl),
              ),
              SizedBox(height: 16),
              _buildField('Correo electrónico', _emailCtrl,
                  type: TextInputType.emailAddress),
              SizedBox(height: 16),
              _buildRow(
                _buildField('Teléfono', _telefonoCtrl,
                    type: TextInputType.phone),
                _buildField('Edad', _edadCtrl, type: TextInputType.number),
              ),
            ]),
            SizedBox(height: 24),
            _buildSection('Documentación', [
              _buildDisabledField('Cédula', _cedulaCtrl),
              SizedBox(height: 16),
              _buildDisabledField('Placa del vehículo', _placaCtrl),
            ]),
            SizedBox(height: 32),
            _saving
                ? Center(child: CircularProgressIndicator(color: Color(0xFF1A8CFF)))
                : SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1A8CFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: Color(0xFF1A8CFF).withValues(alpha: 0.4),
                      ),
                      child: Text('Guardar cambios',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickAvatar,
          child: Stack(
            children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  color: Color(0xFF1A8CFF).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Color(0xFF1A8CFF).withValues(alpha: 0.3),
                      width: 2.5),
                  image: _avatarUrl != null && _avatarUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(
                              '${ApiClient().baseUrl.replaceAll('/api', '')}$_avatarUrl'),
                          fit: BoxFit.cover)
                      : null,
                ),
                child: _avatarUrl == null || _avatarUrl!.isEmpty
                    ? Center(child: Text('${_nombreCtrl.text.isNotEmpty ? _nombreCtrl.text[0] : ''}${_apellidoCtrl.text.isNotEmpty ? _apellidoCtrl.text[0] : ''}',
                        style: TextStyle(color: Colors.white, fontSize: 28,
                            fontWeight: FontWeight.bold)))
                    : null,
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Color(0xFF1A8CFF),
                    shape: BoxShape.circle,
                    border: Border.all(color: Color(0xFF0A0A0A), width: 2.5),
                  ),
                  child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        Text('Conductor',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 14)),
      ],
    );
  }

  Future<void> _pickAvatar() async {
    final xfile = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (xfile == null) return;
    setState(() => _saving = true);
    try {
      String url;
      if (kIsWeb) {
        final bytes = await xfile.readAsBytes();
        url = await UserService().uploadAvatar('', bytes: bytes, filename: xfile.name);
      } else {
        url = await UserService().uploadAvatar(xfile.path);
      }
      setState(() => _avatarUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir foto: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5)),
        SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController ctrl,
      {TextInputType? type}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 11, fontWeight: FontWeight.w500)),
        SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: type,
          style: TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFF1A8CFF), width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDisabledField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 11, fontWeight: FontWeight.w500)),
        SizedBox(height: 6),
        TextField(
          controller: ctrl,
          enabled: false,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.3),
              fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.03),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.04)),
            ),
            contentPadding: EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(Widget a, Widget b) {
    return Row(children: [
      Expanded(child: a),
      SizedBox(width: 12),
      Expanded(child: b),
    ]);
  }
}
