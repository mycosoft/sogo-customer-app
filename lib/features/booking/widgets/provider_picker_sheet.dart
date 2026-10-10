import 'package:flutter/material.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';

/// Bottom sheet listing eligible providers near the pickup point.
/// Tap one to assign them. The Auto-match action (online-only) is shown
/// only when [allowAutoMatch] is true - appointments hide it because
/// matching happens near the scheduled time, not now.
class ProviderPickerSheet extends StatefulWidget {
  const ProviderPickerSheet({
    super.key,
    required this.categoryId,
    required this.lat,
    required this.lng,
    required this.onCreate,
    this.allowAutoMatch = true,
    this.skipLabel,
  });

  final int categoryId;
  final double lat;
  final double lng;
  final Future<void> Function({int? providerId, bool autoMatch}) onCreate;
  final bool allowAutoMatch;

  /// When set, a bottom button lets the user save without picking
  /// (e.g. appointments choose a provider later).
  final String? skipLabel;

  @override
  State<ProviderPickerSheet> createState() => _ProviderPickerSheetState();
}

class _ProviderPickerSheetState extends State<ProviderPickerSheet> {
  late Future<List<dynamic>> _future;
  int? _creating;

  @override
  void initState() {
    super.initState();
    _future = customerApi.providersNearby(
        serviceCategoryId: widget.categoryId, lat: widget.lat, lng: widget.lng);
  }

  Future<void> _pick(int providerId) async {
    setState(() => _creating = providerId);
    try {
      await widget.onCreate(providerId: providerId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _creating = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.78,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(SogoSpacing.lg),
          child: Row(children: [
            const Expanded(
                child: Text('Providers near you', style: SogoText.headlineMd)),
            IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded)),
          ]),
        ),
        if (widget.allowAutoMatch)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SogoSpacing.lg),
            child: SogoButton(
                label: 'Auto match for me (online now)',
                icon: Icons.bolt_rounded,
                onPressed: () async {
                  Navigator.pop(context);
                  await widget.onCreate(autoMatch: true);
                }),
          ),
        if (widget.allowAutoMatch) const SizedBox(height: SogoSpacing.sm),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return ListView(children: [
                  Padding(
                      padding: const EdgeInsets.all(SogoSpacing.xl),
                      child: Text('Could not load providers: ${snap.error}',
                          style: SogoText.bodySm
                              .copyWith(color: SogoColors.danger))),
                ]);
              }
              final providers = snap.data ?? [];
              if (providers.isEmpty) {
                return ListView(children: [
                  Padding(
                      padding: const EdgeInsets.all(SogoSpacing.xxl),
                      child: Column(children: [
                        const Icon(Icons.person_search_rounded,
                            size: 44, color: SogoColors.textMuted),
                        const SizedBox(height: SogoSpacing.md),
                        Text('No providers in your area yet',
                            textAlign: TextAlign.center,
                            style: SogoText.bodyLg
                                .copyWith(color: SogoColors.textSecondary)),
                        const SizedBox(height: SogoSpacing.sm),
                        Text(
                            widget.allowAutoMatch
                                ? 'Use Auto match to be matched as soon as a provider comes online.'
                                : 'Try again later - providers in your area will appear here.',
                            textAlign: TextAlign.center,
                            style: SogoText.bodySm
                                .copyWith(color: SogoColors.textMuted)),
                      ])),
                ]);
              }
              return ListView.separated(
                padding: const EdgeInsets.all(SogoSpacing.lg),
                itemCount: providers.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: SogoSpacing.sm),
                itemBuilder: (context, i) {
                  final p = providers[i] as Map<String, dynamic>;
                  final online = p['is_online'] == true;
                  final distance = p['distance_km'];
                  return SogoCard(
                    onTap: _creating == null
                        ? () => _pick((p['id'] as num).toInt())
                        : null,
                    child: Row(children: [
                      Stack(children: [
                        CircleAvatar(
                            radius: 22,
                            backgroundColor: SogoColors.primaryLight,
                            backgroundImage: p['logo_url'] != null
                                ? NetworkImage('${p['logo_url']}')
                                : null,
                            child: p['logo_url'] == null
                                ? const Icon(Icons.build_circle_outlined,
                                    color: SogoColors.primary)
                                : null),
                        Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                    color: online
                                        ? SogoColors.success
                                        : SogoColors.textMuted,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2)))),
                      ]),
                      const SizedBox(width: SogoSpacing.md),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('${p['business_name'] ?? 'Provider'}',
                                style: SogoText.bodyLg
                                    .copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Row(children: [
                              const Icon(Icons.star_rounded,
                                  size: 14, color: SogoColors.warning),
                              const SizedBox(width: 2),
                              Text('${p['rating_avg'] ?? 0}',
                                  style: SogoText.labelMd
                                      .copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(width: 8),
                              Text('${p['total_completed'] ?? 0} jobs',
                                  style: SogoText.labelMd.copyWith(
                                      color: SogoColors.textSecondary)),
                              if (distance != null) ...[
                                const SizedBox(width: 8),
                                Text('$distance km',
                                    style: SogoText.labelMd.copyWith(
                                        color: SogoColors.textSecondary)),
                              ],
                            ]),
                          ])),
                      Text(online ? 'ONLINE' : 'OFFLINE',
                          style: SogoText.labelMd.copyWith(
                              color: online
                                  ? SogoColors.success
                                  : SogoColors.textMuted,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(width: 4),
                      _creating == (p['id'] as num).toInt()
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.add_circle_outline_rounded,
                              color: SogoColors.primary),
                    ]),
                  );
                },
              );
            },
          ),
        ),
        if (widget.skipLabel != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                SogoSpacing.lg, 0, SogoSpacing.lg, SogoSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await widget.onCreate();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: SogoColors.primary,
                  side: const BorderSide(color: SogoColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: SogoSpacing.md),
                ),
                child: Text(widget.skipLabel!),
              ),
            ),
          ),
      ]),
    );
  }
}
