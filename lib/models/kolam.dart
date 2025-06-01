import 'package:flutter/material.dart';
import 'sensor_data.dart';

class Kolam {
  String name;
  SensorData data;
  Map<String, SensorThreshold> thresholds;
  List<SensorCardData> sensorData;

  Kolam({
    required this.name,
    required this.data,
    required this.thresholds,
    required this.sensorData,
  });

  void updateSensorCards() {
    final statuses = getSensorStatuses() ?? {};
    sensorData = [
      SensorCardData(
        icon: const Icon(Icons.thermostat),
        label: 'Suhu',
        value: '${data.suhu.toStringAsFixed(1)} °C',
        color: getColorForStatus(statuses['suhu'] ?? SensorStatus.normal),
      ),
      SensorCardData(
        icon: const Icon(Icons.opacity),
        label: 'pH',
        value: '${data.ph.toStringAsFixed(1)}',
        color: getColorForStatus(statuses['ph'] ?? SensorStatus.normal),
      ),
      SensorCardData(
        icon: const Icon(Icons.waves),
        label: 'DO',
        value: '${data.dissolvedOxygen.toStringAsFixed(1)} mg/L',
        color: getColorForStatus(statuses['dissolved_oxygen'] ?? SensorStatus.normal),
      ),
      SensorCardData(
        icon: const Icon(Icons.fastfood),
        label: 'Berat Pakan',
        value: '${data.berat.toStringAsFixed(1)} Kg',
        color: getColorForStatus(statuses['berat'] ?? SensorStatus.normal),
      ),
      SensorCardData(
        icon: const Icon(Icons.water_drop),
        label: 'Level Air',
        value: '${data.tinggiAir.toStringAsFixed(1)} %',
        color: getColorForStatus(statuses['tinggi_air'] ?? SensorStatus.normal),
      ),
    ];
  }

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

  factory Kolam.generate(String id, String name) {
    final initialData = SensorData.generateRandom();
    return Kolam(
      name: name,
      data: initialData,
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
        'do': SensorThreshold(
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
        'tinggi_air': SensorThreshold(
          normalMin: 10,
          normalMax: 50,
          criticalMin: 5,
          criticalMax: 60,
        ),
      },
      sensorData: [], // Akan diisi oleh updateSensorCards
    )..updateSensorCards(); // Panggil langsung untuk inisialisasi
  }

  void updateSensorData(SensorData newData) {
    data = newData;
    updateSensorCards();
  }

  Map<String, SensorStatus>? getSensorStatuses() {
    return data.getStatusMap(thresholds);
  }
}

class SensorCardData {
  final Widget icon;
  final String label;
  final String value;
  final Color color;

  SensorCardData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  SensorCardData copyWith({String? value, Color? color}) {
    return SensorCardData(
      icon: icon,
      label: label,
      value: value ?? this.value,
      color: color ?? this.color,
    );
  }
}