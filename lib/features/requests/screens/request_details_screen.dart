import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';

class _Step {
  const _Step(this.label, this.icon);

  final String label;
  final IconData icon;
}

class RequestDetailsScreen extends StatefulWidget {
  const RequestDetailsScreen({super.key, required this.request});

  final Map<String, dynamic> request;

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  late Map<String, dynamic> _request = widget.request;
  bool _loading = false;
  bool _reviewed = false;
  Timer? _pollTimer;
  final MapController _mapController = MapController();

  static const _activeStatuses = [
    'matched',
    'accepted',
    'en_route',
    'arrived',
    'in_progress'
  ];

  bool get _isActive => _activeStatuses.contains('${_request['status']}');
  bool get _canCancel => !_canCancelForbidden.contains('${_request['status']}');
  static const _canCancelForbidden = ['completed', 'cancelled', 'expired'];

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _refresh());
    // Initial refresh so the map gets the latest provider position.
    _refresh();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Polls the request: status changes (timeline) + the provider's live
  /// position so the map marker moves in real time.
  Future<void> _refresh() async {
    try {
      final res = await customerApi.getRequest(_request['id'] as int);
      if (!mounted) return;
      final data = res['data'] as Map<String, dynamic>?;
      if (data != null) {
        setState(() => _request = data);
      }
    } catch (_) {
      // keep the last good data on transient failures
    }
  }

  Map<String, dynamic>? get _provider =>
      _request['provider'] as Map<String, dynamic>?;

  LatLng? get _pickup {
    final lat = (_request['pickup_lat'] as num?);
    final lng = (_request['pickup_lng'] as num?);
    if (lat == null || lng == null) return null;
    return LatLng(lat.toDouble(), lng.toDouble());
  }

  LatLng? get _providerPos {
    final p = _provider;
    final lat = (p?['current_lat'] as num?);
    final lng = (p?['current_lng'] as num?);
    if (p == null ||
        '${p['business_name'] ?? ''}'.isEmpty ||
        lat == null ||
        lng == null) {
      return null;
    }
    return LatLng(lat.toDouble(), lng.toDouble());
  }

  String? get _distanceToPickup {
    final a = _providerPos;
    final b = _pickup;
    if (a == null || b == null) return null;
    final d = _haversineKm(a.latitude, a.longitude, b.latitude, b.longitude);
    return d < 1 ? '${(d * 1000).round()} m' : '${d.toStringAsFixed(1)} km';
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return 2 * r * asin(min(1, sqrt(a)));
  }

  double _rad(double deg) => deg * pi / 180;

  Future<void> _reviewDialog() async {
    final provider = _request['provider'] as Map<String, dynamic>? ?? {};
    final providerUser = provider['user'] as Map<String, dynamic>?;
    final revieweeId = (providerUser?['id'] as num?)?.toInt();
    if (revieweeId == null) return;

    int rating = 5;
    final comment = TextEditingController();

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(SogoRadius.lg))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              left: SogoSpacing.xl,
              right: SogoSpacing.xl,
              top: SogoSpacing.xl,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + SogoSpacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Rate ${provider['business_name'] ?? 'the provider'}',
                style: SogoText.headlineMd),
            const SizedBox(height: SogoSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  5,
                  (i) => IconButton(
                      onPressed: () => setSheet(() => rating = i + 1),
                      icon: Icon(
                          i < rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 36,
                          color: SogoColors.warning))),
            ),
            const SizedBox(height: SogoSpacing.md),
            TextField(
              controller: comment,
              maxLines: 3,
              maxLength: 1000,
              decoration: InputDecoration(
                  labelText: 'Comment (optional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SogoRadius.md))),
            ),
            const SizedBox(height: SogoSpacing.md),
            SogoButton(
                label: 'Submit review',
                onPressed: () async {
                  try {
                    await customerApi.submitReview(
                        requestId: _request['id'] as int,
                        revieweeId: revieweeId,
                        rating: rating,
                        comment: comment.text);
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx)
                          .showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  }
                }),
          ]),
        ),
      ),
    );

    if (submitted == true && mounted) {
      setState(() => _reviewed = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Thanks! Your review was submitted.'),
          backgroundColor: SogoColors.success));
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SogoRadius.lg)),
        title: const Text('Cancel this request?'),
        content:
            const Text('The provider will be notified. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep it')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel request',
                  style: TextStyle(color: SogoColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loading = true);
    try {
      final updated = await customerApi.cancelRequest(_request['id'] as int,
          reason: 'Cancelled from app');
      final data = updated['data'];
      if (data is Map<String, dynamic>) {
        setState(() => _request = data);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Request cancelled')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _callProvider() async {
    final phone =
        '${_provider?['user']?['phone'] ?? _provider?['phone'] ?? ''}';
    if (phone.isEmpty) return;
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  String _fmtTime(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '-';
    return '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  // -- Map --
  Widget _liveMap() {
    final pickup = _pickup;
    final providerPos = _providerPos;

    final points = <LatLng>[
      if (pickup != null) pickup,
      if (providerPos != null) providerPos,
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(SogoRadius.lg),
      child: SizedBox(
        height: 260,
        child: Stack(children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: pickup ?? const LatLng(0.3476, 32.5825),
              initialZoom: 14,
              interactionOptions:
                  const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'co.sogo.customer',
              ),
              MarkerLayer(markers: [
                if (pickup != null)
                  Marker(
                      point: pickup,
                      width: 46,
                      height: 46,
                      child: const Icon(Icons.location_on_rounded,
                          color: SogoColors.primary, size: 44)),
                if (providerPos != null)
                  Marker(
                      point: providerPos,
                      width: 46,
                      height: 46,
                      child: Container(
                          decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: const [SogoShadows.card]),
                          child: const Icon(Icons.build_circle_rounded,
                              color: SogoColors.warning, size: 40))),
              ]),
            ],
          ),
          // Fit both pins whenever they change.
          if (points.length >= 2)
            Positioned(
              right: SogoSpacing.md,
              bottom: SogoSpacing.md,
              child: FloatingActionButton.small(
                heroTag: 'fit_bounds',
                backgroundColor: Colors.white,
                onPressed: () {
                  _mapController.fitCamera(CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(points),
                      padding: const EdgeInsets.all(60)));
                },
                child: const Icon(Icons.center_focus_strong_rounded,
                    color: SogoColors.primary),
              ),
            ),
          Positioned(
              left: SogoSpacing.md,
              bottom: SogoSpacing.md,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(SogoRadius.pill),
                      boxShadow: const [SogoShadows.card]),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.location_on_rounded,
                        size: 12, color: SogoColors.primary),
                    const SizedBox(width: 4),
                    Text('You',
                        style: SogoText.labelMd
                            .copyWith(fontWeight: FontWeight.w700)),
                    if (providerPos != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.build_circle_rounded,
                          size: 12, color: SogoColors.warning),
                      const SizedBox(width: 4),
                      Text('Provider',
                          style: SogoText.labelMd
                              .copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ]))),
        ]),
      ),
    );
  }

  // -- Timeline: connected stepper with icon chips --
  Widget _timeline() {
    final status = '${_request['status'] ?? 'pending'}';
    final logs = (_request['status_history'] as List?) ?? const [];

    String at(Object? key) {
      final v = _request[key];
      return _fmtTime(v == null ? null : '$v');
    }

    final stages = <(_Step, String)>[
      (_Step('Requested', Icons.receipt_long_rounded), at('created_at')),
      (_Step('Provider matched', Icons.handshake_rounded), at('matched_at')),
      (_Step('Accepted', Icons.thumb_up_alt_outlined), at('accepted_at')),
      (_Step('Arriving', Icons.directions_car_rounded), at('arrived_at')),
      (_Step('In progress', Icons.build_rounded), at('started_at')),
      (_Step('Completed', Icons.task_alt_rounded), at('completed_at')),
    ];

    const order = [
      'pending',
      'matched',
      'accepted',
      'en_route',
      'arrived',
      'in_progress',
      'completed'
    ];
    final currentIdx = order.indexOf(status);
    final isCancelled = {'cancelled', 'rejected', 'expired'}.contains(status);

    return SogoCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Progress', style: SogoText.headlineMd),
        const SizedBox(height: SogoSpacing.md),
        ...stages.asMap().entries.map((entry) {
          final i = entry.key;
          final stage = entry.value.$1;
          final time = entry.value.$2;
          final done = time != '-' || (currentIdx >= 0 && i < currentIdx);
          final active =
              !done && !isCancelled && currentIdx >= 0 && i == currentIdx;

          final color = done
              ? SogoColors.success
              : active
                  ? SogoColors.primary
                  : SogoColors.textMuted;
          final isLast = i == stages.length - 1;

          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: done || active
                      ? color.withOpacity(0.14)
                      : SogoColors.surfaceMuted,
                  shape: BoxShape.circle,
                  border: active ? Border.all(color: color, width: 2) : null,
                ),
                child: Icon(
                    done
                        ? Icons.check_rounded
                        : (active ? Icons.sync_rounded : stage.icon),
                    size: 18,
                    color: color),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 18,
                  color: done
                      ? SogoColors.success.withOpacity(0.6)
                      : SogoColors.surfaceBorder,
                ),
            ]),
            const SizedBox(width: SogoSpacing.md),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stage.label,
                          style: SogoText.bodyMd.copyWith(
                              fontWeight: FontWeight.w700,
                              color: done || active
                                  ? SogoColors.textPrimary
                                  : SogoColors.textMuted)),
                      if (time != '-')
                        Text(time,
                            style: SogoText.labelMd
                                .copyWith(color: SogoColors.textSecondary)),
                    ]),
              ),
            ),
          ]);
        }),
        if (isCancelled) ...[
          const SizedBox(height: SogoSpacing.sm),
          Container(
            padding: const EdgeInsets.all(SogoSpacing.md),
            decoration: BoxDecoration(
              color: SogoColors.danger.withOpacity(0.08),
              borderRadius: BorderRadius.circular(SogoRadius.md),
              border: Border.all(color: SogoColors.danger.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.cancel_outlined,
                  color: SogoColors.danger, size: 20),
              const SizedBox(width: SogoSpacing.sm),
              Expanded(
                child: Text(
                    'Request ${status.replaceAll('_', ' ')} - ${_fmtTime('${_request['cancelled_at'] ?? ''}')}',
                    style: SogoText.bodySm.copyWith(color: SogoColors.danger)),
              ),
            ]),
          ),
        ],
        if (logs.isNotEmpty) ...[
          const SizedBox(height: SogoSpacing.md),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Full activity log (${logs.length})',
                  style: SogoText.bodySm
                      .copyWith(color: SogoColors.textSecondary)),
              children: logs.whereType<Map<String, dynamic>>().map((l) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    const Icon(Icons.flag_rounded,
                        size: 14, color: SogoColors.textMuted),
                    const SizedBox(width: SogoSpacing.sm),
                    Expanded(
                        child: Text('${l['status'] ?? ''}'.replaceAll('_', ' '),
                            style: SogoText.bodySm)),
                    Text(_fmtTime('${l['changed_at'] ?? ''}'),
                        style: SogoText.labelMd
                            .copyWith(color: SogoColors.textMuted)),
                  ]),
                );
              }).toList(),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 110,
            child: Text(label,
                style:
                    SogoText.bodySm.copyWith(color: SogoColors.textSecondary))),
        Expanded(
            child: Text(value,
                style: SogoText.bodySm.copyWith(fontWeight: FontWeight.w600))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = (_request['status'] ?? 'pending').toString();
    final provider = _provider;
    final vehicle = _request['vehicle'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(title: Text('Request #${_request['reference'] ?? ''}')),
      body: ListView(
        padding: const EdgeInsets.all(SogoSpacing.lg),
        children: [
          // -- Status header --
          SogoCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(SogoRadius.pill)),
                    child: Text(status.replaceAll('_', ' ').toUpperCase(),
                        style: SogoText.labelMd
                            .copyWith(color: _statusColor(status)))),
                const Spacer(),
                Text(
                    'UGX ${_request['final_price'] ?? _request['estimated_price'] ?? '0'}',
                    style: SogoText.headlineMd),
              ]),
              const SizedBox(height: SogoSpacing.md),
              Text('${_request['category']?['name'] ?? 'Service request'}',
                  style: SogoText.headlineLg),
              const SizedBox(height: 4),
              Text('${_request['description'] ?? ''}',
                  style: SogoText.bodyMd
                      .copyWith(color: SogoColors.textSecondary)),
              const Divider(height: SogoSpacing.xl),
              _infoRow('Pickup', '${_request['pickup_address'] ?? '-'}'),
              if ('${_request['scheduled_at'] ?? ''}'.isNotEmpty)
                _infoRow('Scheduled', _fmtTime('${_request['scheduled_at']}')),
              if ('${_request['destination_address'] ?? ''}'.isNotEmpty)
                _infoRow('Destination', '${_request['destination_address']}'),
              if (vehicle != null)
                _infoRow('Vehicle',
                    '${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''} - ${vehicle['plate_number'] ?? ''}'),
              _infoRow('Payment', '${_request['payment_status'] ?? 'unpaid'}'),
              _infoRow('Created', _fmtTime('${_request['created_at'] ?? ''}')),
            ]),
          ),
          const SizedBox(height: SogoSpacing.lg),

          // -- Live map --
          if (_pickup != null) ...[
            _liveMap(),
            if (_isActive && _distanceToPickup != null)
              Padding(
                padding: const EdgeInsets.only(top: SogoSpacing.sm),
                child: Row(children: [
                  const Icon(Icons.social_distance_rounded,
                      size: 14, color: SogoColors.textSecondary),
                  const SizedBox(width: 6),
                  Text('Provider is $_distanceToPickup away - live',
                      style: SogoText.bodySm
                          .copyWith(color: SogoColors.textSecondary)),
                  const SizedBox(width: 6),
                  const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(strokeWidth: 1.5)),
                ]),
              ),
            const SizedBox(height: SogoSpacing.lg),
          ],

          // -- Provider card --
          if (provider != null &&
              '${provider['business_name'] ?? ''}'.isNotEmpty) ...[
            SogoCard(
              child: Row(children: [
                CircleAvatar(
                    radius: 24,
                    backgroundColor: SogoColors.primaryLight,
                    backgroundImage: provider['logo_url'] != null
                        ? NetworkImage('${provider['logo_url']}')
                        : null,
                    child: provider['logo_url'] == null
                        ? const Icon(Icons.build_circle_outlined,
                            color: SogoColors.primary)
                        : null),
                const SizedBox(width: SogoSpacing.md),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('${provider['business_name']}',
                          style: SogoText.bodyLg
                              .copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: SogoColors.warning),
                        const SizedBox(width: 2),
                        Text('${provider['rating_avg'] ?? 0}',
                            style: SogoText.labelMd
                                .copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Text('${provider['total_completed'] ?? 0} jobs done',
                            style: SogoText.labelMd
                                .copyWith(color: SogoColors.textSecondary)),
                      ]),
                    ])),
                IconButton.filled(
                    onPressed: _callProvider,
                    style: IconButton.styleFrom(
                        backgroundColor: SogoColors.primary),
                    icon: const Icon(Icons.call_rounded, color: Colors.white)),
              ]),
            ),
            const SizedBox(height: SogoSpacing.lg),
          ] else ...[
            SogoCard(
              child: Row(children: [
                Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: SogoColors.warning.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(SogoRadius.md)),
                    child: const Icon(Icons.hourglass_top_rounded,
                        color: SogoColors.warning)),
                const SizedBox(width: SogoSpacing.md),
                Expanded(
                    child: Text(
                        'Finding you a provider?\nYou\'ll get a notification the moment one is matched.',
                        style: SogoText.bodySm
                            .copyWith(color: SogoColors.textSecondary))),
              ]),
            ),
            const SizedBox(height: SogoSpacing.lg),
          ],

          _timeline(),
          const SizedBox(height: SogoSpacing.lg),

          // -- Rate the provider (completed jobs only) --
          if (_request['status'] == 'completed' &&
              (_request['provider'] as Map<String, dynamic>?)?['user'] != null)
            SogoButton(
              label: _reviewed ? 'Thanks for rating' : 'Rate this service',
              icon: Icons.star_rounded,
              onPressed: _reviewed ? null : _reviewDialog,
            ),
          if (_request['status'] == 'completed')
            const SizedBox(height: SogoSpacing.md),

          // -- Cancel (green, as requested) --
          if (_canCancel)
            SogoButton(
              label: 'Cancel request',
              icon: Icons.cancel_outlined,
              onPressed: _loading ? null : _cancel,
              loading: _loading,
            ),
          const SizedBox(height: SogoSpacing.xl),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return SogoColors.success;
      case 'cancelled':
      case 'rejected':
        return SogoColors.danger;
      case 'pending':
        return SogoColors.warning;
      default:
        return SogoColors.primary;
    }
  }
}
