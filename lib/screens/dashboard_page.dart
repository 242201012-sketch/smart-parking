import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../state/app_controller.dart';
import '../widgets/parking_card.dart';
import '../widgets/telemetry_dashboard_panel.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final totalAvailable = controller.parkingLocations.fold<int>(
      0,
      (sum, parking) => sum + parking.availableCapacity,
    );
    final displayName = controller.session?.fullName.trim().isNotEmpty == true
        ? controller.session!.fullName
        : controller.session?.email.split('@').first ?? 'Sürücü';

    return RefreshIndicator(
      onRefresh: controller.refreshParking,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Text(
            'Merhaba, $displayName',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF17332E),
                ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Bugün park yerini birlikte bulalım.',
                  style: TextStyle(color: Color(0xFF667772)),
                ),
              ),
              if (controller.isDemoMode)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBC9),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    'DEMO',
                    style: TextStyle(
                      color: Color(0xFF9A5C00),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
            ],
          ),
          if (controller.isOfflineMode || controller.pendingSyncCount > 0) ...[
            const SizedBox(height: 14),
            Card(
              color: const Color(0xFFFFEBC9),
              child: ListTile(
                leading: Icon(
                  controller.isSyncing
                      ? Icons.sync_rounded
                      : Icons.cloud_off_rounded,
                  color: const Color(0xFF9A5C00),
                ),
                title: Text(
                  controller.isSyncing
                      ? 'Veriler eşitleniyor'
                      : 'Çevrimdışı mod',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  controller.pendingSyncCount > 0
                      ? '${controller.pendingSyncCount} işlem bağlantı gelince gönderilecek.'
                      : 'Son kaydedilen otopark verileri gösteriliyor.',
                ),
                trailing: controller.isDemoMode
                    ? null
                    : TextButton(
                        onPressed: controller.isSyncing
                            ? null
                            : controller.syncNow,
                        child: const Text('Eşitle'),
                      ),
              ),
            ),
          ],
          if (controller.foregroundNotification != null) ...[
            const SizedBox(height: 16),
            Card(
              color: const Color(0xFFE8F2FF),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFD4E6FF),
                  child: Icon(Icons.notifications_active_rounded),
                ),
                title: Text(
                  controller.foregroundNotification!.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(controller.foregroundNotification!.body),
                trailing: IconButton(
                  tooltip: 'Kapat',
                  onPressed: controller.dismissForegroundNotification,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.location_city_rounded,
                  value: '${controller.parkingLocations.length}',
                  label: 'Aktif otopark',
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.directions_car_filled_rounded,
                  value: '$totalAvailable',
                  label: 'Toplam boş yer',
                  color: const Color(0xFFE49335),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF105C4E), Color(0xFF22816D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.my_location_rounded, color: Colors.white),
                    SizedBox(width: 9),
                    Text(
                      'Sana en yakın boş yer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'GPS konumunu kullanarak uygun otoparkı mesafesiyle gösterir.',
                  style: TextStyle(color: Color(0xFFD5ECE7), height: 1.35),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primary,
                  ),
                  onPressed: controller.isFindingNearest
                      ? null
                      : () async {
                          final success = await controller.findNearestParking();
                          if (!success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  controller.errorMessage ?? 'Konum alınamadı.',
                                ),
                              ),
                            );
                          }
                        },
                  icon: controller.isFindingNearest
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.near_me_rounded),
                  label: Text(
                    controller.isFindingNearest ? 'Aranıyor...' : 'En Yakını Bul',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TelemetryDashboardPanel(controller: controller),
          if (controller.nearestParking != null) ...[
            const SizedBox(height: 24),
            const _SectionTitle(title: 'En yakın sonuç'),
            const SizedBox(height: 10),
            ParkingCard(parking: controller.nearestParking!),
          ],
          const SizedBox(height: 24),
          _SectionTitle(
            title: 'Öne çıkan otoparklar',
            trailing: controller.isLoadingParking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          if (controller.parkingLocations.isEmpty && !controller.isLoadingParking)
            _EmptyParking(onRefresh: controller.refreshParking)
          else
            ...controller.parkingLocations.take(3).map(
                  (parking) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ParkingCard(
                      parking: parking,
                      compact: true,
                      onTap: () => controller.selectParking(parking),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 16),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Color(0xFF6C7B77), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _EmptyParking extends StatelessWidget {
  const _EmptyParking({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Icon(Icons.local_parking_outlined, size: 42, color: Color(0xFF82918D)),
            const SizedBox(height: 10),
            const Text('Henüz gösterilecek otopark yok.'),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Yenile'),
            ),
          ],
        ),
      ),
    );
  }

}
