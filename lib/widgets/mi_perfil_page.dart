import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../models/user_profile.dart';
import '../services/user_profile_service.dart';
import '../services/session_manager.dart';
import '../services/user_info_service.dart';
import '../services/avatar_upload_service.dart';
import '../services/auth_service.dart';
import '../constants/service_code.dart';

class MiPerfilPage extends StatefulWidget {
  const MiPerfilPage({super.key});

  @override
  State<MiPerfilPage> createState() => _MiPerfilPageState();
}

class _MiPerfilPageState extends State<MiPerfilPage> {
  final Color mainColor = const Color.fromARGB(255, 27, 111, 129);
  static const String ME_URL = 'https://services.fintbot.pe/api/auth/me/';

  bool _editMode = false;
  bool _loading = false;
  UserProfile? _profile;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fcmTokenController = TextEditingController();

  // Controladores para los campos del backend
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _occupationController = TextEditingController();
  final TextEditingController _educationLevelController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _avatarUrlController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();

  DateTime? _birthday;

  // Opciones para selects
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
    _longitudeController.dispose();
    _latitudeController.dispose();
    _avatarUrlController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.trim().isEmpty) return null;
    return token.trim();
  }

  Future<void> _loadProfile() async {
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

      // Si el token expiró (401), intentamos refrescar y reintentar una vez
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

        // Obtener el token FCM generado por Firebase desde SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final fcm = prefs.getString('fcm_token') ?? '';

        final profile = UserProfile.fromJson(data, fcmToken: fcm);

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
          _longitudeController.text = profile.longitude?.toString() ?? '';
          _latitudeController.text = profile.latitude?.toString() ?? '';
          _avatarUrlController.text = profile.avatarUrl ?? '';
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
      setState(() {
        _birthday = parsed;
        _birthdayController.text =
            '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year.toString().padLeft(4, '0')}';
      });
    } catch (_) {
      // Si falla el parseo, ignoramos y dejamos que el usuario lo vuelva a definir.
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      // ✅ Prioriza lo que el usuario escribió
      String fcmValue = _fcmTokenController.text.trim();
      if (fcmValue.isEmpty) {
        fcmValue = (await SessionManager.getFcmToken()) ?? '';
      }
      if (fcmValue.length > 255) {
        fcmValue = fcmValue.substring(0, 255);
      }

      // Guardar el token FCM en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', fcmValue);

      // Guardar localmente la fecha de cumpleaños (solo en SharedPreferences)
      if (_birthday != null) {
        final String bStr =
            '${_birthday!.year.toString().padLeft(4, '0')}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}';
        await prefs.setString('birthday', bStr);
      }

      final userId = await UserInfoService.fetchUserId(); // se usa para PATCH y, si quieres, para subir avatar
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No se pudo obtener el id del usuario autenticado")),
          );
        }
        return;
      }

      // Actualizar latitud y longitud automáticamente desde el dispositivo (si es posible)
      await _updateLocationFromDevice();

      // 1) Si se seleccionó un avatar local, subirlo y obtener URL
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

      // 2) Construir el body del PATCH con todos los campos editables
      double? longitude;
      double? latitude;
      if (_longitudeController.text.trim().isNotEmpty) {
        longitude = double.tryParse(_longitudeController.text.trim());
      }
      if (_latitudeController.text.trim().isNotEmpty) {
        latitude = double.tryParse(_latitudeController.text.trim());
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
        'use_double_longitude': longitude,
        'use_double_latitude': latitude,
      };

      await UserProfileService.updateUserProfileRaw(
        patchBody,
        userId: userId,
      );

      if (mounted) {
        setState(() {
          _editMode = false;
          _profile = UserProfile.fromJson(patchBody, fcmToken: fcmValue);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Perfil actualizado correctamente")),
        );
      }
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

  Future<void> _updateLocationFromDevice() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _latitudeController.text = position.latitude.toString();
      _longitudeController.text = position.longitude.toString();
    } catch (_) {
      // Si falla, no interrumpimos el guardado del perfil.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Mi Perfil", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: Icon(_editMode ? Icons.close : Icons.edit),
            tooltip: _editMode ? "Cancelar" : "Editar perfil",
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
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                const SizedBox(height: 30),
                                Center(
                                  child: GestureDetector(
                                    onTap: _editMode
                                        ? () async {
                                            final XFile? picked = await _imagePicker.pickImage(
                                              source: ImageSource.gallery,
                                            );
                                            if (picked != null) {
                                              setState(() {
                                                _localAvatarFile = File(picked.path);
                                              });
                                            }
                                          }
                                        : null,
                                    child: CircleAvatar(
                                      radius: 60,
                                      backgroundColor: Colors.white,
                                      backgroundImage: _localAvatarFile != null
                                          ? FileImage(_localAvatarFile!)
                                          : (_avatarUrlController.text.trim().isNotEmpty
                                              ? NetworkImage(_avatarUrlController.text.trim())
                                                  as ImageProvider
                                              : null),
                                      child: (_localAvatarFile == null &&
                                              _avatarUrlController.text.trim().isEmpty)
                                          ? Icon(
                                              FontAwesomeIcons.userCircle,
                                              size: 80,
                                              color: mainColor,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                                // Usuario
                                TextFormField(
                                  controller: _usernameController,
                                  readOnly: !_editMode,
                                  decoration: const InputDecoration(
                                    labelText: "Usuario",
                                    border: OutlineInputBorder(),
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // Nombre completo
                                TextFormField(
                                  controller: _fullNameController,
                                  readOnly: !_editMode,
                                  decoration: const InputDecoration(
                                    labelText: "Nombre completo",
                                    border: OutlineInputBorder(),
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // Edad
                                TextFormField(
                                  controller: _ageController,
                                  readOnly: !_editMode,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "Edad",
                                    border: OutlineInputBorder(),
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // Fecha de cumpleaños (local, para beneficios)
                                TextFormField(
                                  controller: _birthdayController,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: "Fecha de cumpleaños (para beneficios)",
                                    border: OutlineInputBorder(),
                                  ),
                                  onTap: !_editMode
                                      ? null
                                      : () async {
                                          final DateTime now = DateTime.now();
                                          final DateTime initialDate = _birthday ??
                                              DateTime(now.year - 18, now.month, now.day);

                                          final DateTime? picked = await showDatePicker(
                                            context: context,
                                            initialDate: initialDate,
                                            firstDate: DateTime(1900),
                                            lastDate: now,
                                          );

                                          if (picked != null) {
                                            setState(() {
                                              _birthday = picked;
                                              _birthdayController.text =
                                                  '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year.toString().padLeft(4, '0')}';
                                            });
                                          }
                                        },
                                ),

                                const SizedBox(height: 10),

                                // Género
                                DropdownButtonFormField<String>(
                                  value: _genderOptions.contains(_genderController.text)
                                      ? _genderController.text
                                      : _genderOptions.first,
                                  decoration: const InputDecoration(
                                    labelText: "Género",
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _genderOptions
                                      .map((g) => DropdownMenuItem<String>(
                                            value: g,
                                            child: Text(g),
                                          ))
                                      .toList(),
                                  onChanged: !_editMode
                                      ? null
                                      : (value) {
                                          if (value == null) return;
                                          setState(() {
                                            _genderController.text = value;
                                          });
                                        },
                                ),

                                const SizedBox(height: 10),

                                // Descripción
                                TextFormField(
                                  controller: _descriptionController,
                                  readOnly: !_editMode,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: "Descripción",
                                    border: OutlineInputBorder(),
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // Dirección
                                TextFormField(
                                  controller: _addressController,
                                  readOnly: !_editMode,
                                  decoration: const InputDecoration(
                                    labelText: "Dirección",
                                    border: OutlineInputBorder(),
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // Ocupación
                                DropdownButtonFormField<String>(
                                  value: _occupationOptions.contains(_occupationController.text)
                                      ? _occupationController.text
                                      : _occupationOptions.first,
                                  decoration: const InputDecoration(
                                    labelText: "Ocupación",
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _occupationOptions
                                      .map((o) => DropdownMenuItem<String>(
                                            value: o,
                                            child: Text(o),
                                          ))
                                      .toList(),
                                  onChanged: !_editMode
                                      ? null
                                      : (value) {
                                          if (value == null) return;
                                          setState(() {
                                            _occupationController.text = value;
                                          });
                                        },
                                ),

                                const SizedBox(height: 10),

                                // Nivel educativo
                                DropdownButtonFormField<String>(
                                  value: _educationOptions.contains(_educationLevelController.text)
                                      ? _educationLevelController.text
                                      : _educationOptions.first,
                                  decoration: const InputDecoration(
                                    labelText: "Nivel de educación",
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _educationOptions
                                      .map((e) => DropdownMenuItem<String>(
                                            value: e,
                                            child: Text(e),
                                          ))
                                      .toList(),
                                  onChanged: !_editMode
                                      ? null
                                      : (value) {
                                          if (value == null) return;
                                          setState(() {
                                            _educationLevelController.text = value;
                                          });
                                        },
                                ),

                                const SizedBox(height: 30),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_editMode)
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.save),
                              label: const Text("Guardar cambios"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: mainColor,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _loading ? null : _saveProfile,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
