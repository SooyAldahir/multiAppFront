import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/auth_controller.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';

/// Datos personales y foto de perfil.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final User _user = context.read<AuthController>().user!;
  late final _name = TextEditingController(text: _user.name);
  late final _phone = TextEditingController(text: _user.phone);
  late final _city = TextEditingController(text: _user.city);
  late final _bio = TextEditingController(text: _user.bio);
  late DateTime? _birthDate = _user.birthDate;
  late String? _avatarUrl = _user.avatarUrl;
  Uint8List? _localPhoto;
  bool _saving = false;
  bool _uploading = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    _bio.dispose();
    super.dispose();
  }

  String? _clean(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _pickPhoto(ImageSource source) async {
    Uint8List bytes;
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
        preferredCameraDevice: CameraDevice.front,
      );
      if (file == null) return;
      bytes = await file.readAsBytes();
    } on PlatformException {
      if (mounted) showMessage(context, 'No se pudo abrir la cámara o la galería. Revisa los permisos.', error: true);
      return;
    }
    if (!mounted) return;
    setState(() {
      _localPhoto = bytes;
      _uploading = true;
    });
    try {
      final user = await context.read<ProfileRepository>().uploadAvatar(bytes);
      if (!mounted) return;
      await context.read<AuthController>().setUser(user);
      setState(() => _avatarUrl = user.avatarUrl);
      if (mounted) showMessage(context, 'Foto de perfil actualizada');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _localPhoto = null);
      showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _uploading = true);
    try {
      final user = await context.read<ProfileRepository>().deleteAvatar();
      if (!mounted) return;
      await context.read<AuthController>().setUser(user);
      setState(() {
        _avatarUrl = null;
        _localPhoto = null;
      });
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _photoOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (_avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.priorityHigh),
                title: const Text('Quitar foto', style: TextStyle(color: AppColors.priorityHigh)),
                onTap: () {
                  Navigator.pop(context);
                  _removePhoto();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Fecha de nacimiento',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      showMessage(context, 'Escribe tu nombre', error: true);
      return;
    }
    final phone = _clean(_phone);
    if (phone != null && !RegExp(r'^[0-9 +()\-]{7,20}$').hasMatch(phone)) {
      showMessage(context, 'Escribe un teléfono válido (solo números, espacios, + y guiones)', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final user = await context.read<ProfileRepository>().update({
        'name': name,
        'phone': phone,
        'birthDate': _birthDate == null ? null : User.dateOnly(_birthDate!),
        'city': _clean(_city),
        'bio': _clean(_bio),
      });
      if (!mounted) return;
      await context.read<AuthController>().setUser(user);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = context.select<AuthController, String>((a) => a.user?.initials ?? '?');

    return Scaffold(
      appBar: AppBar(title: const Text('Datos personales')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: GestureDetector(
              onTap: _uploading ? null : _photoOptions,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (_localPhoto != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(34),
                      child: Image.memory(_localPhoto!, width: 110, height: 110, fit: BoxFit.cover),
                    )
                  else
                    Avatar(initials: initials, imageUrl: _avatarUrl, size: 110, showStatus: false),
                  if (_uploading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(34),
                        ),
                        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                      ),
                    ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.background, width: 3),
                      ),
                      child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: _uploading ? null : _photoOptions,
              child: Text(_avatarUrl == null ? 'Agregar foto' : 'Cambiar foto'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Nombre', counterText: ''),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            maxLength: 20,
            decoration: const InputDecoration(labelText: 'Teléfono', counterText: '', prefixIcon: Icon(Icons.phone_outlined)),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickBirthDate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Fecha de nacimiento',
                prefixIcon: const Icon(Icons.cake_outlined),
                suffixIcon: _birthDate == null
                    ? null
                    : IconButton(
                        tooltip: 'Quitar',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() => _birthDate = null),
                      ),
              ),
              child: Text(
                _birthDate == null
                    ? 'Sin definir'
                    : DateFormat("d 'de' MMMM 'de' y", 'es').format(_birthDate!),
                style: TextStyle(color: _birthDate == null ? AppColors.mutedLight : AppColors.ink),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _city,
            textCapitalization: TextCapitalization.words,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Ciudad', counterText: '', prefixIcon: Icon(Icons.location_city_outlined)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _bio,
            maxLines: 3,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Sobre mí', alignLabelWithHint: true),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
