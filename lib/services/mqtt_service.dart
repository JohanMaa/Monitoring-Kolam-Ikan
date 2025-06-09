import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';

final logger = Logger();

// Kelas untuk mengelola koneksi dan komunikasi MQTT
class MqttService {
  MqttServerClient client;
  String broker = 'broker.emqx.io';
  int port = 1883;
  String topic = 'kolam_ikan/data';
  Function(Map<String, dynamic>)? onDataReceived;
  int reconnectAttempts = 0;
  final int maxReconnectAttempts = 5;
  final _connectionStatusController =
      StreamController<MqttConnectionState>.broadcast();
  Stream<MqttConnectionState> get connectionStatus =>
      _connectionStatusController.stream;

  // Konstruktor untuk inisialisasi client MQTT
  MqttService()
      : client = MqttServerClient.withPort(
            'broker.emqx.io',
            'flutter_kolam_ikan_${DateTime.now().millisecondsSinceEpoch}',
            1883);

  // Mengatur konfigurasi broker, port, dan topik
  void setConfiguration({
    required String broker,
    required int port,
    required String topic,
  }) {
    this.broker = broker;
    this.port = port;
    this.topic = topic;
    client = MqttServerClient.withPort(
        broker, 'flutter_kolam_ikan_${DateTime.now().millisecondsSinceEpoch}', port);
    logger.i('MQTT configuration updated: broker=$broker, port=$port, topic=$topic');
  }

  // Menghubungkan ke broker MQTT
  Future<void> connect() async {
    if (client.connectionStatus!.state == MqttConnectionState.connected ||
        client.connectionStatus!.state == MqttConnectionState.connecting) {
      logger.d('Already connected or connecting, skipping connect attempt');
      return;
    }

    reconnectAttempts = 0;
    client.logging(on: true);
    client.keepAlivePeriod = 20;
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    client.onSubscribed = onSubscribed;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_kolam_ikan')
        .withWillTopic('willtopic')
        .withWillMessage('Connection Closed')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    client.connectionMessage = connMessage;
    _connectionStatusController.add(MqttConnectionState.connecting);
    logger.d('Attempting to connect to MQTT broker: $broker:$port');

    try {
      await client.connect();
    } catch (e) {
      logger.e('MQTT Connection Error: $e');
      _connectionStatusController.add(MqttConnectionState.disconnected);
      onDisconnected();
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      client.subscribe(topic, MqttQos.atMostOnce);
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? event) {
        final recMess = event![0].payload as MqttPublishMessage;
        final payload =
            MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            onDataReceived?.call(decoded);
          } else {
            logger.w('Error: Decoded data is not a JSON object, got: $decoded');
          }
        } catch (e) {
          logger.e('Error decoding JSON: $e, Raw payload: $payload');
        }
      });
      logger.i('Successfully subscribed to topic: $topic');
    } else {
      _connectionStatusController.add(MqttConnectionState.disconnected);
      logger.e('MQTT Connection Failed - Status: ${client.connectionStatus}');
    }
  }

  // Memutuskan koneksi dari broker
  void disconnect() {
    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      client.disconnect();
      logger.i('Disconnected from MQTT broker');
    } else {
      logger.d('No active connection to disconnect');
    }
    _connectionStatusController.add(MqttConnectionState.disconnected);
  }

  // Callback saat koneksi berhasil
  void onConnected() {
    reconnectAttempts = 0;
    _connectionStatusController.add(MqttConnectionState.connected);
    logger.i('Connected to MQTT broker');
  }

  // Callback saat koneksi terputus
  void onDisconnected() {
    if (client.connectionStatus!.state == MqttConnectionState.connected) return;
    _connectionStatusController.add(MqttConnectionState.disconnected);
    logger.w('Disconnected from MQTT broker');
    if (reconnectAttempts < maxReconnectAttempts) {
      final delaySeconds = min(pow(2, reconnectAttempts).toInt(), 32);
      logger.i('Scheduling reconnect attempt ${reconnectAttempts + 1} in $delaySeconds seconds');
      Future.delayed(Duration(seconds: delaySeconds), () {
        if (client.connectionStatus!.state != MqttConnectionState.connected &&
            client.connectionStatus!.state != MqttConnectionState.connecting) {
          logger.i('Attempting to reconnect... (Attempt ${reconnectAttempts + 1})');
          reconnectAttempts++;
          connect();
        }
      });
    } else {
      logger.e('Max reconnect attempts reached. Please reconnect manually.');
    }
  }

  // Callback saat berhasil berlangganan topik
  void onSubscribed(String topic) {
    logger.i('Subscribed to $topic');
  }

  // Mengirim pesan ke topik MQTT
  Future<void> publish(String message) async {
    if (client.connectionStatus!.state != MqttConnectionState.connected) {
      logger.w('Cannot publish, client not connected');
      return;
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    logger.i('Published message: $message');
  }

  // Mendapatkan status koneksi saat ini
  MqttConnectionState getConnectionStatus() {
    return client.connectionStatus?.state ?? MqttConnectionState.disconnected;
  }

  // Membersihkan sumber daya saat tidak digunakan
  void dispose() {
    logger.d('Disposing MqttService');
    _connectionStatusController.close();
    disconnect();
  }
}