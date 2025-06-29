import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:monitoring_kolam_ikan/services/default_threshold.dart';
import 'dart:io';
import 'package:monitoring_kolam_ikan/services/mqtt_service.dart';
import 'package:monitoring_kolam_ikan/models/sensor_data.dart';
import 'package:monitoring_kolam_ikan/services/settings_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Halaman pengaturan aplikasi
class SettingsPage extends StatefulWidget {
  final MqttService mqttService;
  final Function(Map<String, SensorThreshold>) onThresholdsChanged;

  const SettingsPage({super.key, required this.mqttService, required this.onThresholdsChanged});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  final Map<String, TextEditingController> controllers = {};
  final List<String> sensorNames = ['suhu', 'ph', 'dissolvedOxygen', 'berat', 'tinggiAir'];
  Map<String, SensorThreshold> thresholds = {};
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    _loadAllThresholds();
    _loadProfileImage();
    SettingsService.thresholdsNotifier.addListener(_onThresholdsChanged);
  }

  void _onThresholdsChanged() {
    setState(() {
      thresholds = SettingsService.thresholdsNotifier.value;
      for (var sensor in sensorNames) {
        final th = thresholds[sensor] ?? defaultThresholds[sensor]!;
        controllers['$sensor-normalMin']?.text = th.normalMin.toStringAsFixed(2);
        controllers['$sensor-normalMax']?.text = th.normalMax.toStringAsFixed(2);
        controllers['$sensor-criticalMin']?.text = th.criticalMin.toStringAsFixed(2);
        controllers['$sensor-criticalMax']?.text = th.criticalMax.toStringAsFixed(2);
      }
    });
    widget.onThresholdsChanged(thresholds);
  }

  Future<void> _loadAllThresholds() async {
    final savedThresholds = await SettingsService.getThresholds();
    setState(() {
      thresholds = Map.from(defaultThresholds);
      thresholds.addAll(savedThresholds);
      for (var sensor in sensorNames) {
        final th = thresholds[sensor] ?? defaultThresholds[sensor]!;
        controllers['$sensor-normalMin'] = TextEditingController(text: th.normalMin.toStringAsFixed(2));
        controllers['$sensor-normalMax'] = TextEditingController(text: th.normalMax.toStringAsFixed(2));
        controllers['$sensor-criticalMin'] = TextEditingController(text: th.criticalMin.toStringAsFixed(2));
        controllers['$sensor-criticalMax'] = TextEditingController(text: th.criticalMax.toStringAsFixed(2));
      }
    });
    widget.onThresholdsChanged(thresholds);
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image_path');
    if (imagePath != null && File(imagePath).existsSync()) {
      if (mounted) {
        setState(() {
          _profileImage = File(imagePath);
        });
      }
    }
  }

  Future<void> _saveThresholds() async {
    final newThresholds = <String, SensorThreshold>{};
    for (var sensor in sensorNames) {
      final normalMin = double.tryParse(controllers['$sensor-normalMin']!.text) ?? defaultThresholds[sensor]!.normalMin;
      final normalMax = double.tryParse(controllers['$sensor-normalMax']!.text) ?? defaultThresholds[sensor]!.normalMax;
      final criticalMin = double.tryParse(controllers['$sensor-criticalMin']!.text) ?? defaultThresholds[sensor]!.criticalMin;
      final criticalMax = double.tryParse(controllers['$sensor-criticalMax']!.text) ?? defaultThresholds[sensor]!.criticalMax;

      if (normalMin > normalMax) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Normal Min untuk ${getSensorLabel(sensor)} tidak boleh lebih besar dari Normal Max')),
          );
        }
        return;
      }
      if (criticalMin > criticalMax) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Critical Min untuk ${getSensorLabel(sensor)} tidak boleh lebih besar dari Critical Max')),
          );
        }
        return;
      }

      final newThreshold = SensorThreshold(
        normalMin: normalMin,
        normalMax: normalMax,
        criticalMin: criticalMin,
        criticalMax: criticalMax,
      );
      newThresholds[sensor] = newThreshold;
    }

    setState(() {
      thresholds = newThresholds;
    });
    await SettingsService.setThresholds(thresholds);
    widget.onThresholdsChanged(thresholds);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ambang batas berhasil disimpan!')),
      );
    }
  }

  String getSensorLabel(String sensor) {
    return sensor == 'suhu'
        ? 'Suhu'
        : sensor == 'ph'
            ? 'pH'
            : sensor == 'dissolvedOxygen'
                ? 'DO'
                : sensor == 'berat'
                    ? 'Berat Pakan'
                    : 'Level Air';
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && mounted) {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/profile_image.jpg';
      final newImage = await File(pickedFile.path).copy(imagePath);
      setState(() {
        _profileImage = newImage;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_path', imagePath);
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
              getSensorLabel(sensor),
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

  Widget _buildProfile(String name, String role, String description, String imageAsset) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: GestureDetector(
        onTap: _pickProfileImage,
        child: CircleAvatar(
          radius: 28,
          backgroundImage: _profileImage != null
              ? FileImage(_profileImage!)
              : const AssetImage('assets/default_profile.jpg') as ImageProvider,
        ),
      ),
      title: Text(name),
      subtitle: Text(role),
      onTap: () => _showProfileDialog(name, role, description, imageAsset),
    );
  }

  void _showProfileDialog(String name, String role, String description, String imageAsset) {
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
                  : const AssetImage('assets/default_profile.jpg') as ImageProvider,
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
                        borderRadius: BorderRadius.circular(12),
                      ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _infoRow(Icons.info_outline, "Nama Aplikasi", "Monitoring Kolam Ikan"),
          _infoRow(Icons.update, "Versi", "1.1.2"),
          _infoRow(Icons.people, "Tim Pengembang", "Johan, Rifki, Rohmat"),
          _infoRow(Icons.copyright, "Hak Cipta", "© 2025 Monitoring Kolam Team"),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Colors.blueGrey.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  @override
  void dispose() {
    SettingsService.thresholdsNotifier.removeListener(_onThresholdsChanged);
    controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }
}