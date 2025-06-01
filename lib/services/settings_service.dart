import 'package:flutter/foundation.dart';
import 'package:monitoring_kolam_ikan/models/sensor_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'default_threshold.dart';

class SettingsService {
  // ValueNotifier untuk notifikasi perubahan thresholds
  static final ValueNotifier<Map<String, SensorThreshold>> _thresholdsNotifier =
      ValueNotifier<Map<String, SensorThreshold>>(defaultThresholds);

  // Getter untuk ValueNotifier
  static ValueNotifier<Map<String, SensorThreshold>> get thresholdsNotifier => _thresholdsNotifier;

  // Mengambil threshold yang disimpan dari SharedPreferences
  static Future<Map<String, SensorThreshold>> getThresholds() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    final thresholds = {
      'suhu': SensorThreshold(
        normalMin: prefs.getDouble('suhu_normal_min') ?? defaultThresholds['suhu']!.normalMin,
        normalMax: prefs.getDouble('suhu_normal_max') ?? defaultThresholds['suhu']!.normalMax,
        criticalMin: prefs.getDouble('suhu_critical_min') ?? defaultThresholds['suhu']!.criticalMin,
        criticalMax: prefs.getDouble('suhu_critical_max') ?? defaultThresholds['suhu']!.criticalMax,
      ),
      'ph': SensorThreshold(
        normalMin: prefs.getDouble('ph_normal_min') ?? defaultThresholds['ph']!.normalMin,
        normalMax: prefs.getDouble('ph_normal_max') ?? defaultThresholds['ph']!.normalMax,
        criticalMin: prefs.getDouble('ph_critical_min') ?? defaultThresholds['ph']!.criticalMin,
        criticalMax: prefs.getDouble('ph_critical_max') ?? defaultThresholds['ph']!.criticalMax,
      ),
      'do': SensorThreshold(
        normalMin: prefs.getDouble('do_normal_min') ?? defaultThresholds['do']!.normalMin,
        normalMax: prefs.getDouble('do_normal_max') ?? defaultThresholds['do']!.normalMax,
        criticalMin: prefs.getDouble('do_critical_min') ?? defaultThresholds['do']!.criticalMin,
        criticalMax: prefs.getDouble('do_critical_max') ?? defaultThresholds['do']!.criticalMax,
      ),
      'berat': SensorThreshold(
        normalMin: prefs.getDouble('berat_normal_min') ?? defaultThresholds['berat']!.normalMin,
        normalMax: prefs.getDouble('berat_normal_max') ?? defaultThresholds['berat']!.normalMax,
        criticalMin: prefs.getDouble('berat_critical_min') ?? defaultThresholds['berat']!.criticalMin,
        criticalMax: prefs.getDouble('berat_critical_max') ?? defaultThresholds['berat']!.criticalMax,
      ),
      'tinggi_air': SensorThreshold(
        normalMin: prefs.getDouble('tinggi_air_normal_min') ?? defaultThresholds['tinggi_air']!.normalMin,
        normalMax: prefs.getDouble('tinggi_air_normal_max') ?? defaultThresholds['tinggi_air']!.normalMax,
        criticalMin: prefs.getDouble('tinggi_air_critical_min') ?? defaultThresholds['tinggi_air']!.criticalMin,
        criticalMax: prefs.getDouble('tinggi_air_critical_max') ?? defaultThresholds['tinggi_air']!.criticalMax,
      ),
    };

    // Perbarui ValueNotifier dengan data yang diambil
    _thresholdsNotifier.value = thresholds;
    return thresholds;
  }

  // Menyimpan semua threshold sekaligus ke SharedPreferences
  static Future<void> setThresholds(Map<String, SensorThreshold> thresholds) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Simpan thresholds untuk semua sensor
    prefs.setDouble('suhu_normal_min', thresholds['suhu']!.normalMin);
    prefs.setDouble('suhu_normal_max', thresholds['suhu']!.normalMax);
    prefs.setDouble('suhu_critical_min', thresholds['suhu']!.criticalMin);
    prefs.setDouble('suhu_critical_max', thresholds['suhu']!.criticalMax);

    prefs.setDouble('ph_normal_min', thresholds['ph']!.normalMin);
    prefs.setDouble('ph_normal_max', thresholds['ph']!.normalMax);
    prefs.setDouble('ph_critical_min', thresholds['ph']!.criticalMin);
    prefs.setDouble('ph_critical_max', thresholds['ph']!.criticalMax);

    prefs.setDouble('do_normal_min', thresholds['do']!.normalMin);
    prefs.setDouble('do_normal_max', thresholds['do']!.normalMax);
    prefs.setDouble('do_critical_min', thresholds['do']!.criticalMin);
    prefs.setDouble('do_critical_max', thresholds['do']!.criticalMax);

    prefs.setDouble('berat_normal_min', thresholds['berat']!.normalMin);
    prefs.setDouble('berat_normal_max', thresholds['berat']!.normalMax);
    prefs.setDouble('berat_critical_min', thresholds['berat']!.criticalMin);
    prefs.setDouble('berat_critical_max', thresholds['berat']!.criticalMax);

    prefs.setDouble('tinggi_air_normal_min', thresholds['tinggi_air']!.normalMin);
    prefs.setDouble('tinggi_air_normal_max', thresholds['tinggi_air']!.normalMax);
    prefs.setDouble('tinggi_air_critical_min', thresholds['tinggi_air']!.criticalMin);
    prefs.setDouble('tinggi_air_critical_max', thresholds['tinggi_air']!.criticalMax);

    // Perbarui ValueNotifier untuk notifikasi perubahan
    _thresholdsNotifier.value = thresholds;
  }

  // Menyimpan threshold untuk sensor tertentu (opsional, tetap dipertahankan untuk kompatibilitas)
  static Future<void> saveThreshold(String sensor, SensorThreshold newThreshold) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    prefs.setDouble('${sensor}_normal_min', newThreshold.normalMin);
    prefs.setDouble('${sensor}_normal_max', newThreshold.normalMax);
    prefs.setDouble('${sensor}_critical_min', newThreshold.criticalMin);
    prefs.setDouble('${sensor}_critical_max', newThreshold.criticalMax);

    // Ambil thresholds saat ini dan perbarui hanya untuk sensor yang diubah
    final currentThresholds = await getThresholds();
    currentThresholds[sensor] = newThreshold;

    // Perbarui ValueNotifier
    _thresholdsNotifier.value = currentThresholds;
  }
}