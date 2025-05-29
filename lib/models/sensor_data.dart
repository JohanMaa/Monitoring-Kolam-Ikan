import 'dart:math';

class SensorData {
  final double suhu;
  final double ph;
  final double kekeruhan;
  final double dissolvedOxygen;
  final double berat;
  final double tinggiAir;
  final String sensorType;
  final double value;

  SensorData({
    required this.suhu,
    required this.ph,
    required this.kekeruhan,
    required this.dissolvedOxygen,
    required this.berat,
    required this.tinggiAir,
    required this.sensorType,
    required this.value,
  });

  SensorData copyWith({
    double? suhu,
    double? ph,
    double? kekeruhan,
    double? dissolvedOxygen,
    double? berat,
    double? tinggiAir,
    String? sensorType,
    double? value,
  }) {
    return SensorData(
      suhu: suhu ?? this.suhu,
      ph: ph ?? this.ph,
      kekeruhan: kekeruhan ?? this.kekeruhan,
      dissolvedOxygen: dissolvedOxygen ?? this.dissolvedOxygen,
      berat: berat ?? this.berat,
      tinggiAir: tinggiAir ?? this.tinggiAir,
      sensorType: sensorType ?? this.sensorType,
      value: value ?? this.value,
    );
  }

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      suhu: (json['suhu'] ?? 0).toDouble(),
      ph: (json['ph'] ?? 0).toDouble(),
      kekeruhan: (json['kekeruhan'] ?? 0).toDouble(),
      dissolvedOxygen: (json['do'] ?? 0).toDouble(),
      berat: (json['berat_pakan'] ?? 0).toDouble(),
      tinggiAir: (json['level_air'] ?? 0).toDouble(),
      sensorType: json['sensorType'] ?? 'Unknown',
      value: (json['value'] ?? 0).toDouble(),
    );
  }

  factory SensorData.generateRandom() {
    final Random rand = Random();
    final List<String> sensorTypes = ['Suhu', 'pH', 'Kekeruhan', 'DO', 'Berat Pakan', 'Level Air'];
    return SensorData(
      suhu: 15 + rand.nextDouble() * 15, // 15 - 30°C
      ph: 5 + rand.nextDouble() * 3, // 5 - 8
      kekeruhan: 10 + rand.nextDouble() * 40, // 10 - 50 NTU
      dissolvedOxygen: 3 + rand.nextDouble() * 7, // 3 - 10 mg/L
      berat: rand.nextDouble() * 5, // 0 - 5 Kg
      tinggiAir: 10 + rand.nextDouble() * 40, // 10 - 50%
      sensorType: sensorTypes[rand.nextInt(sensorTypes.length)],
      value: rand.nextDouble() * 100,
    );
  }

  Map<String, SensorStatus> getStatusMap(Map<String, SensorThreshold> thresholds) {
    return {
      'suhu': getStatus(suhu, thresholds['suhu']!),
      'ph': getStatus(ph, thresholds['ph']!),
      'kekeruhan': getStatus(kekeruhan, thresholds['kekeruhan']!),
      'dissolved_oxygen': getStatus(dissolvedOxygen, thresholds['do']!),
      'berat': getStatus(berat, thresholds['berat']!),
      'tinggi_air': getStatus(tinggiAir, thresholds['tinggi_air']!),
    };
  }

  SensorStatus getStatus(double value, SensorThreshold threshold) {
    if (value >= threshold.normalMin && value <= threshold.normalMax) {
      return SensorStatus.normal;
    } else if (value >= threshold.criticalMin && value <= threshold.criticalMax) {
      return SensorStatus.kritis;
    } else {
      return SensorStatus.darurat;
    }
  }
}

enum SensorStatus {
  normal,
  kritis,
  darurat,
}

class SensorThreshold {
  final double normalMin;
  final double normalMax;
  final double criticalMin;
  final double criticalMax;

  SensorThreshold({
    required this.normalMin,
    required this.normalMax,
    required this.criticalMin,
    required this.criticalMax,
  });

  Map<String, dynamic> toJson() => {
        'normalMin': normalMin,
        'normalMax': normalMax,
        'criticalMin': criticalMin,
        'criticalMax': criticalMax,
      };

  factory SensorThreshold.fromJson(Map<String, dynamic> json) {
    return SensorThreshold(
      normalMin: (json['normalMin'] ?? 0).toDouble(),
      normalMax: (json['normalMax'] ?? 0).toDouble(),
      criticalMin: (json['criticalMin'] ?? 0).toDouble(),
      criticalMax: (json['criticalMax'] ?? 0).toDouble(),
    );
  }
}