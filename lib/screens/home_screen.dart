import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../state/app_controller.dart';
import 'dashboard_page.dart';
import 'parking_map_page.dart';
import 'parking_list_page.dart';
import 'profile_page.dart';
import 'qr_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const _titles = [
    'SmartParking',
    'Canlı Harita',
    'Otoparklar',
    'QR İşlemleri',
    'Profil',
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(controller: widget.controller),
      ParkingMapPage(controller: widget.controller),
      ParkingListPage(controller: widget.controller),
      QrPage(controller: widget.controller),
      ProfilePage(controller: widget.controller),
    ];
    final requestedTab = widget.controller.takeRequestedHomeTab();
    if (requestedTab != null &&
        requestedTab >= 0 &&
        requestedTab < pages.length &&
        requestedTab != _selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedIndex = requestedTab);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Tooltip(
              message: widget.controller.isRealtimeConnected
                  ? 'Canlı veri bağlantısı açık'
                  : 'Canlı veri bağlantısı kapalı',
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.controller.isRealtimeConnected
                      ? const Color(0xFFDDF3EC)
                      : const Color(0xFFF2E7E7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.controller.isRealtimeConnected
                      ? Icons.sensors_rounded
                      : Icons.sensors_off_rounded,
                  size: 20,
                  color: widget.controller.isRealtimeConnected
                      ? AppTheme.primary
                      : const Color(0xFFA15B5B),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Harita',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_parking_outlined),
            selectedIcon: Icon(Icons.local_parking_rounded),
            label: 'Otoparklar',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_2_outlined),
            selectedIcon: Icon(Icons.qr_code_2_rounded),
            label: 'QR',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
