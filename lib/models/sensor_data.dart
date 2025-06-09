// Enum untuk status sensor
enum SensorStatus { normal, kritis, darurat }

// Kelas untuk menyimpan ambang batas sensor
class SensorThreshold {
  final double normalMin;
  final double normalMax;
  final double criticalMin;
  final double criticalMax;

  // Konstruktor dengan parameter wajib
  const SensorThreshold({
    required this.normalMin,
    required this.normalMax,
    required this.criticalMin,
    required this.criticalMax,
  });

  // Membuat instance dari JSON
  factory SensorThreshold.fromJson(Map<String, dynamic> json) {
    return SensorThreshold(
      normalMin: (json['normalMin'] as num).toDouble(),
      normalMax: (json['normalMax'] as num).toDouble(),
      criticalMin: (json['criticalMin'] as num).toDouble(),
      criticalMax: (json['criticalMax'] as num).toDouble(),
    );
  }

  // Mengonversi ke format JSON
  Map<String, dynamic> toJson() {
    return {
      'normalMin': normalMin,
      'normalMax': normalMax,
      'criticalMin': criticalMin,
      'criticalMax': criticalMax,
    };
  }
}

// Kelas untuk menyimpan data sensor
class SensorData {
  final double suhu;
  final double ph;
  final double dissolvedOxygen;
  final double berat;
  final double tinggiAir;
  final String sensorType;
  final double value;

  // Konstruktor dengan parameter wajib
  const SensorData({
    required this.suhu,
    required this.ph,
    required this.dissolvedOxygen,
    required this.berat,
    required this.tinggiAir,
    required this.sensorType,
    required this.value,
  });

  // Membuat instance dari JSON
  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      suhu: (json['suhu'] as num).toDouble(),
      ph: (json['ph'] as num).toDouble(),
      dissolvedOxygen: (json['dissolvedOxygen'] as num).toDouble(),
      berat: (json['berat'] as num).toDouble(),
      tinggiAir: (json['tinggiAir'] as num).toDouble(),
      sensorType: json['sensorType'] as String,
      value: (json['value'] as num).toDouble(),
    );
  }

  // Mengonversi ke format JSON
  Map<String, dynamic> toJson() {
    return {
      'suhu': suhu,
      'ph': ph,
      'dissolvedOxygen': dissolvedOxygen,
      'berat': berat,
      'tinggiAir': tinggiAir,
      'sensorType': sensorType,
      'value': value,
    };
  }

  // Mendapatkan status sensor berdasarkan ambang batas
  Map<String, SensorStatus> getStatusMap(Map<String, SensorThreshold> thresholds) {
    final statusMap = <String, SensorStatus>{};

    // Suhu
    final suhuThreshold = thresholds['suhu']!;
    statusMap['suhu'] = _getStatus(suhu, suhuThreshold);

    // pH
    final phThreshold = thresholds['ph']!;
    statusMap['ph'] = _getStatus(ph, phThreshold);

    // Dissolved Oxygen (DO)
    final doThreshold = thresholds['do']!;
    statusMap['do'] = _getStatus(dissolvedOxygen, doThreshold);

    // Berat
    final beratThreshold = thresholds['berat']!;
    statusMap['berat'] = _getStatus(berat, beratThreshold);

    // Tinggi Air
    final tinggiAirThreshold = thresholds['tinggi_air']!;
    statusMap['tinggi_air'] = _getStatus(tinggiAir, tinggiAirThreshold);

    return statusMap;
  }

  // Menentukan status sensor berdasarkan nilai dan ambang batas
  SensorStatus _getStatus(double value, SensorThreshold threshold) {
    if (value >= threshold.normalMin && value <= threshold.normalMax) {
      return SensorStatus.normal;
    } else if (value < threshold.criticalMin || value > threshold.criticalMax) {
      return SensorStatus.darurat;
    } else {
      return SensorStatus.kritis;
    }
  }
}