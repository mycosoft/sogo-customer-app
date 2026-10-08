import 'package:flutter/material.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';
import '../../booking/screens/book_service_screen.dart';
import 'request_details_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  static const _filters = [
    ('all', 'All'),
    ('active', 'Active'),
    ('scheduled', 'Scheduled'),
    ('completed', 'Completed'),
    ('cancelled', 'Cancelled'),
  ];

  String _filter = 'all';
  late Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await customerApi.listRequests();
    final data = res['data'];
    if (data is Map && data['items'] is List) {
      return List<Map<String, dynamic>>.from(data['items'] as List);
    }
    if (data is Map && data['data'] is List) {
      return List<Map<String, dynamic>>.from(data['data'] as List);
    }
    if (data is List) return List<Map<String, dynamic>>.from(data);
    return const [];
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> all) {
    switch (_filter) {
      case 'active':
        return all
            .where((r) =>
                !{'completed', 'cancelled', 'rejected'}.contains(r['status']))
            .toList();
      case 'completed':
        return all.where((r) => r['status'] == 'completed').toList();
      case 'scheduled':
        return all
            .where((r) =>
                '${r['scheduled_at'] ?? ''}'.isNotEmpty &&
                !{'completed', 'cancelled', 'rejected'}.contains(r['status']))
            .toList();
      case 'cancelled':
        return all
            .where((r) => {'cancelled', 'rejected'}.contains(r['status']))
            .toList();
      default:
        return all;
    }
  }

  String _shortSchedule(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return SogoColors.success;
      case 'cancelled':
      case 'rejected':
        return SogoColors.danger;
      case 'pending':
      case 'pending_match':
        return SogoColors.warning;
      default:
        return SogoColors.primary; // in progress states
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.task_alt_rounded;
      case 'cancelled':
      case 'rejected':
        return Icons.cancel_outlined;
      case 'pending':
      case 'pending_match':
        return Icons.hourglass_top_rounded;
      default:
        return Icons.local_shipping_rounded; // on the way / in progress
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(title: const Text('My requests')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new_request',
        backgroundColor: SogoColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const BookServiceScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data!;
          final requests = _filtered(all);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(SogoSpacing.lg),
              children: [
                // Status filters
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _filters
                        .map((f) => Padding(
                              padding:
                                  const EdgeInsets.only(right: SogoSpacing.sm),
                              child: ChoiceChip(
                                  label: Text(f.$2),
                                  selected: _filter == f.$1,
                                  selectedColor: SogoColors.primary,
                                  labelStyle: SogoText.bodySm.copyWith(
                                      color: _filter == f.$1
                                          ? Colors.white
                                          : SogoColors.textSecondary,
                                      fontWeight: FontWeight.w700),
                                  onSelected: (_) =>
                                      setState(() => _filter = f.$1)),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: SogoSpacing.md),

                if (requests.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: SogoSpacing.xxl),
                    child: Column(children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                            color: SogoColors.primaryLight,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.handyman_outlined,
                            size: 40, color: SogoColors.primary),
                      ),
                      const SizedBox(height: SogoSpacing.lg),
                      Text(
                          _filter == 'all' ? 'No requests yet' : 'Nothing here',
                          style: SogoText.headlineMd),
                      const SizedBox(height: SogoSpacing.sm),
                      Text(
                          _filter == 'all'
                              ? 'Book a service and your nearest verified provider will come to you.'
                              : 'No requests in this category yet.',
                          textAlign: TextAlign.center,
                          style: SogoText.bodyMd
                              .copyWith(color: SogoColors.textSecondary)),
                      const SizedBox(height: SogoSpacing.lg),
                      SogoButton(
                          label: 'Book a service',
                          icon: Icons.add_rounded,
                          fullWidth: false,
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const BookServiceScreen()))),
                    ]),
                  )
                else
                  ...requests.map((r) {
                    final status = (r['status'] ?? 'pending').toString();
                    final color = _statusColor(status);
                    final price = num.tryParse(
                        '${r['final_price'] ?? r['quoted_price'] ?? r['price'] ?? ''}');
                    final date = r['created_at'] != null
                        ? '${r['created_at']}'
                            .substring(0, 16)
                            .replaceAll('T', ' ')
                        : '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: SogoSpacing.md),
                      child: SogoCard(
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    RequestDetailsScreen(request: r))),
                        child: Row(children: [
                          Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius:
                                      BorderRadius.circular(SogoRadius.md)),
                              child: Icon(_statusIcon(status), color: color)),
                          const SizedBox(width: SogoSpacing.md),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(
                                    '${r['category']?['name'] ?? 'Service request'}',
                                    style: SogoText.bodyLg
                                        .copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                    '${r['provider']?['business_name'] ?? 'Finding a provider?'}',
                                    style: SogoText.bodySm.copyWith(
                                        color: SogoColors.textSecondary)),
                                const SizedBox(height: 2),
                                Text('$date',
                                    style: SogoText.labelMd
                                        .copyWith(color: SogoColors.textMuted)),
                                if ('${r['scheduled_at'] ?? ''}'.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                        'Scheduled: ${_shortSchedule('${r['scheduled_at']}')}',
                                        style: SogoText.labelMd.copyWith(
                                            color: SogoColors.primary,
                                            fontWeight: FontWeight.w700)),
                                  ),
                              ])),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (price != null)
                                  Text('UGX ${price.toStringAsFixed(0)}',
                                      style: SogoText.bodyMd.copyWith(
                                          fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                        color: color.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(
                                            SogoRadius.pill)),
                                    child: Text(status.replaceAll('_', ' '),
                                        style: SogoText.labelMd
                                            .copyWith(color: color))),
                              ]),
                          const Icon(Icons.chevron_right_rounded,
                              color: SogoColors.textMuted),
                        ]),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}
