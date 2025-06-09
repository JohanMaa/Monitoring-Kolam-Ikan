import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monitoring_kolam_ikan/services/mqtt_service.dart';
import 'package:mqtt_client/mqtt_client.dart';

// Halaman untuk mengatur koneksi MQTT
class ConnectionPage extends StatefulWidget {
  final MqttService mqttService;
  final VoidCallback onConnected;

  // Konstruktor dengan parameter wajib
  const ConnectionPage({
    super.key,
    required this.mqttService,
    required this.onConnected,
    required MqttConnectionState connectionStatus,
  });

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

// State untuk mengelola logika halaman koneksi
class _ConnectionPageState extends State<ConnectionPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController brokerController = TextEditingController();
  final TextEditingController portController = TextEditingController();
  final TextEditingController topicController = TextEditingController();

  String _statusMessage = 'Belum terkoneksi';
  bool isConnecting = false;

  // Inisialisasi state dan konfigurasi
  @override
  void initState() {
    super.initState();
    _loadSavedConfiguration();
    // Tambahkan listener untuk status koneksi
    widget.mqttService.client.updates?.listen((event) {
      final connectionState = widget.mqttService.client.connectionStatus?.state;
      if (connectionState == MqttConnectionState.connected) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Terhubung ke MQTT broker';
            isConnecting = false;
          });
        }
      } else if (connectionState == MqttConnectionState.disconnected) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Terputus dari MQTT broker';
            isConnecting = false;
          });
        }
      }
    });
  }

  // Memuat konfigurasi tersimpan
  Future<void> _loadSavedConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      brokerController.text = prefs.getString('mqtt_broker') ?? widget.mqttService.broker;
      portController.text = prefs.getInt('mqtt_port')?.toString() ?? widget.mqttService.port.toString();
      topicController.text = prefs.getString('mqtt_topic') ?? widget.mqttService.topic;
    });
  }

  // Menyimpan konfigurasi ke penyimpanan
  Future<void> _saveConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mqtt_broker', brokerController.text);
    await prefs.setInt('mqtt_port', int.parse(portController.text));
    await prefs.setString('mqtt_topic', topicController.text);
  }

  // Membersihkan sumber daya
  @override
  void dispose() {
    brokerController.dispose();
    portController.dispose();
    topicController.dispose();
    super.dispose();
  }

  // Menghubungkan ke broker MQTT
  Future<void> _connectToBroker() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        isConnecting = true;
        _statusMessage = 'Menyambungkan...';
      });

      try {
        widget.mqttService.setConfiguration(
          broker: brokerController.text,
          port: int.parse(portController.text),
          topic: topicController.text,
        );

        await _saveConfiguration();
        await widget.mqttService.connect();

        if (mounted) {
          setState(() {
            _statusMessage = 'Terhubung ke MQTT broker';
            isConnecting = false;
          });
        }

        Fluttertoast.showToast(
          msg: "Berhasil terhubung ke broker",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green.shade600,
          textColor: const Color.fromARGB(255, 0, 0, 0),
        );

        widget.onConnected();
      } catch (e) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Gagal terhubung: $e';
            isConnecting = false;
          });
        }

        Fluttertoast.showToast(
          msg: "Gagal terhubung: $e",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red.shade700,
          textColor: const Color.fromARGB(255, 0, 0, 0),
        );
      }
    }
  }

  // Memutuskan koneksi dari broker MQTT
  void _disconnectFromBroker() {
    widget.mqttService.disconnect();
    if (mounted) {
      setState(() {
        _statusMessage = 'Terputus dari MQTT broker';
      });
    }
  }

  // Membangun UI halaman koneksi
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Konfigurasi Koneksi',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _buildInputField(
                label: 'Broker MQTT',
                controller: brokerController,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Broker tidak boleh kosong' : null,
              ),
              const SizedBox(height: 20),
              _buildInputField(
                label: 'Port',
                controller: portController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Port tidak boleh kosong';
                  final port = int.tryParse(value);
                  if (port == null) return 'Port harus berupa angka';
                  if (port < 0 || port > 65535) return 'Port harus antara 0 dan 65535';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildInputField(
                label: 'Topik',
                controller: topicController,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Topik tidak boleh kosong' : null,
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isConnecting ? null : _connectToBroker,
                  icon: isConnecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_done),
                  label: Text(isConnecting ? 'Menyambungkan...' : 'Hubungkan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.mqttService.client.connectionStatus?.state == MqttConnectionState.connected
                      ? _disconnectFromBroker
                      : null,
                  icon: const Icon(Icons.cloud_off),
                  label: const Text('Putuskan Koneksi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color: const Color.fromARGB(255, 0, 0, 0),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Membangun field input untuk form
  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.cyan.shade800),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.cyan.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.cyan.shade600, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}