import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/sogo_widgets.dart';
import '../../orders/screens/orders_screen.dart';

/// Delivery details + payment choice (wallet / cash on delivery).
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  String _payment = 'cash';
  bool _placing = false;
  num _walletBalance = 0;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    _address.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _prefill() async {
    try {
      final me = await authApi.me();
      final user = me['data'] as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() {
        _phone.text = '${user['phone'] ?? ''}';
        final parts = ['${user['address'] ?? ''}', '${user['city'] ?? ''}']
            .where((s) => s.isNotEmpty)
            .join(', ');
        _address.text = parts;
      });
    } catch (_) {}
    try {
      final pay = await customerApi.payments();
      final wallet = (pay['data'] as Map<String, dynamic>?)?['wallet']
          as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _walletBalance = num.tryParse('${wallet?['balance'] ?? 0}') ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _useGps() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 12))
          .timeout(const Duration(seconds: 15));
      final res = await apiClient.get('/locations/reverse',
          query: {'lat': pos.latitude, 'lng': pos.longitude});
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final full = '${data['full_address'] ?? data['short'] ?? ''}';
      if (!mounted) return;
      if (full.isNotEmpty) {
        setState(() => _address.text = full);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Delivery location set from GPS')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _place() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _placing = true);
    try {
      final res = await shopApi.checkout(
        deliveryAddress: _address.text.trim(),
        deliveryPhone: _phone.text.trim(),
        notes: _notes.text.trim(),
        paymentMethod: _payment,
      );
      if (!mounted) return;
      final data = res['data'] as Map<String, dynamic>? ?? {};
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SogoRadius.lg)),
          title: const Text('Order placed'),
          content: Text(
              'Order ${data['reference'] ?? ''} is confirmed.\n${_payment == 'wallet' ? 'Paid from your wallet.' : 'Pay cash on delivery.'}'),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Track order')),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OrdersScreen()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(title: const Text('Checkout')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(SogoSpacing.lg),
          children: [
            const SogoSectionTitle('Delivery details'),
            const SizedBox(height: SogoSpacing.md),
            SogoCard(
              child: Column(children: [
                SogoTextField(
                    label: 'Delivery address',
                    hint: 'Plot, street, area',
                    controller: _address,
                    prefixIcon: Icons.location_on_outlined,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null),
                const SizedBox(height: SogoSpacing.md),
                SogoTextField(
                    label: 'Delivery phone',
                    hint: 'Where the rider calls',
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_outlined),
                const SizedBox(height: SogoSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                      onPressed: _useGps,
                      icon: const Icon(Icons.gps_fixed_rounded, size: 16),
                      label: const Text('Use my GPS location')),
                ),
                SogoTextField(
                    label: 'Notes (optional)',
                    hint: 'Gate code, landmarks…',
                    controller: _notes,
                    maxLines: 2),
              ]),
            ),
            const SizedBox(height: SogoSpacing.xl),
            const SogoSectionTitle('Payment'),
            const SizedBox(height: SogoSpacing.md),
            SogoCard(
              child: Column(children: [
                RadioListTile<String>(
                  value: 'cash',
                  groupValue: _payment,
                  onChanged: (v) => setState(() => _payment = v!),
                  title: const Text('Cash on delivery'),
                  subtitle: const Text('Pay the rider when it arrives'),
                  secondary: const Icon(Icons.payments_outlined,
                      color: SogoColors.primary),
                  activeColor: SogoColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  value: 'wallet',
                  groupValue: _payment,
                  onChanged: (v) => setState(() => _payment = v!),
                  title: const Text('SOGO wallet'),
                  subtitle: Text('Balance: ${ugx(_walletBalance)}'),
                  secondary: const Icon(Icons.account_balance_wallet_outlined,
                      color: SogoColors.primary),
                  activeColor: SogoColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
              ]),
            ),
            const SizedBox(height: SogoSpacing.xl),
            SogoButton(
                label:
                    _payment == 'wallet' ? 'Pay & place order' : 'Place order',
                icon: Icons.check_circle_outline_rounded,
                onPressed: _placing ? null : _place,
                loading: _placing),
          ],
        ),
      ),
    );
  }
}
