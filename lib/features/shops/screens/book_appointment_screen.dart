import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/sogo_widgets.dart';
import '../../requests/screens/my_requests_screen.dart';

/// Simple appointment booking from a provider's profile.
/// Captures only: which service (dropdown), appointment date/time,
/// and the reason - then notifies the provider.
class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({super.key, required this.provider});

  final Map<String, dynamic> provider;

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  int? _selectedCategoryId;
  DateTime? _dateTime;
  bool _loading = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _services {
    final list = (widget.provider['services'] as List?) ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .where((s) => s['is_active'] != false)
        .toList();
  }

  String _serviceLabel(Map<String, dynamic> s) {
    final cat = s['category'] as Map<String, dynamic>?;
    final name = '${cat?['name'] ?? s['name'] ?? 'Service'}';
    final price = num.tryParse('${s['price'] ?? ''}');
    if (price != null && price > 0) {
      return '$name - ${ugx(price)}';
    }
    return name;
  }

  String _dateLabel() {
    final s = _dateTime;
    if (s == null) return 'Pick date & time *';
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

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context,
        initialDate: _dateTime ?? now.add(const Duration(days: 1)),
        firstDate: now,
        lastDate: now.add(const Duration(days: 60)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
            _dateTime ?? now.add(const Duration(hours: 2))));
    if (time == null || !mounted) return;
    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (picked.isBefore(now.add(const Duration(minutes: 30)))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pick a time at least 30 minutes from now')));
      return;
    }
    setState(() => _dateTime = picked);
  }

  /// Appointment happens at the shop: prefer the provider's coordinates,
  /// else take one quick GPS fix of the customer.
  Future<(double, double, String)> _pickup() async {
    final plat = (widget.provider['current_lat'] as num?)?.toDouble();
    final plng = (widget.provider['current_lng'] as num?)?.toDouble();
    final paddr = [
      '${widget.provider['address'] ?? ''}',
      '${widget.provider['city'] ?? ''}',
    ].where((s) => s.isNotEmpty).join(', ');
    if (plat != null && plng != null) {
      return (
        plat,
        plng,
        paddr.isNotEmpty
            ? paddr
            : '${widget.provider['business_name'] ?? 'Shop'}'
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is required');
    }
    final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 15))
        .timeout(const Duration(seconds: 20));
    if (pos.latitude == 0 && pos.longitude == 0) {
      throw Exception('GPS has no fix yet. Step outside and retry.');
    }
    return (
      pos.latitude,
      pos.longitude,
      paddr.isNotEmpty ? paddr : 'My location'
    );
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select which service you need')));
      return;
    }
    if (_dateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pick the appointment date & time first')));
      return;
    }
    setState(() => _loading = true);
    try {
      final loc = await _pickup();
      final providerId = (widget.provider['id'] as num).toInt();
      await customerApi.createRequest({
        'service_category_id': _selectedCategoryId,
        'description': _reason.text.trim(),
        'pickup_lat': loc.$1,
        'pickup_lng': loc.$2,
        'pickup_address': loc.$3,
        'scheduled_at': _dateTime!.toUtc().toIso8601String(),
        'provider_id': providerId,
        'auto_match': false,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Appointment sent to ${widget.provider['business_name'] ?? 'the shop'}. They will confirm shortly.'),
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
    final services = _services;
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(
        title:
            Text('Appointment - ${widget.provider['business_name'] ?? 'Shop'}'),
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
                      const SogoSectionTitle('Which service?'),
                      const SizedBox(height: SogoSpacing.md),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedCategoryId,
                        isExpanded: true,
                        items: services
                            .map((s) => DropdownMenuItem<int>(
                                value: ((s['category']
                                            as Map<String, dynamic>?)?['id'] ??
                                        s['service_category_id'] as num?)
                                    ?.toInt(),
                                child: Text(_serviceLabel(s),
                                    overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: services.isEmpty
                            ? null
                            : (v) => setState(() => _selectedCategoryId = v),
                        decoration: InputDecoration(
                          labelText: 'Select service *',
                          prefixIcon: const Icon(Icons.build_circle_outlined),
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(SogoRadius.md)),
                        ),
                        validator: (v) => v == null ? 'Choose a service' : null,
                      ),
                      const SizedBox(height: SogoSpacing.xl),
                      const SogoSectionTitle('When?'),
                      const SizedBox(height: SogoSpacing.md),
                      SogoCard(
                        onTap: _pickDateTime,
                        child: Row(children: [
                          const Icon(Icons.event_rounded,
                              color: SogoColors.primary),
                          const SizedBox(width: SogoSpacing.md),
                          Expanded(
                              child: Text(
                                  _dateTime == null
                                      ? 'Pick date & time *'
                                      : _dateLabel(),
                                  style: SogoText.bodyLg.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: _dateTime == null
                                          ? SogoColors.textSecondary
                                          : SogoColors.textPrimary))),
                          const Icon(Icons.chevron_right_rounded,
                              color: SogoColors.textMuted),
                        ]),
                      ),
                      const SizedBox(height: SogoSpacing.xl),
                      const SogoSectionTitle('Reason'),
                      const SizedBox(height: SogoSpacing.md),
                      SogoTextField(
                        label: 'Why do you need this service? *',
                        hint: 'e.g. brake pads worn out, grinding noise',
                        controller: _reason,
                        maxLines: 4,
                        validator: (v) => v == null || v.trim().length < 5
                            ? 'Tell the shop briefly why you are coming'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                color: SogoColors.surface,
                padding: const EdgeInsets.all(SogoSpacing.lg),
                child: SafeArea(
                  top: false,
                  child: SogoButton(
                      label: 'Send appointment',
                      icon: Icons.send_rounded,
                      onPressed: _loading ? null : _submit,
                      loading: _loading),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
