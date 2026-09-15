import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/parking_session.dart';
import '../services/parking_session_service.dart';
import '../state/app_controller.dart';
import 'payment_page.dart';

class ParkingSessionPage extends StatefulWidget {
  const ParkingSessionPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<ParkingSessionPage> createState() => _ParkingSessionPageState();
}

class _ParkingSessionPageState extends State<ParkingSessionPage> {
  final ParkingSessionService _service = ParkingSessionService();
  ParkingSession? _active;
  List<ParkingSession> _history = const [];
  bool _loading = true;
  bool _changing = false;
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
    if (widget.controller.isDemoMode || widget.controller.isOfflineMode) {
      setState(() {
        _loading = false;
        _error = 'Park ücretlendirmesi için gerçek oturum ve internet bağlantısı gerekir.';
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
        _service.getActive(token),
        _service.getHistory(token),
      ]);
      if (!mounted) return;
      setState(() {
        _active = results[0] as ParkingSession?;
        _history = results[1] as List<ParkingSession>;
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
      appBar: AppBar(title: const Text('Park Oturumları')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                children: [
                  if (_error != null)
                    Card(
                      color: const Color(0xFFFFEBC9),
                      child: ListTile(
                        leading: const Icon(Icons.info_outline_rounded),
                        title: const Text('Park oturumu kullanılamıyor'),
                        subtitle: Text(_error!),
                      ),
                    ),
                  if (_active == null) ...[
                    Card(
                      color: const Color(0xFFE2F1EC),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(Icons.play_circle_outline_rounded, size: 48, color: AppTheme.primary),
                            const SizedBox(height: 10),
                            const Text('Aktif park oturumu yok', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            const Text('Girişte oturumu başlat; çıkışta ücret otomatik hesaplansın.', textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _changing || _error != null ? null : _start,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Parkı başlat'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Card(
                      color: const Color(0xFFE2F1EC),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.timer_rounded, color: AppTheme.primary),
                                SizedBox(width: 8),
                                Text('Ücretlendirme devam ediyor', style: TextStyle(fontWeight: FontWeight.w800)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(_active!.parkingLotName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                            Text('${_active!.vehiclePlate} · Başlangıç ${_dateTime(_active!.startedAt)}'),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                              onPressed: _changing ? null : _stop,
                              icon: const Icon(Icons.stop_rounded),
                              label: const Text('Parkı bitir ve ücreti hesapla'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(child: Text('Geçmiş', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => PaymentPage(controller: widget.controller)),
                        ),
                        icon: const Icon(Icons.credit_card_rounded),
                        label: const Text('Ödemeler'),
                      ),
                    ],
                  ),
                  if (_history.isEmpty)
                    const Card(child: ListTile(leading: Icon(Icons.history_rounded), title: Text('Park geçmişi yok')))
                  else
                    ..._history.map(
                      (session) => Card(
                        child: ListTile(
                          leading: Icon(session.isActive ? Icons.timer_rounded : Icons.local_parking_rounded),
                          title: Text(session.parkingLotName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${session.vehiclePlate} · ${_dateTime(session.startedAt)}'),
                          trailing: session.totalAmount == null
                              ? const Text('Devam ediyor')
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${session.totalAmount!.toStringAsFixed(2)} TL', style: const TextStyle(fontWeight: FontWeight.w800)),
                                    Text(session.paymentStatus == 'paid' ? 'Ödendi' : 'Bekliyor', style: Theme.of(context).textTheme.labelSmall),
                                  ],
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _start() async {
    if (widget.controller.parkingLocations.isEmpty) return;
    var parkingId = widget.controller.selectedParking?.id
        ?? widget.controller.parkingLocations.first.id;
    final plate = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Parkı başlat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: parkingId,
                decoration: const InputDecoration(labelText: 'Otopark'),
                items: widget.controller.parkingLocations
                    .map((parking) => DropdownMenuItem(value: parking.id, child: Text(parking.name)))
                    .toList(),
                onChanged: (value) => setState(() => parkingId = value ?? parkingId),
              ),
              const SizedBox(height: 12),
              TextField(controller: plate, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Araç plakası')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Başlat')),
          ],
        ),
      ),
    );
    final plateValue = plate.text.trim();
    plate.dispose();
    if (accepted != true || plateValue.length < 5) return;
    setState(() => _changing = true);
    try {
      await _service.start(
        await widget.controller.getAccessToken(),
        parkingLotId: parkingId,
        vehiclePlate: plateValue,
      );
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  Future<void> _stop() async {
    final active = _active;
    if (active == null) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Park bitirilsin mi?'),
        content: const Text('Geçen süreye göre ücret hesaplanacak ve ödeme bekleyenlere eklenecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Parkı bitir')),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _changing = true);
    try {
      final ended = await _service.stop(
        await widget.controller.getAccessToken(),
        active.id,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Park oturumu tamamlandı'),
          content: Text('Ödenecek tutar: ${ended.totalAmount?.toStringAsFixed(2) ?? '0.00'} TL'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Sonra')),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(this.context).push(
                  MaterialPageRoute(builder: (_) => PaymentPage(controller: widget.controller)),
                );
              },
              child: const Text('Ödemeye geç'),
            ),
          ],
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  String _dateTime(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
