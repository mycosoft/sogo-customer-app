import 'package:flutter/material.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/sogo_widgets.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const _filters = [
    ('all', 'All'),
    ('pending', 'Pending'),
    ('processing', 'Processing'),
    ('shipped', 'Shipped'),
    ('delivered', 'Delivered'),
    ('cancelled', 'Cancelled'),
  ];

  String _filter = 'all';
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() =>
      customerApi.listOrders(status: _filter == 'all' ? null : _filter);

  void _retap(String f) {
    setState(() {
      _filter = f;
      _future = _load();
    });
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'delivered':
        return SogoColors.success;
      case 'cancelled':
        return SogoColors.danger;
      case 'shipped':
        return SogoColors.primary;
      case 'processing':
        return SogoColors.warning;
      default:
        return SogoColors.textSecondary;
    }
  }

  String _ugx(num? v) => ugx(v);

  Future<void> _openDetails(Map<String, dynamic> order) async {
    final id = order['id'];
    try {
      final res = await customerApi.getOrder(id as int);
      if (!mounted) return;
      final data = res['data'] as Map<String, dynamic>? ?? {};
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(SogoRadius.lg))),
        builder: (_) => Padding(
          padding: EdgeInsets.only(
              left: SogoSpacing.xl,
              right: SogoSpacing.xl,
              top: SogoSpacing.xl,
              bottom:
                  MediaQuery.of(context).viewInsets.bottom + SogoSpacing.xl),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                      child: Text('${data['reference'] ?? 'Order'}',
                          style: SogoText.headlineMd)),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: _statusColor('${data['status']}')
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(SogoRadius.pill)),
                      child: Text('${data['status'] ?? ''}',
                          style: SogoText.labelMd.copyWith(
                              color: _statusColor('${data['status']}')))),
                ]),
                const SizedBox(height: SogoSpacing.lg),
                if ((data['items'] as List?)?.isNotEmpty == true) ...[
                  const SogoSectionTitle('Items'),
                  ...((data['items'] as List).map((raw) {
                    final item = raw as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: SogoSpacing.sm),
                      child: Row(children: [
                        Expanded(
                            child: Text(
                                '${item['quantity'] ?? 1} x ${item['name'] ?? item['product_name'] ?? 'Item'}',
                                style: SogoText.bodyMd)),
                        Text(
                            _ugx(num.tryParse(
                                '${item['line_total'] ?? item['subtotal'] ?? item['price'] ?? 0}')),
                            style: SogoText.bodyMd
                                .copyWith(fontWeight: FontWeight.w700)),
                      ]),
                    );
                  })),
                  const Divider(height: SogoSpacing.xl),
                ],
                _row(
                    'Subtotal', _ugx(num.tryParse('${data['subtotal'] ?? 0}'))),
                _row('Delivery',
                    _ugx(num.tryParse('${data['delivery_fee'] ?? 0}'))),
                if (num.tryParse('${data['discount'] ?? 0}') != null &&
                    num.parse('${data['discount']}') > 0)
                  _row('Discount',
                      '- ${_ugx(num.tryParse('${data['discount']}'))}'),
                if (num.tryParse('${data['tax'] ?? 0}') != null &&
                    num.parse('${data['tax']}') > 0)
                  _row('Tax', _ugx(num.tryParse('${data['tax']}'))),
                const Divider(height: SogoSpacing.lg),
                _row('Total', _ugx(num.tryParse('${data['total'] ?? 0}')),
                    bold: true),
                const SizedBox(height: SogoSpacing.lg),
                if ('${data['delivery_address'] ?? ''}'.isNotEmpty)
                  _row('Deliver to', '${data['delivery_address']}'),
                if ('${data['delivery_phone'] ?? ''}'.isNotEmpty)
                  _row('Phone', '${data['delivery_phone']}'),
                _row('Payment', '${data['payment_status'] ?? 'unpaid'}'),
                if (data['provider'] != null)
                  _row('Provider',
                      '${(data['provider'] as Map<String, dynamic>)['business_name'] ?? ''}'),
                // Pay later (wallet) for unpaid orders.
                if ('${data['payment_status'] ?? ''}' != 'paid') ...[
                  const SizedBox(height: SogoSpacing.lg),
                  SogoButton(
                      label:
                          'Pay ${num.tryParse('${data['total'] ?? 0}') != null ? _ugx(num.tryParse('${data['total']}')) : ''} with wallet',
                      icon: Icons.account_balance_wallet_outlined,
                      onPressed: () => _payOrder((data['id'] as num).toInt())),
                ],
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _payOrder(int orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SogoRadius.lg)),
        title: const Text('Pay with wallet?'),
        content: const Text(
            'The order total will be debited from your SOGO wallet and sent to the shop.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pay now')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final res = await shopApi.payOrder(orderId);
      if (!mounted) return;
      Navigator.pop(context); // close detail sheet
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['message'] ?? 'Order paid'),
          backgroundColor: SogoColors.success));
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style:
                    SogoText.bodyMd.copyWith(color: SogoColors.textSecondary))),
        Text(value,
            style: SogoText.bodyMd.copyWith(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(title: const Text('My orders')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _future = _load());
        },
        child: Column(children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: SogoSpacing.lg),
              children: _filters
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(right: SogoSpacing.sm),
                        child: ChoiceChip(
                            label: Text(f.$2),
                            selected: _filter == f.$1,
                            selectedColor: SogoColors.primary,
                            labelStyle: SogoText.bodySm.copyWith(
                                color: _filter == f.$1
                                    ? Colors.white
                                    : SogoColors.textSecondary),
                            onSelected: (_) => _retap(f.$1)),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return ListView(children: [
                    Padding(
                        padding: const EdgeInsets.all(SogoSpacing.xl),
                        child: Text('Could not load orders: ${snap.error}',
                            style: SogoText.bodyMd
                                .copyWith(color: SogoColors.danger))),
                  ]);
                }
                final data = snap.data?['data'];
                final items = (data is Map<String, dynamic>
                        ? data['data']
                        : data) as List? ??
                    [];
                if (items.isEmpty) {
                  return ListView(children: [
                    Padding(
                        padding: const EdgeInsets.all(SogoSpacing.xxl),
                        child: Column(children: [
                          const Icon(Icons.receipt_long_outlined,
                              size: 48, color: SogoColors.textMuted),
                          const SizedBox(height: SogoSpacing.md),
                          Text('No orders yet',
                              style: SogoText.bodyLg
                                  .copyWith(color: SogoColors.textSecondary)),
                        ])),
                  ]);
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(SogoSpacing.lg),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: SogoSpacing.md),
                  itemBuilder: (context, i) {
                    final o = items[i] as Map<String, dynamic>;
                    final total = num.tryParse('${o['total'] ?? 0}') ?? 0;
                    return SogoCard(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(SogoRadius.md),
                        onTap: () => _openDetails(o),
                        child: Row(children: [
                          Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                  color: SogoColors.primaryLight,
                                  borderRadius:
                                      BorderRadius.circular(SogoRadius.md)),
                              child: const Icon(Icons.receipt_long_outlined,
                                  color: SogoColors.primary)),
                          const SizedBox(width: SogoSpacing.md),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('${o['reference'] ?? 'Order'}',
                                    style: SogoText.bodyLg
                                        .copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                    'Payment: ${o['payment_status'] ?? 'unpaid'}',
                                    style: SogoText.bodySm.copyWith(
                                        color: SogoColors.textSecondary)),
                              ])),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_ugx(total),
                                    style: SogoText.bodyMd
                                        .copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text('${o['status'] ?? ''}',
                                    style: SogoText.labelMd.copyWith(
                                        color: _statusColor('${o['status']}'))),
                              ]),
                          const Icon(Icons.chevron_right_rounded,
                              color: SogoColors.textMuted),
                        ]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
