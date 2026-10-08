import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';
import '../../auth/screens/login_screen.dart';
import '../../messages/screens/chats_screen.dart';
import '../../support/screens/support_screen.dart';
import '../../vehicles/screens/vehicles_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _future = authApi.me();
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController();
  final _nationalId = TextEditingController();
  final _occupation = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();
  String? _gender;
  DateTime? _dob;
  String? _language;
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _showPassword = false;
  // View-first: the form only appears after tapping Edit profile.
  bool _editing = false;
  String? _avatarPath;
  String? _coverPath;
  bool _filled = false;

  static const _languages = [
    ('en', 'English'),
    ('lg', 'Luganda'),
    ('sw', 'Kiswahili')
  ];

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _country.dispose();
    _nationalId.dispose();
    _occupation.dispose();
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SogoRadius.lg)),
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to use the app.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Stay')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out',
                style: TextStyle(color: SogoColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await authApi.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _saveProfile() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _savingProfile = true);
    try {
      await customerApi.updateProfile({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'city': _city.text.trim(),
        'country': _country.text.trim(),
        'national_id': _nationalId.text.trim(),
        'occupation': _occupation.text.trim(),
        'emergency_contact_name': _emergencyName.text.trim(),
        'emergency_contact_phone': _emergencyPhone.text.trim(),
        if (_gender != null) 'gender': _gender!,
        if (_dob != null)
          'date_of_birth': _dob!.toIso8601String().substring(0, 10),
        if (_language != null) 'preferred_language': _language!,
      }, avatarPath: _avatarPath, coverPath: _coverPath);
      setState(() {
        _future = authApi.me();
        _editing = false;
        _avatarPath = null;
        _coverPath = null;
        _filled = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile updated'),
              backgroundColor: SogoColors.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            backgroundColor: SogoColors.danger,
            content: Text('Could not save: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _updatePassword() async {
    if (_currentPassword.text.isEmpty || _newPassword.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Enter current password and a new password (min 8 characters)')),
      );
      return;
    }
    setState(() => _savingPassword = true);
    try {
      await authApi.updatePassword(
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      );
      _currentPassword.clear();
      _newPassword.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Password updated'),
              backgroundColor: SogoColors.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    final first = parts.first[0];
    final second = parts.length > 1 ? parts.last[0] : '';
    return (first + second).toUpperCase();
  }

  Future<void> _pickImage(bool isAvatar) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1600, imageQuality: 82);
    if (x == null) return;
    setState(() {
      if (isAvatar) {
        _avatarPath = x.path;
      } else {
        _coverPath = x.path;
      }
    });
  }

  void _fillFrom(Map<String, dynamic> user) {
    if (_filled) return;
    _filled = true;
    _name.text = '${user['name'] ?? ''}';
    _email.text = '${user['email'] ?? ''}';
    _phone.text = '${user['phone'] ?? ''}';
    _address.text = '${user['address'] ?? ''}';
    _city.text = '${user['city'] ?? ''}';
    _country.text = '${user['country'] ?? ''}';
    _nationalId.text = '${user['national_id'] ?? ''}';
    _occupation.text = '${user['occupation'] ?? ''}';
    _emergencyName.text = '${user['emergency_contact_name'] ?? ''}';
    _emergencyPhone.text = '${user['emergency_contact_phone'] ?? ''}';
    _gender = (user['gender'] == null || '${user['gender']}'.isEmpty)
        ? null
        : '${user['gender']}';
    _language = (user['preferred_language'] == null ||
            '${user['preferred_language']}'.isEmpty)
        ? null
        : '${user['preferred_language']}';
    _dob = user['date_of_birth'] == null || '${user['date_of_birth']}'.isEmpty
        ? null
        : DateTime.tryParse('${user['date_of_birth']}');
  }

  Widget _header(Map<String, dynamic> user) {
    // me() returns avatar + cover_image_url as full URLs.
    final avatar = '${user['avatar'] ?? ''}';
    final cover = '${user['cover_image_url'] ?? ''}';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SogoRadius.xl),
        boxShadow: const [SogoShadows.elevated],
      ),
      child: Column(
        children: [
          // Cover banner.
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(SogoRadius.xl)),
            child: Container(
              height: 120,
              width: double.infinity,
              color: SogoColors.primary,
              foregroundDecoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.25)
                    ]),
              ),
              child: _coverPath != null
                  ? Image.file(File(_coverPath!), fit: BoxFit.cover)
                  : (cover.isNotEmpty
                      ? Image.network(cover,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink())
                      : const SizedBox.shrink()),
            ),
          ),
          // Identity row overlapping the cover.
          Container(
            padding: const EdgeInsets.fromLTRB(
                SogoSpacing.xl, 0, SogoSpacing.xl, SogoSpacing.xl),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [SogoColors.primary, SogoColors.primaryDark]),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(SogoRadius.xl)),
            ),
            child: Row(
              children: [
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Stack(children: [
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _avatarPath != null || avatar.isNotEmpty
                            ? Colors.transparent
                            : Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: _avatarPath != null
                          ? ClipOval(
                              child: Image.file(File(_avatarPath!),
                                  width: 66, height: 66, fit: BoxFit.cover))
                          : (avatar.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(avatar,
                                      width: 66,
                                      height: 66,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Text(
                                            _initials(user['name']),
                                            style: SogoText.headlineLg
                                                .copyWith(color: Colors.white),
                                          )))
                              : Text(
                                  _initials(user['name']),
                                  style: SogoText.headlineLg
                                      .copyWith(color: Colors.white),
                                )),
                    ),
                    if (_editing)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () => _pickImage(true),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                size: 14, color: SogoColors.primary),
                          ),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(width: SogoSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${user['name'] ?? ''}',
                        style:
                            SogoText.headlineMd.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${user['phone'] ?? user['email'] ?? ''}',
                        style: SogoText.bodySm.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                if (_editing)
                  IconButton(
                    tooltip: 'Change cover',
                    onPressed: () => _pickImage(false),
                    icon: const Icon(Icons.add_photo_alternate_outlined,
                        color: Colors.white),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountDetails() {
    return SogoCard(
      child: Form(
        key: _form,
        child: Column(
          children: [
            SogoTextField(
              label: 'Full name',
              hint: 'Your name',
              controller: _name,
              prefixIcon: Icons.person_outline,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: SogoSpacing.md),
            SogoTextField(
              label: 'Email',
              hint: 'you@example.com',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.alternate_email,
              validator: (v) =>
                  v == null || !v.contains('@') ? 'Invalid email' : null,
            ),
            const SizedBox(height: SogoSpacing.md),
            SogoTextField(
              label: 'Phone',
              hint: '+256 700 000 000',
              controller: _phone,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
            ),
            const SizedBox(height: SogoSpacing.md),
            // -- Extended profile (matches the web profile page) --
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: const Icon(Icons.wc_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SogoRadius.md))),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: SogoSpacing.md),
            InkWell(
              borderRadius: BorderRadius.circular(SogoRadius.md),
              onTap: () async {
                final picked = await showDatePicker(
                    context: context,
                    initialDate: _dob ?? DateTime(2000),
                    firstDate: DateTime(1930),
                    lastDate: DateTime.now());
                if (picked != null) setState(() => _dob = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                    labelText: 'Date of birth',
                    prefixIcon: const Icon(Icons.cake_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(SogoRadius.md))),
                child: Text(_dob == null
                    ? 'Select date'
                    : _dob!.toIso8601String().substring(0, 10)),
              ),
            ),
            const SizedBox(height: SogoSpacing.md),
            SogoTextField(
              label: 'National ID (NIN)',
              hint: 'CM00000000',
              controller: _nationalId,
              prefixIcon: Icons.badge_outlined,
            ),
            const SizedBox(height: SogoSpacing.md),
            SogoTextField(
              label: 'Street address',
              hint: 'Plot 12, Acacia Avenue',
              controller: _address,
              prefixIcon: Icons.home_outlined,
            ),
            const SizedBox(height: SogoSpacing.md),
            SogoTextField(
              label: 'City / Town',
              hint: 'Kampala',
              controller: _city,
              prefixIcon: Icons.location_city_outlined,
            ),
            const SizedBox(height: SogoSpacing.md),
            SogoTextField(
              label: 'Country',
              hint: 'Uganda',
              controller: _country,
              prefixIcon: Icons.public_outlined,
            ),
            const SizedBox(height: SogoSpacing.md),
            SogoTextField(
              label: 'Occupation',
              hint: 'e.g. Teacher',
              controller: _occupation,
              prefixIcon: Icons.work_outline,
            ),
            const SizedBox(height: SogoSpacing.md),
            SogoTextField(
              label: 'Emergency contact name',
              hint: 'Next of kin',
              controller: _emergencyName,
              prefixIcon: Icons.contact_emergency_outlined,
            ),
            const SizedBox(height: SogoSpacing.md),
            SogoTextField(
              label: 'Emergency contact phone',
              hint: '+256 700 000 000',
              controller: _emergencyPhone,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
            ),
            const SizedBox(height: SogoSpacing.md),
            DropdownButtonFormField<String>(
              value: _language,
              decoration: InputDecoration(
                  labelText: 'Preferred language',
                  prefixIcon: const Icon(Icons.language_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SogoRadius.md))),
              items: _languages
                  .map((l) => DropdownMenuItem(value: l.$1, child: Text(l.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _language = v),
            ),
            const SizedBox(height: SogoSpacing.lg),
            SogoButton(
                label: 'Save changes',
                onPressed: _saveProfile,
                loading: _savingProfile),
          ],
        ),
      ),
    );
  }

  Widget _viewRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: SogoSpacing.sm),
      child: Row(children: [
        Icon(icon, size: 18, color: SogoColors.primary),
        const SizedBox(width: SogoSpacing.md),
        SizedBox(
            width: 120,
            child: Text(label,
                style:
                    SogoText.bodySm.copyWith(color: SogoColors.textSecondary))),
        Expanded(
            child: Text(value,
                style: SogoText.bodySm.copyWith(fontWeight: FontWeight.w600))),
      ]),
    );
  }

  String _langName(String? code) {
    return switch (code) {
      'lg' => 'Luganda',
      'sw' => 'Kiswahili',
      'en' => 'English',
      _ => code ?? '',
    };
  }

  Widget _profileView(Map<String, dynamic> user) {
    final location = [
      '${user['address'] ?? ''}',
      '${user['city'] ?? ''}',
      '${user['country'] ?? ''}'
    ].where((s) => s.isNotEmpty).join(', ');
    return SogoCard(
      child: Column(children: [
        _viewRow(Icons.person_outline, 'Name', '${user['name'] ?? ''}'),
        _viewRow(Icons.alternate_email, 'Email', '${user['email'] ?? ''}'),
        _viewRow(Icons.phone_outlined, 'Phone', '${user['phone'] ?? ''}'),
        _viewRow(
            Icons.wc_outlined,
            'Gender',
            '${user['gender'] ?? ''}'.isEmpty
                ? ''
                : '${user['gender']}'[0].toUpperCase() +
                    '${user['gender']}'.substring(1)),
        _viewRow(Icons.cake_outlined, 'Born', '${user['date_of_birth'] ?? ''}'),
        _viewRow(Icons.badge_outlined, 'National ID',
            '${user['national_id'] ?? ''}'),
        _viewRow(Icons.home_outlined, 'Address', location),
        _viewRow(
            Icons.work_outline, 'Occupation', '${user['occupation'] ?? ''}'),
        _viewRow(Icons.contact_emergency_outlined, 'Emergency',
            '${user['emergency_contact_name'] ?? ''}${'${user['emergency_contact_phone'] ?? ''}'.isNotEmpty ? ' · ${user['emergency_contact_phone']}' : ''}'),
        _viewRow(
            Icons.language_outlined,
            'Language',
            _langName('${user['preferred_language'] ?? ''}'.isEmpty
                ? null
                : '${user['preferred_language']}')),
        const SizedBox(height: SogoSpacing.md),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _editing = true),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit profile'),
            style: OutlinedButton.styleFrom(
              foregroundColor: SogoColors.primary,
              side: const BorderSide(color: SogoColors.primary, width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: SogoSpacing.md + 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SogoRadius.md),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _vehiclesCard() {
    return SogoCard(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const VehiclesScreen())),
      padding: const EdgeInsets.symmetric(
          horizontal: SogoSpacing.lg, vertical: SogoSpacing.md),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: SogoColors.primaryLight,
              borderRadius: BorderRadius.circular(SogoRadius.md),
            ),
            child: const Icon(Icons.directions_car_outlined,
                color: SogoColors.primary),
          ),
          const SizedBox(width: SogoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manage vehicles',
                    style:
                        SogoText.bodyLg.copyWith(fontWeight: FontWeight.w700)),
                Text('Add, edit or remove your vehicles',
                    style: SogoText.bodySm
                        .copyWith(color: SogoColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: SogoColors.textMuted),
        ],
      ),
    );
  }

  Widget _linkCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return SogoCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
          horizontal: SogoSpacing.lg, vertical: SogoSpacing.md),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: SogoColors.primaryLight,
              borderRadius: BorderRadius.circular(SogoRadius.md),
            ),
            child: Icon(icon, color: SogoColors.primary),
          ),
          const SizedBox(width: SogoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        SogoText.bodyLg.copyWith(fontWeight: FontWeight.w700)),
                Text(subtitle,
                    style: SogoText.bodySm
                        .copyWith(color: SogoColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: SogoColors.textMuted),
        ],
      ),
    );
  }

  Widget _securityCard() {
    return SogoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _securityChildren(),
      ),
    );
  }

  List<Widget> _securityChildren() {
    if (!_showPassword) {
      return [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _showPassword = true),
            icon: const Icon(Icons.lock_outline, size: 18),
            label: const Text('Change password'),
            style: OutlinedButton.styleFrom(
              foregroundColor: SogoColors.primary,
              side: const BorderSide(color: SogoColors.primary, width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: SogoSpacing.md + 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SogoRadius.md),
              ),
            ),
          ),
        ),
      ];
    }
    return [
      SogoTextField(
        label: 'Current password',
        hint: 'Enter current password',
        controller: _currentPassword,
        obscureText: true,
        prefixIcon: Icons.lock_outline,
      ),
      const SizedBox(height: SogoSpacing.md),
      SogoTextField(
        label: 'New password',
        hint: 'At least 8 characters',
        controller: _newPassword,
        obscureText: true,
        prefixIcon: Icons.lock_reset_outlined,
      ),
      const SizedBox(height: SogoSpacing.lg),
      Row(
        children: [
          Expanded(
            child: SogoButton(
              label: 'Update password',
              onPressed: _updatePassword,
              loading: _savingPassword,
            ),
          ),
          const SizedBox(width: SogoSpacing.sm),
          IconButton(
            onPressed: () {
              _currentPassword.clear();
              _newPassword.clear();
              setState(() => _showPassword = false);
            },
            icon: const Icon(Icons.close_rounded, color: SogoColors.textMuted),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data!['data'] as Map<String, dynamic>;
          _fillFrom(user);

          final children = <Widget>[
            _header(user),
            const SizedBox(height: SogoSpacing.xl),
            if (_editing) ...[
              Row(children: [
                const Expanded(child: SogoSectionTitle('Edit profile')),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _editing = false;
                    _avatarPath = null;
                    _coverPath = null;
                    _filled = false;
                    _future = authApi.me();
                  }),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Cancel'),
                ),
              ]),
              _accountDetails(),
            ] else ...[
              const SogoSectionTitle('My details'),
              _profileView(user),
            ],
            const SizedBox(height: SogoSpacing.xl),
            const SogoSectionTitle('Account details'),
            _accountDetails(),
            const SizedBox(height: SogoSpacing.xl),
            const SogoSectionTitle('My vehicles'),
            _vehiclesCard(),
            const SizedBox(height: SogoSpacing.md),
            _linkCard(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Messages',
                subtitle: 'Chat with providers and SOGO Support',
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChatsScreen()))),
            const SizedBox(height: SogoSpacing.md),
            _linkCard(
                icon: Icons.support_agent_rounded,
                title: 'Help & support',
                subtitle: 'FAQs or send us a message',
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SupportScreen()))),
            const SizedBox(height: SogoSpacing.xl),
            const SogoSectionTitle('Security'),
            _securityCard(),
            const SizedBox(height: SogoSpacing.xl),
            SogoButton(
              label: 'Log out',
              variant: SogoButtonVariant.danger,
              icon: Icons.logout_rounded,
              onPressed: _logout,
            ),
            const SizedBox(height: SogoSpacing.xxl),
          ];

          return ListView(
            padding: const EdgeInsets.all(SogoSpacing.lg),
            children: children,
          );
        },
      ),
    );
  }
}
