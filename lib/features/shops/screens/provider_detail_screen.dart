import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/sogo_widgets.dart';
import 'book_appointment_screen.dart';
import 'products/product_detail_screen.dart';
import '../../messages/screens/chats_screen.dart';

/// A shop/provider profile: cover, contact actions (call/chat/book),
/// products, services and reviews.
class ProviderDetailScreen extends StatefulWidget {
  const ProviderDetailScreen({super.key, required this.providerId});

  final int providerId;

  @override
  State<ProviderDetailScreen> createState() => _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends State<ProviderDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = shopApi.shopDetail(widget.providerId);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Widget _miniStat(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: SogoSpacing.md, horizontal: SogoSpacing.sm),
        decoration: BoxDecoration(
          color: SogoColors.surface,
          borderRadius: BorderRadius.circular(SogoRadius.md),
          border: Border.all(color: SogoColors.surfaceBorder),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: SogoText.bodyLg.copyWith(fontWeight: FontWeight.w800)),
          Text(label,
              style:
                  SogoText.labelMd.copyWith(color: SogoColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _aboutRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SogoSpacing.sm),
      child: Row(children: [
        Icon(icon, size: 18, color: SogoColors.primary),
        const SizedBox(width: SogoSpacing.md),
        SizedBox(
            width: 88,
            child: Text(label,
                style:
                    SogoText.bodySm.copyWith(color: SogoColors.textSecondary))),
        Expanded(
            child: Text(value,
                style: SogoText.bodySm.copyWith(fontWeight: FontWeight.w600))),
      ]),
    );
  }

  String _hoursLabel(Map hours) {
    // operating_hours is day -> {open, close} (legacy "08:00-18:00" tolerated).
    String range(Object? v) {
      if (v is Map) {
        final open = '${v['open'] ?? ''}';
        final close = '${v['close'] ?? ''}';
        if (open.isEmpty || close.isEmpty) return '';
        return '$open-$close';
      }
      return '$v';
    }

    const order = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final parts = <String>[];
    for (final d in order) {
      final v = hours[d] ??
          hours[d.toUpperCase()] ??
          hours['${d[0].toUpperCase()}${d.substring(1)}'];
      final r = range(v);
      if (v != null && r.isNotEmpty) {
        parts.add('${d[0].toUpperCase()}: $r');
      }
    }
    if (parts.isEmpty) {
      // Fall back to whatever shape it has.
      return hours.entries
          .take(3)
          .map((e) => '${e.key}: ${range(e.value)}')
          .join(' Â· ');
    }
    // Collapse identical consecutive ranges: "Mon-Fri: 08:00-18:00".
    final first = parts.first.split(': ').last;
    final sameWeekdays =
        parts.take(5).every((p) => p.split(': ').last == first);
    if (sameWeekdays && parts.length >= 5) {
      final rest = parts.skip(5).map((p) => p).join(', ');
      return 'Mon-Fri: $first${rest.isEmpty ? '' : ' Â· $rest'}';
    }
    return parts.take(4).join(' Â· ');
  }

  Future<void> _call(String? phone) async {
    final cleaned = '${phone ?? ''}'.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri.parse('tel:$cleaned');
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (_) {}
  }

  Future<void> _chat(int userId, String name) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(userId: userId, name: name)));
  }

  void _book(Map<String, dynamic> provider) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BookAppointmentScreen(provider: provider)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.hasError) {
              return Scaffold(
                  appBar: AppBar(), body: Center(child: Text('${snap.error}')));
            }
            return Scaffold(
                appBar: AppBar(),
                body: const Center(child: CircularProgressIndicator()));
          }
          final p = snap.data!['data'] as Map<String, dynamic>;
          final user = p['user'] as Map<String, dynamic>? ?? {};
          final products = (p['products'] as List?) ?? [];
          final services = (p['services'] as List?) ?? [];
          final reviews = p['reviews'] as Map<String, dynamic>? ?? {};
          final summary = reviews['summary'] as Map<String, dynamic>? ?? {};
          final reviewList = (reviews['reviews'] as List?) ?? [];
          final online = p['is_online'] == true;
          final userId = (user['id'] as num?)?.toInt();

          return NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: SogoColors.primary,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text('${p['business_name'] ?? 'Shop'}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  background: p['cover_image_url'] != null
                      ? Image.network('${p['cover_image_url']}',
                          fit: BoxFit.cover)
                      : Container(color: SogoColors.primaryDark),
                ),
              ),
            ],
            body: Column(children: [
              Padding(
                padding: const EdgeInsets.all(SogoSpacing.lg),
                child: Row(children: [
                  CircleAvatar(
                      radius: 26,
                      backgroundColor: SogoColors.primaryLight,
                      backgroundImage: p['logo_url'] != null
                          ? NetworkImage('${p['logo_url']}')
                          : null,
                      child: p['logo_url'] == null
                          ? const Icon(Icons.storefront_outlined,
                              color: SogoColors.primary)
                          : null),
                  const SizedBox(width: SogoSpacing.md),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          Flexible(
                              child: Text('${p['business_name'] ?? ''}',
                                  style: SogoText.bodyLg
                                      .copyWith(fontWeight: FontWeight.w800),
                                  overflow: TextOverflow.ellipsis)),
                          if (p['verification_status'] == 'approved') ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded,
                                color: Color(0xFF38BDF8), size: 18),
                          ],
                          const SizedBox(width: 6),
                          Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: online
                                      ? SogoColors.success
                                      : SogoColors.textMuted,
                                  shape: BoxShape.circle)),
                        ]),
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.star_rounded,
                              size: 14, color: SogoColors.warning),
                          const SizedBox(width: 2),
                          Text(
                              '${summary['average_rating'] ?? p['rating_avg'] ?? 0} (${summary['total_ratings'] ?? p['total_ratings'] ?? 0})',
                              style: SogoText.labelMd
                                  .copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Flexible(
                              child: Text(
                                  '${p['city'] ?? ''} Â· ${p['provider_type'] ?? ''}',
                                  overflow: TextOverflow.ellipsis,
                                  style: SogoText.labelMd.copyWith(
                                      color: SogoColors.textSecondary))),
                        ]),
                      ])),
                ]),
              ),
              // Actions: call / chat / book.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: SogoSpacing.lg),
                child: Row(children: [
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: () => _call('${user['phone'] ?? ''}'),
                          icon: const Icon(Icons.call_outlined, size: 18),
                          label: const Text('Call'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: SogoColors.primary,
                              side: const BorderSide(
                                  color: SogoColors.primary)))),
                  const SizedBox(width: SogoSpacing.sm),
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: userId == null
                              ? null
                              : () => _chat(
                                  userId, '${p['business_name'] ?? 'Shop'}'),
                          icon: const Icon(Icons.chat_bubble_outline_rounded,
                              size: 18),
                          label: const Text('Chat'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: SogoColors.primary,
                              side: const BorderSide(
                                  color: SogoColors.primary)))),
                  const SizedBox(width: SogoSpacing.sm),
                  Expanded(
                      child: FilledButton.icon(
                          onPressed: () => _book(p),
                          icon: const Icon(Icons.event_rounded, size: 18),
                          label: const Text('Appointment'),
                          style: FilledButton.styleFrom(
                              backgroundColor: SogoColors.primary,
                              foregroundColor: Colors.white))),
                ]),
              ),
              if ('${p['description'] ?? ''}'.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      SogoSpacing.lg, SogoSpacing.md, SogoSpacing.lg, 0),
                  child: Text('${p['description']}',
                      style: SogoText.bodySm
                          .copyWith(color: SogoColors.textSecondary)),
                ),
              // â”€â”€ About & contact strip â”€â”€
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    SogoSpacing.lg, SogoSpacing.md, SogoSpacing.lg, 0),
                child: SogoCard(
                  child: Column(children: [
                    _aboutRow(Icons.work_history_outlined, 'Experience',
                        '${p['experience_years'] ?? 0} yrs Â· ${p['total_completed'] ?? 0} jobs done'),
                    if ('${p['address'] ?? ''}'.isNotEmpty ||
                        '${p['city'] ?? ''}'.isNotEmpty)
                      _aboutRow(
                          Icons.location_on_outlined,
                          'Location',
                          [
                            '${p['address'] ?? ''}',
                            '${p['city'] ?? ''}',
                            '${p['region'] ?? ''}'
                          ].where((s) => s.isNotEmpty).join(', ')),
                    if (num.tryParse('${p['hourly_rate'] ?? ''}') != null)
                      _aboutRow(Icons.payments_outlined, 'Hourly rate',
                          ugx(num.tryParse('${p['hourly_rate']}'))),
                    if ('${p['website'] ?? ''}'.isNotEmpty)
                      _aboutRow(
                          Icons.public_outlined, 'Website', '${p['website']}'),
                    if (p['operating_hours'] != null &&
                        (p['operating_hours'] is Map) &&
                        (p['operating_hours'] as Map).isNotEmpty)
                      _aboutRow(Icons.schedule_outlined, 'Hours',
                          _hoursLabel(p['operating_hours'] as Map))
                    else
                      _aboutRow(Icons.schedule_outlined, 'Hours',
                          'Not specified yet'),
                    _aboutRow(
                        p['is_online'] == true
                            ? Icons.check_circle_rounded
                            : Icons.pause_circle_outline_rounded,
                        'Status',
                        p['is_online'] == true
                            ? 'Online now'
                            : 'Currently offline'),
                  ]),
                ),
              ),
              const SizedBox(height: SogoSpacing.md),
              // Stats strip.
              Row(children: [
                _miniStat('${p['total_completed'] ?? 0}', 'Jobs done',
                    Icons.task_alt_rounded, SogoColors.success),
                const SizedBox(width: SogoSpacing.sm),
                _miniStat('${p['experience_years'] ?? 0} yrs', 'Experience',
                    Icons.work_history_outlined, SogoColors.info),
                const SizedBox(width: SogoSpacing.sm),
                _miniStat('${products.length}', 'Products',
                    Icons.inventory_2_outlined, SogoColors.warning),
              ]),
              const SizedBox(height: SogoSpacing.sm),
              TabBar(
                controller: _tabs,
                labelColor: SogoColors.primary,
                unselectedLabelColor: SogoColors.textSecondary,
                indicatorColor: SogoColors.primary,
                tabs: [
                  Tab(text: 'Products (${products.length})'),
                  Tab(text: 'Services (${services.length})'),
                  Tab(text: 'Reviews (${summary['total_ratings'] ?? 0})'),
                ],
              ),
              Expanded(
                child: TabBarView(controller: _tabs, children: [
                  _productsTab(products),
                  _servicesTab(services),
                  _reviewsTab(reviewList),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _productsTab(List products) {
    if (products.isEmpty) {
      return ListView(children: [
        Padding(
            padding: const EdgeInsets.all(SogoSpacing.xxl),
            child: Column(children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 44, color: SogoColors.textMuted),
              const SizedBox(height: SogoSpacing.md),
              Text('No products listed yet',
                  style: SogoText.bodyMd
                      .copyWith(color: SogoColors.textSecondary)),
            ])),
      ]);
    }
    return GridView.builder(
      padding: const EdgeInsets.all(SogoSpacing.lg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: SogoSpacing.md,
          crossAxisSpacing: SogoSpacing.md,
          childAspectRatio: 0.72),
      itemCount: products.length,
      itemBuilder: (context, i) {
        final pr = products[i] as Map<String, dynamic>;
        final inStock = pr['in_stock'] == true;
        return GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  ProductDetailScreen(productId: (pr['id'] as num).toInt()))),
          child: SogoCard(
            padding: EdgeInsets.zero,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: SogoColors.surfaceMuted,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(SogoRadius.md)),
                  ),
                  child: Center(
                      child: pr['main_image_url'] != null
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(SogoRadius.md)),
                              child: Image.network('${pr['main_image_url']}',
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity),
                            )
                          : const Icon(Icons.inventory_2_outlined,
                              size: 40, color: SogoColors.textMuted)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(SogoSpacing.sm),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${pr['name'] ?? ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SogoText.bodySm
                              .copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(ugx(num.tryParse('${pr['price'] ?? 0}')),
                          style: SogoText.bodyMd.copyWith(
                              fontWeight: FontWeight.w800,
                              color: SogoColors.primary)),
                      Text(inStock ? 'In stock' : 'Out of stock',
                          style: SogoText.labelMd.copyWith(
                              color: inStock
                                  ? SogoColors.success
                                  : SogoColors.danger)),
                    ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _servicesTab(List services) {
    if (services.isEmpty) {
      return ListView(children: [
        Padding(
            padding: const EdgeInsets.all(SogoSpacing.xxl),
            child: Column(children: [
              const Icon(Icons.build_circle_outlined,
                  size: 44, color: SogoColors.textMuted),
              const SizedBox(height: SogoSpacing.md),
              Text('No services listed',
                  style: SogoText.bodyMd
                      .copyWith(color: SogoColors.textSecondary)),
            ])),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(SogoSpacing.lg),
      itemCount: services.length,
      separatorBuilder: (_, __) => const SizedBox(height: SogoSpacing.sm),
      itemBuilder: (context, i) {
        final s = services[i] as Map<String, dynamic>;
        final cat = s['category'] as Map<String, dynamic>?;
        return SogoCard(
          child: Row(children: [
            const Icon(Icons.build_circle_outlined, color: SogoColors.primary),
            const SizedBox(width: SogoSpacing.md),
            Expanded(
                child: Text('${cat?['name'] ?? s['name'] ?? 'Service'}',
                    style:
                        SogoText.bodyMd.copyWith(fontWeight: FontWeight.w600))),
            if (s['price'] != null)
              Text(ugx(num.tryParse('${s['price']}')),
                  style: SogoText.bodySm
                      .copyWith(color: SogoColors.textSecondary)),
          ]),
        );
      },
    );
  }

  Widget _reviewsTab(List reviews) {
    if (reviews.isEmpty) {
      return ListView(children: [
        Padding(
            padding: const EdgeInsets.all(SogoSpacing.xxl),
            child: Column(children: [
              const Icon(Icons.rate_review_outlined,
                  size: 44, color: SogoColors.textMuted),
              const SizedBox(height: SogoSpacing.md),
              Text('No reviews yet',
                  style: SogoText.bodyMd
                      .copyWith(color: SogoColors.textSecondary)),
            ])),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(SogoSpacing.lg),
      itemCount: reviews.length,
      separatorBuilder: (_, __) => const SizedBox(height: SogoSpacing.sm),
      itemBuilder: (context, i) {
        final r = reviews[i] as Map<String, dynamic>;
        return SogoCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Row(
                  children: List.generate(
                      5,
                      (s) => Icon(
                          s < ((r['rating'] ?? 0) as num).round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 14,
                          color: SogoColors.warning))),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      '${(r['reviewer'] as Map<String, dynamic>?)?['name'] ?? r['reviewer_name'] ?? r['customer_name'] ?? 'Customer'}',
                      style: SogoText.labelMd
                          .copyWith(color: SogoColors.textSecondary))),
            ]),
            if ('${r['comment'] ?? r['review'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('${r['comment'] ?? r['review']}', style: SogoText.bodySm),
            ],
          ]),
        );
      },
    );
  }
}
