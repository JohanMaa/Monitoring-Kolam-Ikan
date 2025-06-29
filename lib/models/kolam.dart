import 'package:flutter/material.dart';
import 'sensor_data.dart';

// Kelas untuk menyimpan data kolam
class Kolam {
  String id;
  String name;
  SensorData data;
  Map<String, SensorThreshold> thresholds;
  Map<String, SensorCardData> sensorData;

  // Konstruktor dengan parameter wajib
  Kolam({
    required this.id,
    required this.name,
    required this.data,
    required this.thresholds,
    required this.sensorData,
  });

  // Memperbarui data kartu sensor
  void updateSensorCards() {
    final statuses = getSensorStatuses() ?? {};
    sensorData = {
      'suhu': SensorCardData(
        icon: const Icon(Icons.thermostat),
        label: 'Suhu',
        value: '${data.suhu.toStringAsFixed(1)} ',
        color: getColorForStatus(statuses['suhu'] ?? SensorStatus.normal),
      ),
      'ph': SensorCardData(
        icon: const Icon(Icons.opacity),
        label: 'pH',
        value: '${data.ph.toStringAsFixed(1)}',
        color: getColorForStatus(statuses['ph'] ?? SensorStatus.normal),
      ),
      'dissolvedOxygen': SensorCardData(
        icon: const Icon(Icons.waves),
        label: 'DO',
        value: '${data.dissolvedOxygen.toStringAsFixed(1)} ',
        color: getColorForStatus(statuses['dissolvedOxygen'] ?? SensorStatus.normal),
      ),
      'berat': SensorCardData(
        icon: const Icon(Icons.fastfood),
        label: 'Berat Pakan',
        value: '${data.berat.toStringAsFixed(1)} ',
        color: getColorForStatus(statuses['berat'] ?? SensorStatus.normal),
      ),
      'tinggiAir': SensorCardData(
        icon: const Icon(Icons.water_drop),
        label: 'Level Air',
        value: '${data.tinggiAir.toStringAsFixed(1)} ',
        color: getColorForStatus(statuses['tinggiAir'] ?? SensorStatus.normal),
      ),
    };
  }

  // Menentukan warna berdasarkan status sensor
  Color getColorForStatus(SensorStatus status) {
    switch (status) {
      case SensorStatus.normal:
        return Colors.green;
      case SensorStatus.kritis:
        return Colors.orange;
      case SensorStatus.darurat:
        return Colors.red;
    }
  }

  // Membuat instance kolam baru
  factory Kolam.generate(String id, String name, {SensorData? initialData}) {
    // Gunakan initialData jika diberikan, jika tidak buat data dengan nilai 0
    final sensorData = initialData ??
        SensorData(
          suhu: 0,
          ph: 0,
          dissolvedOxygen: 0,
          berat: 0,
          tinggiAir: 0,
          sensorType: 'Suhu',
          value: 0,
        );
    return Kolam(
      id: id,
      name: name,
      data: sensorData,
      thresholds: {
        'suhu': SensorThreshold(
          normalMin: 20,
          normalMax: 30,
          criticalMin: 15,
          criticalMax: 35,
        ),
        'ph': SensorThreshold(
          normalMin: 6.5,
          normalMax: 8.0,
          criticalMin: 5.0,
          criticalMax: 9.0,
        ),
        'dissolvedOxygen': SensorThreshold(
          normalMin: 5,
          normalMax: 8,
          criticalMin: 3,
          criticalMax: 10,
        ),
        'berat': SensorThreshold(
          normalMin: 0,
          normalMax: 5,
          criticalMin: -5,
          criticalMax: 10,
        ),
        'tinggiAir': SensorThreshold(
          normalMin: 10,
          normalMax: 50,
          criticalMin: 5,
          criticalMax: 60,
        ),
      },
      sensorData: {},
    )..updateSensorCards();
  }

  // Memperbarui data sensor
  void updateSensorData(SensorData newData) {
    data = newData;
    updateSensorCards();
  }

  // Mendapatkan status sensor
  Map<String, SensorStatus>? getSensorStatuses() {
    return data.getStatusMap(thresholds);
  }
}

// Kelas untuk menyimpan data kartu sensor
class SensorCardData {
  final Widget icon;
  final String label;
  final String value;
  final Color color;

  // Konstruktor dengan parameter wajib
  SensorCardData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  // Membuat salinan dengan nilai tertentu
  SensorCardData copyWith({String? value, Color? color}) {
    return SensorCardData(
      icon: icon,
      label: label,
      value: value ?? this.value,
      color: color ?? this.color,
    );
  }
}