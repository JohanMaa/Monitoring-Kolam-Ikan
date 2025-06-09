import 'package:monitoring_kolam_ikan/models/sensor_data.dart';

// Definisi ambang batas default untuk berbagai jenis sensor
Map<String, SensorThreshold> defaultThresholds = {
  'suhu': SensorThreshold(normalMin: 20, normalMax: 30, criticalMin: 10, criticalMax: 40),
  'ph': SensorThreshold(normalMin: 6.5, normalMax: 8, criticalMin: 5.5, criticalMax: 9),
  'do': SensorThreshold(normalMin: 5, normalMax: 8, criticalMin: 3, criticalMax: 10),
  'berat': SensorThreshold(normalMin: 0, normalMax: 5, criticalMin: -2, criticalMax: 10),
  'tinggi_air': SensorThreshold(normalMin: 10, normalMax: 50, criticalMin: 5, criticalMax: 60),
};