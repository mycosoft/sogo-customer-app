import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  static const _types = [
    ('car', 'Car', Icons.directions_car_outlined),
    ('suv', 'SUV', Icons.directions_car_filled_outlined),
    ('pickup', 'Pickup', Icons.local_shipping_outlined),
    ('van', 'Van', Icons.airport_shuttle_outlined),
    ('motorcycle', 'Motorcycle', Icons.two_wheeler_outlined),
    ('truck', 'Truck', Icons.fire_truck_outlined),
  ];

  static const _fuels = ['petrol', 'diesel', 'hybrid', 'electric'];

  late Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final items = await vehicleApi.list();
    return List<Map<String, dynamic>>.from(items);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _confirmDelete(Map<String, dynamic> v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SogoRadius.lg)),
        title: const Text('Remove vehicle?'),
        content: Text(
            '${v['plate_number']} - ${v['make'] ?? ''} ${v['model'] ?? ''} will be removed from your account.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove',
                  style: TextStyle(color: SogoColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    await vehicleApi.delete(v['id'] as int);
    if (mounted) setState(() => _future = _load());
  }

  Future<void> _showForm({Map<String, dynamic>? vehicle}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(SogoRadius.lg))),
      builder: (_) =>
          _VehicleFormSheet(vehicle: vehicle, types: _types, fuels: _fuels),
    );
    if (saved != true) return;
    _refresh();
  }

  IconData _typeIcon(String? type) {
    for (final t in _types) {
      if (t.$1 == type) return t.$3;
    }
    return Icons.directions_car_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(title: const Text('My vehicles')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_vehicle',
        backgroundColor: SogoColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add vehicle'),
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
          final vehicles = snapshot.data!;
          if (vehicles.isEmpty) {
            return ListView(children: [
              Padding(
                padding: const EdgeInsets.only(
                    top: SogoSpacing.xxl,
                    left: SogoSpacing.xl,
                    right: SogoSpacing.xl),
                child: Column(children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                        color: SogoColors.primaryLight, shape: BoxShape.circle),
                    child: const Icon(Icons.directions_car_outlined,
                        size: 40, color: SogoColors.primary),
                  ),
                  const SizedBox(height: SogoSpacing.lg),
                  const Text('No vehicles yet', style: SogoText.headlineMd),
                  const SizedBox(height: SogoSpacing.sm),
                  Text(
                      'Add your vehicle so providers know exactly what they are working on.',
                      textAlign: TextAlign.center,
                      style: SogoText.bodyMd
                          .copyWith(color: SogoColors.textSecondary)),
                  const SizedBox(height: SogoSpacing.lg),
                  SogoButton(
                      label: 'Add your first vehicle',
                      icon: Icons.add_rounded,
                      fullWidth: false,
                      onPressed: () => _showForm()),
                ]),
              ),
            ]);
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(SogoSpacing.lg),
              itemCount: vehicles.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: SogoSpacing.md),
              itemBuilder: (context, i) {
                final v = vehicles[i];
                final isPrimary = v['is_primary'] == true;
                return SogoCard(
                  child: Column(children: [
                    Row(children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(SogoRadius.md),
                          child: '${v['photo'] ?? ''}'.isNotEmpty
                              ? Image.network('${v['photo']}',
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                      width: 52,
                                      height: 52,
                                      color: SogoColors.primaryLight,
                                      child: const Icon(
                                          Icons.directions_car_outlined,
                                          color: SogoColors.primary)))
                              : Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                      color: isPrimary
                                          ? SogoColors.primary.withOpacity(0.14)
                                          : SogoColors.primaryLight,
                                      borderRadius:
                                          BorderRadius.circular(SogoRadius.md)),
                                  child: Icon(
                                      _typeIcon('${v['vehicle_type'] ?? ''}'),
                                      color: SogoColors.primary,
                                      size: 26))),
                      const SizedBox(width: SogoSpacing.md),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Row(children: [
                              Flexible(
                                  child: Text(
                                      '${v['make'] ?? ''} ${v['model'] ?? ''}',
                                      style: SogoText.bodyLg.copyWith(
                                          fontWeight: FontWeight.w700),
                                      overflow: TextOverflow.ellipsis)),
                              if (isPrimary) ...[
                                const SizedBox(width: 6),
                                Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: SogoColors.primary,
                                        borderRadius: BorderRadius.circular(
                                            SogoRadius.pill)),
                                    child: Text('PRIMARY',
                                        style: SogoText.labelMd.copyWith(
                                            color: Colors.white, fontSize: 9))),
                              ],
                            ]),
                            const SizedBox(height: 2),
                            Text(
                                '${v['year'] ?? ''} - ${'${v['color'] ?? ''}'.isNotEmpty ? '${v['color']} - ' : ''}${'${v['fuel_type'] ?? ''}'.isNotEmpty ? '${v['fuel_type']} - ' : ''}${v['mileage'] != null && v['mileage'] != '' ? '${v['mileage']} km' : ''}',
                                style: SogoText.bodySm
                                    .copyWith(color: SogoColors.textSecondary)),
                          ])),
                      // Plate chip
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: SogoColors.surfaceMuted,
                              borderRadius:
                                  BorderRadius.circular(SogoRadius.sm),
                              border:
                                  Border.all(color: SogoColors.surfaceBorder)),
                          child: Text('${v['plate_number'] ?? ''}',
                              style: SogoText.labelMd
                                  .copyWith(fontWeight: FontWeight.w800))),
                    ]),
                    const SizedBox(height: SogoSpacing.md),
                    Row(children: [
                      Expanded(
                          child: OutlinedButton.icon(
                              onPressed: () => _showForm(vehicle: v),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Edit'),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: SogoColors.primary,
                                  side: const BorderSide(
                                      color: SogoColors.primary, width: 1.2)))),
                      const SizedBox(width: SogoSpacing.sm),
                      if (!isPrimary)
                        Expanded(
                            child: OutlinedButton.icon(
                                onPressed: () async {
                                  await vehicleApi.setPrimary(v['id'] as int);
                                  if (mounted) _refresh();
                                },
                                icon: const Icon(Icons.star_outline, size: 16),
                                label: const Text('Set primary'),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: SogoColors.warning,
                                    side: const BorderSide(
                                        color: SogoColors.warning,
                                        width: 1.2)))),
                      const SizedBox(width: SogoSpacing.sm),
                      Expanded(
                          child: OutlinedButton.icon(
                              onPressed: () => _confirmDelete(v),
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: const Text('Remove'),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: SogoColors.danger,
                                  side: const BorderSide(
                                      color: SogoColors.danger, width: 1.2)))),
                    ]),
                  ]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _VehicleFormSheet extends StatefulWidget {
  const _VehicleFormSheet(
      {required this.vehicle, required this.types, required this.fuels});

  final Map<String, dynamic>? vehicle;
  final List<(String, String, IconData)> types;
  final List<String> fuels;

  @override
  State<_VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends State<_VehicleFormSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _plate =
      TextEditingController(text: '${widget.vehicle?['plate_number'] ?? ''}');
  late final TextEditingController _make =
      TextEditingController(text: '${widget.vehicle?['make'] ?? ''}');
  late final TextEditingController _model =
      TextEditingController(text: '${widget.vehicle?['model'] ?? ''}');
  late final TextEditingController _year =
      TextEditingController(text: '${widget.vehicle?['year'] ?? ''}');
  late final TextEditingController _color =
      TextEditingController(text: '${widget.vehicle?['color'] ?? ''}');
  late final TextEditingController _vin =
      TextEditingController(text: '${widget.vehicle?['vin'] ?? ''}');
  late final TextEditingController _mileage =
      TextEditingController(text: '${widget.vehicle?['mileage'] ?? ''}');
  late String? _type = widget.vehicle?['vehicle_type'] == null ||
          '${widget.vehicle?['vehicle_type']}'.isEmpty
      ? 'car'
      : '${widget.vehicle?['vehicle_type']}';
  late String? _fuel = widget.vehicle?['fuel_type'] == null ||
          '${widget.vehicle?['fuel_type']}'.isEmpty
      ? null
      : '${widget.vehicle?['fuel_type']}';
  String? _existingPhoto;
  String? _newPhotoPath;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final photo = widget.vehicle?['photo'];
    _existingPhoto = (photo == null || '$photo'.isEmpty) ? null : '$photo';
  }

  @override
  void dispose() {
    _plate.dispose();
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _color.dispose();
    _vin.dispose();
    _mileage.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1600, imageQuality: 82);
    if (x == null) return;
    setState(() {
      _newPhotoPath = x.path;
      _existingPhoto = null;
    });
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
        source: ImageSource.camera, maxWidth: 1600, imageQuality: 82);
    if (x == null) return;
    setState(() {
      _newPhotoPath = x.path;
      _existingPhoto = null;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final payload = {
      'plate_number': _plate.text.trim(),
      'make': _make.text.trim(),
      'model': _model.text.trim(),
      'year': int.tryParse(_year.text.trim()),
      'color': _color.text.trim(),
      'vehicle_type': _type,
      'fuel_type': _fuel,
      'vin': _vin.text.trim(),
      'mileage': int.tryParse(_mileage.text.trim()),
    };
    try {
      await vehicleApi.save(payload,
          photoPath: _newPhotoPath, id: widget.vehicle?['id'] as int?);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _saving = false);
      }
    }
  }

  Widget _photoPicker() {
    final showNew = _newPhotoPath != null;
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        height: 130,
        width: double.infinity,
        decoration: BoxDecoration(
          color: SogoColors.surfaceMuted,
          borderRadius: BorderRadius.circular(SogoRadius.md),
          border: Border.all(color: SogoColors.surfaceBorder),
        ),
        child: showNew
            ? ClipRRect(
                borderRadius: BorderRadius.circular(SogoRadius.md),
                child: Stack(fit: StackFit.expand, children: [
                  Image.file(File(_newPhotoPath!), fit: BoxFit.cover),
                  const Positioned(
                      right: 6,
                      top: 6,
                      child: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.close_rounded,
                              size: 16, color: SogoColors.danger)))
                ]),
              )
            : _existingPhoto != null && _existingPhoto!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(SogoRadius.md),
                    child: Stack(fit: StackFit.expand, children: [
                      Image.network(_existingPhoto!, fit: BoxFit.cover),
                      const Positioned(
                          right: 6,
                          top: 6,
                          child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.edit_rounded,
                                  size: 16, color: SogoColors.primary))),
                    ]),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_photo_alternate_outlined,
                          color: SogoColors.textMuted),
                      const SizedBox(height: 6),
                      Text('Add vehicle photo',
                          style: SogoText.bodySm
                              .copyWith(color: SogoColors.textSecondary)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _takePhoto,
                        child: Text('or take a photo',
                            style: SogoText.labelMd.copyWith(
                                color: SogoColors.primary,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: SogoSpacing.xl,
          right: SogoSpacing.xl,
          top: SogoSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + SogoSpacing.lg),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                  child: Text(
                      widget.vehicle == null ? 'Add vehicle' : 'Edit vehicle',
                      style: SogoText.headlineMd)),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: SogoSpacing.md),
            _photoPicker(),
            const SizedBox(height: SogoSpacing.md),
            SogoTextField(
                label: 'Plate number',
                hint: 'e.g. UAB 123A',
                controller: _plate,
                prefixIcon: Icons.pin_outlined,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: SogoSpacing.md),
            Row(children: [
              Expanded(
                  child: SogoTextField(
                      label: 'Make',
                      hint: 'Toyota',
                      controller: _make,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null)),
              const SizedBox(width: SogoSpacing.md),
              Expanded(
                  child: SogoTextField(
                      label: 'Model',
                      hint: 'Corolla',
                      controller: _model,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null)),
            ]),
            const SizedBox(height: SogoSpacing.md),
            Row(children: [
              Expanded(
                  child: SogoTextField(
                      label: 'Year',
                      hint: '2015',
                      controller: _year,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final y = int.tryParse(v ?? '');
                        if (y == null ||
                            y < 1950 ||
                            y > DateTime.now().year + 1) {
                          return 'Invalid year';
                        }
                        return null;
                      })),
              const SizedBox(width: SogoSpacing.md),
              Expanded(
                  child: SogoTextField(
                      label: 'Color', hint: 'Silver', controller: _color)),
            ]),
            const SizedBox(height: SogoSpacing.md),
            // Vehicle type picker
            SizedBox(
              height: 86,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: widget.types
                    .map((t) => Padding(
                          padding: const EdgeInsets.only(right: SogoSpacing.sm),
                          child: GestureDetector(
                            onTap: () => setState(() => _type = t.$1),
                            child: Container(
                                width: 76,
                                decoration: BoxDecoration(
                                    color: _type == t.$1
                                        ? SogoColors.primaryLight
                                        : SogoColors.surfaceMuted,
                                    borderRadius:
                                        BorderRadius.circular(SogoRadius.md),
                                    border: Border.all(
                                        color: _type == t.$1
                                            ? SogoColors.primary
                                            : SogoColors.surfaceBorder,
                                        width: _type == t.$1 ? 2 : 1)),
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(t.$3,
                                          size: 26,
                                          color: _type == t.$1
                                              ? SogoColors.primary
                                              : SogoColors.textSecondary),
                                      const SizedBox(height: 4),
                                      Text(t.$2,
                                          style: SogoText.labelMd.copyWith(
                                              color: _type == t.$1
                                                  ? SogoColors.primary
                                                  : SogoColors.textSecondary)),
                                    ])),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: SogoSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _fuel,
              decoration: InputDecoration(
                  labelText: 'Fuel type',
                  prefixIcon: const Icon(Icons.local_gas_station_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SogoRadius.md))),
              items: widget.fuels
                  .map((f) => DropdownMenuItem(
                      value: f,
                      child: Text(f[0].toUpperCase() + f.substring(1))))
                  .toList(),
              onChanged: (v) => setState(() => _fuel = v),
            ),
            const SizedBox(height: SogoSpacing.md),
            Row(children: [
              Expanded(
                  child: SogoTextField(
                      label: 'VIN / Chassis (optional)',
                      hint: '17 characters',
                      controller: _vin)),
              const SizedBox(width: SogoSpacing.md),
              Expanded(
                  child: SogoTextField(
                      label: 'Mileage (km)',
                      hint: 'e.g. 84500',
                      controller: _mileage,
                      keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: SogoSpacing.lg),
            SogoButton(
                label: widget.vehicle == null ? 'Add vehicle' : 'Save changes',
                onPressed: _saving ? null : _save,
                loading: _saving),
          ]),
        ),
      ),
    );
  }
}
