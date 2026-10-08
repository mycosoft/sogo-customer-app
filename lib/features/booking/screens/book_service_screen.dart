import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/service_icons.dart';
import '../../../core/widgets/sogo_widgets.dart';
import '../../requests/screens/my_requests_screen.dart';
import '../widgets/provider_picker_sheet.dart';

class _PermissionBlocked implements Exception {
  const _PermissionBlocked();
}

/// Immediate booking: GPS + address, pick a service, then find providers
/// near you (list or online auto-match). For later dates use the
/// Appointment screen instead.
class BookServiceScreen extends StatefulWidget {
  const BookServiceScreen(
      {super.key, this.initialProviderId, this.initialProviderName});

  /// When booking straight from a shop profile, this provider is
  /// pre-selected (the picker is skipped).
  final int? initialProviderId;
  final String? initialProviderName;

  @override
  State<BookServiceScreen> createState() => _BookServiceScreenState();
}

class _BookServiceScreenState extends State<BookServiceScreen> {
  final _form = GlobalKey<FormState>();
  final _pickup = TextEditingController();
  final _description = TextEditingController();
  final _search = TextEditingController();
  final _categories = <Map<String, dynamic>>[];
  final _vehicles = <Map<String, dynamic>>[];
  int? _selectedCategoryId;
  int? _selectedVehicleId;
  double? _lat;
  double? _lng;
  String? _placeName;
  bool _locating = false;
  bool _loading = false;
  bool _booting = true;
  // Address autocomplete state.
  List<Map<String, dynamic>> _suggestions = [];
  bool _searching = false;
  bool _searchOpen = false;
  Timer? _searchDebounce;
  // Stream GPS state (converges on the real location).
  StreamSubscription<Position>? _posSub;
  double? _bestAccuracy;
  bool _refining = false;
  int _resolveToken = 0;
  double? _resolvedLat;
  double? _resolvedLng;
  // GPS failure state shown directly in the card (no silent failures).
  String? _gpsError;
  String? _gpsLookupDetail;
  bool _gpsPermissionBlocked = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _pickup.dispose();
    _description.dispose();
    _search.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final categories = await serviceApi.categories();
      final vehicles = await vehicleApi.list();
      if (!mounted) return;
      setState(() {
        _categories.addAll(categories.cast<Map<String, dynamic>>());
        _vehicles.addAll(vehicles.cast<Map<String, dynamic>>());
        _selectedCategoryId =
            _categories.isNotEmpty ? _categories.first['id'] as int : null;
        _selectedVehicleId =
            _vehicles.isNotEmpty ? _vehicles.first['id'] as int : null;
        _booting = false;
      });
      // Grab GPS + place name right away.
      await _captureGps();
    } catch (e) {
      if (!mounted) return;
      setState(() => _booting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _ensureLocationReady() async {
    var enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception('Location services are disabled - turn on GPS');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied - we cannot see your GPS');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const _PermissionBlocked();
    }
  }

  /// Stream-based capture: take the first valid fix immediately, then
  /// keep refining while the accuracy keeps improving.
  Future<void> _captureGps() async {
    // Tapping again while refining locks the current fix.
    if (_refining) {
      await _posSub?.cancel();
      _posSub = null;
      if (mounted) {
        setState(() {
          _refining = false;
          _locating = false;
        });
      }
      return;
    }

    setState(() {
      _locating = true;
      _refining = false;
      _gpsError = null;
      _gpsLookupDetail = null;
      _gpsPermissionBlocked = false;
      _bestAccuracy = null;
    });
    try {
      await _ensureLocationReady();

      await _posSub?.cancel();
      final done = Completer<void>();
      final watchdog = Timer(const Duration(seconds: 25), () {
        if (!done.isCompleted) done.complete();
      });

      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((p) {
        if (!mounted) return;
        if (p.latitude == 0 && p.longitude == 0) return; // no-fix sentinel
        var acc = p.accuracy;
        if (acc <= 0) acc = 5000; // unknown accuracy = poor
        final best = _bestAccuracy;
        final isFirst = best == null;
        if (isFirst || acc < best - 8) {
          _bestAccuracy = acc;
          _applyFix(p, refining: acc > 20);
          if (acc <= 20 && !done.isCompleted) done.complete();
        }
      }, onError: (Object e) {
        if (!done.isCompleted) done.completeError(e);
      });

      await done.future;
      watchdog.cancel();
      await _posSub?.cancel();
      _posSub = null;

      if (!mounted) return;
      if (_lat == null || _lng == null) {
        // Stream gave nothing - last known as a final fallback.
        final last = await Geolocator.getLastKnownPosition();
        if (last == null || (last.latitude == 0 && last.longitude == 0)) {
          throw Exception('Could not get a GPS fix - step outside and retry');
        }
        _applyFix(last, refining: false);
        await _resolveAddress();
      }
      setState(() {
        _locating = false;
        _refining = false;
      });
    } on _PermissionBlocked {
      await _posSub?.cancel();
      _posSub = null;
      if (!mounted) return;
      setState(() {
        _locating = false;
        _refining = false;
        _gpsError =
            'Location permission is blocked for this app. Grant it in Settings.';
        _gpsPermissionBlocked = true;
      });
    } catch (e) {
      await _posSub?.cancel();
      _posSub = null;
      if (!mounted) {
        return;
      }
      setState(() {
        _locating = false;
        _refining = false;
        _gpsError = '$e';
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _applyFix(Position p, {required bool refining}) {
    _lat = p.latitude;
    _lng = p.longitude;
    if (!mounted) return;
    setState(() {
      _locating = false;
      _refining = refining;
    });
    _resolveAddress();
  }

  /// Resolve the FULL human-readable address. Newer fixes invalidate
  /// older in-flight lookups. Throttled to moves over 150m.
  Future<void> _resolveAddress() async {
    final token = ++_resolveToken;

    if (_placeName != null &&
        _lat != null &&
        _lng != null &&
        _resolvedLat != null &&
        _resolvedLng != null &&
        _movedKm(_resolvedLat!, _resolvedLng!, _lat!, _lng!) < 0.15) {
      return; // barely moved - keep the current label
    }

    try {
      final res = await apiClient
          .get('/locations/reverse', query: {'lat': _lat, 'lng': _lng});
      if (!mounted || token != _resolveToken) return;
      final data = res['data'] as Map<String, dynamic>? ?? {};

      var full = _str(data['full_address']);
      var short = _str(data['short']);

      if (full == null || short == null) {
        final parts = <String?>[
          data['road'],
          data['suburb'],
          data['city'],
          data['district'],
          data['region'],
          data['country'],
        ].map(_str).whereType<String>().where((s) => s.isNotEmpty).toList();
        final composed = parts.join(', ');
        final display = _str(data['display_name']);
        short ??= parts.isNotEmpty ? parts.take(3).join(', ') : display;
        full ??= display ?? (composed.isEmpty ? null : composed);
      }

      setState(() {
        if (short != null && short.isNotEmpty) {
          _placeName = short;
          _pickup.text = (full != null && full.isNotEmpty) ? full : short;
          _resolvedLat = _lat;
          _resolvedLng = _lng;
          _gpsError = null;
          _gpsLookupDetail = null;
        } else {
          _gpsLookupDetail =
              'server returned no place name for ${_lat?.toStringAsFixed(4)}, ${_lng?.toStringAsFixed(4)}';
          _gpsError =
              'GPS set - address lookup failed. Search or type the address below.';
        }
      });
    } catch (e) {
      debugPrint('[GPS] reverse lookup failed at $_lat,$_lng: $e');
      if (!mounted || token != _resolveToken) return;
      setState(() {
        _gpsLookupDetail =
            'at ${_lat?.toStringAsFixed(5)}, ${_lng?.toStringAsFixed(5)} -> $e';
        _gpsError =
            'GPS set - address lookup failed. Search or type the address below.';
      });
    }
  }

  String? _str(Object? v) {
    final s = '$v';
    return (s.isEmpty || s == 'null') ? null : s;
  }

  double _movedKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    const rad = 3.141592653589793 / 180;
    final dLat = (lat2 - lat1) * rad;
    final dLng = (lng2 - lng1) * rad;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * rad) * cos(lat2 * rad) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * asin(min(1, sqrt(a)));
  }

  // -- Address search (type + pick) --
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final q = value.trim();
    if (q.length < 3) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _searchOpen = false;
          _searching = false;
        });
      }
      return;
    }
    setState(() {
      _searchOpen = true;
      _searching = true;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final res =
            await apiClient.get('/locations/autocomplete', query: {'q': q});
        final data = res['data'] as List? ?? [];
        if (!mounted) return;
        setState(() {
          _suggestions = data.cast<Map<String, dynamic>>();
          _searching = false;
        });
      } catch (_) {
        if (mounted) {
          setState(() {
            _suggestions = [];
            _searching = false;
          });
        }
      }
    });
  }

  void _pickSuggestion(Map<String, dynamic> s) {
    final lat = (s['lat'] as num?)?.toDouble();
    final lng = (s['lng'] as num?)?.toDouble();
    final address = _str(s['full_address']);
    final short = _str(s['short']) ?? address;
    setState(() {
      if (lat != null && lng != null) {
        _lat = lat;
        _lng = lng;
      }
      _placeName = short;
      if (address != null) _pickup.text = address;
      _search.text = short ?? '';
      _searchOpen = false;
      _suggestions = [];
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_selectedCategoryId == null ||
        _selectedVehicleId == null ||
        _lat == null ||
        _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tap "Use my location" so we know where to come')));
      return;
    }
    // Booked straight from a shop profile - provider pre-selected.
    if (widget.initialProviderId != null) {
      await _createRequest(providerId: widget.initialProviderId);
      return;
    }
    // Don't create yet - first show the providers available near the
    // pickup location. The picker creates the request.
    _openProviderPicker();
  }

  Future<void> _createRequest({int? providerId, bool autoMatch = false}) async {
    setState(() => _loading = true);
    try {
      final res = await customerApi.createRequest({
        'service_category_id': _selectedCategoryId,
        'vehicle_id': _selectedVehicleId,
        'description': _description.text.trim(),
        'pickup_lat': _lat,
        'pickup_lng': _lng,
        'pickup_address': _pickup.text.trim(),
        if (providerId != null) 'provider_id': providerId,
        'auto_match': autoMatch,
      });
      final created = res['data'] as Map<String, dynamic>? ?? {};
      final requestId = created['id'] as int?;

      // Strict online auto-match runs right after the deferred creation.
      if (providerId == null && autoMatch && requestId != null) {
        try {
          await customerApi.autoMatch(requestId);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    '$e\nPick a provider from the list instead - your request is saved.'),
                duration: const Duration(seconds: 6)));
          }
        }
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Opens the provider picker: available providers near the pickup
  /// location (online first), an Auto-match action, or skip.
  Future<void> _openProviderPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(SogoRadius.lg))),
      builder: (_) => ProviderPickerSheet(
          categoryId: _selectedCategoryId!,
          lat: _lat!,
          lng: _lng!,
          onCreate: _createRequest),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(
        title: const Text('Book a service'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(SogoSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SogoSectionTitle('What do you need?'),
                      const SizedBox(height: SogoSpacing.md),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: SogoSpacing.md,
                        crossAxisSpacing: SogoSpacing.md,
                        childAspectRatio: 1.05,
                        children: _categories.map((c) {
                          final selected = _selectedCategoryId == c['id'];
                          final price =
                              num.tryParse('${c['base_price'] ?? ''}');
                          final icon = serviceIconFor(
                              '${c['slug'] ?? ''}', '${c['name'] ?? ''}');
                          final iconColor = serviceColorFor(
                              '${c['slug'] ?? ''}', '${c['name'] ?? ''}');
                          return GestureDetector(
                            onTap: () => setState(
                                () => _selectedCategoryId = c['id'] as int),
                            child: SogoCard(
                              color: selected
                                  ? SogoColors.primaryLight
                                  : SogoColors.surface,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: iconColor.withOpacity(0.14),
                                      shape: BoxShape.circle,
                                    ),
                                    child:
                                        Icon(icon, color: iconColor, size: 24),
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                    child: Text('${c['name']}',
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: SogoText.bodyMd.copyWith(
                                            fontWeight: FontWeight.w700)),
                                  ),
                                  if (price != null && price > 0)
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        child: Text(
                                            'from UGX ${price.toStringAsFixed(0)}',
                                            style: SogoText.labelMd.copyWith(
                                                color:
                                                    SogoColors.textSecondary)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: SogoSpacing.xl),
                      const SogoSectionTitle('Your vehicle'),
                      const SizedBox(height: SogoSpacing.md),
                      DropdownButtonFormField<int>(
                        value: _selectedVehicleId,
                        items: _vehicles
                            .map((v) => DropdownMenuItem<int>(
                                value: v['id'] as int,
                                child: Text(
                                    '${v['plate_number']} - ${v['make'] ?? ''} ${v['model'] ?? ''}')))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedVehicleId = v),
                        decoration: InputDecoration(
                          labelText: 'Select vehicle',
                          prefixIcon: const Icon(Icons.directions_car_outlined),
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(SogoRadius.md)),
                        ),
                      ),
                      const SizedBox(height: SogoSpacing.xl),
                      const SogoSectionTitle('Where are you?'),
                      const SizedBox(height: SogoSpacing.md),

                      // GPS capture card - full address, no coordinates.
                      Container(
                        padding: const EdgeInsets.all(SogoSpacing.md),
                        decoration: BoxDecoration(
                          color: _lat != null
                              ? SogoColors.primaryLight
                              : SogoColors.surface,
                          borderRadius: BorderRadius.circular(SogoRadius.md),
                          border: Border.all(
                              color: _lat != null
                                  ? SogoColors.primary.withOpacity(0.4)
                                  : SogoColors.surfaceBorder),
                        ),
                        child: Column(children: [
                          Row(children: [
                            Icon(
                                _locating
                                    ? Icons.location_searching_rounded
                                    : (_lat != null
                                        ? Icons.location_on_rounded
                                        : Icons.location_off_rounded),
                                color: _lat != null
                                    ? SogoColors.primary
                                    : SogoColors.textMuted,
                                size: 22),
                            const SizedBox(width: SogoSpacing.sm),
                            Expanded(
                              child: Text(
                                  _locating
                                      ? 'Finding your location…'
                                      : (_placeName ?? 'Location not set yet'),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: SogoText.bodyMd
                                      .copyWith(fontWeight: FontWeight.w600)),
                            ),
                            IconButton(
                                tooltip: 'Refresh GPS',
                                onPressed: _locating ? null : _captureGps,
                                icon: _locating
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Icon(Icons.gps_fixed_rounded,
                                        color: SogoColors.primary)),
                          ]),
                          if (_lat != null && !_locating)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: SogoSpacing.sm),
                              child: Row(children: [
                                Icon(
                                    _refining
                                        ? Icons.sync_rounded
                                        : Icons.verified_rounded,
                                    size: 14,
                                    color: _refining
                                        ? SogoColors.primary
                                        : SogoColors.success),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                      _refining
                                          ? 'Refining location… tap the GPS button to lock'
                                          : 'GPS location set',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: SogoText.labelMd.copyWith(
                                          color: _refining
                                              ? SogoColors.primary
                                              : SogoColors.success,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ]),
                            ),
                          // Visible failure reason (no silent failures).
                          if (_gpsError != null && !_locating)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: SogoSpacing.sm),
                              child: Row(children: [
                                const Icon(Icons.warning_amber_rounded,
                                    size: 14, color: SogoColors.danger),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(_gpsError!,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: SogoText.labelMd.copyWith(
                                                color: SogoColors.danger)),
                                        if (_gpsLookupDetail != null &&
                                            _gpsLookupDetail!.isNotEmpty)
                                          Text(_gpsLookupDetail!,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: SogoText.labelMd.copyWith(
                                                  color: SogoColors.textMuted)),
                                      ]),
                                ),
                                if (_gpsPermissionBlocked)
                                  TextButton(
                                    onPressed: () =>
                                        Geolocator.openAppSettings(),
                                    child: Text('Settings',
                                        style: SogoText.labelMd.copyWith(
                                            color: SogoColors.primary,
                                            fontWeight: FontWeight.w800)),
                                  )
                                else
                                  TextButton(
                                    onPressed: _captureGps,
                                    child: Text('Retry',
                                        style: SogoText.labelMd.copyWith(
                                            color: SogoColors.primary,
                                            fontWeight: FontWeight.w800)),
                                  ),
                              ]),
                            ),
                        ]),
                      ),
                      const SizedBox(height: SogoSpacing.md),

                      // Address search - type + pick.
                      SogoTextField(
                        label: 'Search address',
                        hint: 'Street, landmark, area…',
                        controller: _search,
                        prefixIcon: Icons.search_rounded,
                        onChanged: _onSearchChanged,
                      ),
                      if (_searchOpen) ...[
                        const SizedBox(height: SogoSpacing.sm),
                        Container(
                          decoration: BoxDecoration(
                            color: SogoColors.surface,
                            borderRadius: BorderRadius.circular(SogoRadius.md),
                            border: Border.all(color: SogoColors.surfaceBorder),
                          ),
                          child: _searching
                              ? const Padding(
                                  padding: EdgeInsets.all(SogoSpacing.md),
                                  child: Center(
                                      child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))),
                                )
                              : _suggestions.isEmpty
                                  ? Padding(
                                      padding:
                                          const EdgeInsets.all(SogoSpacing.md),
                                      child: Text(
                                          'No places found - try another name',
                                          style: SogoText.bodySm.copyWith(
                                              color: SogoColors.textSecondary)),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: _suggestions.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, i) {
                                        final s = _suggestions[i];
                                        return ListTile(
                                          dense: true,
                                          leading: const Icon(
                                              Icons.location_on_outlined,
                                              color: SogoColors.primary,
                                              size: 20),
                                          title: Text(
                                              '${s['short'] ?? s['display_name'] ?? ''}',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: SogoText.bodyMd),
                                          subtitle: s['full_address'] != null &&
                                                  s['full_address'] !=
                                                      s['short']
                                              ? Text('${s['full_address']}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: SogoText.labelMd
                                                      .copyWith(
                                                          color: SogoColors
                                                              .textSecondary))
                                              : null,
                                          onTap: () => _pickSuggestion(s),
                                        );
                                      },
                                    ),
                        ),
                      ],
                      const SizedBox(height: SogoSpacing.md),
                      SogoTextField(
                        label: 'Pickup address',
                        hint: 'Describe exactly where we should come',
                        controller: _pickup,
                        prefixIcon: Icons.location_on_outlined,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: SogoSpacing.lg),
                      const SogoSectionTitle('Describe the problem'),
                      const SizedBox(height: SogoSpacing.md),
                      SogoTextField(
                        label: 'What happened?',
                        hint: 'e.g. car wont start, smoke from engine',
                        controller: _description,
                        maxLines: 4,
                        validator: (v) => v == null || v.length < 10
                            ? 'Add a bit more detail'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                color: SogoColors.surface,
                padding: EdgeInsets.only(
                    left: SogoSpacing.lg,
                    right: SogoSpacing.lg,
                    top: SogoSpacing.lg,
                    bottom: MediaQuery.of(context).viewInsets.bottom > 0
                        ? SogoSpacing.sm
                        : SogoSpacing.lg),
                child: SafeArea(
                  top: false,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (widget.initialProviderId != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: SogoSpacing.sm),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: SogoSpacing.md,
                              vertical: SogoSpacing.sm),
                          decoration: BoxDecoration(
                            color: SogoColors.primaryLight,
                            borderRadius: BorderRadius.circular(SogoRadius.md),
                          ),
                          child: Text(
                              'Booking with ${widget.initialProviderName ?? 'this shop'}',
                              textAlign: TextAlign.center,
                              style: SogoText.bodySm.copyWith(
                                  color: SogoColors.primary,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    SogoButton(
                        label: widget.initialProviderId != null
                            ? 'Book this shop'
                            : 'Find providers near me',
                        onPressed: _submit,
                        loading: _loading),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
