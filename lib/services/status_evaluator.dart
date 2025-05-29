// lib/services/status_evaluator.dart

import 'package:monitoring_kolam_ikan/models/sensor_data.dart';

class StatusEvaluator {
  // Fungsi untuk mengevaluasi status sensor berdasarkan nilai sensor dan threshold
  static SensorStatus evaluateStatus(double value, SensorThreshold threshold) {
    if (value >= threshold.normalMin && value <= threshold.normalMax) {
      return SensorStatus.normal;
    } else if (value >= threshold.criticalMin && value <= threshold.criticalMax) {
      return SensorStatus.kritis;
    } else {
      return SensorStatus.darurat;
    }
  }

  // Fungsi untuk mengevaluasi status semua sensor
  static Map<String, SensorStatus> evaluateAll(
    SensorData sensorData,
    Map<String, SensorThreshold> thresholds,
  ) {
    return {
      'suhu': evaluateStatus(sensorData.suhu, thresholds['suhu']!),
      'ph': evaluateStatus(sensorData.ph, thresholds['ph']!),
      'kekeruhan': evaluateStatus(sensorData.kekeruhan, thresholds['kekeruhan']!),
    };
  }
}
