import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monitoring_kolam_ikan/services/mqtt_service.dart';
import 'package:mqtt_client/mqtt_client.dart';

// Halaman untuk mengatur koneksi MQTT dengan konfigurasi broker, port, dan topik.
class ConnectionPage extends StatefulWidget {
  final MqttService mqttService;
  final VoidCallback onConnected;

  // Konstruktor dengan parameter wajib untuk MqttService dan callback saat terhubung.
  const ConnectionPage({
    super.key,
    required this.mqttService,
    required this.onConnected, required MqttConnectionState connectionStatus,
  });

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

// State untuk mengelola logika dan UI halaman koneksi.
class _ConnectionPageState extends State<ConnectionPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController brokerController = TextEditingController();
  final TextEditingController portController = TextEditingController();
  final TextEditingController topicController = TextEditingController();

  final ValueNotifier<String> statusNotifier = ValueNotifier<String>('Belum terkoneksi');
  final ValueNotifier<bool> isConnectingNotifier = ValueNotifier<bool>(false);

  // Inisialisasi state, memuat konfigurasi tersimpan, dan menambahkan listener status koneksi.
  @override
  void initState() {
    super.initState();
    _loadSavedConfiguration();
    _setupConnectionListener();
  }

  // Mengatur listener untuk memantau perubahan status koneksi MQTT.
  void _setupConnectionListener() {
    widget.mqttService.client.updates?.listen((event) {
      final connectionState = widget.mqttService.client.connectionStatus?.state;
      if (connectionState == MqttConnectionState.connected) {
        statusNotifier.value = 'Terhubung ke MQTT broker';
        isConnectingNotifier.value = false;
      } else if (connectionState == MqttConnectionState.disconnected) {
        statusNotifier.value = 'Terputus dari MQTT broker';
        isConnectingNotifier.value = false;
      }
    });
  }

  // Memuat konfigurasi tersimpan dari SharedPreferences.
  Future<void> _loadSavedConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      brokerController.text = prefs.getString('mqtt_broker') ?? widget.mqttService.broker;
      portController.text = prefs.getInt('mqtt_port')?.toString() ?? widget.mqttService.port.toString();
      topicController.text = prefs.getString('mqtt_topic') ?? widget.mqttService.topic;
    });
  }

  Future<void> _saveConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mqtt_broker', brokerController.text);
    await prefs.setInt('mqtt_port', int.parse(portController.text));
    await prefs.setString('mqtt_topic', topicController.text);
  }

  // Membersihkan sumber daya saat widget dihancurkan.
  @override
  void dispose() {
    brokerController.dispose();
    portController.dispose();
    topicController.dispose();
    statusNotifier.dispose();
    isConnectingNotifier.dispose();
    super.dispose();
  }

  // Menghubungkan ke broker MQTT dengan konfigurasi yang d zimagerikan.
  Future<void> _connectToBroker() async {
    if (!_formKey.currentState!.validate()) return;

    isConnectingNotifier.value = true;
    statusNotifier.value = 'Menyambungkan...';

    try {
      final port = int.tryParse(portController.text);
      if (port == null) {
        throw const FormatException('Port harus berupa angka');
      }

      widget.mqttService.setConfiguration(
        broker: brokerController.text,
        port: port,
        topic: topicController.text,
      );

      await _saveConfiguration();
      await widget.mqttService.connect();

      statusNotifier.value = 'Terhubung ke MQTT broker';
      isConnectingNotifier.value = false;

      Fluttertoast.showToast(
        msg: 'Berhasil terhubung ke broker',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green.shade600,
        textColor: Colors.white,
      );

      widget.onConnected();
    } on FormatException catch (e) {
      _showError('Format input tidak valid: $e');
    } catch (e) {
      _showError('Terjadi kesalahan: $e');
    }
  }

  // Menampilkan pesan error kepada pengguna.
  void _showError(String message) {
    statusNotifier.value = message;
    isConnectingNotifier.value = false;
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red.shade700,
      textColor: Colors.white,
    );
  }

  // Memutuskan koneksi dari broker MQTT.
  void _disconnectFromBroker() {
    widget.mqttService.disconnect();
    statusNotifier.value = 'Terputus dari MQTT broker';
  }

  // Membangun UI halaman koneksi.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Stack(
        children: [
          SingleChildScrollView(
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
                    hintText: 'contoh: mqtt.example.com',
                    validator: (value) => value == null || value.isEmpty ? 'Broker tidak boleh kosong' : null,
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    label: 'Port',
                    controller: portController,
                    hintText: 'contoh: 1883',
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
                    hintText: 'contoh: sensor/data',
                    validator: (value) => value == null || value.isEmpty ? 'Topik tidak boleh kosong' : null,
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: isConnectingNotifier,
                      builder: (context, isConnecting, _) {
                        return ElevatedButton.icon(
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
                        );
                      },
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
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _resetToDefault,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.cyan.shade700,
                        side: BorderSide(color: Colors.cyan.shade700),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      child: const Text('Reset ke Default'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: ValueListenableBuilder<String>(
                      valueListenable: statusNotifier,
                      builder: (context, status, _) {
                        return Text(
                          status,
                          style: const TextStyle(
                            color: Colors.black,
                            fontStyle: FontStyle.italic,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: isConnectingNotifier,
            builder: (context, isConnecting, _) {
              return isConnecting
                  ? Container(
                      color: Colors.black.withOpacity(0.3),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.cyan,
                        ),
                      ),
                    )
                  : const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  // Membangun field input untuk form dengan desain konsisten.
  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
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

  // Mengatur ulang konfigurasi ke nilai default.
  void _resetToDefault() {
    setState(() {
      brokerController.text = widget.mqttService.broker;
      portController.text = widget.mqttService.port.toString();
      topicController.text = widget.mqttService.topic;
    });
    _saveConfiguration();
    statusNotifier.value = 'Konfigurasi direset ke default';
    Fluttertoast.showToast(
      msg: 'Konfigurasi direset ke default',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.blue.shade600,
      textColor: Colors.white,
    );
  }
}