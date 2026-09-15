import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/app_theme.dart';
import '../models/parking_location.dart';
import '../state/app_controller.dart';

class QrPage extends StatelessWidget {
  const QrPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final parking = controller.selectedParking;
    final reservation = controller.activeReservation;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Otopark QR Kodu',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bir otopark seçip kodunu paylaşabilir veya mevcut kodu tarayabilirsin.',
            style: TextStyle(color: Color(0xFF667772), height: 1.4),
          ),
          const SizedBox(height: 18),
          if (reservation != null) ...[
            Card(
              color: reservation.isPendingSync
                  ? const Color(0xFFFFEBC9)
                  : const Color(0xFFE2F1EC),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      reservation.isPendingSync
                          ? Icons.cloud_upload_outlined
                          : Icons.timer_rounded,
                      color: reservation.isPendingSync
                          ? const Color(0xFF9A5C00)
                          : AppTheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${reservation.parkingSpaceCode} · ${reservation.vehiclePlate}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            reservation.isPendingSync
                                ? 'İnternet gelince sunucuda kesinleşecek'
                                : '${reservation.parkingLotName} · ${reservation.estimatedAmount.toStringAsFixed(2)} TL',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Rezervasyonu iptal et',
                      onPressed: controller.isReserving
                          ? null
                          : () async {
                              final success = await controller.cancelReservation();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success
                                      ? 'Rezervasyon iptal edildi.'
                                      : controller.errorMessage ?? 'İptal edilemedi.'),
                                ),
                              );
                            },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<String>(
            initialValue: parking?.id,
            decoration: const InputDecoration(
              labelText: 'Otopark seç',
              prefixIcon: Icon(Icons.local_parking_rounded),
            ),
            items: controller.parkingLocations
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(item.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (id) {
              if (id == null) return;
              final selected = controller.findParkingById(id);
              if (selected != null) controller.selectParking(selected);
            },
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: parking == null
                  ? const SizedBox(
                      height: 250,
                      child: Center(child: Text('QR oluşturmak için otopark seçin.')),
                    )
                  : reservation?.isPendingSync == true
                      ? const SizedBox(
                          height: 250,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 62,
                                color: Color(0xFF9A5C00),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Rezervasyon henüz kesinleşmedi',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'QR giriş kodu, çevrimdışı istek sunucuya ulaştıktan sonra oluşacaktır.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF667772)),
                              ),
                            ],
                          ),
                        )
                      : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE1E8E6)),
                          ),
                          child: QrImageView(
                            data: reservation?.qrToken ?? _qrData(parking),
                            version: QrVersions.auto,
                            size: 210,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: AppTheme.primary,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF17332E),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          reservation == null
                              ? parking.name
                              : '${reservation.parkingLotName} · ${reservation.parkingSpaceCode}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reservation == null
                              ? '${parking.availableCapacity} boş / ${parking.totalCapacity} toplam'
                              : 'Rezervasyon giriş kodu',
                          style: const TextStyle(color: Color(0xFF667772)),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => _scan(context),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('QR Kod Tara'),
          ),
        ],
      ),
    );
  }

  String _qrData(ParkingLocation parking) {
    return jsonEncode({
      'type': 'smartparking',
      'parkingId': parking.id,
      'name': parking.name,
    });
  }

  Future<void> _scan(BuildContext context) async {
    final rawValue = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (rawValue == null || !context.mounted) return;

    var parkingId = rawValue;
    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is Map && decoded['parkingId'] != null) {
        parkingId = decoded['parkingId'].toString();
      }
    } catch (_) {
      // Plain parking id QR codes are supported as well.
    }

    final parking = controller.findParkingById(parkingId);
    if (parking == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu QR kod kayıtlı bir otoparka ait değil.')),
      );
      return;
    }

    controller.selectParking(parking);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${parking.name} seçildi.')),
    );
  }
}

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (value == null || value.isEmpty) return;

    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('QR Kod Tara'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _scannerController.toggleTorch,
            icon: const Icon(Icons.flashlight_on_rounded),
          ),
          IconButton(
            onPressed: _scannerController.switchCamera,
            icon: const Icon(Icons.cameraswitch_rounded),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _scannerController, onDetect: _onDetect),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Text(
              'QR kodu çerçevenin içine hizalayın.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
