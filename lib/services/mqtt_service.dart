import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:convert';

class MqttService {
  late MqttServerClient client;
  String broker = 'broker.emqx.io';
  int port = 1883;
  String topic = 'kolam_ikan/data';
  Function(Map<String, dynamic>)? onDataReceived;
  int reconnectAttempts = 0;
  final int maxReconnectAttempts = 3;

  void setConfiguration({
    required String broker,
    required int port,
    required String topic,
  }) {
    this.broker = broker;
    this.port = port;
    this.topic = topic;
  }

  Future<void> connect() async {
    reconnectAttempts = 0;
    client = MqttServerClient.withPort(broker, 'flutter_kolam_ikan', port);
    client.logging(on: false);
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

    try {
      await client.connect();
    } catch (e) {
      print('MQTT Connection Error: $e');
      disconnect();
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('MQTT Connected');
      client.subscribe(topic, MqttQos.atMostOnce);

      client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? event) {
        final recMess = event![0].payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        print('Received message from topic "${event[0].topic}": $payload');

        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            print('Decoded JSON data: $decoded');
            onDataReceived?.call(decoded);
          } else {
            print('Error: Decoded data is not a JSON object, got: $decoded');
          }
        } catch (e) {
          print('Error decoding JSON: $e, Raw payload: $payload');
        }
      });
    } else {
      print('MQTT Connection Failed - Status: ${client.connectionStatus}');
    }
  }

  void disconnect() {
    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      client.disconnect();
    }
    print('Disconnected from MQTT broker');
  }

  void onConnected() {
    print('Connected to MQTT broker');
  }

  void onDisconnected() {
    print('Disconnected from MQTT broker');
    if (reconnectAttempts < maxReconnectAttempts) {
      Future.delayed(const Duration(seconds: 5), () {
        if (client.connectionStatus?.state != MqttConnectionState.connected) {
          print('Attempting to reconnect... (Attempt ${reconnectAttempts + 1})');
          reconnectAttempts++;
          connect();
        }
      });
    } else {
      print('Max reconnect attempts reached. Please reconnect manually.');
    }
  }

  void onSubscribed(String topic) {
    print('Subscribed to $topic');
  }

  Future<void> publish(String message) async {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);

    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    print('Published message: $message');
  }
}