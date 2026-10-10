import 'package:flutter/material.dart';
import '../../../../core/app_services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/sogo_widgets.dart';
import '../cart_screen.dart';
import '../provider_detail_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  int _qty = 1;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _future = shopApi.productDetail(widget.productId);
  }

  Future<void> _addToCart(int productId, {bool buyNow = false}) async {
    setState(() => _adding = true);
    try {
      final res = await shopApi.cartAdd(productId: productId, quantity: _qty);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['message'] ?? 'Added to cart'),
          backgroundColor: SogoColors.success,
          action: SnackBarAction(
            label: 'VIEW CART',
            textColor: Colors.white,
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const CartScreen())),
          )));
      if (buyNow) {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const CartScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(title: const Text('Product')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.hasError) {
              return Center(child: Text('${snap.error}'));
            }
            return const Center(child: CircularProgressIndicator());
          }
          final p = snap.data!['data'] as Map<String, dynamic>;
          final provider = p['provider'] as Map<String, dynamic>? ?? {};
          final inStock = p['in_stock'] == true;
          final images = (p['images'] as List?) ?? [];
          final hero =
              p['main_image_url'] ?? (images.isNotEmpty ? images.first : null);

          return Column(children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(SogoSpacing.lg),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(SogoRadius.lg),
                        child: Stack(children: [
                          Container(
                            height: 250,
                            width: double.infinity,
                            color: SogoColors.surface,
                            child: hero != null
                                ? Image.network('$hero',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.inventory_2_outlined,
                                        size: 64,
                                        color: SogoColors.textMuted))
                                : const Icon(Icons.inventory_2_outlined,
                                    size: 64, color: SogoColors.textMuted),
                          ),
                          Positioned(
                            left: SogoSpacing.md,
                            top: SogoSpacing.md,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: inStock
                                    ? SogoColors.success
                                    : SogoColors.danger,
                                borderRadius:
                                    BorderRadius.circular(SogoRadius.pill),
                              ),
                              child: Text(
                                  inStock
                                      ? 'IN STOCK Â· ${p['stock_quantity'] ?? ''}'
                                      : 'OUT OF STOCK',
                                  style: SogoText.labelMd.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ),
                          if (p['compare_at_price'] != null)
                            Positioned(
                              right: SogoSpacing.md,
                              top: SogoSpacing.md,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: SogoColors.danger,
                                  borderRadius:
                                      BorderRadius.circular(SogoRadius.pill),
                                ),
                                child: Text('SALE',
                                    style: SogoText.labelMd.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800)),
                              ),
                            ),
                        ]),
                      ),
                      const SizedBox(height: SogoSpacing.lg),
                      if ('${p['brand'] ?? ''}'.isNotEmpty)
                        Row(children: [
                          Text('${p['brand']}'.toUpperCase(),
                              style: SogoText.labelMd.copyWith(
                                  color: SogoColors.textSecondary,
                                  fontWeight: FontWeight.w700)),
                          if ('${p['condition'] ?? ''}'.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: SogoColors.surfaceMuted,
                                borderRadius:
                                    BorderRadius.circular(SogoRadius.pill),
                              ),
                              child: Text('${p['condition']}',
                                  style: SogoText.labelMd.copyWith(
                                      color: SogoColors.textSecondary)),
                            ),
                          ],
                        ]),
                      Text('${p['name'] ?? ''}', style: SogoText.headlineLg),
                      const SizedBox(height: SogoSpacing.sm),
                      SogoCard(
                        child: Column(children: [
                          Row(children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(ugx(num.tryParse('${p['price'] ?? 0}')),
                                      style: SogoText.headlineMd
                                          .copyWith(color: SogoColors.primary)),
                                  if (p['compare_at_price'] != null)
                                    Text(
                                        ugx(num.tryParse(
                                            '${p['compare_at_price']}')),
                                        style: SogoText.bodySm.copyWith(
                                            color: SogoColors.textMuted,
                                            decoration:
                                                TextDecoration.lineThrough)),
                                ])),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Total',
                                      style: SogoText.labelMd.copyWith(
                                          color: SogoColors.textSecondary)),
                                  Text(
                                      ugx((num.tryParse('${p['price'] ?? 0}') ??
                                              0) *
                                          _qty),
                                      style: SogoText.headlineMd),
                                ]),
                          ]),
                          const SizedBox(height: SogoSpacing.sm),
                          const Divider(height: 1),
                          const SizedBox(height: SogoSpacing.sm),
                          Row(children: [
                            const Icon(Icons.local_shipping_outlined,
                                size: 16, color: SogoColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                                p['free_delivery'] == true
                                    ? 'Free delivery'
                                    : 'Delivery: ${ugx(num.tryParse('${p['delivery_fee'] ?? 0}') ?? 0)}',
                                style: SogoText.labelMd.copyWith(
                                    color: p['free_delivery'] == true
                                        ? SogoColors.success
                                        : SogoColors.textSecondary)),
                          ]),
                        ]),
                      ),
                      if ('${p['description'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: SogoSpacing.md),
                        const SogoSectionTitle('About this item'),
                        Text('${p['description']}',
                            style: SogoText.bodyMd
                                .copyWith(color: SogoColors.textSecondary)),
                      ],
                      if (p['specifications'] != null &&
                          '${p['specifications']}'.isNotEmpty) ...[
                        const SizedBox(height: SogoSpacing.md),
                        const SogoSectionTitle('Specifications'),
                        SogoCard(
                          child: Text('${p['specifications']}',
                              style: SogoText.bodySm),
                        ),
                      ],
                      if ('${p['model_compatibility'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: SogoSpacing.md),
                        SogoCard(
                          child: Row(children: [
                            const Icon(Icons.directions_car_outlined,
                                color: SogoColors.primary),
                            const SizedBox(width: SogoSpacing.md),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('Fits',
                                      style: SogoText.labelMd.copyWith(
                                          color: SogoColors.textSecondary)),
                                  Text('${p['model_compatibility']}',
                                      style: SogoText.bodyMd.copyWith(
                                          fontWeight: FontWeight.w600)),
                                ])),
                          ]),
                        ),
                      ],
                      const SizedBox(height: SogoSpacing.md),
                      // Sold by.
                      SogoCard(
                        onTap: provider['id'] == null
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => ProviderDetailScreen(
                                        providerId:
                                            (provider['id'] as num).toInt()))),
                        child: Row(children: [
                          CircleAvatar(
                              radius: 20,
                              backgroundColor: SogoColors.primaryLight,
                              backgroundImage: provider['logo_url'] != null
                                  ? NetworkImage('${provider['logo_url']}')
                                  : null,
                              child: provider['logo_url'] == null
                                  ? const Icon(Icons.storefront_outlined,
                                      color: SogoColors.primary, size: 20)
                                  : null),
                          const SizedBox(width: SogoSpacing.md),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('Sold by',
                                    style: SogoText.labelMd.copyWith(
                                        color: SogoColors.textSecondary)),
                                Text('${provider['business_name'] ?? 'Shop'}',
                                    style: SogoText.bodyMd
                                        .copyWith(fontWeight: FontWeight.w700)),
                              ])),
                          const Icon(Icons.chevron_right_rounded,
                              color: SogoColors.textMuted),
                        ]),
                      ),
                    ]),
              ),
            ),
            // Qty + add to cart bar.
            Container(
              color: SogoColors.surface,
              padding: const EdgeInsets.all(SogoSpacing.lg),
              child: SafeArea(
                top: false,
                child: Row(children: [
                  Container(
                    decoration: BoxDecoration(
                        border: Border.all(color: SogoColors.surfaceBorder),
                        borderRadius: BorderRadius.circular(SogoRadius.md)),
                    child: Row(children: [
                      IconButton(
                          onPressed:
                              _qty > 1 ? () => setState(() => _qty--) : null,
                          icon: const Icon(Icons.remove_rounded)),
                      Text('$_qty', style: SogoText.bodyLg),
                      IconButton(
                          onPressed: () => setState(() => _qty++),
                          icon: const Icon(Icons.add_rounded)),
                    ]),
                  ),
                  const SizedBox(width: SogoSpacing.md),
                  Expanded(
                    child: SogoButton(
                        label: 'Add to cart',
                        icon: Icons.shopping_cart_outlined,
                        onPressed: !inStock || _adding
                            ? null
                            : () => _addToCart((p['id'] as num).toInt())),
                  ),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
