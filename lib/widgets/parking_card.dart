import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/parking_location.dart';

class ParkingCard extends StatelessWidget {
  const ParkingCard({
    super.key,
    required this.parking,
    this.onTap,
    this.compact = false,
  });

  final ParkingLocation parking;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final available = parking.hasAvailableSpace;
    final statusColor = available ? const Color(0xFF138A65) : const Color(0xFFC14343);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 16 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5F3EF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.local_parking_rounded,
                      color: AppTheme.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parking.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          parking.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF6C7B77),
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null) const Icon(Icons.chevron_right_rounded),
                ],
              ),
              SizedBox(height: compact ? 14 : 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: parking.occupancyRatio,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE9EFED),
                  color: parking.occupancyRatio > 0.85
                      ? const Color(0xFFE28452)
                      : AppTheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      available ? '${parking.availableCapacity} boş yer' : 'Dolu',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${parking.totalCapacity} kapasite',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6C7B77),
                        ),
                  ),
                  if (parking.distanceKm != null) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.near_me_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text('${parking.distanceKm!.toStringAsFixed(2)} km'),
                  ],
                ],
              ),
              if (parking.hourlyRate > 0 ||
                  parking.hasElectricCharging ||
                  parking.hasAccessibleSpaces ||
                  parking.isCovered) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    if (parking.hourlyRate > 0)
                      _FeatureChip(
                        icon: Icons.payments_outlined,
                        label: '${parking.hourlyRate.toStringAsFixed(0)} TL/saat',
                      ),
                    if (parking.hasElectricCharging)
                      const _FeatureChip(
                        icon: Icons.ev_station_outlined,
                        label: 'EV şarj',
                      ),
                    if (parking.hasAccessibleSpaces)
                      const _FeatureChip(
                        icon: Icons.accessible_rounded,
                        label: 'Erişilebilir',
                      ),
                    if (parking.isCovered)
                      const _FeatureChip(
                        icon: Icons.roofing_outlined,
                        label: 'Kapalı',
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5F3),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
