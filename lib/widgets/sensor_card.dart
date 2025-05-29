import 'package:flutter/material.dart';
import 'package:monitoring_kolam_ikan/models/sensor_data.dart';

class SensorCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final SensorStatus status;
  final SensorData? data;

  const SensorCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.status,
    this.data,
  });

  Color _getStatusColor(SensorStatus status) {
    switch (status) {
      case SensorStatus.normal:
        return Colors.greenAccent.shade100;
      case SensorStatus.kritis:
        return Colors.orangeAccent.shade100;
      case SensorStatus.darurat:
        return Colors.redAccent.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _getStatusColor(status),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Hapus const
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$value $unit',
                  style: const TextStyle(fontSize: 20),
                ),
                Icon(
                  status == SensorStatus.normal
                      ? Icons.check_circle
                      : status == SensorStatus.kritis
                          ? Icons.warning_amber_rounded
                          : Icons.error,
                  color: status == SensorStatus.normal
                      ? Colors.green
                      : status == SensorStatus.kritis
                          ? Colors.orange
                          : Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}