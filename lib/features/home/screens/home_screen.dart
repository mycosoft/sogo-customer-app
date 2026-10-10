import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/sogo_widgets.dart';
import '../../booking/screens/book_service_screen.dart';
import '../../messages/screens/chats_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../orders/screens/orders_screen.dart';
import '../../requests/screens/my_requests_screen.dart';
import '../../requests/screens/request_details_screen.dart';
import '../../shops/screens/book_appointment_screen.dart';
import '../../shops/screens/shops_screen.dart';
import '../../shops/widgets/cart_icon_button.dart';
import '../../support/screens/support_screen.dart';
import '../../vehicles/screens/vehicles_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<Map<String, dynamic>> _future = _load();

  Future<Map<String, dynamic>> _load() async {
    final dashboard = await customerApi.dashboard();
    final requests = await customerApi.listRequests();
    final orders = await customerApi.listOrders();

    int unread = 0;
    try {
      final unreadRes = await notificationApi.unread();
      unread = ((unreadRes['count'] ?? 0) as num).toInt();
    } catch (_) {}

    String name = '';
    try {
      final me = await authApi.me();
      name = '${me['data']?['name'] ?? ''}';
    } catch (_) {}

    return {
      'stats':
          (dashboard['data']?['stats'] ?? const {}) as Map<String, dynamic>,
      'requests': _items(requests),
      'orders': _items(orders),
      'unread': unread,
      'name': name,
    };
  }

  String _firstName(String full) {
    final parts = full.trim().split(RegExp(r'\s+'));
    return (parts.isEmpty || parts.first.isEmpty) ? 'there' : parts.first;
  }

  /// One stat per row, full width (vertical stack).
  Widget _statRow(String label, String value, IconData icon, Color color) {
    return SogoCard(
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(SogoRadius.md),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: SogoSpacing.md),
        Expanded(
            child: Text(label,
                style: SogoText.bodyLg.copyWith(fontWeight: FontWeight.w600))),
        Text(value,
            style: SogoText.headlineMd.copyWith(fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _quickLink(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: SogoSpacing.md),
          decoration: BoxDecoration(
            color: SogoColors.surface,
            borderRadius: BorderRadius.circular(SogoRadius.md),
            border: Border.all(color: SogoColors.surfaceBorder),
          ),
          child: Column(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: SogoText.labelMd
                    .copyWith(fontWeight: FontWeight.w600, fontSize: 11),
                maxLines: 1),
          ]),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> res) {
    final data = res['data'];
    if (data is Map && data['items'] is List) {
      return List<Map<String, dynamic>>.from(data['items'] as List);
    }
    if (data is Map && data['data'] is List) {
      return List<Map<String, dynamic>>.from(data['data'] as List);
    }
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return const [];
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _pickProviderForAppointment() async {
    // Get current location
    double? lat;
    double? lng;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10))
            .timeout(const Duration(seconds: 12));
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (_) {}

    // Use Kampala as fallback if no GPS
    lat ??= 0.3476;
    lng ??= 32.5825;

    // Fetch nearby providers (all categories)
    List<dynamic> providers = [];
    try {
      providers = await serviceApi.nearbyProviders(lat: lat, lng: lng);
    } catch (_) {}

    if (!mounted) return;

    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProviderListSheet(providers: providers),
    );

    if (picked != null && picked['id'] != null && mounted) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BookAppointmentScreen(provider: picked),
      ));
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(
        title: const Text('SOGO'),
        actions: [
          const CartIconButton(),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChatsScreen()),
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 24),
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snap) {
              final unread = (snap.data?['unread'] as num?) ?? 0;
              return Stack(children: [
                IconButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen()),
                    );
                    setState(() => _future = _load());
                  },
                  icon: const Icon(Icons.notifications_none_rounded, size: 26),
                ),
                if (unread > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: SogoColors.danger, shape: BoxShape.circle),
                      child: Text('$unread',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
              ]);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            return const Center(child: CircularProgressIndicator());
          }

          final stats = snapshot.data!['stats'] as Map<String, dynamic>;
          final requests =
              snapshot.data!['requests'] as List<Map<String, dynamic>>;
          final orders = snapshot.data!['orders'] as List<Map<String, dynamic>>;
          final name = '${snapshot.data!['name'] ?? ''}';

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ?"??"? Header: gradient banner with greeting ?"??"?
                      Container(
                        padding: const EdgeInsets.fromLTRB(
                            SogoSpacing.lg,
                            SogoSpacing.lg,
                            SogoSpacing.lg,
                            SogoSpacing.xl + 12),
                        decoration: const BoxDecoration(
                          color: SogoColors.primary,
                          borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(SogoRadius.xl)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Hello, ${_firstName(name)}',
                                          style: SogoText.headlineLg
                                              .copyWith(color: Colors.white)),
                                      const SizedBox(height: 4),
                                      Text(
                                          'Your bookings, vehicles and payments - all in one place.',
                                          style: SogoText.bodySm
                                              .copyWith(color: Colors.white70)),
                                    ]),
                              ),
                            ]),
                            const SizedBox(height: SogoSpacing.md),
                            // Floating quick-book card over the banner
                            SogoCard(
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const BookServiceScreen()),
                                );
                                setState(() => _future = _load());
                              },
                              padding: const EdgeInsets.symmetric(
                                  horizontal: SogoSpacing.lg,
                                  vertical: SogoSpacing.md),
                              child: Row(children: [
                                Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                        color: SogoColors.primaryLight,
                                        borderRadius: BorderRadius.circular(
                                            SogoRadius.md)),
                                    child: const Icon(
                                        Icons.build_circle_outlined,
                                        color: SogoColors.primary)),
                                const SizedBox(width: SogoSpacing.md),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text('Book a service',
                                          style: SogoText.bodyLg.copyWith(
                                              fontWeight: FontWeight.w700)),
                                      Text('Nearest verified provider, fast',
                                          style: SogoText.bodySm.copyWith(
                                              color: SogoColors.textSecondary)),
                                    ])),
                                const Icon(Icons.arrow_forward_rounded,
                                    color: SogoColors.primary),
                              ]),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(SogoSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                _statRow(
                                    'Active requests',
                                    '${stats['active_requests'] ?? 0}',
                                    Icons.assignment_late_outlined,
                                    SogoColors.warning),
                                const SizedBox(height: SogoSpacing.md),
                                _statRow(
                                    'Completed',
                                    '${stats['completed_services'] ?? 0}',
                                    Icons.check_circle_outline,
                                    SogoColors.success),
                                const SizedBox(height: SogoSpacing.md),
                                _statRow(
                                    'Spent',
                                    ugx(num.tryParse(
                                        '${stats['orders_spent'] ?? 0}')),
                                    Icons.payments_outlined,
                                    SogoColors.tertiary),
                              ],
                            ),
                            const SizedBox(height: SogoSpacing.xl),
                            // Quick links - 3x2 grid
                            const SogoSectionTitle('Quick links'),
                            const SizedBox(height: SogoSpacing.sm),
                            Row(children: [
                              _quickLink(
                                  Icons.storefront_outlined,
                                  'Providers',
                                  SogoColors.primary,
                                  () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const ShopsScreen()))),
                              const SizedBox(width: SogoSpacing.md),
                              _quickLink(
                                  Icons.event_rounded,
                                  'Appointment',
                                  SogoColors.secondary,
                                  () => _pickProviderForAppointment()),
                              const SizedBox(width: SogoSpacing.md),
                              _quickLink(
                                  Icons.receipt_long_outlined,
                                  'Orders',
                                  SogoColors.warning,
                                  () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const OrdersScreen()))),
                            ]),
                            const SizedBox(height: SogoSpacing.md),
                            Row(children: [
                              _quickLink(Icons.directions_car_outlined,
                                  'Vehicles', SogoColors.info, () async {
                                await Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const VehiclesScreen()));
                                setState(() => _future = _load());
                              }),
                              const SizedBox(width: SogoSpacing.md),
                              _quickLink(
                                  Icons.chat_bubble_outline_rounded,
                                  'Messages',
                                  SogoColors.success,
                                  () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const ChatsScreen()))),
                              const SizedBox(width: SogoSpacing.md),
                              _quickLink(
                                  Icons.support_agent_rounded,
                                  'Support',
                                  SogoColors.tertiary,
                                  () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const SupportScreen()))),
                            ]),
                            const SizedBox(height: SogoSpacing.xl),
                            Row(children: [
                              const Expanded(
                                  child: SogoSectionTitle('Recent requests')),
                              TextButton(
                                onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const MyRequestsScreen())),
                                child: Text('View all',
                                    style: SogoText.bodySm.copyWith(
                                        color: SogoColors.primary,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ]),
                            ...requests.take(2).map((request) => Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: SogoSpacing.md),
                                  child: SogoCard(
                                    onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                RequestDetailsScreen(
                                                    request: request))),
                                    child: _RequestTile(request: request),
                                  ),
                                )),
                            const SizedBox(height: SogoSpacing.xl),
                            Row(children: [
                              const Expanded(
                                  child: SogoSectionTitle('Recent orders')),
                              TextButton(
                                onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => const OrdersScreen())),
                                child: Text('View all',
                                    style: SogoText.bodySm.copyWith(
                                        color: SogoColors.primary,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ]),
                            ...orders.take(2).map((order) => Padding(
                                padding: const EdgeInsets.only(
                                    bottom: SogoSpacing.md),
                                child: SogoCard(
                                  child: InkWell(
                                    borderRadius:
                                        BorderRadius.circular(SogoRadius.md),
                                    onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const OrdersScreen())),
                                    child: Row(
                                      children: [
                                        Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                                color: SogoColors.primaryLight,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        SogoRadius.md)),
                                            child: const Icon(
                                                Icons.receipt_long_outlined,
                                                color: SogoColors.primary)),
                                        const SizedBox(width: SogoSpacing.md),
                                        Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                              Text(
                                                  '${order['reference'] ?? 'Order'}',
                                                  style: SogoText.bodyLg
                                                      .copyWith(
                                                          fontWeight:
                                                              FontWeight.w700)),
                                              Text('${order['status'] ?? ''}',
                                                  style: SogoText.bodySm
                                                      .copyWith(
                                                          color: SogoColors
                                                              .textSecondary))
                                            ])),
                                        const Icon(Icons.chevron_right_rounded,
                                            color: SogoColors.textMuted),
                                      ],
                                    ),
                                  ),
                                ))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProviderListSheet extends StatelessWidget {
  const _ProviderListSheet({required this.providers});
  final List<dynamic> providers;

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront_outlined,
                  size: 48, color: SogoColors.textMuted),
              const SizedBox(height: SogoSpacing.md),
              Text('No providers found nearby',
                  style: SogoText.bodyMd.copyWith(color: SogoColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(SogoSpacing.lg),
          child: Row(children: [
            const Expanded(
                child: Text('Choose a provider', style: SogoText.headlineMd)),
            IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded)),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: SogoSpacing.lg),
            itemCount: providers.length,
            separatorBuilder: (_, __) => const SizedBox(height: SogoSpacing.sm),
            itemBuilder: (_, i) {
              final p = providers[i] as Map<String, dynamic>;
              return SogoCard(
                onTap: () => Navigator.pop(context, p),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(SogoRadius.md),
                    child: Container(
                      width: 48,
                      height: 48,
                      color: SogoColors.primaryLight,
                      child: p['logo_url'] != null
                          ? Image.network('${p['logo_url']}', fit: BoxFit.cover)
                          : const Icon(Icons.storefront_outlined,
                              color: SogoColors.primary),
                    ),
                  ),
                  const SizedBox(width: SogoSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${p['business_name'] ?? 'Provider'}',
                            style: SogoText.bodyLg
                                .copyWith(fontWeight: FontWeight.w700)),
                        if (p['address'] != null)
                          Text('${p['address']}',
                              style: SogoText.bodySm
                                  .copyWith(color: SogoColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        if (p['rating_avg'] != null)
                          Row(children: [
                            const Icon(Icons.star_rounded,
                                size: 14, color: SogoColors.warning),
                            const SizedBox(width: 4),
                            Text('${p['rating_avg']}',
                                style: SogoText.bodySm
                                    .copyWith(fontWeight: FontWeight.w600)),
                          ]),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: SogoColors.textMuted),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request});

  final Map<String, dynamic> request;

  Color _statusColor(String status) {
    return switch (status) {
      'completed' => SogoColors.success,
      'cancelled' || 'rejected' || 'expired' => SogoColors.danger,
      'pending' => SogoColors.warning,
      _ => SogoColors.primary, // active states
    };
  }

  @override
  Widget build(BuildContext context) {
    final status = (request['status'] ?? 'pending').toString();
    final label = status.replaceAll('_', ' ').toUpperCase();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('#${request['reference'] ?? ''}',
                  style: SogoText.bodySm.copyWith(color: SogoColors.textMuted)),
              const SizedBox(height: 4),
              Text('${request['category']?['name'] ?? 'Service request'}',
                  style: SogoText.headlineMd),
              const SizedBox(height: 2),
              Text('${request['pickup_address'] ?? ''}',
                  style: SogoText.bodySm
                      .copyWith(color: SogoColors.textSecondary)),
            ],
          ),
        ),
        SogoBadge(label: label, color: _statusColor(status)),
      ],
    );
  }
}
