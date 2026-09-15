import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/app_theme.dart';
import '../state/app_controller.dart';
import 'admin_page.dart';
import 'parking_session_page.dart';
import 'payment_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final session = controller.session;
    final name = session?.fullName.trim().isNotEmpty == true
        ? session!.fullName
        : 'SmartParking Kullanıcısı';

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFFDCEFEA),
                  child: Text(
                    _initials(name),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session?.email ?? '',
                        style: const TextStyle(color: Color(0xFF667772)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Column(
            children: [
              _InfoTile(
                icon: Icons.timer_outlined,
                title: 'Park oturumları',
                subtitle: 'Parkı başlat, bitir ve ücreti hesapla',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ParkingSessionPage(controller: controller),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 64),
              _InfoTile(
                icon: controller.isOfflineMode
                    ? Icons.cloud_off_rounded
                    : Icons.cloud_done_outlined,
                title: controller.isDemoMode ? 'Demo modu' : 'API bağlantısı',
                subtitle: controller.isDemoMode
                    ? '81 il örnek verileri • API gerekmez'
                    : controller.isOfflineMode
                    ? 'Çevrimdışı • ${controller.pendingSyncCount} bekleyen işlem'
                    : AppConfig.apiBaseUrl,
                trailing: controller.isDemoMode
                    ? null
                    : controller.isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
                onTap: controller.isDemoMode || controller.isSyncing
                    ? null
                    : controller.syncNow,
              ),
              const Divider(height: 1, indent: 64),
              _InfoTile(
                icon: controller.isRealtimeConnected
                    ? Icons.sensors_rounded
                    : Icons.sensors_off_rounded,
                title: 'Canlı durum',
                subtitle: controller.isRealtimeConnected
                    ? 'Bağlı'
                    : 'Çevrimdışı',
              ),
              const Divider(height: 1, indent: 64),
              _InfoTile(
                icon: controller.isPushEnabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_outlined,
                title: 'Google Cloud bildirimleri',
                subtitle: !controller.isFirebaseEnabled
                    ? 'Firebase yapılandırması bekleniyor'
                    : controller.isPushEnabled
                    ? 'FCM cihaz kaydı etkin'
                    : 'Bildirim izni kapalı veya cihaz kaydedilemedi',
              ),
              const Divider(height: 1, indent: 64),
              const _InfoTile(
                icon: Icons.security_rounded,
                title: 'Güvenli oturum',
                subtitle: 'JWT anahtarları cihazın güvenli alanında saklanır',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Column(
            children: [
              _InfoTile(
                icon: Icons.credit_card_rounded,
                title: 'Ödemeler',
                subtitle: 'iyzico güvenli sayfasında kredi kartıyla ödeme',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PaymentPage(controller: controller),
                  ),
                ),
              ),
              if (controller.isAdmin) ...[
                const Divider(height: 1, indent: 64),
                _InfoTile(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Yönetim paneli',
                  subtitle: 'Otopark, doluluk ve sensör yönetimi',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AdminPage(controller: controller),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => _confirmLogout(context),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Çıkış Yap'),
        ),
      ],
    );
  }

  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    return words
        .take(2)
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase())
        .join();
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış yapılsın mı?'),
        content: const Text('Bu cihazdaki oturum bilgileri temizlenecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.logout();
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
