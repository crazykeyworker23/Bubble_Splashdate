import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/user_profile.dart';
import '../services/user_profile_service.dart';
import '../services/session_manager.dart';
import '../services/user_info_service.dart';
import '../services/avatar_upload_service.dart';
import '../services/auth_service.dart';

import '../constants/api_constants.dart';
import '../constants/service_code.dart';

class MiPerfilPage extends StatefulWidget {
  const MiPerfilPage({super.key});

  @override
  State<MiPerfilPage> createState() => _MiPerfilPageState();
}

class _MiPerfilPageState extends State<MiPerfilPage> {
  // --- Puntos por completar perfil ---
  static const int puntosPerfilCompleto = 60;
  bool _perfilCompleto = false;
  bool _puntosOtorgados = false;

  static const Color _brandDark = Color(0xFF0F3D4A);
  static const Color _brandTeal = Color(0xFF128FA0);
  static const Color _bg = Color(0xFFF4FAFF);

  static const String ME_URL = ApiConstants.baseUrl + '/auth/me/';

  bool _editMode = false;
  bool _loading = false;
  UserProfile? _profile;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fcmTokenController = TextEditingController();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _occupationController = TextEditingController();
  final TextEditingController _educationLevelController = TextEditingController();
  final TextEditingController _avatarUrlController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  DateTime? _birthday;

  final List<String> _genderOptions = const [
    'Sin especificar',
    'Masculino',
    'Femenino',
    'Otro',
  ];

  final List<String> _occupationOptions = const [
    'Sin especificar',
    'Estudiante',
    'Empleado',
    'Independiente',
    'Desempleado',
    'Otro',
  ];

  final List<String> _educationOptions = const [
    'Sin especificar',
    'Primaria',
    'Secundaria',
    'Técnico',
    'Universitario',
    'Postgrado',
  ];

  final ImagePicker _imagePicker = ImagePicker();
  File? _localAvatarFile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadLocalBirthday();
  }

  @override
  void dispose() {
    _fcmTokenController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _occupationController.dispose();
    _educationLevelController.dispose();
    _avatarUrlController.dispose();
    _birthdayController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // =========================
  // ✅ PERFIL COMPLETO
  // =========================
  bool _verificarPerfilCompleto() {
    final full = _fullNameController.text.trim();
    final age = _ageController.text.trim();
    final gen = _genderController.text.trim();
    final addr = _addressController.text.trim();
    final occ = _occupationController.text.trim();
    final edu = _educationLevelController.text.trim();

    bool validSelect(String v) => v.isNotEmpty && v != 'Sin especificar';

    return full.isNotEmpty &&
        age.isNotEmpty &&
        validSelect(gen) &&
        addr.isNotEmpty &&
        validSelect(occ) &&
        validSelect(edu);
  }

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.trim().isEmpty) return null;
    return token.trim();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final token = await _getAccessToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No hay access_token. Inicia sesión nuevamente.")),
          );
        }
        return;
      }

      http.Response response = await http.get(
        Uri.parse(ME_URL),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'X-Service-Code': kServiceCode,
        },
      );

      if (response.statusCode == 401 && await AuthService.refreshToken()) {
        final newToken = await _getAccessToken();
        if (newToken != null) {
          response = await http.get(
            Uri.parse(ME_URL),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $newToken',
              'X-Service-Code': kServiceCode,
            },
          );
        }
      }

      if (response.statusCode == 401) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tu sesión ha expirado. Inicia sesión nuevamente para ver tu perfil.'),
            ),
          );
        }
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        final fcm = prefs.getString('fcm_token') ?? '';

        final profile = UserProfile.fromJson(data, fcmToken: fcm);

        // Para flag por usuario (evitar que quede global)
        final userId = await UserInfoService.fetchUserId();
        final flagKey = userId == null ? 'puntos_perfil_completo' : 'puntos_perfil_completo_$userId';

        if (!mounted) return;
        setState(() {
          _profile = profile;

          _fcmTokenController.text = profile.fcmToken;
          _usernameController.text = profile.username;
          _fullNameController.text = profile.fullName;
          _ageController.text = profile.age ?? '';
          _genderController.text = profile.gender ?? '';
          _descriptionController.text = profile.description ?? '';
          _addressController.text = profile.address ?? '';
          _occupationController.text = profile.occupation ?? '';
          _educationLevelController.text = profile.educationLevel ?? '';
          _avatarUrlController.text = profile.avatarUrl ?? '';
          _phoneController.text = profile.celular ?? '';

          _perfilCompleto = _verificarPerfilCompleto();
          _puntosOtorgados = prefs.getBool(flagKey) ?? false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error al cargar perfil: ${response.statusCode}")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al cargar perfil: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadLocalBirthday() async {
    final prefs = await SharedPreferences.getInstance();
    final String? birthdayStr = prefs.getString('birthday');
    if (birthdayStr == null || birthdayStr.trim().isEmpty) return;

    try {
      final DateTime parsed = DateTime.parse(birthdayStr);
      if (!mounted) return;
      setState(() {
        _birthday = parsed;
        _birthdayController.text =
            '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year.toString().padLeft(4, '0')}';
      });
    } catch (_) {}
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;
    setState(() => _loading = true);

    try {
      String fcmValue = _fcmTokenController.text.trim();
      if (fcmValue.isEmpty) {
        fcmValue = (await SessionManager.getFcmToken()) ?? '';
      }
      if (fcmValue.length > 255) {
        fcmValue = fcmValue.substring(0, 255);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', fcmValue);

      if (_birthday != null) {
        final String bStr =
            '${_birthday!.year.toString().padLeft(4, '0')}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}';
        await prefs.setString('birthday', bStr);
      }

      final userId = await UserInfoService.fetchUserId();
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No se pudo obtener el id del usuario autenticado")),
          );
        }
        return;
      }

      // ✅ flag por usuario
      final flagKey = 'puntos_perfil_completo_$userId';
      final String keyPuntos = 'puntos_$userId';

      if (_localAvatarFile != null) {
        try {
          final uploadedUrl = await AvatarUploadService.uploadAvatar(_localAvatarFile!);
          _avatarUrlController.text = uploadedUrl;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al subir avatar: $e')),
            );
          }
        }
      }

      final patchBody = <String, dynamic>{
        'use_txt_fcm': fcmValue,
        'use_txt_username': _usernameController.text.trim(),
        'use_txt_fullname': _fullNameController.text.trim(),
        'use_txt_age': _ageController.text.trim(),
        'use_txt_gender': _genderController.text.trim(),
        'use_txt_description': _descriptionController.text.trim(),
        'use_txt_address': _addressController.text.trim(),
        'use_txt_occupation': _occupationController.text.trim(),
        'use_txt_educationlevel': _educationLevelController.text.trim(),
        'use_txt_avatar': _avatarUrlController.text.trim(),
        'use_txt_celular': _phoneController.text.trim(),
      };

      await UserProfileService.updateUserProfileRaw(
        patchBody,
        userId: userId,
      );

      final perfilCompletoAhora = _verificarPerfilCompleto();
      final puntosOtorgados = prefs.getBool(flagKey) ?? false;

      if (!mounted) return;
      setState(() {
        _editMode = false;
        _perfilCompleto = perfilCompletoAhora;
        _puntosOtorgados = puntosOtorgados;
      });

      if (perfilCompletoAhora && !puntosOtorgados) {
        final int puntosActuales = prefs.getInt(keyPuntos) ?? 0;
        await prefs.setInt(keyPuntos, puntosActuales + puntosPerfilCompleto);
        await prefs.setBool(flagKey, true);

        if (!mounted) return;
        setState(() => _puntosOtorgados = true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Felicidades! Has completado tu perfil y ganaste 60 puntos extra.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Perfil actualizado correctamente")),
        );
      }

      await _loadProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al actualizar: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // =========================
  // 🎨 UI Helpers
  // =========================
  InputDecoration _premiumInputDecoration({
    required String label,
    IconData? icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, color: _brandTeal),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _brandTeal, width: 1.4),
      ),
    );
  }

  Widget _sectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _brandTeal.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _brandTeal, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _brandDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final XFile? picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (picked != null) {
      if (!mounted) return;
      setState(() => _localAvatarFile = File(picked.path));
    }
  }

  ImageProvider? _avatarProvider() {
    if (_localAvatarFile != null) return FileImage(_localAvatarFile!);
    final url = _avatarUrlController.text.trim();
    if (url.isNotEmpty) return NetworkImage(url);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _brandDark,
        foregroundColor: Colors.white,
        title: const Text("Mi Perfil", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: _editMode ? "Cancelar" : "Editar",
            icon: Icon(_editMode ? Icons.close : Icons.edit),
            onPressed: _loading ? null : () => setState(() => _editMode = !_editMode),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(child: Text("No se pudo cargar el perfil"))
              : Column(
                  children: [
                    if (!_perfilCompleto)
                      Container(
                        width: double.infinity,
                        color: Colors.amber.shade100,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
                        child: Row(
                          children: const [
                            Icon(Icons.info_outline, color: Colors.amber, size: 22),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Completa todos tus datos para ganar 60 puntos extra y acceder a todos los beneficios.",
                                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _premiumHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                _sectionCard(
                                  title: "Identidad",
                                  icon: Icons.badge_outlined,
                                  children: [
                                    TextFormField(
                                      controller: _usernameController,
                                      readOnly: !_editMode,
                                      decoration: _premiumInputDecoration(
                                        label: "Usuario",
                                        icon: Icons.alternate_email,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _fullNameController,
                                      readOnly: !_editMode,
                                      decoration: _premiumInputDecoration(
                                        label: "Nombre completo",
                                        icon: Icons.person_outline,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _ageController,
                                      readOnly: !_editMode,
                                      keyboardType: TextInputType.number,
                                      decoration: _premiumInputDecoration(
                                        label: "Edad",
                                        icon: Icons.cake_outlined,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _birthdayController,
                                      readOnly: true,
                                      decoration: _premiumInputDecoration(
                                        label: "Cumpleaños (para beneficios)",
                                        icon: Icons.event_outlined,
                                      ),
                                      onTap: !_editMode
                                          ? null
                                          : () async {
                                              final now = DateTime.now();
                                              final initialDate =
                                                  _birthday ?? DateTime(now.year - 18, now.month, now.day);

                                              final picked = await showDatePicker(
                                                context: context,
                                                initialDate: initialDate,
                                                firstDate: DateTime(1900),
                                                lastDate: now,
                                              );

                                              if (picked != null && mounted) {
                                                setState(() {
                                                  _birthday = picked;
                                                  _birthdayController.text =
                                                      '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year.toString().padLeft(4, '0')}';
                                                });
                                              }
                                            },
                                    ),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      value: _genderOptions.contains(_genderController.text)
                                          ? _genderController.text
                                          : _genderOptions.first,
                                      decoration: _premiumInputDecoration(
                                        label: "Género",
                                        icon: Icons.wc_outlined,
                                      ),
                                      items: _genderOptions
                                          .map((g) => DropdownMenuItem<String>(value: g, child: Text(g)))
                                          .toList(),
                                      onChanged: !_editMode
                                          ? null
                                          : (v) => setState(() => _genderController.text = (v ?? _genderOptions.first)),
                                    ),
                                  ],
                                ),
                                _sectionCard(
                                  title: "Sobre ti",
                                  icon: Icons.notes_outlined,
                                  children: [
                                    TextFormField(
                                      controller: _descriptionController,
                                      readOnly: !_editMode,
                                      maxLines: 3,
                                      decoration: _premiumInputDecoration(
                                        label: "Descripción",
                                        icon: Icons.short_text,
                                        hint: "Cuéntanos un poco sobre ti",
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _addressController,
                                      readOnly: !_editMode,
                                      decoration: _premiumInputDecoration(
                                        label: "Dirección",
                                        icon: Icons.location_on_outlined,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _phoneController,
                                      readOnly: !_editMode,
                                      keyboardType: TextInputType.phone,
                                      decoration: _premiumInputDecoration(
                                        label: "Celular",
                                        icon: Icons.phone_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                                _sectionCard(
                                  title: "Ocupación y estudios",
                                  icon: Icons.school_outlined,
                                  children: [
                                    DropdownButtonFormField<String>(
                                      value: _occupationOptions.contains(_occupationController.text)
                                          ? _occupationController.text
                                          : _occupationOptions.first,
                                      decoration: _premiumInputDecoration(
                                        label: "Ocupación",
                                        icon: Icons.work_outline,
                                      ),
                                      items: _occupationOptions
                                          .map((o) => DropdownMenuItem<String>(value: o, child: Text(o)))
                                          .toList(),
                                      onChanged: !_editMode
                                          ? null
                                          : (v) => setState(
                                              () => _occupationController.text = (v ?? _occupationOptions.first)),
                                    ),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      value: _educationOptions.contains(_educationLevelController.text)
                                          ? _educationLevelController.text
                                          : _educationOptions.first,
                                      decoration: _premiumInputDecoration(
                                        label: "Nivel de educación",
                                        icon: Icons.menu_book_outlined,
                                      ),
                                      items: _educationOptions
                                          .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                                          .toList(),
                                      onChanged: !_editMode
                                          ? null
                                          : (v) => setState(
                                              () => _educationLevelController.text = (v ?? _educationOptions.first)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 90),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_editMode) _bottomSaveBar(),
                  ],
                ),
    );
  }

  Widget _premiumHeader() {
    final avatar = _avatarProvider();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_brandDark, _brandTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _editMode ? _pickAvatar : null,
            child: Stack(
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    image: avatar != null ? DecorationImage(image: avatar, fit: BoxFit.cover) : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.20),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: avatar == null
                      ? const Center(
                          child: Icon(
                            FontAwesomeIcons.userCircle,
                            size: 46,
                            color: _brandTeal,
                          ),
                        )
                      : null,
                ),
                if (_editMode)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, size: 15, color: _brandTeal),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fullNameController.text.trim().isEmpty ? "Tu perfil" : _fullNameController.text.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _usernameController.text.trim().isEmpty ? "@" : "@${_usernameController.text.trim()}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: Text(
                    _editMode ? "Modo edición" : "Vista segura",
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomSaveBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _loading ? null : () => setState(() => _editMode = false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _brandDark,
                  side: BorderSide(color: _brandDark.withOpacity(0.25)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text("Cancelar"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _saveProfile,
                icon: const Icon(Icons.save),
                label: const Text("Guardar"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
