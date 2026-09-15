import 'package:flutter/material.dart';

import '../models/parking_location.dart';
import '../state/app_controller.dart';
import '../widgets/parking_card.dart';

class ParkingListPage extends StatefulWidget {
  const ParkingListPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<ParkingListPage> createState() => _ParkingListPageState();
}

class _ParkingListPageState extends State<ParkingListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedProvince = '';

  AppController get controller => widget.controller;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller.isLoadingParking && controller.parkingLocations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.parkingLocations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, size: 58),
              const SizedBox(height: 14),
              const Text('Otopark bulunamadı.'),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: controller.refreshParking,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Yenile'),
              ),
            ],
          ),
        ),
      );
    }

    final provinces =
        controller.parkingLocations
            .map((parking) => parking.zone.trim())
            .where((province) => province.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final query = _normalize(_searchController.text);
    final filteredParking = controller.parkingLocations.where((parking) {
      final provinceMatches =
          _selectedProvince.isEmpty || parking.zone == _selectedProvince;
      final queryMatches =
          query.isEmpty ||
          _normalize(parking.name).contains(query) ||
          _normalize(parking.address).contains(query) ||
          _normalize(parking.zone).contains(query);
      return provinceMatches && queryMatches;
    }).toList();

    final listItems = <Widget>[
      Card(
        margin: EdgeInsets.zero,
        color: const Color(0xFFE2F1EC),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.public_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Türkiye genelinde otopark bul',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Chip(label: Text('${filteredParking.length} otopark')),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'İl, otopark veya adres ara',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Aramayı temizle',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedProvince,
                decoration: const InputDecoration(
                  labelText: 'İl seçin',
                  prefixIcon: Icon(Icons.location_city_rounded),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Tüm Türkiye')),
                  ...provinces.map(
                    (province) => DropdownMenuItem(
                      value: province,
                      child: Text(province),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _selectedProvince = value ?? ''),
              ),
            ],
          ),
        ),
      ),
      if (filteredParking.isEmpty)
        const Card(
          child: ListTile(
            leading: Icon(Icons.search_off_rounded),
            title: Text('Bu aramaya uygun otopark bulunamadı'),
            subtitle: Text('Farklı bir il veya arama ifadesi deneyin.'),
          ),
        )
      else
        ...filteredParking.map(
          (parking) => ParkingCard(
            parking: parking,
            onTap: () => _showDetails(context, parking),
          ),
        ),
    ];

    return RefreshIndicator(
      onRefresh: controller.refreshParking,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        itemCount: listItems.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => listItems[index],
      ),
    );
  }

  String _normalize(String value) => value
      .replaceAll('İ', 'I')
      .replaceAll('ı', 'i')
      .replaceAll('Ç', 'C')
      .replaceAll('ç', 'c')
      .replaceAll('Ğ', 'G')
      .replaceAll('ğ', 'g')
      .replaceAll('Ö', 'O')
      .replaceAll('ö', 'o')
      .replaceAll('Ş', 'S')
      .replaceAll('ş', 's')
      .replaceAll('Ü', 'U')
      .replaceAll('ü', 'u')
      .toLowerCase()
      .trim();

  void _showDetails(BuildContext context, ParkingLocation parking) {
    controller.selectParking(parking);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          4,
          22,
          22 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              parking.name,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(parking.address),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _DetailTile(
                    icon: Icons.event_available_rounded,
                    label: 'Boş yer',
                    value: '${parking.availableCapacity}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DetailTile(
                    icon: Icons.directions_car_rounded,
                    label: 'Kapasite',
                    value: '${parking.totalCapacity}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (parking.hourlyRate > 0)
                  Chip(
                    avatar: const Icon(Icons.payments_outlined, size: 17),
                    label: Text(
                      '${parking.hourlyRate.toStringAsFixed(0)} TL/saat',
                    ),
                  ),
                if (parking.hasElectricCharging)
                  const Chip(
                    avatar: Icon(Icons.ev_station_outlined, size: 17),
                    label: Text('EV şarj'),
                  ),
                if (parking.hasAccessibleSpaces)
                  const Chip(
                    avatar: Icon(Icons.accessible_rounded, size: 17),
                    label: Text('Erişilebilir'),
                  ),
                if (parking.isCovered)
                  const Chip(
                    avatar: Icon(Icons.roofing_outlined, size: 17),
                    label: Text('Kapalı'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Konum: ${parking.latitude.toStringAsFixed(5)}, '
              '${parking.longitude.toStringAsFixed(5)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.qr_code_2_rounded),
                    label: const Text('QR için seç'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: parking.hasAvailableSpace
                        ? () {
                            Navigator.pop(sheetContext);
                            _showReservationForm(context, parking);
                          }
                        : null,
                    icon: const Icon(Icons.timer_outlined),
                    label: const Text('Yer ayır'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReservationForm(
    BuildContext context,
    ParkingLocation parking,
  ) async {
    final plateController = TextEditingController();
    var duration = 15;
    var requireElectric = false;
    var requireAccessible = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Süreli yer ayır'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: plateController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Araç plakası',
                    prefixIcon: Icon(Icons.directions_car_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: duration,
                  decoration: const InputDecoration(labelText: 'Ayırma süresi'),
                  items: const [10, 15, 30, 60]
                      .map(
                        (minutes) => DropdownMenuItem(
                          value: minutes,
                          child: Text('$minutes dakika'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => duration = value ?? 15),
                ),
                if (parking.hasElectricCharging)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: requireElectric,
                    onChanged: (value) =>
                        setState(() => requireElectric = value ?? false),
                    title: const Text('EV şarj alanı gerekli'),
                  ),
                if (parking.hasAccessibleSpaces)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: requireAccessible,
                    onChanged: (value) =>
                        setState(() => requireAccessible = value ?? false),
                    title: const Text('Erişilebilir alan gerekli'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Yer ayır'),
            ),
          ],
        ),
      ),
    );

    final plate = plateController.text.trim();
    plateController.dispose();
    if (confirmed != true || !context.mounted) return;
    if (plate.length < 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Geçerli bir plaka girin.')));
      return;
    }

    final success = await controller.createReservation(
      parking: parking,
      vehiclePlate: plate,
      durationMinutes: duration,
      requireElectric: requireElectric,
      requireAccessible: requireAccessible,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? controller.activeReservation?.isPendingSync == true
                    ? 'İstek çevrimdışı kuyruğa alındı; internet gelince kesinleşecek.'
                    : '${controller.activeReservation?.parkingSpaceCode ?? ''} alanı ayrıldı.'
              : controller.errorMessage ?? 'Rezervasyon oluşturulamadı.',
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5F3),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
