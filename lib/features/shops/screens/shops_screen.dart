import 'package:flutter/material.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';
import 'provider_detail_screen.dart';
import '../widgets/cart_icon_button.dart';

class ShopsScreen extends StatefulWidget {
  const ShopsScreen({super.key});

  @override
  State<ShopsScreen> createState() => _ShopsScreenState();
}

class _ShopsScreenState extends State<ShopsScreen> {
  final _search = TextEditingController();
  int? _serviceCategoryId;
  List<Map<String, dynamic>> _serviceCategories = [];
  int _page = 1;
  int _lastPage = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  final _items = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _reload();
  }

  Future<void> _loadFilters() async {
    try {
      final cats = await serviceApi.categories();
      if (!mounted) return;
      setState(() {
        _serviceCategories = cats.cast<Map<String, dynamic>>();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _items.clear();
    });
    try {
      final res = await shopApi.shops(
          q: _search.text.trim(),
          serviceCategoryId: _serviceCategoryId,
          page: 1);
      final meta = res['meta'] as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() {
        _lastPage = ((meta['last_page'] ?? 1) as num).toInt();
        _items.addAll(
            ((res['data'] as List?) ?? []).cast<Map<String, dynamic>>());
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: SogoSpacing.sm),
      child: ChoiceChip(
          label: Text(label),
          selected: selected,
          selectedColor: SogoColors.primary,
          labelStyle: SogoText.bodySm.copyWith(
              color: selected ? Colors.white : SogoColors.textSecondary,
              fontWeight: FontWeight.w700),
          onSelected: (_) => onTap()),
    );
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _lastPage) return;
    setState(() => _loadingMore = true);
    try {
      final res = await shopApi.shops(
          q: _search.text.trim(),
          serviceCategoryId: _serviceCategoryId,
          page: _page + 1);
      if (!mounted) return;
      setState(() {
        _page++;
        _items.addAll(
            ((res['data'] as List?) ?? []).cast<Map<String, dynamic>>());
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(
        title: const Text('Providers'),
        actions: const [CartIconButton(), SizedBox(width: 4)],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              SogoSpacing.lg, SogoSpacing.lg, SogoSpacing.lg, 0),
          child: SogoTextField(
            label: '',
            hint: 'Search providers, services, areasâ€¦',
            controller: _search,
            prefixIcon: Icons.search_rounded,
            onChanged: (_) => _reload(),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: SogoSpacing.lg),
            children: [
              _filterChip('All', _serviceCategoryId == null, () {
                setState(() => _serviceCategoryId = null);
                _reload();
              }),
              ..._serviceCategories.map((c) => _filterChip('${c['name']}',
                      _serviceCategoryId == (c['id'] as num?)?.toInt(), () {
                    setState(
                        () => _serviceCategoryId = (c['id'] as num?)?.toInt());
                    _reload();
                  })),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _reload(),
            child: Builder(builder: (context) {
              if (_loading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (_error != null) {
                return ListView(children: [
                  Padding(
                      padding: const EdgeInsets.all(SogoSpacing.xl),
                      child: Text('Could not load providers: $_error',
                          style: SogoText.bodyMd
                              .copyWith(color: SogoColors.danger))),
                ]);
              }
              if (_items.isEmpty) {
                return ListView(children: [
                  Padding(
                      padding: const EdgeInsets.all(SogoSpacing.xxl),
                      child: Column(children: [
                        const Icon(Icons.storefront_outlined,
                            size: 48, color: SogoColors.textMuted),
                        const SizedBox(height: SogoSpacing.md),
                        Text('No providers found',
                            style: SogoText.bodyLg
                                .copyWith(color: SogoColors.textSecondary)),
                        const SizedBox(height: SogoSpacing.sm),
                        Text('Try another name, area or category.',
                            style: SogoText.bodySm
                                .copyWith(color: SogoColors.textMuted)),
                      ])),
                ]);
              }
              return ListView.separated(
                padding: const EdgeInsets.all(SogoSpacing.lg),
                itemCount: _items.length + (_page < _lastPage ? 1 : 0),
                separatorBuilder: (_, __) =>
                    const SizedBox(height: SogoSpacing.md),
                itemBuilder: (context, i) {
                  if (i >= _items.length) {
                    _loadMore();
                    return const Center(
                        child: Padding(
                            padding: EdgeInsets.all(SogoSpacing.md),
                            child: CircularProgressIndicator()));
                  }
                  final s = _items[i];
                  final online = s['is_online'] == true;
                  return SogoCard(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProviderDetailScreen(
                            providerId: (s['id'] as num).toInt()))),
                    child: Row(children: [
                      CircleAvatar(
                          radius: 24,
                          backgroundColor: SogoColors.primaryLight,
                          backgroundImage: s['logo_url'] != null
                              ? NetworkImage('${s['logo_url']}')
                              : null,
                          child: s['logo_url'] == null
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
                                  child: Text('${s['business_name'] ?? 'Shop'}',
                                      style: SogoText.bodyLg.copyWith(
                                          fontWeight: FontWeight.w700),
                                      overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 6),
                              Container(
                                  width: 9,
                                  height: 9,
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
                              Text('${s['rating_avg'] ?? 0}',
                                  style: SogoText.labelMd
                                      .copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                    '${s['city'] ?? ''} Â· ${s['provider_type'] ?? ''}',
                                    overflow: TextOverflow.ellipsis,
                                    style: SogoText.labelMd.copyWith(
                                        color: SogoColors.textSecondary)),
                              ),
                            ]),
                          ])),
                      const Icon(Icons.chevron_right_rounded,
                          color: SogoColors.textMuted),
                    ]),
                  );
                },
              );
            }),
          ),
        ),
      ]),
    );
  }
}
