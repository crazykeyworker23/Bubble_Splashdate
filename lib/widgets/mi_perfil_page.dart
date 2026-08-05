import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bubblesplash/services/app_http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/user_profile.dart';
import '../services/user_profile_service.dart';
import '../services/session_manager.dart';
import '../services/user_info_service.dart';
import '../services/avatar_upload_service.dart';
import '../services/sede_service.dart';
import 'sede_selector_field.dart';
import '../services/auth_service.dart';

import '../constants/api_constants.dart';
import '../constants/service_code.dart';

class MiPerfilPage extends StatefulWidget {
  const MiPerfilPage({super.key});

  @override
  State<MiPerfilPage> createState() => _MiPerfilPageState();
}

class _MiPerfilPageState extends State<MiPerfilPage>
    with TickerProviderStateMixin {
  static const Color _brandDark = Color(0xFF0F3D4A);
  static const Color _brandTeal = Color(0xFF128FA0);
  static const Color _bg = Color(0xFFF4FAFF);

  static const String ME_URL = ApiConstants.baseUrl + '/auth/me/';

  bool _editMode = false;
  bool _loading = false;
  bool _saving = false;
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
  final TextEditingController _educationLevelController =
      TextEditingController();
  final TextEditingController _avatarUrlController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

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
    'Secundaria',
    'Técnico',
    'Universitario',
    'Postgrado',
  ];

  final ImagePicker _imagePicker = ImagePicker();

  /// Sede del cliente: define a qué local llegan sus pedidos.
  Sede? _sede;
  bool _sedeGuardando = false;
  File? _localAvatarFile;

  // Animaciones
  late final AnimationController _saveBarController;
  late final Animation<Offset> _saveBarSlide;
  late final AnimationController _cameraPulseController;
  late final Animation<double> _cameraPulse;

  @override
  void initState() {
    super.initState();

    // Animación slide para la barra de guardar
    _saveBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _saveBarSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _saveBarController,
      curve: Curves.easeOutCubic,
    ));

    // Animación pulse para el ícono de cámara del avatar
    _cameraPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _cameraPulse = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(
        parent: _cameraPulseController,
        curve: Curves.easeInOut,
      ),
    );

    _loadProfile();
  }

  @override
  void dispose() {
    _saveBarController.dispose();
    _cameraPulseController.dispose();
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
    _phoneController.dispose();
    super.dispose();
  }

  // ===========================
  // Cambio de modo edición
  // ===========================
  void _toggleEditMode() {
    if (_loading || _saving) return;
    setState(() => _editMode = !_editMode);

    if (_editMode) {
      HapticFeedback.mediumImpact();
      _saveBarController.forward();
      _cameraPulseController.repeat(reverse: true);
    } else {
      _saveBarController.reverse();
      _cameraPulseController.stop();
      _cameraPulseController.reset();
    }
  }

  // ===========================
  // Carga de perfil
  // ===========================
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
            const SnackBar(
                content:
                    Text("No hay access_token. Inicia sesión nuevamente.")),
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
              content: Text(
                  'Tu sesión ha expirado. Inicia sesión nuevamente para ver tu perfil.'),
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
        });

        // Sede del cliente (perfil Bubble). Se consulta aparte porque vive en
        // el módulo bubblesplash, no en el usuario base.
        final bubbleProfile = await SedeService.fetchMyProfile();
        if (mounted && bubbleProfile != null) {
          final dynamic sedeJson = bubbleProfile['sede'];
          if (sedeJson is Map<String, dynamic>) {
            setState(() => _sede = Sede.fromJson(sedeJson));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text("Error al cargar perfil: ${response.statusCode}")),
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

  // ===========================
  // Guardado de perfil
  // ===========================
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    if (!mounted) return;
    setState(() => _saving = true);

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

      final userId = await UserInfoService.fetchUserId();
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    "No se pudo obtener el id del usuario autenticado")),
          );
        }
        return;
      }

      if (_localAvatarFile != null) {
        try {
          final uploadedUrl =
              await AvatarUploadService.uploadAvatar(_localAvatarFile!);
          _avatarUrlController.text = uploadedUrl;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al subir avatar: $e')),
            );
          }
        }
      }

      // ✅ La sede se guarda en el perfil Bubble (endpoint propio).
      if (_sede != null) {
        setState(() => _sedeGuardando = true);
        final ok = await SedeService.updateMySede(_sede!);
        if (mounted) setState(() => _sedeGuardando = false);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo actualizar tu sede. Intenta nuevamente.'),
            ),
          );
        }
      }

      final patchBody = <String, dynamic>{
        'use_txt_fcm': fcmValue,
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

      if (!mounted) return;

      // Feedback de éxito
      HapticFeedback.lightImpact();

      setState(() {
        _editMode = false;
        _localAvatarFile = null;
      });

      _saveBarController.reverse();
      _cameraPulseController.stop();
      _cameraPulseController.reset();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text("Perfil actualizado correctamente"),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );

      await _loadProfile();
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text("Error al actualizar: $e")),
              ],
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // =========================
  // 🎨 UI Helpers
  // =========================
  InputDecoration _premiumInputDecoration({
    required String label,
    IconData? icon,
    String? hint,
    bool isReadOnly = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, color: _brandTeal),
      suffixIcon: isReadOnly
          ? Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade400)
          : null,
      filled: true,
      fillColor: _editMode ? const Color(0xFFFFFBF0) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: _editMode ? _brandTeal.withOpacity(0.3) : Colors.grey.shade200,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _brandTeal, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: _editMode ? const Color(0xFFFFFDF6) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _editMode
              ? _brandTeal.withOpacity(0.18)
              : Colors.transparent,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_editMode ? 0.06 : 0.04),
            blurRadius: _editMode ? 12 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _editMode
                      ? _brandTeal.withOpacity(0.18)
                      : _brandTeal.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _brandTeal, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _brandDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_editMode) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _brandTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Editando',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _brandTeal,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 75);
    if (picked != null) {
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() => _localAvatarFile = File(picked.path));
    }
  }

  ImageProvider? _avatarProvider() {
    if (_localAvatarFile != null) return FileImage(_localAvatarFile!);
    final url = _avatarUrlController.text.trim();
    if (url.isNotEmpty) return NetworkImage(url);
    return null;
  }

  // =========================
  // BUILD
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _brandDark,
        foregroundColor: Colors.white,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: Text(
            _editMode ? "Edita tu perfil" : "Mi perfil",
            key: ValueKey(_editMode),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: _brandTeal),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando perfil...',
                    style: TextStyle(
                      color: _brandDark.withOpacity(0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : _profile == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off_outlined,
                          size: 48, color: _brandDark.withOpacity(0.3)),
                      const SizedBox(height: 12),
                      const Text("No se pudo cargar el perfil"),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _loadProfile,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Reintentar"),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _premiumHeader(),
                    // Banner guía contextual con AnimatedSize
                    AnimatedSize(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOutCubic,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _editMode
                                ? [const Color(0xFFFFF8E1), const Color(0xFFFFF4D0)]
                                : [const Color(0xFFE8F5E9), const Color(0xFFE0F2F1)],
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _editMode
                                  ? Icons.edit_note_rounded
                                  : Icons.info_outline_rounded,
                              size: 18,
                              color: _editMode
                                  ? const Color(0xFF6C4A00)
                                  : _brandTeal,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _editMode
                                    ? "Modo edición activo. Modifica tus datos y toca Guardar al final."
                                    : "Para modificar tus datos, toca el botón 'Editar Perfil' en la parte superior.",
                                style: TextStyle(
                                  color: _editMode
                                      ? const Color(0xFF6C4A00)
                                      : _brandDark,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
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
                                          readOnly: true,
                                          decoration:
                                              _premiumInputDecoration(
                                            label:
                                                "Usuario (no editable)",
                                            icon: Icons.alternate_email,
                                            isReadOnly: true,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        TextFormField(
                                          controller:
                                              _fullNameController,
                                          readOnly: !_editMode,
                                          textCapitalization:
                                              TextCapitalization.words,
                                          decoration:
                                              _premiumInputDecoration(
                                            label: "Nombre completo",
                                            icon: Icons.person_outline,
                                          ),
                                          validator: _editMode
                                              ? (v) {
                                                  if (v == null ||
                                                      v.trim().length < 3) {
                                                    return 'Ingresa tu nombre completo';
                                                  }
                                                  return null;
                                                }
                                              : null,
                                        ),
                                        const SizedBox(height: 10),
                                        TextFormField(
                                          controller: _ageController,
                                          readOnly: !_editMode,
                                          keyboardType:
                                              TextInputType.number,
                                          decoration:
                                              _premiumInputDecoration(
                                            label: "Edad",
                                            icon: Icons.cake_outlined,
                                          ),
                                          validator: _editMode
                                              ? (v) {
                                                  if (v != null &&
                                                      v.trim().isNotEmpty) {
                                                    final n =
                                                        int.tryParse(v.trim());
                                                    if (n == null ||
                                                        n < 1 ||
                                                        n > 120) {
                                                      return 'Ingresa una edad válida (1-120)';
                                                    }
                                                  }
                                                  return null;
                                                }
                                              : null,
                                        ),
                                        const SizedBox(height: 10),
                                        DropdownButtonFormField<String>(
                                          value: _genderOptions.contains(
                                                  _genderController.text)
                                              ? _genderController.text
                                              : _genderOptions.first,
                                          decoration:
                                              _premiumInputDecoration(
                                            label: "Género",
                                            icon: Icons.wc_outlined,
                                          ),
                                          items: _genderOptions
                                              .map((g) =>
                                                  DropdownMenuItem<
                                                      String>(
                                                      value: g,
                                                      child: Text(g)))
                                              .toList(),
                                          onChanged: !_editMode
                                              ? null
                                              : (v) => setState(
                                                    () => _genderController
                                                            .text =
                                                        (v ??
                                                            _genderOptions
                                                                .first),
                                                  ),
                                        ),
                                      ],
                                    ),
                                    _sectionCard(
                                      title: "Mi sede",
                                      icon: Icons.storefront_rounded,
                                      children: [
                                        SedeSelectorField(
                                          selectedSedeId: _sede?.id,
                                          enabled: _editMode && !_sedeGuardando,
                                          onChanged: (sede) =>
                                              setState(() => _sede = sede),
                                          helperText:
                                              'Tus pedidos llegan a esta sede y aquí ves su catálogo y beneficios.',
                                        ),
                                      ],
                                    ),
                                    _sectionCard(
                                      title: "Sobre ti",
                                      icon: Icons.notes_outlined,
                                      children: [
                                        TextFormField(
                                          controller:
                                              _descriptionController,
                                          readOnly: !_editMode,
                                          maxLines: 3,
                                          decoration:
                                              _premiumInputDecoration(
                                            label: "Descripción",
                                            icon: Icons.short_text,
                                            hint:
                                                "Cuéntanos un poco sobre ti",
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        TextFormField(
                                          controller:
                                              _addressController,
                                          readOnly: !_editMode,
                                          decoration:
                                              _premiumInputDecoration(
                                            label: "Dirección",
                                            icon: Icons
                                                .location_on_outlined,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        TextFormField(
                                          controller: _phoneController,
                                          readOnly: !_editMode,
                                          keyboardType:
                                              TextInputType.phone,
                                          decoration:
                                              _premiumInputDecoration(
                                            label: "Celular",
                                            icon: Icons.phone_outlined,
                                          ),
                                          validator: _editMode
                                              ? (v) {
                                                  if (v != null &&
                                                      v.trim().isNotEmpty) {
                                                    final digits = v
                                                        .trim()
                                                        .replaceAll(
                                                            RegExp(
                                                                r'[^0-9]'),
                                                            '');
                                                    if (digits.length <
                                                            7 ||
                                                        digits.length >
                                                            15) {
                                                      return 'Número inválido (7-15 dígitos)';
                                                    }
                                                  }
                                                  return null;
                                                }
                                              : null,
                                        ),
                                      ],
                                    ),
                                    _sectionCard(
                                      title: "Ocupación y estudios",
                                      icon: Icons.school_outlined,
                                      children: [
                                        DropdownButtonFormField<String>(
                                          value: _occupationOptions
                                                  .contains(
                                                      _occupationController
                                                          .text)
                                              ? _occupationController
                                                  .text
                                              : _occupationOptions
                                                  .first,
                                          decoration:
                                              _premiumInputDecoration(
                                            label: "Ocupación",
                                            icon: Icons.work_outline,
                                          ),
                                          items: _occupationOptions
                                              .map((o) =>
                                                  DropdownMenuItem<
                                                      String>(
                                                      value: o,
                                                      child: Text(o)))
                                              .toList(),
                                          onChanged: !_editMode
                                              ? null
                                              : (v) => setState(
                                                    () => _occupationController
                                                            .text =
                                                        (v ??
                                                            _occupationOptions
                                                                .first),
                                                  ),
                                        ),
                                        const SizedBox(height: 10),
                                        DropdownButtonFormField<String>(
                                          value: _educationOptions
                                                  .contains(
                                                      _educationLevelController
                                                          .text)
                                              ? _educationLevelController
                                                  .text
                                              : _educationOptions.first,
                                          decoration:
                                              _premiumInputDecoration(
                                            label:
                                                "Nivel de educación",
                                            icon:
                                                Icons.menu_book_outlined,
                                          ),
                                          items: _educationOptions
                                              .map((e) =>
                                                  DropdownMenuItem<
                                                      String>(
                                                      value: e,
                                                      child: Text(e)))
                                              .toList(),
                                          onChanged: !_editMode
                                              ? null
                                              : (v) => setState(
                                                    () => _educationLevelController
                                                            .text =
                                                        (v ??
                                                            _educationOptions
                                                                .first),
                                                  ),
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
                      ),
                    ),
                    // Barra de guardar con animación slide
                    SlideTransition(
                      position: _saveBarSlide,
                      child: _editMode
                          ? _bottomSaveBar()
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
    );
  }

  // =========================
  // HEADER PREMIUM
  // =========================
  Widget _premiumHeader() {
    final avatar = _avatarProvider();
    final age = _ageController.text.trim();
    final gender = _genderController.text.trim();
    final occupation = _occupationController.text.trim();

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
                    image: avatar != null
                        ? DecorationImage(image: avatar, fit: BoxFit.cover)
                        : null,
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
                    bottom: 0,
                    right: 0,
                    child: ScaleTransition(
                      scale: _cameraPulse,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _brandTeal.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 15, color: _brandTeal),
                      ),
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
                  _fullNameController.text.trim().isEmpty
                      ? "Tu perfil"
                      : _fullNameController.text.trim(),
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
                  _usernameController.text.trim().isEmpty
                      ? "@"
                      : "@${_usernameController.text.trim()}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 10),
                if (!_editMode)
                  // Botón grande, ancho completo y visible para editar
                  GestureDetector(
                    onTap: _toggleEditMode,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_rounded,
                              size: 18, color: _brandTeal),
                          SizedBox(width: 8),
                          Text(
                            "Editar mi Perfil",
                            style: TextStyle(
                              color: _brandDark,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_editMode)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.28),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.25)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              "Editando datos",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                if (!_editMode)
                  const SizedBox(height: 8),
                if (!_editMode)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (age.isNotEmpty)
                        _headerInfoChip(Icons.cake_outlined, "$age años"),
                      if (gender.isNotEmpty)
                        _headerInfoChip(Icons.wc_outlined, gender),
                      if (occupation.isNotEmpty)
                        _headerInfoChip(Icons.work_outline, occupation),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // =========================
  // BOTTOM SAVE BAR
  // =========================
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
              child: OutlinedButton.icon(
                onPressed: (_loading || _saving)
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        _toggleEditMode();
                      },
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text("Cancelar"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _brandDark,
                  side: BorderSide(color: _brandDark.withOpacity(0.25)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_loading || _saving) ? null : _saveProfile,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline, size: 20),
                label: Text(_saving ? "Guardando..." : "Guardar"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 4,
                  shadowColor: _brandTeal.withOpacity(0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
