import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_theme.dart';
import '../models/parking_location.dart';
import '../state/app_controller.dart';

class ParkingMapPage extends StatefulWidget {
  const ParkingMapPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<ParkingMapPage> createState() => _ParkingMapPageState();
}

class _ParkingMapPageState extends State<ParkingMapPage> {
  GoogleMapController? _mapController;

  static const _amasya = CameraPosition(
    target: LatLng(40.6503, 35.8353),
    zoom: 13.5,
  );

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locations = widget.controller.parkingLocations;
    if (locations.isEmpty && widget.controller.isLoadingParking) {
      return const Center(child: CircularProgressIndicator());
    }
    if (locations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_outlined, size: 58),
              const SizedBox(height: 12),
              const Text('Haritada gösterilecek otopark bulunamadı.'),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: widget.controller.refreshParking,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Yenile'),
              ),
            ],
          ),
        ),
      );
    }

    final selected = widget.controller.selectedParking;
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: _amasya,
          markers: locations.map(_markerFor).toSet(),
          myLocationEnabled: widget.controller.currentLocation != null,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: true,
          onMapCreated: (controller) {
            _mapController = controller;
            unawaited(_fitLocations(locations));
          },
        ),
        Positioned(
          top: 14,
          left: 14,
          right: 14,
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  const Icon(Icons.sensors_rounded, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${locations.length} otopark · canlı doluluk işaretleri',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tümünü göster',
                    onPressed: () => _fitLocations(locations),
                    icon: const Icon(Icons.center_focus_strong_rounded),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: selected == null ? 22 : 174,
          child: FloatingActionButton.small(
            heroTag: 'map-location',
            tooltip: 'Konumuma git',
            onPressed: _goToNearest,
            child: widget.controller.isFindingNearest
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded),
          ),
        ),
        if (selected != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _SelectedParkingCard(
              parking: selected,
              onDirections: () => _openDirections(selected),
            ),
          ),
      ],
    );
  }

  Marker _markerFor(ParkingLocation parking) {
    final hue = parking.availableCapacity == 0
        ? BitmapDescriptor.hueRed
        : parking.occupancyRatio >= 0.8
            ? BitmapDescriptor.hueOrange
            : BitmapDescriptor.hueGreen;
    return Marker(
      markerId: MarkerId(parking.id),
      position: LatLng(parking.latitude, parking.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      infoWindow: InfoWindow(
        title: parking.name,
        snippet: '${parking.availableCapacity} boş yer',
      ),
      onTap: () {
        widget.controller.selectParking(parking);
        unawaited(_focusParking(parking));
      },
    );
  }

  Future<void> _goToNearest() async {
    final found = await widget.controller.findNearestParking();
    if (!mounted) return;
    if (!found || widget.controller.nearestParking == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.controller.errorMessage ?? 'Konum alınamadı.'),
        ),
      );
      return;
    }
    await _focusParking(widget.controller.nearestParking!);
  }

  Future<void> _focusParking(ParkingLocation parking) async {
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(parking.latitude, parking.longitude),
          zoom: 16,
        ),
      ),
    );
  }

  Future<void> _fitLocations(List<ParkingLocation> locations) async {
    final controller = _mapController;
    if (controller == null || locations.isEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    if (locations.length == 1) {
      await _focusParking(locations.first);
      return;
    }

    final latitudes = locations.map((item) => item.latitude);
    final longitudes = locations.map((item) => item.longitude);
    final bounds = LatLngBounds(
      southwest: LatLng(
        latitudes.reduce((a, b) => a < b ? a : b),
        longitudes.reduce((a, b) => a < b ? a : b),
      ),
      northeast: LatLng(
        latitudes.reduce((a, b) => a > b ? a : b),
        longitudes.reduce((a, b) => a > b ? a : b),
      ),
    );
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
  }

  Future<void> _openDirections(ParkingLocation parking) async {
    final uri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      {
        'api': '1',
        'destination': '${parking.latitude},${parking.longitude}',
        'travelmode': 'driving',
      },
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened) {
      await widget.controller.trackDirectionsOpened(parking);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yol tarifi açılamadı.')),
      );
    }
  }
}

class _SelectedParkingCard extends StatelessWidget {
  const _SelectedParkingCard({
    required this.parking,
    required this.onDirections,
  });

  final ParkingLocation parking;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: parking.hasAvailableSpace
                    ? const Color(0xFFDDF3EC)
                    : const Color(0xFFFFE2E2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.local_parking_rounded,
                color: parking.hasAvailableSpace
                    ? AppTheme.primary
                    : const Color(0xFFB24A4A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    parking.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${parking.availableCapacity} boş yer · ${parking.hourlyRate.toStringAsFixed(0)} TL/saat',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: onDirections,
              icon: const Icon(Icons.directions_rounded),
              label: const Text('Git'),
            ),
          ],
        ),
      ),
    );
  }
}
