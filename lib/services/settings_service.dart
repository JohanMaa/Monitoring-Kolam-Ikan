import 'package:flutter/foundation.dart';
import 'package:monitoring_kolam_ikan/models/sensor_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monitoring_kolam_ikan/services/default_threshold.dart';
import 'dart:convert';

// Kelas untuk mengelola penyimpanan pengaturan
class SettingsService {
  // ValueNotifier untuk notifikasi perubahan thresholds
  static final ValueNotifier<Map<String, SensorThreshold>> _thresholdsNotifier =
      ValueNotifier<Map<String, SensorThreshold>>(defaultThresholds);

  // Getter untuk ValueNotifier
  static ValueNotifier<Map<String, SensorThreshold>> get thresholdsNotifier => _thresholdsNotifier;

  // Mengambil threshold yang disimpan dari SharedPreferences
  static Future<Map<String, SensorThreshold>> getThresholds() async {
    final prefs = await SharedPreferences.getInstance();
    final String? thresholdsJson = prefs.getString('thresholds');
    if (thresholdsJson == null) {
      _thresholdsNotifier.value = defaultThresholds;
      return defaultThresholds;
    }
    try {
      final Map<String, dynamic> decoded = jsonDecode(thresholdsJson);
      final thresholds = decoded.map((key, value) => MapEntry(key, SensorThreshold.fromJson(value)));
      _thresholdsNotifier.value = thresholds;
      return thresholds;
    } catch (e) {
      _thresholdsNotifier.value = defaultThresholds;
      return defaultThresholds;
    }
  }

  // Menyimpan semua threshold ke SharedPreferences
  static Future<void> setThresholds(Map<String, SensorThreshold> thresholds) async {
    final prefs = await SharedPreferences.getInstance();
    final thresholdsJson = thresholds.map((key, value) => MapEntry(key, value.toJson()));
    await prefs.setString('thresholds', jsonEncode(thresholdsJson));
    _thresholdsNotifier.value = thresholds;
  }
}