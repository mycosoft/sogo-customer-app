import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';

const String _kTerms = '''
Welcome to SOGO - services on the go. By creating an account or using the SOGO apps or website, you agree to these terms.

1. Using SOGO
You must be at least 18 years old to create an account. You are responsible for keeping your login details safe and for all activity under your account. Provide accurate information - false details may lead to suspension.

2. Services
SOGO connects customers with independent, verified service providers (mechanics, and other home & auto services). Providers are screened and approved by SOGO before they can receive jobs, but they act as independent contractors. SOGO facilitates the booking, payment and quality feedback loop.

3. Bookings & cancellations
A booking is confirmed when a provider accepts your request. You may cancel a request before a provider arrives; repeated abuse of free cancellations or no-shows may result in fees or account limits.

4. Payments
All payments are processed securely through Flutterwave (Mobile Money, cards, or your SOGO wallet). Wallet deposits are credited once payment is confirmed. Service fees are shown before you confirm a booking. Refunds for failed or cancelled jobs are returned to your SOGO wallet.

5. Withdrawals
Provider earnings and approved customer refunds may be withdrawn to Mobile Money or a bank account. Withdrawals are reviewed by SOGO and paid out through Flutterwave transfers.

6. Conduct
Treat providers, customers and SOGO staff with respect. Fraud, abuse, harassment or attempts to move transactions off-platform may result in immediate suspension.

7. Liability
SOGO is provided "as is". While we verify providers, SOGO is not liable for the underlying workmanship beyond facilitating refunds where a job was paid but not delivered. Nothing in these terms limits rights you have under Ugandan consumer law.

8. Changes
We may update these terms; material changes will be communicated in the app. Continuing to use SOGO after an update means you accept the new terms.

Contact: support@sogo.co.ug - +256 312 345 678
''';

const String _kPrivacy = '''
Your privacy matters. This policy explains what SOGO collects and why.

1. What we collect
- Account details: name, phone number, email, and the profile fields you add (address, city, vehicle details, emergency contact).
- Location data: your GPS position is used ONLY to match you with nearby providers and to show live job tracking. You control this via your device permissions.
- Communications: messages you exchange with providers/support through the app.
- Payment metadata: transaction references and statuses from Flutterwave. SOGO never stores your card or Mobile Money PIN.

2. How we use it
To create and secure your account, match bookings to the nearest available provider, show live tracking, send OTP codes and service notifications by SMS, WhatsApp and push, and provide support.

3. Sharing
Your name, phone number and booking location are shared with the provider assigned to your job - no one else. Payments are handled by Flutterwave. We never sell your data.

4. Storage & security
Data is stored on secured servers with access limited to authorised SOGO staff. Messages and notifications are encrypted in transit.

5. Your rights
You can view, correct and delete your profile details in the app. Deleting your account removes your personal data except records we must keep for accounting or legal reasons.

6. Contact
Questions about privacy: support@sogo.co.ug
''';

Future<void> showTermsModal(BuildContext context,
    {bool initialPrivacy = false}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(SogoRadius.lg))),
    builder: (ctx) => const _TermsSheet(),
  );
}

class _TermsSheet extends StatefulWidget {
  const _TermsSheet();

  @override
  State<_TermsSheet> createState() => _TermsSheetState();
}

class _TermsSheetState extends State<_TermsSheet> {
  bool _privacy = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.82,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                SogoSpacing.lg, SogoSpacing.lg, SogoSpacing.lg, 0),
            child: Row(children: [
              Expanded(
                child: Text(_privacy ? 'Privacy Policy' : 'Terms of Service',
                    style: SogoText.headlineMd),
              ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SogoSpacing.lg),
            child: Row(children: [
              Expanded(
                  child: _segment('Terms of Service', !_privacy,
                      () => setState(() => _privacy = false))),
              const SizedBox(width: SogoSpacing.sm),
              Expanded(
                  child: _segment('Privacy Policy', _privacy,
                      () => setState(() => _privacy = true))),
            ]),
          ),
          const Divider(height: SogoSpacing.lg),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  SogoSpacing.lg, 0, SogoSpacing.lg, SogoSpacing.xxl),
              child: Text(
                _privacy ? _kPrivacy : _kTerms,
                style: SogoText.bodyMd
                    .copyWith(color: SogoColors.textSecondary, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segment(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? SogoColors.primary : SogoColors.surfaceMuted,
          borderRadius: BorderRadius.circular(SogoRadius.md),
        ),
        child: Center(
            child: Text(label,
                style: SogoText.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : SogoColors.textSecondary))),
      ),
    );
  }
}
