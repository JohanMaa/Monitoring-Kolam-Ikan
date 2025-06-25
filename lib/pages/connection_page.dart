import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monitoring_kolam_ikan/services/mqtt_service.dart';
import 'package:mqtt_client/mqtt_client.dart';

// Halaman untuk mengatur koneksi MQTT dengan konfigurasi broker, port, dan topik.
class ConnectionPage extends StatefulWidget {
  final MqttService mqttService;
  final VoidCallback onConnected;

  /// Konstruktor dengan parameter wajib untuk [MqttService] dan callback saat terhubung.
  const ConnectionPage({
    super.key,
    required this.mqttService,
    required this.onConnected,
  });

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _brokerController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final ValueNotifier<String> _statusNotifier = ValueNotifier<String>('Belum terkoneksi');
  final ValueNotifier<bool> _isConnectingNotifier = ValueNotifier<bool>(false);
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _mqttSubscription;

  @override
  void initState() {
    super.initState();
    _loadSavedConfiguration();
    _setupConnectionListener();
  }

  /// Mengatur listener untuk memantau perubahan status koneksi MQTT.
  void _setupConnectionListener() {
    _mqttSubscription = widget.mqttService.client.updates?.listen((event) {
      final connectionState = widget.mqttService.client.connectionStatus!.state;
      switch (connectionState) {
        case MqttConnectionState.connected:
          _statusNotifier.value = 'Terhubung ke MQTT broker';
          _isConnectingNotifier.value = false;
          break;
        case MqttConnectionState.connecting:
          _statusNotifier.value = 'Menyambungkan...';
          _isConnectingNotifier.value = true;
          break;
        case MqttConnectionState.disconnected:
          _statusNotifier.value = 'Terputus dari MQTT broker';
          _isConnectingNotifier.value = false;
          break;
        case MqttConnectionState.disconnecting:
          _statusNotifier.value = 'Memutuskan koneksi...';
          _isConnectingNotifier.value = true;
          break;
        case MqttConnectionState.faulted:
          _statusNotifier.value = 'Koneksi gagal';
          _isConnectingNotifier.value = false;
          break;
      }
    });
  }

  /// Memuat konfigurasi tersimpan dari SharedPreferences.
  Future<void> _loadSavedConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _brokerController.text = prefs.getString('mqtt_broker') ?? widget.mqttService.broker;
      _portController.text = prefs.getInt('mqtt_port')?.toString() ?? widget.mqttService.port.toString();
      _topicController.text = prefs.getString('mqtt_topic') ?? widget.mqttService.topic;
    });
  }

  /// Menyimpan konfigurasi ke SharedPreferences.
  Future<void> _saveConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mqtt_broker', _brokerController.text);
    await prefs.setInt('mqtt_port', int.parse(_portController.text));
    await prefs.setString('mqtt_topic', _topicController.text);
  }

  @override
  void dispose() {
    _brokerController.dispose();
    _portController.dispose();
    _topicController.dispose();
    _statusNotifier.dispose();
    _isConnectingNotifier.dispose();
    _mqttSubscription?.cancel();
    super.dispose();
  }

  /// Menghubungkan ke broker MQTT dengan konfigurasi dari form.
  Future<void> _connectToBroker() async {
    if (!_formKey.currentState!.validate()) return;

    _isConnectingNotifier.value = true;
    _statusNotifier.value = 'Menyambungkan...';

    try {
      widget.mqttService.setConfiguration(
        broker: _brokerController.text,
        port: int.parse(_portController.text),
        topic: _topicController.text,
      );

      await _saveConfiguration();
      await widget.mqttService.connect();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berhasil terhubung ke broker'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      widget.onConnected();
    } catch (e) {
      _showError('Terjadi kesalahan: $e');
    }
  }

  /// Menampilkan pesan error kepada pengguna.
  void _showError(String message) {
    _statusNotifier.value = message;
    _isConnectingNotifier.value = false;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Memutuskan koneksi dari broker MQTT.
  void _disconnectFromBroker() {
    widget.mqttService.disconnect();
    _statusNotifier.value = 'Terputus dari MQTT broker';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Konfigurasi Koneksi MQTT',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: Colors.cyan,
        elevation: 0,
      ),
      backgroundColor: Colors.grey.shade50,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        'Atur Koneksi MQTT',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildInputField(
                      label: 'Broker MQTT',
                      controller: _brokerController,
                      hintText: 'contoh: mqtt.example.com',
                      validator: (value) => value == null || value.isEmpty
                          ? 'Broker tidak boleh kosong'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      label: 'Port',
                      controller: _portController,
                      hintText: 'contoh: 1883',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Port tidak boleh kosong';
                        }
                        final port = int.tryParse(value);
                        if (port == null) return 'Port harus berupa angka';
                        if (port < 0 || port > 65535) {
                          return 'Port harus antara 0 dan 65535';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      label: 'Topik',
                      controller: _topicController,
                      hintText: 'contoh: sensor/data',
                      validator: (value) => value == null || value.isEmpty
                          ? 'Topik tidak boleh kosong'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: ValueListenableBuilder<String>(
                          valueListenable: _statusNotifier,
                          builder: (context, status, _) {
                            return Row(
                              children: [
                                Icon(
                                  status.contains('Terhubung')
                                      ? Icons.check_circle
                                      : status.contains('Terputus') || status.contains('Belum')
                                          ? Icons.cancel
                                          : Icons.hourglass_empty,
                                  color: status.contains('Terhubung')
                                      ? Colors.green
                                      : status.contains('Terputus') || status.contains('Belum')
                                          ? Colors.red
                                          : Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildButton(
                      label: 'Hubungkan',
                      icon: Icons.cloud_done,
                      color: Colors.cyan.shade700,
                      onPressed: _connectToBroker,
                      isLoadingListenable: _isConnectingNotifier,
                      loadingLabel: 'Menyambungkan...',
                    ),
                    const SizedBox(height: 12),
                    _buildButton(
                      label: 'Putuskan Koneksi',
                      icon: Icons.cloud_off,
                      color: Colors.red.shade700,
                      onPressed: widget.mqttService.client.connectionStatus!.state ==
                              MqttConnectionState.connected
                          ? _disconnectFromBroker
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _buildButton(
                      label: 'Reset ke Default',
                      icon: Icons.restore,
                      color: Colors.cyan.shade700,
                      onPressed: _resetToDefault,
                      isOutlined: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _isConnectingNotifier,
            builder: (context, isConnecting, _) {
              return isConnecting
                  ? Container(
                      color: Colors.black.withOpacity(0.3),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.cyan),
                      ),
                    )
                  : const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  /// Membangun field input untuk form dengan desain konsisten.
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

  /// Membangun tombol dengan gaya konsisten.
  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool isOutlined = false,
    ValueListenable<bool>? isLoadingListenable,
    String? loadingLabel,
  }) {
    return SizedBox(
      width: double.infinity,
      child: isLoadingListenable != null
          ? ValueListenableBuilder<bool>(
              valueListenable: isLoadingListenable,
              builder: (context, isLoading, _) {
                return isOutlined
                    ? OutlinedButton.icon(
                        onPressed: isLoading ? null : onPressed,
                        icon: Icon(icon, color: color),
                        label: Text(isLoading ? loadingLabel ?? label : label),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: color,
                          side: BorderSide(color: color),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: isLoading ? null : onPressed,
                        icon: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(icon),
                        label: Text(isLoading ? loadingLabel ?? label : label),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      );
              },
            )
          : isOutlined
              ? OutlinedButton.icon(
                  onPressed: onPressed,
                  icon: Icon(icon, color: color),
                  label: Text(label),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: onPressed,
                  icon: Icon(icon),
                  label: Text(label),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
    );
  }

  /// Mengatur ulang konfigurasi ke nilai default.
  void _resetToDefault() {
    widget.mqttService.disconnect();
    setState(() {
      _brokerController.text = widget.mqttService.broker;
      _portController.text = widget.mqttService.port.toString();
      _topicController.text = widget.mqttService.topic;
    });
    _saveConfiguration();
    _statusNotifier.value = 'Konfigurasi direset ke default';
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konfigurasi direset ke default'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}