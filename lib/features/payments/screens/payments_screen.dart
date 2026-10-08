import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/sogo_widgets.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late Future<Map<String, dynamic>> _future;
  Future<Map<String, dynamic>>? _withdrawalsFuture;
  bool _showWithdrawals = false;
  StreamSubscription? _linkSub;
  final AppLinks _links = AppLinks();
  String? _lastVerifiedTxRef;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _listenDeepLinks();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  /// The Flutterwave return page bounces straight back into the app via
  /// sogo://wallet/deposit/return?tx_ref=??? ??" verify the deposit and
  /// refresh the wallet right here.
  Future<void> _listenDeepLinks() async {
    try {
      final initial = await _links.getInitialLink();
      if (initial != null) _handleDeepLink(initial);
    } catch (_) {}
    _linkSub = _links.uriLinkStream.listen(
      (uri) => _handleDeepLink(uri),
      onError: (_) {},
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.scheme != 'sogo') return;
    final txRef = uri.queryParameters['tx_ref'];
    if (txRef == null || txRef.isEmpty || txRef == _lastVerifiedTxRef) return;
    _lastVerifiedTxRef = txRef;
    await _verifyDeposit(txRef);
  }

  Future<Map<String, dynamic>> _load() async {
    _withdrawalsFuture ??= _loadWithdrawals();
    return customerApi.payments();
  }

  Future<Map<String, dynamic>> _loadWithdrawals() =>
      apiClient.get('/api/v1/wallet/withdrawals', query: {'per_page': 20});

  // ?"??"? Deposit ?"??"?
  Future<void> _deposit() async {
    final amount = await _promptAmount('Amount to deposit');
    if (amount == null) return;

    Map<String, dynamic>? data;
    try {
      final res = await apiClient
          .post('/api/v1/customer/wallet/deposit', {'amount': amount});
      data = res['data'] as Map<String, dynamic>?;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return;
    }

    final link = '${data?['link'] ?? ''}';
    final txRef = '${data?['tx_ref'] ?? ''}';
    if (link.isEmpty || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Complete the payment in the browser???')));

    final launched =
        await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);

    // Give the user a moment, then verify ??" the webhook may also land.
    await Future.delayed(const Duration(seconds: 6));
    if (!mounted) return;
    await _verifyDeposit(txRef, reopened: launched != true);
  }

  Future<void> _verifyDeposit(String txRef, {bool reopened = false}) async {
    if (txRef.isEmpty) return;
    try {
      final res = await apiClient
          .post('/api/v1/customer/wallet/deposit/verify', {'tx_ref': txRef});
      final settled = res['data']?['settled'] == true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(settled
              ? 'Deposit confirmed ??" wallet updated'
              : (res['message'] ?? 'Payment not confirmed yet')),
          backgroundColor: settled ? SogoColors.success : SogoColors.warning));
      setState(() => _future = _load());
    } catch (e) {
      if (!mounted) return;
      if (reopened) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
      setState(() => _future = _load());
    }
  }

  // ?"??"? Withdraw ?"??"?
  Future<void> _withdraw(num balance) async {
    final sheet = showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(SogoRadius.lg))),
      builder: (_) => _WithdrawSheet(balance: balance),
    );
    final result = await sheet;
    if (result == null || !mounted) return;

    try {
      final res = await apiClient.post('/api/v1/wallet/withdraw', result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['message'] ?? 'Withdrawal requested'),
          backgroundColor: SogoColors.success));
      setState(() {
        _future = _load();
        _withdrawalsFuture = _loadWithdrawals();
        _showWithdrawals = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<num?> _promptAmount(String label) {
    final controller = TextEditingController();
    return showDialog<num>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SogoRadius.lg)),
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              prefixText: 'UGX ', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                final v = num.tryParse(controller.text.trim());
                Navigator.pop(ctx, (v != null && v >= 500) ? v : null);
              },
              child: const Text('Continue')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(title: const Text('Payments')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _future = _load();
            _withdrawalsFuture = _loadWithdrawals();
          });
        },
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _ErrorView(
                  message: '${snap.error}',
                  onRetry: () {
                    setState(() => _future = _load());
                  });
            }

            final data = snap.data?['data'] as Map<String, dynamic>? ?? {};
            final wallet = data['wallet'] as Map<String, dynamic>? ?? {};
            final txns = (data['transactions'] as List?) ?? [];

            final successCount = txns
                .where((t) => '${(t as Map)['status']}' == 'successful')
                .length;
            final pendingCount = txns
                .where((t) => '${(t as Map)['status']}' == 'pending')
                .length;

            return ListView(
              padding: const EdgeInsets.all(SogoSpacing.lg),
              children: [
                // Wallet hero
                Container(
                  padding: const EdgeInsets.all(SogoSpacing.xl),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [SogoColors.primary, SogoColors.primaryDark]),
                    borderRadius: BorderRadius.circular(SogoRadius.xl),
                    boxShadow: const [SogoShadows.elevated],
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Wallet balance',
                            style: SogoText.bodySm
                                .copyWith(color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text(ugx(num.tryParse('${wallet['balance'] ?? 0}')),
                            style: SogoText.displayMd
                                .copyWith(color: Colors.white)),
                        const SizedBox(height: SogoSpacing.md),
                        // Pending only - lifetime removed (not needed).
                        if ((num.tryParse('${wallet['pending_balance'] ?? 0}')
                                    ?.round() ??
                                0) >
                            0)
                          _walletChip(
                              'Pending',
                              ugx(num.tryParse(
                                  '${wallet['pending_balance'] ?? 0}'))),
                        const SizedBox(height: SogoSpacing.lg),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _deposit,
                              icon:
                                  const Icon(Icons.add_card_rounded, size: 18),
                              label: const Text('Deposit'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                    color: Colors.white70, width: 1.4),
                                padding: const EdgeInsets.symmetric(
                                    vertical: SogoSpacing.md),
                              ),
                            ),
                          ),
                          const SizedBox(width: SogoSpacing.md),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _withdraw(
                                  num.tryParse('${wallet['balance'] ?? 0}') ??
                                      0),
                              icon: const Icon(Icons.account_balance_rounded,
                                  size: 18),
                              label: const Text('Withdraw'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: SogoColors.primary,
                                padding: const EdgeInsets.symmetric(
                                    vertical: SogoSpacing.md),
                              ),
                            ),
                          ),
                        ]),
                      ]),
                ),
                const SizedBox(height: SogoSpacing.lg),

                // Tabs: transactions / withdrawals
                Row(children: [
                  Expanded(
                      child: _tabButton('Transactions', !_showWithdrawals,
                          () => setState(() => _showWithdrawals = false))),
                  const SizedBox(width: SogoSpacing.sm),
                  Expanded(
                      child: _tabButton('Withdrawals', _showWithdrawals,
                          () => setState(() => _showWithdrawals = true))),
                ]),
                const SizedBox(height: SogoSpacing.md),

                if (!_showWithdrawals) ...[
                  Row(children: [
                    _stat('$successCount', 'Successful', SogoColors.success),
                    const SizedBox(width: SogoSpacing.md),
                    _stat('$pendingCount', 'Pending', SogoColors.warning),
                  ]),
                  const SizedBox(height: SogoSpacing.lg),
                  if (txns.isEmpty)
                    _emptyCard(Icons.receipt_long_outlined,
                        'No transactions yet.\nBook a service or deposit to your wallet.')
                  else
                    ...txns.map((raw) {
                      final txn = raw as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: SogoSpacing.md),
                        child: _TransactionTile(txn: txn),
                      );
                    }),
                ] else
                  FutureBuilder<Map<String, dynamic>>(
                    future: _withdrawalsFuture,
                    builder: (context, wsnap) {
                      if (wsnap.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.all(SogoSpacing.xxl),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final wraw = wsnap.data?['data'];
                      final wlist = (wraw is Map<String, dynamic>
                              ? wraw['data']
                              : wraw) as List? ??
                          [];
                      if (wlist.isEmpty) {
                        return _emptyCard(Icons.account_balance_rounded,
                            'No withdrawals yet.');
                      }
                      return Column(
                        children: wlist.map((raw) {
                          final w = raw as Map<String, dynamic>;
                          final status = '${w['status'] ?? ''}';
                          final color = switch (status) {
                            'completed' => SogoColors.success,
                            'failed' ||
                            'rejected' ||
                            'cancelled' =>
                              SogoColors.danger,
                            _ => SogoColors.warning,
                          };
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: SogoSpacing.md),
                            child: SogoCard(
                              child: Row(children: [
                                Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                        color: color.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(
                                            SogoRadius.md)),
                                    child: Icon(
                                        status == 'completed'
                                            ? Icons.check_circle_outline
                                            : Icons.timelapse_rounded,
                                        color: color)),
                                const SizedBox(width: SogoSpacing.md),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(
                                          ugx(num.tryParse(
                                              '${w['amount'] ?? 0}')),
                                          style: SogoText.bodyLg.copyWith(
                                              fontWeight: FontWeight.w700)),
                                      Text(
                                          '${w['destination_type'] ?? ''} ?- ${w['destination_account'] ?? ''}',
                                          style: SogoText.bodySm.copyWith(
                                              color: SogoColors.textSecondary)),
                                    ])),
                                Text(status,
                                    style: SogoText.labelMd
                                        .copyWith(color: color)),
                              ]),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                const SizedBox(height: SogoSpacing.xxl),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _walletChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(SogoRadius.pill)),
      child: Text('$label: $value',
          style: SogoText.labelMd.copyWith(color: Colors.white)),
    );
  }

  Widget _tabButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: SogoSpacing.sm + 2),
        decoration: BoxDecoration(
          color: active ? SogoColors.primary : SogoColors.surface,
          borderRadius: BorderRadius.circular(SogoRadius.pill),
          border: Border.all(
              color: active ? SogoColors.primary : SogoColors.surfaceBorder),
        ),
        child: Center(
            child: Text(label,
                style: SogoText.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : SogoColors.textSecondary))),
      ),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Expanded(
      child: SogoCard(
        padding: const EdgeInsets.all(SogoSpacing.md),
        child: Column(children: [
          Text(value,
              style: SogoText.headlineLg.copyWith(color: color, fontSize: 20)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  SogoText.labelMd.copyWith(color: SogoColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _emptyCard(IconData icon, String message) {
    return SogoCard(
      child: Padding(
        padding: const EdgeInsets.all(SogoSpacing.xl),
        child: Column(children: [
          Icon(icon, size: 48, color: SogoColors.textMuted),
          const SizedBox(height: SogoSpacing.md),
          Text(message,
              textAlign: TextAlign.center,
              style: SogoText.bodyMd.copyWith(color: SogoColors.textSecondary)),
        ]),
      ),
    );
  }
}

class _WithdrawSheet extends StatefulWidget {
  const _WithdrawSheet({required this.balance});

  final num balance;

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _account = TextEditingController();
  final _name = TextEditingController();
  final _bankCode = TextEditingController();
  final _bankName = TextEditingController();
  String _destination = 'mobile_money';

  @override
  void dispose() {
    _amount.dispose();
    _account.dispose();
    _name.dispose();
    _bankCode.dispose();
    _bankName.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, {
      'amount': num.tryParse(_amount.text.trim()) ?? 0,
      'destination_type': _destination,
      'destination_account': _account.text.trim(),
      'destination_name': _name.text.trim(),
      if (_destination == 'bank')
        'destination_bank_code': _bankCode.text.trim(),
      if (_destination == 'bank')
        'destination_bank_name': _bankName.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: SogoSpacing.xl,
          right: SogoSpacing.xl,
          top: SogoSpacing.xl,
          bottom: MediaQuery.of(context).viewInsets.bottom + SogoSpacing.xl),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Withdraw funds',
                style:
                    SogoText.headlineMd.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Available: ${ugx(widget.balance)}',
                style:
                    SogoText.bodySm.copyWith(color: SogoColors.textSecondary)),
            const SizedBox(height: SogoSpacing.lg),
            SogoTextField(
                label: 'Amount (UGX)',
                hint: 'Minimum 5,000',
                controller: _amount,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.payments_outlined,
                validator: (v) {
                  final n = num.tryParse(v ?? '');
                  if (n == null || n < 5000)
                    return 'Minimum withdrawal is UGX 5,000';
                  if (n > widget.balance) return 'Amount exceeds your balance';
                  return null;
                }),
            const SizedBox(height: SogoSpacing.md),
            Row(children: [
              Expanded(
                  child: ChoiceChip(
                      label: const Text('Mobile Money'),
                      selected: _destination == 'mobile_money',
                      selectedColor: SogoColors.primary,
                      labelStyle: SogoText.bodySm.copyWith(
                          color: _destination == 'mobile_money'
                              ? Colors.white
                              : SogoColors.textSecondary),
                      onSelected: (_) =>
                          setState(() => _destination = 'mobile_money'))),
              const SizedBox(width: SogoSpacing.sm),
              Expanded(
                  child: ChoiceChip(
                      label: const Text('Bank'),
                      selected: _destination == 'bank',
                      selectedColor: SogoColors.primary,
                      labelStyle: SogoText.bodySm.copyWith(
                          color: _destination == 'bank'
                              ? Colors.white
                              : SogoColors.textSecondary),
                      onSelected: (_) =>
                          setState(() => _destination = 'bank'))),
            ]),
            const SizedBox(height: SogoSpacing.md),
            SogoTextField(
                label: _destination == 'mobile_money'
                    ? 'Mobile money number'
                    : 'Account number',
                hint: '0770 000 000',
                controller: _account,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
                validator: (v) =>
                    v == null || v.trim().length < 6 ? 'Required' : null),
            const SizedBox(height: SogoSpacing.md),
            SogoTextField(
                label: 'Account holder name',
                hint: 'As registered on the account',
                controller: _name,
                prefixIcon: Icons.person_outline,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null),
            if (_destination == 'bank') ...[
              const SizedBox(height: SogoSpacing.md),
              SogoTextField(
                  label: 'Bank code',
                  hint: 'e.g. UG012 (from your bank)',
                  controller: _bankCode,
                  prefixIcon: Icons.account_balance_outlined,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: SogoSpacing.md),
              SogoTextField(
                  label: 'Bank name',
                  hint: 'e.g. Stanbic Bank',
                  controller: _bankName,
                  prefixIcon: Icons.account_balance_outlined,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null),
            ],
            const SizedBox(height: SogoSpacing.lg),
            SogoButton(label: 'Request withdrawal', onPressed: _submit),
          ]),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.txn});

  final Map<String, dynamic> txn;

  @override
  Widget build(BuildContext context) {
    final type = '${txn['type'] ?? 'payment'}';
    final status = '${txn['status'] ?? ''}';

    // Unified status colors across payments / deposits / withdrawals.
    final color = switch (status) {
      'successful' || 'completed' => SogoColors.success,
      'pending' || 'processing' => SogoColors.warning,
      _ => SogoColors.danger,
    };

    final isWithdrawal = type == 'withdrawal';
    final isDeposit = type == 'deposit';
    final title = isWithdrawal
        ? 'Withdrawal'
        : isDeposit
            ? 'Wallet deposit'
            : '${txn['service_request']?['reference'] ?? txn['reference'] ?? 'Payment'}';
    final subtitle = isWithdrawal
        ? 'To ${txn['destination'] ?? 'account'}'
        : (txn['paid_at'] != null
            ? '${txn['paid_at']}'.substring(0, 16).replaceAll('T', ' ')
            : status);
    final amountPrefix = isWithdrawal ? '- ' : '';

    return SogoCard(
      child: Row(children: [
        Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(SogoRadius.md)),
            child: Icon(
                isWithdrawal
                    ? Icons.account_balance_rounded
                    : isDeposit
                        ? Icons.add_card_rounded
                        : Icons.verified_outlined,
                color: color)),
        const SizedBox(width: SogoSpacing.md),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: SogoText.bodyLg.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: SogoText.bodySm.copyWith(color: SogoColors.textSecondary)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$amountPrefix${ugx(num.tryParse('${txn['amount'] ?? 0}'))}',
              style: SogoText.bodyMd.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(status, style: SogoText.labelMd.copyWith(color: color)),
        ]),
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SogoSpacing.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 44, color: SogoColors.danger),
          const SizedBox(height: SogoSpacing.md),
          Text(message,
              textAlign: TextAlign.center,
              style: SogoText.bodySm.copyWith(color: SogoColors.textSecondary)),
          const SizedBox(height: SogoSpacing.lg),
          SogoButton(label: 'Retry', fullWidth: false, onPressed: onRetry),
        ]),
      ),
    );
  }
}
