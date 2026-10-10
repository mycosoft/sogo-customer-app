import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/service_icons.dart';
import '../../../core/widgets/sogo_widgets.dart';
import '../../requests/screens/my_requests_screen.dart';
import '../../booking/widgets/provider_picker_sheet.dart';

/// Appointment = a booking for a chosen future date/time.
/// No instant auto-match: the provider is picked from the list (or later),
/// and matching/escalation only kick in near the scheduled time.
class AppointmentScreen extends StatefulWidget {
  const AppointmentScreen(
      {super.key, this.initialProviderId, this.initialProviderName});

  /// When booking straight from a shop profile, this provider is
  /// pre-selected (the picker is skipped).
  final int? initialProviderId;
  final String? initialProviderName;

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  final _form = GlobalKey<FormState>();
  final _pickup = TextEditingController();
  final _description = TextEditingController();
  final _categories = <Map<String, dynamic>>[];
  final _vehicles = <Map<String, dynamic>>[];
  int? _selectedCategoryId;
  int? _selectedVehicleId;
  double? _lat;
  double? _lng;
  String? _placeName;
  DateTime? _scheduledAt;
  bool _locating = false;
  bool _loading = false;
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pickup.dispose();
    _description.dispose();
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
      await _captureGps();
    } catch (e) {
      if (!mounted) return;
      setState(() => _booting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _captureGps() async {
    setState(() => _locating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw Exception('Location services are disabled');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required');
      }
      Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
                timeLimit: const Duration(seconds: 15))
            .timeout(const Duration(seconds: 20));
      } on TimeoutException {
        final last = await Geolocator.getLastKnownPosition();
        if (last == null) rethrow;
        pos = last;
      }
      if (pos.latitude == 0 && pos.longitude == 0) {
        throw Exception('GPS has no fix yet. Step outside and retry.');
      }
      _lat = pos.latitude;
      _lng = pos.longitude;

      String? label;
      try {
        final res = await apiClient
            .get('/locations/reverse', query: {'lat': _lat, 'lng': _lng});
        final data = res['data'] as Map<String, dynamic>? ?? {};
        label = '${data['full_address'] ?? data['short'] ?? ''}';
        if (label.isEmpty) label = null;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _placeName = label;
        if (label != null) _pickup.text = label;
        _locating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _locating = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  String _scheduleLabel() {
    final s = _scheduledAt;
    if (s == null) return 'Pick date & time';
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
    final hh = s.hour.toString().padLeft(2, '0');
    final mm = s.minute.toString().padLeft(2, '0');
    return '${days[s.weekday - 1]} ${s.day} ${months[s.month - 1]} at $hh:$mm';
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context,
        initialDate: _scheduledAt ?? now.add(const Duration(days: 1)),
        firstDate: now,
        lastDate: now.add(const Duration(days: 60)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
            _scheduledAt ?? now.add(const Duration(hours: 2))));
    if (time == null || !mounted) return;
    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (picked.isBefore(now.add(const Duration(minutes: 30)))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pick a time at least 30 minutes from now')));
      return;
    }
    setState(() => _scheduledAt = picked);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_selectedCategoryId == null ||
        _selectedVehicleId == null ||
        _lat == null ||
        _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Set your location so providers know where to come')));
      return;
    }
    if (_scheduledAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pick the appointment date & time first')));
      return;
    }
    // Booked straight from a shop profile — provider pre-selected.
    if (widget.initialProviderId != null) {
      await _createAppointment(providerId: widget.initialProviderId);
      return;
    }
    // Provider list without auto-match (matching happens near the time).
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
          allowAutoMatch: false,
          skipLabel: 'Save appointment (choose provider later)',
          onCreate: _createAppointment),
    );
  }

  Future<void> _createAppointment(
      {int? providerId, bool autoMatch = false}) async {
    setState(() => _loading = true);
    try {
      await customerApi.createRequest({
        'service_category_id': _selectedCategoryId,
        'vehicle_id': _selectedVehicleId,
        'description': _description.text.trim(),
        'pickup_lat': _lat,
        'pickup_lng': _lng,
        'pickup_address': _pickup.text.trim(),
        'scheduled_at': _scheduledAt!.toUtc().toIso8601String(),
        if (providerId != null) 'provider_id': providerId,
        'auto_match': false,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Appointment saved for ${_scheduleLabel()} — providers can see your time.'),
          backgroundColor: SogoColors.success,
          duration: const Duration(seconds: 4)));
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

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(
        title: const Text('Schedule appointment'),
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
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: SogoSpacing.sm,
                        crossAxisSpacing: SogoSpacing.sm,
                        childAspectRatio: 0.95,
                        children: _categories.map((c) {
                          final selected = _selectedCategoryId == c['id'];
                          final icon = serviceIconFor(
                              '${c['slug'] ?? ''}', '${c['name'] ?? ''}');
                          final iconColor = serviceColorFor(
                              '${c['slug'] ?? ''}', '${c['name'] ?? ''}');
                          return GestureDetector(
                            onTap: () => setState(
                                () => _selectedCategoryId = c['id'] as int),
                            child: Container(
                              decoration: BoxDecoration(
                                color: selected
                                    ? SogoColors.primaryLight
                                    : SogoColors.surface,
                                borderRadius:
                                    BorderRadius.circular(SogoRadius.md),
                                border: Border.all(
                                    color: selected
                                        ? SogoColors.primary
                                        : SogoColors.surfaceBorder,
                                    width: selected ? 2 : 1),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: iconColor.withOpacity(0.14),
                                      shape: BoxShape.circle,
                                    ),
                                    child:
                                        Icon(icon, color: iconColor, size: 20),
                                  ),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: Text('${c['name']}',
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: SogoText.labelMd.copyWith(
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: SogoSpacing.xl),
                      const SogoSectionTitle('When?'),
                      const SizedBox(height: SogoSpacing.md),
                      SogoCard(
                        onTap: _pickSchedule,
                        child: Row(children: [
                          const Icon(Icons.event_rounded,
                              color: SogoColors.primary),
                          const SizedBox(width: SogoSpacing.md),
                          Expanded(
                              child: Text(
                                  _scheduledAt == null
                                      ? 'Pick date & time *'
                                      : _scheduleLabel(),
                                  style: SogoText.bodyLg.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: _scheduledAt == null
                                          ? SogoColors.textSecondary
                                          : SogoColors.textPrimary))),
                          const Icon(Icons.chevron_right_rounded,
                              color: SogoColors.textMuted),
                        ]),
                      ),
                      const SizedBox(height: SogoSpacing.xl),
                      const SogoSectionTitle('Your vehicle'),
                      const SizedBox(height: SogoSpacing.md),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedVehicleId,
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
                      const SogoSectionTitle('Where?'),
                      const SizedBox(height: SogoSpacing.md),
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
                        child: Row(children: [
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
                      ),
                      const SizedBox(height: SogoSpacing.md),
                      SogoTextField(
                        label: 'Pickup address',
                        hint: 'Where should we come?',
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
                            : 'Choose provider',
                        icon: Icons.event_rounded,
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
