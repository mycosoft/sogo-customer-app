import 'package:flutter/material.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';
import '../../../core/widgets/terms_modal.dart';
import 'otp_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _terms = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_terms) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please accept the terms')));
      return;
    }
    setState(() => _loading = true);
    try {
      await authApi.register(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      // Verify the phone (OTP) first - customers land straight on the
      // dashboard afterwards, no admin approval needed.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(phone: _phone.text.trim())),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SogoSpacing.xl),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Join SOGO', style: SogoText.displayMd),
                const SizedBox(height: 6),
                Text('Book and manage vehicle services in minutes',
                    style: SogoText.bodyMd
                        .copyWith(color: SogoColors.textSecondary)),
                const SizedBox(height: SogoSpacing.xl),
                SogoTextField(
                    label: 'Full name',
                    hint: 'Your name',
                    controller: _name,
                    prefixIcon: Icons.person_outline,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null),
                const SizedBox(height: SogoSpacing.lg),
                SogoTextField(
                    label: 'Phone',
                    hint: '+256 700 000 000',
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_outlined,
                    validator: (v) =>
                        v == null || v.length < 7 ? 'Invalid phone' : null),
                const SizedBox(height: SogoSpacing.lg),
                SogoTextField(
                    label: 'Email',
                    hint: 'you@example.com',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.alternate_email,
                    validator: (v) =>
                        v == null || !v.contains('@') ? 'Invalid email' : null),
                const SizedBox(height: SogoSpacing.lg),
                SogoTextField(
                    label: 'Password',
                    hint: 'At least 8 characters',
                    controller: _password,
                    obscureText: _obscure,
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                        icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: SogoColors.textMuted),
                        onPressed: () => setState(() => _obscure = !_obscure)),
                    validator: (v) =>
                        v == null || v.length < 8 ? 'Min 8 characters' : null),
                const SizedBox(height: SogoSpacing.lg),
                SogoTextField(
                    label: 'Confirm password',
                    hint: 'Re-enter password',
                    controller: _confirm,
                    obscureText: true,
                    prefixIcon: Icons.lock_outline,
                    validator: (v) =>
                        v != _password.text ? 'Passwords do not match' : null),
                const SizedBox(height: SogoSpacing.md),
                Row(
                  children: [
                    Checkbox(
                        value: _terms,
                        onChanged: (v) => setState(() => _terms = v ?? false),
                        activeColor: SogoColors.primary),
                    Expanded(
                        child: GestureDetector(
                      onTap: () => showTermsModal(context),
                      child: Text.rich(
                        TextSpan(
                          text: 'I agree to the ',
                          style: SogoText.bodySm
                              .copyWith(color: SogoColors.textSecondary),
                          children: [
                            TextSpan(
                              text: 'Terms & Privacy Policy',
                              style: SogoText.bodySm.copyWith(
                                  color: SogoColors.primary,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline),
                            ),
                          ],
                        ),
                      ),
                    )),
                  ],
                ),
                const SizedBox(height: SogoSpacing.md),
                SogoButton(
                    label: 'Create account',
                    onPressed: _submit,
                    loading: _loading),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
