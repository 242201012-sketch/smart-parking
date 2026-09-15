import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/admin_models.dart';
import '../services/admin_service.dart';
import '../state/app_controller.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final AdminService _service = AdminService();
  AdminDashboard? _dashboard;
  List<AdminSensor> _sensors = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!widget.controller.isAdmin) {
      setState(() {
        _loading = false;
        _error = 'Bu ekran yalnızca yönetici rolüne açıktır.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await widget.controller.getAccessToken();
      final results = await Future.wait([
        _service.getDashboard(token),
        _service.getSensors(token),
      ]);
      if (!mounted) return;
      setState(() {
        _dashboard = results[0] as AdminDashboard;
        _sensors = results[1] as List<AdminSensor>;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yönetim Paneli')),
      body: _loading && _dashboard == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                children: [
                  if (_error != null)
                    Card(
                      color: const Color(0xFFFFECE8),
                      child: ListTile(
                        leading: const Icon(Icons.error_outline_rounded),
                        title: const Text('Yönetim verisi alınamadı'),
                        subtitle: Text(_error!),
                        trailing: IconButton(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ),
                    ),
                  if (_dashboard != null) ...[
                    _SummaryGrid(totals: _dashboard!.totals),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _createParkingLot,
                            icon: const Icon(Icons.add_location_alt_outlined),
                            label: const Text('Otopark ekle'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _dashboard!.lots.isEmpty ? null : _createSensor,
                            icon: const Icon(Icons.sensors_outlined),
                            label: const Text('Sensör ekle'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Otopark dolulukları',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ..._dashboard!.lots.map(
                      (lot) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      lot.name,
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  Text('${lot.occupancyPercent.toStringAsFixed(0)}% dolu'),
                                ],
                              ),
                              const SizedBox(height: 10),
                              LinearProgressIndicator(
                                value: (lot.occupancyPercent / 100).clamp(0, 1),
                              ),
                              const SizedBox(height: 6),
                              Text('${lot.availableCapacity} boş / ${lot.totalCapacity} toplam'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Sensörler',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (_sensors.isEmpty)
                      const Card(
                        child: ListTile(
                          leading: Icon(Icons.sensors_off_outlined),
                          title: Text('Kayıtlı sensör yok'),
                        ),
                      )
                    else
                      ..._sensors.map(_sensorTile),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _sensorTile(AdminSensor sensor) {
    return Card(
      child: SwitchListTile(
        value: sensor.isActive,
        onChanged: (value) => _setSensorStatus(sensor, value),
        secondary: CircleAvatar(
          backgroundColor: sensor.isOnline
              ? const Color(0xFFDDF3EC)
              : const Color(0xFFF2E7E7),
          child: Icon(
            sensor.isOnline ? Icons.sensors_rounded : Icons.sensors_off_rounded,
            color: sensor.isOnline ? AppTheme.primary : const Color(0xFFA15B5B),
          ),
        ),
        title: Text(sensor.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${sensor.deviceId} · ${sensor.parkingLotName}\n'
          '${sensor.isOnline ? 'Çevrimiçi' : 'Çevrimdışı'}'
          '${sensor.batteryPercent == null ? '' : ' · Pil %${sensor.batteryPercent}'}',
        ),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _setSensorStatus(AdminSensor sensor, bool value) async {
    try {
      await _service.setSensorStatus(
        await widget.controller.getAccessToken(),
        sensor.id,
        value,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _createSensor() async {
    final dashboard = _dashboard;
    if (dashboard == null || dashboard.lots.isEmpty) return;
    final deviceController = TextEditingController();
    final nameController = TextEditingController();
    var parkingLotId = dashboard.lots.first.id;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Yeni sensör'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: parkingLotId,
                  decoration: const InputDecoration(labelText: 'Otopark'),
                  items: dashboard.lots
                      .map((lot) => DropdownMenuItem(value: lot.id, child: Text(lot.name)))
                      .toList(),
                  onChanged: (value) => setState(() => parkingLotId = value ?? parkingLotId),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: deviceController,
                  decoration: const InputDecoration(labelText: 'Cihaz kodu (örn. ESP32-01)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Görünen ad'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    final deviceId = deviceController.text.trim();
    final name = nameController.text.trim();
    deviceController.dispose();
    nameController.dispose();
    if (submitted != true || deviceId.length < 3) return;
    try {
      await _service.createSensor(
        await widget.controller.getAccessToken(),
        parkingLotId: parkingLotId,
        deviceId: deviceId,
        name: name,
      );
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _createParkingLot() async {
    final code = TextEditingController();
    final name = TextEditingController();
    final address = TextEditingController();
    final zone = TextEditingController();
    final latitude = TextEditingController();
    final longitude = TextEditingController();
    final capacity = TextEditingController(text: '50');
    final rate = TextEditingController(text: '25');
    final controllers = [code, name, address, zone, latitude, longitude, capacity, rate];
    var electric = false;
    var accessible = false;
    var covered = false;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Yeni otopark'),
          content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(code, 'Kod', hint: 'AMASYA-04'),
                  _field(name, 'Otopark adı'),
                  _field(address, 'Adres'),
                  _field(zone, 'Bölge'),
                  Row(children: [Expanded(child: _field(latitude, 'Enlem', number: true)), const SizedBox(width: 8), Expanded(child: _field(longitude, 'Boylam', number: true))]),
                  Row(children: [Expanded(child: _field(capacity, 'Kapasite', number: true)), const SizedBox(width: 8), Expanded(child: _field(rate, 'TL/saat', number: true))]),
                  CheckboxListTile(contentPadding: EdgeInsets.zero, value: electric, onChanged: (value) => setState(() => electric = value ?? false), title: const Text('Elektrikli şarj')),
                  CheckboxListTile(contentPadding: EdgeInsets.zero, value: accessible, onChanged: (value) => setState(() => accessible = value ?? false), title: const Text('Erişilebilir alan')),
                  CheckboxListTile(contentPadding: EdgeInsets.zero, value: covered, onChanged: (value) => setState(() => covered = value ?? false), title: const Text('Kapalı otopark')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Oluştur')),
          ],
        ),
      ),
    );
    final values = {
      'externalCode': code.text.trim(),
      'name': name.text.trim(),
      'address': address.text.trim(),
      'zone': zone.text.trim(),
      'latitude': double.tryParse(latitude.text.replaceAll(',', '.')),
      'longitude': double.tryParse(longitude.text.replaceAll(',', '.')),
      'capacity': int.tryParse(capacity.text),
      'hourlyRate': double.tryParse(rate.text.replaceAll(',', '.')),
      'hasElectricCharging': electric,
      'hasAccessibleSpaces': accessible,
      'isCovered': covered,
    };
    for (final controller in controllers) {
      controller.dispose();
    }
    if (submitted != true || values.values.any((value) => value == null || value == '')) return;
    try {
      await _service.createParkingLot(
        await widget.controller.getAccessToken(),
        values: values,
      );
      await _load();
      await widget.controller.refreshParking(silent: true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    bool number = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true, signed: true) : null,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.totals});

  final AdminTotals totals;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.people_outline_rounded, '${totals.users}', 'Kullanıcı'),
      (Icons.local_parking_rounded, '${totals.parkingLots}', 'Otopark'),
      (Icons.directions_car_outlined, '${totals.availableSpaces}/${totals.spaces}', 'Boş / toplam'),
      (Icons.sensors_rounded, '${totals.onlineSensors}/${totals.sensorDevices}', 'Çevrimiçi sensör'),
      (Icons.event_available_outlined, '${totals.activeReservations}', 'Aktif rezervasyon'),
      (Icons.query_stats_rounded, '${totals.readingsLast24Hours}', '24 saatlik okuma'),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.55,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.$1, color: AppTheme.primary),
                const SizedBox(height: 8),
                Text(item.$2, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                Text(item.$3, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        );
      },
    );
  }
}
