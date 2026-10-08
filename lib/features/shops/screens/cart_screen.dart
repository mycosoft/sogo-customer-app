import 'package:flutter/material.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/sogo_widgets.dart';
import 'checkout_screen.dart';
import 'products/product_detail_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = shopApi.cart();
  }

  void _reload() {
    setState(() => _future = shopApi.cart());
  }

  Future<void> _setQty(int itemId, int qty) async {
    try {
      await shopApi.cartUpdateItem(itemId: itemId, quantity: qty);
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _remove(int itemId) async {
    try {
      await shopApi.cartRemoveItem(itemId);
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(title: const Text('My cart')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.hasError) {
              return Center(child: Text('${snap.error}'));
            }
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!['data'] as Map<String, dynamic>? ?? {};
          final items = (data['items'] as List?) ?? [];
          final provider = data['provider'] as Map<String, dynamic>?;

          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(SogoSpacing.xxl),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.shopping_cart_outlined,
                      size: 56, color: SogoColors.textMuted),
                  const SizedBox(height: SogoSpacing.md),
                  Text('Your cart is empty', style: SogoText.headlineMd),
                  const SizedBox(height: SogoSpacing.sm),
                  Text('Browse shops and add parts you need.',
                      style: SogoText.bodyMd
                          .copyWith(color: SogoColors.textSecondary)),
                  const SizedBox(height: SogoSpacing.lg),
                  SogoButton(
                      label: 'Browse shops',
                      fullWidth: false,
                      onPressed: () => Navigator.of(context).pop()),
                ]),
              ),
            );
          }

          final subtotal = num.tryParse('${data['subtotal'] ?? 0}') ?? 0;

          return Column(children: [
            if (provider != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    SogoSpacing.lg, SogoSpacing.lg, SogoSpacing.lg, 0),
                child: Row(children: [
                  const Icon(Icons.storefront_outlined,
                      size: 16, color: SogoColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text('From ${provider['business_name'] ?? 'shop'}',
                          style: SogoText.bodySm.copyWith(
                              color: SogoColors.textSecondary,
                              fontWeight: FontWeight.w600))),
                  TextButton(
                      onPressed: () async {
                        await shopApi.cartClear();
                        _reload();
                      },
                      child: const Text('Clear')),
                ]),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(SogoSpacing.lg),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: SogoSpacing.md),
                itemBuilder: (context, i) {
                  final it = items[i] as Map<String, dynamic>;
                  final qty = (it['quantity'] as num?)?.toInt() ?? 1;
                  return SogoCard(
                    child: Row(children: [
                      Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                              color: SogoColors.surfaceMuted,
                              borderRadius:
                                  BorderRadius.circular(SogoRadius.md)),
                          child: it['main_image_url'] != null
                              ? ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(SogoRadius.md),
                                  child: Image.network(
                                      '${it['main_image_url']}',
                                      fit: BoxFit.cover),
                                )
                              : const Icon(Icons.inventory_2_outlined,
                                  color: SogoColors.textMuted)),
                      const SizedBox(width: SogoSpacing.md),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('${it['name'] ?? ''}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: SogoText.bodyMd
                                    .copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                                '${ugx(num.tryParse('${it['unit_price'] ?? 0}'))} each',
                                style: SogoText.bodySm
                                    .copyWith(color: SogoColors.textSecondary)),
                            const SizedBox(height: 6),
                            Row(children: [
                              _qtyBtn(Icons.remove_rounded, () {
                                if (qty > 1) {
                                  _setQty((it['id'] as num).toInt(), qty - 1);
                                } else {
                                  _remove((it['id'] as num).toInt());
                                }
                              }),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: SogoSpacing.sm),
                                child: Text('$qty', style: SogoText.bodyLg),
                              ),
                              _qtyBtn(
                                  Icons.add_rounded,
                                  () => _setQty(
                                      (it['id'] as num).toInt(), qty + 1)),
                              const Spacer(),
                              IconButton(
                                  onPressed: () =>
                                      _remove((it['id'] as num).toInt()),
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 20, color: SogoColors.danger)),
                            ]),
                          ])),
                      const SizedBox(width: SogoSpacing.sm),
                      Text(ugx(num.tryParse('${it['line_total'] ?? 0}')),
                          style: SogoText.bodyMd
                              .copyWith(fontWeight: FontWeight.w800)),
                    ]),
                  );
                },
              ),
            ),
            Container(
              color: SogoColors.surface,
              padding: const EdgeInsets.all(SogoSpacing.lg),
              child: SafeArea(
                top: false,
                child: Column(children: [
                  Row(children: [
                    Expanded(
                        child: Text('Subtotal',
                            style: SogoText.bodyLg
                                .copyWith(fontWeight: FontWeight.w700))),
                    Text(ugx(subtotal),
                        style: SogoText.headlineMd
                            .copyWith(color: SogoColors.primary)),
                  ]),
                  const SizedBox(height: 4),
                  Text('Delivery fee is added by the shop at checkout.',
                      style: SogoText.labelMd
                          .copyWith(color: SogoColors.textSecondary)),
                  const SizedBox(height: SogoSpacing.md),
                  SogoButton(
                      label: 'Checkout',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const CheckoutScreen()));
                        _reload();
                      }),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SogoRadius.sm),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            border: Border.all(color: SogoColors.surfaceBorder),
            borderRadius: BorderRadius.circular(SogoRadius.sm)),
        child: Icon(icon, size: 16, color: SogoColors.primary),
      ),
    );
  }
}
