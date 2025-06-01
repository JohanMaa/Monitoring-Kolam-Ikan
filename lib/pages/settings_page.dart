import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:monitoring_kolam_ikan/services/mqtt_service.dart';
import '../models/sensor_data.dart';
import '../services/settings_service.dart';
import '../services/default_threshold.dart';

class SettingsPage extends StatefulWidget {
  final MqttService mqttService;

  const SettingsPage({super.key, required this.mqttService});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  final Map<String, TextEditingController> controllers = {};
  final List<String> sensorNames = [
    'suhu',
    'ph',
    'do',
    'berat',
    'tinggi_air'
  ];
  Map<String, SensorThreshold> thresholds = {};
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    _loadAllThresholds();
  }

  Future<void> _loadAllThresholds() async {
    final savedThresholds = await SettingsService.getThresholds();
    thresholds = savedThresholds;

    for (var sensor in sensorNames) {
      final saved = savedThresholds[sensor];
      final th = saved ?? defaultThresholds[sensor]!;

      controllers['$sensor-normalMin'] =
          TextEditingController(text: th.normalMin.toString());
      controllers['$sensor-normalMax'] =
          TextEditingController(text: th.normalMax.toString());
      controllers['$sensor-criticalMin'] =
          TextEditingController(text: th.criticalMin.toString());
      controllers['$sensor-criticalMax'] =
          TextEditingController(text: th.criticalMax.toString());
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveThresholds() async {
    final newThresholds = <String, SensorThreshold>{};
    for (var sensor in sensorNames) {
      final newThreshold = SensorThreshold(
        normalMin: double.tryParse(controllers['$sensor-normalMin']!.text) ?? 0.0,
        normalMax: double.tryParse(controllers['$sensor-normalMax']!.text) ?? 0.0,
        criticalMin: double.tryParse(controllers['$sensor-criticalMin']!.text) ?? 0.0,
        criticalMax: double.tryParse(controllers['$sensor-criticalMax']!.text) ?? 0.0,
      );
      newThresholds[sensor] = newThreshold;
      await SettingsService.saveThreshold(sensor, newThreshold);
    }
    thresholds = newThresholds;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ambang batas berhasil disimpan!')),
      );
    }
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && mounted) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Widget _buildThresholdInput(String sensor) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sensor.toUpperCase(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _inputField(
                    sensor: sensor,
                    key: 'normalMin',
                    label: 'Normal Min',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _inputField(
                    sensor: sensor,
                    key: 'normalMax',
                    label: 'Normal Max',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _inputField(
                    sensor: sensor,
                    key: 'criticalMin',
                    label: 'Kritis Min',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _inputField(
                    sensor: sensor,
                    key: 'criticalMax',
                    label: 'Kritis Max',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField({
    required String sensor,
    required String key,
    required String label,
  }) {
    return TextField(
      controller: controllers['$sensor-$key'],
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
    );
  }

  Widget _buildProfile(
      String name, String role, String description, String imageAsset) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: GestureDetector(
        onTap: _pickProfileImage,
        child: CircleAvatar(
          radius: 28,
          backgroundImage: _profileImage != null
              ? FileImage(_profileImage!)
              : AssetImage(imageAsset) as ImageProvider,
        ),
      ),
      title: Text(name),
      subtitle: Text(role),
      onTap: () => _showProfileDialog(name, role, description, imageAsset),
    );
  }

  void _showProfileDialog(
      String name, String role, String description, String imageAsset) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: _profileImage != null
                  ? FileImage(_profileImage!)
                  : AssetImage(imageAsset) as ImageProvider,
            ),
            const SizedBox(height: 12),
            Text(
              role,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(description),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tutup"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: thresholds.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                const SizedBox(height: 8),
                const Text(
                  "Profil Tim",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                _buildProfile(
                  "Johan Maulana",
                  "Flutter Developer",
                  "Johan adalah pengembang Flutter dengan minat pada aplikasi IoT.",
                  "assets/johan.jpg",
                ),
                _buildProfile(
                  "Muhammad Rifki Nuryasin",
                  "UI/UX Designer",
                  "Rifki merancang tampilan dan pengalaman pengguna aplikasi ini.",
                  "assets/rifki.jpg",
                ),
                _buildProfile(
                  "Rohmat Cahyo Susilo",
                  "Backend Engineer",
                  "Rohmat menangani komunikasi MQTT dan backend sistem.",
                  "assets/rohmat.jpg",
                ),
                const SizedBox(height: 16),
                const Divider(thickness: 1.2),
                const Text(
                  "Ambang Batas Sensor",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ...sensorNames.map((sensor) => _buildThresholdInput(sensor)),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton.icon(
                    onPressed: _saveThresholds,
                    icon: const Icon(Icons.save),
                    label: const Text('Simpan Pengaturan'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(thickness: 1.2),
                const Text(
                  "Info Aplikasi",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                _buildAppInfo(),
              ],
            ),
    );
  }

  Widget _buildAppInfo() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(Icons.info_outline),
          title: Text("Nama Aplikasi"),
          subtitle: Text("Monitoring Kolam Ikan"),
        ),
        ListTile(
          leading: Icon(Icons.update),
          title: Text("Versi"),
          subtitle: Text("1.0.0"),
        ),
        ListTile(
          leading: Icon(Icons.people),
          title: Text("Tim Pengembang"),
          subtitle: Text("Johan, Rifki, Rohmat"),
        ),
        ListTile(
          leading: Icon(Icons.copyright),
          title: Text("Hak Cipta"),
          subtitle: Text("© 2025 MonitoringKolam Team"),
        ),
      ],
    );
  }
}