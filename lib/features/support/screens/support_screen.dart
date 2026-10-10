import 'package:flutter/material.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';

/// General support - mirrors the web customer support page.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static const _subjects = [
    'Service Request',
    'Billing Inquiry',
    'Technical Support',
    'Vehicle Registration',
    'Other',
  ];

  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _message = TextEditingController();
  String _subject = _subjects.first;
  bool _sending = false;

  @override
  void dispose() {
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final res = await apiClient.post('/api/v1/customer/support', {
        'subject': _subject,
        'message': _message.text.trim(),
        'phone': _phone.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['message'] ?? 'Message sent'),
          backgroundColor: SogoColors.success));
      _message.clear();
      Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(title: const Text('Help & support')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(SogoSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Quick contact
          Row(children: [
            Expanded(
                child: SogoCard(
              onTap: () {},
              padding: const EdgeInsets.all(SogoSpacing.md),
              child: Column(children: [
                const Icon(Icons.phone_outlined, color: SogoColors.primary),
                const SizedBox(height: 6),
                Text('Call us',
                    style:
                        SogoText.bodySm.copyWith(fontWeight: FontWeight.w700)),
                Text('+256 312 345 678',
                    style: SogoText.labelMd
                        .copyWith(color: SogoColors.textSecondary)),
              ]),
            )),
            const SizedBox(width: SogoSpacing.md),
            Expanded(
                child: SogoCard(
              onTap: () {},
              padding: const EdgeInsets.all(SogoSpacing.md),
              child: Column(children: [
                const Icon(Icons.mail_outline, color: SogoColors.primary),
                const SizedBox(height: 6),
                Text('Email',
                    style:
                        SogoText.bodySm.copyWith(fontWeight: FontWeight.w700)),
                Text('support@sogo.co.ug',
                    style: SogoText.labelMd
                        .copyWith(color: SogoColors.textSecondary)),
              ]),
            )),
          ]),
          const SizedBox(height: SogoSpacing.xl),

          SogoCard(
            child: Form(
              key: _form,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Send us a message', style: SogoText.headlineMd),
                    const SizedBox(height: SogoSpacing.lg),
                    DropdownButtonFormField<String>(
                      initialValue: _subject,
                      decoration: InputDecoration(
                          labelText: 'Subject',
                          prefixIcon: const Icon(Icons.subject_outlined),
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(SogoRadius.md))),
                      items: _subjects
                          .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _subject = v ?? _subjects.first),
                    ),
                    const SizedBox(height: SogoSpacing.md),
                    SogoTextField(
                        label: 'Phone (optional)',
                        hint: 'Where we can reach you',
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined),
                    const SizedBox(height: SogoSpacing.md),
                    TextFormField(
                      controller: _message,
                      maxLines: 5,
                      maxLength: 4000,
                      decoration: InputDecoration(
                          labelText: 'Message',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(SogoRadius.md))),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Tell us what happened'
                          : null,
                    ),
                    const SizedBox(height: SogoSpacing.md),
                    SogoButton(
                        label: 'Send message',
                        onPressed: _submit,
                        loading: _sending),
                  ]),
            ),
          ),
          const SizedBox(height: SogoSpacing.xl),

          const SogoSectionTitle('Quick answers'),
          ...[
            (
              'How do I book a service?',
              'Tap the green + button on the bottom bar, pick a service and your location - we match the nearest available provider.'
            ),
            (
              'How do payments work?',
              'Pay by Mobile Money or card through Flutterwave, or top up your SOGO wallet from the Payments tab and pay from your balance.'
            ),
            (
              'Where is my order?',
              'Open Orders from your home screen and tap any order to see its status, items and totals.'
            ),
            (
              'Is my provider verified?',
              'Yes - every provider on SOGO is identity-checked and approved by our team before they can receive jobs.'
            ),
          ].map((faq) => Padding(
                padding: const EdgeInsets.only(bottom: SogoSpacing.md),
                child: SogoCard(
                  padding: const EdgeInsets.all(SogoSpacing.md),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(faq.$1,
                            style: SogoText.bodyMd
                                .copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(faq.$2,
                            style: SogoText.bodySm
                                .copyWith(color: SogoColors.textSecondary)),
                      ]),
                ),
              )),
        ]),
      ),
    );
  }
}
