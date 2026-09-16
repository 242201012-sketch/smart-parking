import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../services/api_exception.dart';
import '../services/telemetry_dashboard_service.dart';

/// Dashboard sayfasına gömülebilir canlı telemetri paneli.
///
/// Arka plan [`TelemetryDashboardService`]'ini kullanarak
/// coalesced sensör görünümlerini, ANPR trendini ve kapasite
/// anlık görüntüsünü çeker. Oturumda erişim token'ı yoksa
/// (demo/çevrimdışı mod) hiçbir şey göstermez — bu sayede
/// widget testleri network olmadan deterministik kalır.
class TelemetryDashboardPanel extends StatefulWidget {
  const TelemetryDashboardPanel({
    super.key,
    required this.controller,
    this.service,
  });

  final AppController controller;
  final TelemetryDashboardService? service;

  @override
  State<TelemetryDashboardPanel> createState() =>
      _TelemetryDashboardPanelState();
}

class _TelemetryDashboardPanelState extends State<TelemetryDashboardPanel> {
  late final TelemetryDashboardService _service =
      widget.service ?? TelemetryDashboardService();

  List<CoalescedSensorSpaceView> _spaces = const [];
  List<AnprTrendPoint> _trend = const [];
  ParkingLotCapacitySnapshot? _capacity;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_hasAccess) _load();
  }

  bool get _hasAccess =>
      !widget.controller.isDemoMode &&
      (widget.controller.session?.accessToken.isNotEmpty ?? false);

  String? get _lotId => widget.controller.parkingLocations.isNotEmpty
      ? widget.controller.selectedParking?.id ??
          widget.controller.parkingLocations.first.id
      : null;

  Future<void> _load() async {
    final token = widget.controller.session?.accessToken;
    final lotId = _lotId;
    if (token == null || token.isEmpty || lotId == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getCoalescedSensorSpaces(
          accessToken: token,
          parkingLotId: lotId,
        ),
        _service.getAnprTrend(
          accessToken: token,
          parkingLotId: lotId,
        ),
        _service.getCapacity(
          accessToken: token,
          parkingLotId: lotId,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _spaces = results[0] as List<CoalescedSensorSpaceView>;
        _trend = results[1] as List<AnprTrendPoint>;
        _capacity = results[2] as ParkingLotCapacitySnapshot;
        _isLoading = false;
      });
    } on ApiException catch (exception) {
      if (!mounted) return;
      setState(() {
        _error = exception.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Telemetri yüklenemedi.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAccess) return const SizedBox.shrink();
    return Card(
      elevation: 0,
      color: const Color(0xFFF2F7F5),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFDCE7E2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sensors_rounded,
                    size: 20, color: Color(0xFF105C4E)),
                const SizedBox(width: 8),
                const Text(
                  'Canlı telemetri',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF17332E),
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    tooltip: 'Yenile',
                    visualDensity: VisualDensity.compact,
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13),
              )
            else ...[
              _CapacityStrip(capacity: _capacity),
              if (_spaces.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Coalesced sensörler (${_spaces.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF55706A),
                  ),
                ),
                const SizedBox(height: 8),
                ..._spaces.take(4).map(
                      (space) => _SpaceTile(space: space),
                    ),
              ],
              if (_trend.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'ANPR trendi (son saat)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF55706A),
                  ),
                ),
                const SizedBox(height: 8),
                _TrendStrip(points: _trend),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CapacityStrip extends StatelessWidget {
  const _CapacityStrip({required this.capacity});

  final ParkingLotCapacitySnapshot? capacity;

  @override
  Widget build(BuildContext context) {
    if (capacity == null) {
      return const Text(
        'Kapasite verisi bekleniyor…',
        style: TextStyle(color: Color(0xFF6C7B77), fontSize: 13),
      );
    }
    final free = capacity!.availableSpaces;
    final ratio = capacity!.occupancyRatio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$free boş / ${capacity!.totalSpaces} toplam',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF17332E),
              ),
            ),
            const Spacer(),
            Text(
              '${(ratio * 100).toStringAsFixed(0)}% dolu',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF105C4E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: const Color(0xFFDCE7E2),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF22816D)),
          ),
        ),
      ],
    );
  }
}

class _SpaceTile extends StatelessWidget {
  const _SpaceTile({required this.space});

  final CoalescedSensorSpaceView space;

  @override
  Widget build(BuildContext context) {
    final battery = space.batteryPercent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            space.isOccupied
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: space.isOccupied
                ? const Color(0xFF22816D)
                : const Color(0xFF8CA49D),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              space.spaceCode,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '${space.readingCount} okuma',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6C7B77),
            ),
          ),
          if (battery != null) ...[
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.battery_full_rounded,
                    size: 15, color: Color(0xFF55706A)),
                Text(
                  '%${battery.round()}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF55706A),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TrendStrip extends StatelessWidget {
  const _TrendStrip({required this.points});

  final List<AnprTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final totalEntries =
        points.fold<int>(0, (sum, p) => sum + p.entries);
    final totalExits = points.fold<int>(0, (sum, p) => sum + p.exits);
    return Row(
      children: [
        _TrendPill(
          label: 'Giriş',
          value: totalEntries,
          icon: Icons.login_rounded,
        ),
        const SizedBox(width: 10),
        _TrendPill(
          label: 'Çıkış',
          value: totalExits,
          icon: Icons.logout_rounded,
        ),
      ],
    );
  }
}

class _TrendPill extends StatelessWidget {
  const _TrendPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDCE7E2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF22816D)),
            const SizedBox(width: 8),
            Text(
              '$value $label',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF17332E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
