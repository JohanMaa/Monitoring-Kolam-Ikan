// ignore_for_file: cast_from_null_always_fails, avoid_print, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:monitoring_kolam_ikan/models/kolam.dart';
import 'package:monitoring_kolam_ikan/models/sensor_data.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:uuid/uuid.dart';
import 'package:monitoring_kolam_ikan/widgets/sensor_card.dart';
import 'package:monitoring_kolam_ikan/services/mqtt_service.dart';
import 'package:monitoring_kolam_ikan/pages/settings_page.dart';
import 'package:monitoring_kolam_ikan/pages/connection_page.dart';
import 'package:monitoring_kolam_ikan/pages/history_page.dart';
import 'package:monitoring_kolam_ikan/services/default_threshold.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Halaman utama untuk dashboard aplikasi
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  DashboardPageState createState() => DashboardPageState();
}

// State untuk mengelola logika dashboard
class DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late MqttService mqttService;
  int _selectedIndex = 0;
  List<Kolam> kolams = [];
  final ValueNotifier<List<Map<String, dynamic>>> historyNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  Map<String, SensorThreshold> thresholds = defaultThresholds;
  Map<String, DateTime> lastUpdateTimes = {};
  Map<String, DateTime> lastNotificationTimes = {};
  Timer? _saveKolamsTimer;
  Timer? _saveHistoryTimer;
  final Duration debounceDuration = const Duration(seconds: 5);
  final Duration notificationCooldown = const Duration(seconds: 30);

  // Inisialisasi state dan koneksi MQTT
  @override
  void initState() {
    super.initState();
    mqttService = MqttService();
    mqttService.onDataReceived = updateSensorData;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadKolams();
      await _loadHistory();
      if (kolams.isEmpty) {
        _initialKolam();
      }
      mqttService.connect();
    });
  }

  // Memuat daftar kolam dari penyimpanan
  Future<void> _loadKolams() async {
    final prefs = await SharedPreferences.getInstance();
    final String? kolamsJson = prefs.getString('kolams');
    if (kolamsJson != null) {
      try {
        final List<dynamic> kolamsList = jsonDecode(kolamsJson);
        setState(() {
          kolams = kolamsList.map((json) {
            final data = SensorData.fromJson(json['data']);
            return Kolam(
              id: json['id'] as String,
              name: json['name'] as String,
              data: data,
              thresholds: thresholds,
              sensorData: {},
            )..updateSensorCards();
          }).toList();
        });
      } catch (e) {
        print('Error loading kolams: $e');
      }
    }
  }

  // Menyimpan daftar kolam ke penyimpanan
  Future<void> _saveKolams() async {
    _saveKolamsTimer?.cancel();
    _saveKolamsTimer = Timer(debounceDuration, () async {
      final prefs = await SharedPreferences.getInstance();
      final kolamsJson = kolams
          .map((kolam) => {
                'id': kolam.id,
                'name': kolam.name,
                'data': {
                  'suhu': kolam.data.suhu,
                  'ph': kolam.data.ph,
                  'dissolvedOxygen': kolam.data.dissolvedOxygen,
                  'berat': kolam.data.berat,
                  'tinggiAir': kolam.data.tinggiAir,
                  'sensorType': kolam.data.sensorType,
                  'value': kolam.data.value,
                },
              })
          .toList();
      await prefs.setString('kolams', jsonEncode(kolamsJson));
      print('Saved kolams: ${kolams.map((k) => k.name).toList()}');
    });
  }

  // Memuat riwayat dari penyimpanan
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString('history');
    if (historyJson != null) {
      try {
        final List<Map<String, dynamic>> loadedHistory =
            List<Map<String, dynamic>>.from(jsonDecode(historyJson));
        historyNotifier.value = loadedHistory;
      } catch (e) {
        print('Error loading history: $e');
      }
    }
  }

  // Menyimpan riwayat ke penyimpanan
  Future<void> _saveHistory() async {
    _saveHistoryTimer?.cancel();
    _saveHistoryTimer = Timer(debounceDuration, () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('history', jsonEncode(historyNotifier.value));
      print('Saved history: ${historyNotifier.value.length} entries');
    });
  }

  // Inisialisasi kolam awal
  void _initialKolam() {
    setState(() {
      const initialData = SensorData(
        suhu: 0,
        ph: 0,
        dissolvedOxygen: 0,
        berat: 0,
        tinggiAir: 0,
        sensorType: 'Suhu',
        value: 0,
      );
      final newKolam =
          Kolam.generate('initial_kolam', 'Kolam 1', initialData: initialData);
      kolams.add(newKolam);
      _saveKolams();
    });
  }

  // Menentukan warna berdasarkan status sensor
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

  // Menampilkan notifikasi
  void _showNotification(String message, SensorStatus status) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: getColorForStatus(status),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Memperbarui data sensor dari MQTT
  void updateSensorData(Map<String, dynamic> data) {
    final kolamName = data['kolam'] as String?;
    final kolamId = data['id'] as String?;
    if (kolamName == null && kolamId == null) {
      print('No kolam name or id in data: $data');
      return;
    }

    try {
      setState(() {
        Kolam? targetKolam;

        if (kolamId != null) {
          targetKolam = kolams.firstWhere((kolam) => kolam.id == kolamId,
              orElse: () => null as Kolam);
        }
        if (targetKolam == null && kolamName != null) {
          targetKolam = kolams.firstWhere((kolam) => kolam.name == kolamName,
              orElse: () => null as Kolam);
        }

        if (targetKolam == null && (kolamName != null || kolamId != null)) {
          final uuid = Uuid();
          final newId = kolamId ?? uuid.v4();
          final newName = kolamName ?? 'Kolam Baru ${kolams.length + 1}';
          const initialData = SensorData(
            suhu: 0,
            ph: 0,
            dissolvedOxygen: 0,
            berat: 0,
            tinggiAir: 0,
            sensorType: 'Suhu',
            value: 0,
          );
          targetKolam = Kolam.generate(newId, newName, initialData: initialData);
          kolams.add(targetKolam);
          _listKey.currentState?.insertItem(
            kolams.length - 1,
            duration: const Duration(milliseconds: 500),
          );
          _saveKolams();
          print('Created new kolam: ${targetKolam.name} (ID: ${targetKolam.id})');
        }

        if (targetKolam != null) {
          final oldData = targetKolam.data;
          final newData = SensorData(
            suhu: (data['suhu'] as num?)?.toDouble() ?? oldData.suhu,
            ph: (data['ph'] as num?)?.toDouble() ?? oldData.ph,
            dissolvedOxygen:
                (data['do'] as num?)?.toDouble() ?? oldData.dissolvedOxygen,
            berat:
                (data['berat_pakan'] as num?)?.toDouble() ?? oldData.berat,
            tinggiAir:
                (data['level_air'] as num?)?.toDouble() ?? oldData.tinggiAir,
            sensorType: data['sensorType'] as String? ?? oldData.sensorType,
            value: (data['value'] as num?)?.toDouble() ?? oldData.value,
          );

          final oldStatus = oldData.getStatusMap(thresholds);
          final newStatus = newData.getStatusMap(thresholds);
          final now = DateTime.now();
          final lastNotified = lastNotificationTimes[targetKolam.name] ?? DateTime(1970);

          for (var sensor in newStatus.keys) {
            final oldSensorStatus = oldStatus[sensor] ?? SensorStatus.normal;
            final newSensorStatus = newStatus[sensor] ?? SensorStatus.normal;
            if (newSensorStatus != SensorStatus.normal &&
                newSensorStatus.index > oldSensorStatus.index &&
                now.difference(lastNotified) >= notificationCooldown) {
              final sensorLabel = sensor == 'suhu'
                  ? 'Suhu'
                  : sensor == 'ph'
                      ? 'pH'
                      : sensor == 'dissolvedOxygen'
                          ? 'DO'
                          : sensor == 'berat'
                              ? 'Berat Pakan'
                              : 'Level Air';
              final unit = sensor == 'suhu'
                  ? '°C'
                  : sensor == 'dissolvedOxygen'
                      ? 'mg/L'
                      : sensor == 'berat'
                          ? 'Kg'
                          : sensor == 'tinggiAir'
                              ? '%'
                              : '';
              final value = newData.toJson()[sensor].toString();
              final statusLabel = newSensorStatus == SensorStatus.kritis
                  ? 'kritis'
                  : 'darurat';
              _showNotification(
                'Peringatan: $sensorLabel di ${targetKolam.name} $statusLabel ($value$unit)!',
                newSensorStatus,
              );
              lastNotificationTimes[targetKolam.name] = now;
            }
          }

          if (oldData.suhu != newData.suhu ||
              oldData.ph != newData.ph ||
              oldData.dissolvedOxygen != newData.dissolvedOxygen ||
              oldData.berat != newData.berat ||
              oldData.tinggiAir != newData.tinggiAir) {
            final kolamHistory = historyNotifier.value
                .where((entry) => entry['kolamName'] == targetKolam!.name)
                .toList();
            if (kolamHistory.length >= 1000) {
              final oldestEntry = kolamHistory.reduce((a, b) => DateTime.parse(
                      a['timestamp'])
                  .isBefore(DateTime.parse(b['timestamp']))
                  ? a
                  : b);
              historyNotifier.value = List.from(historyNotifier.value)
                ..remove(oldestEntry);
            }

            historyNotifier.value = [
              ...historyNotifier.value,
              {
                'kolamName': targetKolam.name,
                'id': targetKolam.id,
                'data': {
                  'suhu': newData.suhu,
                  'ph': newData.ph,
                  'dissolvedOxygen': newData.dissolvedOxygen,
                  'berat': newData.berat,
                  'tinggiAir': newData.tinggiAir,
                  'sensorType': newData.sensorType,
                  'value': newData.value,
                },
                'timestamp': DateTime.now().toUtc().toIso8601String(),
              },
            ];
            _saveHistory();
            print(
                'History updated for ${targetKolam.name} (ID: ${targetKolam.id}): ${historyNotifier.value.length} entries');
          }

          targetKolam.data = newData;
          lastUpdateTimes[targetKolam.name] = DateTime.now();
          targetKolam.updateSensorCards();
          _saveKolams();
        }
      });
    } catch (e) {
      print('Error updating sensor data: $e');
    }
  }

  // Menambahkan kolam baru
  void _addKolam() async {
    final String? kolamName = await _showInputDialog();
    if (kolamName != null && kolamName.isNotEmpty) {
      final uuid = Uuid();
      final String kolamId = uuid.v4();
      const initialData = SensorData(
        suhu: 0,
        ph: 0,
        dissolvedOxygen: 0,
        berat: 0,
        tinggiAir: 0,
        sensorType: 'Suhu',
        value: 0,
      );
      final Kolam newKolam =
          Kolam.generate(kolamId, kolamName, initialData: initialData);

      setState(() {
        kolams.add(newKolam);
      });
      _listKey.currentState?.insertItem(
        kolams.length - 1,
        duration: const Duration(milliseconds: 500),
      );
      _selectedIndex = 0;
      await _saveKolams();
    }
  }

  // Menampilkan dialog input nama kolam
  Future<String?> _showInputDialog({String? currentName}) async {
    String? input;
    String? errorText;
    final controller = TextEditingController(text: currentName ?? '');
    final focusNode = FocusNode();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(currentName == null ? 'Nama Kolam Baru' : 'Edit Nama Kolam'),
              content: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Masukkan nama kolam',
                  errorText: errorText,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z0-9\s]+$')),
                  LengthLimitingTextInputFormatter(30),
                ],
                onChanged: (value) {
                  setState(() {
                    errorText = _validateKolamName(value.trim(), currentName);
                  });
                },
              ),
              actions: [
                TextButton(
                  child: const Text('Batal'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('Simpan'),
                  onPressed: () {
                    final name = controller.text.trim();
                    final error = _validateKolamName(name, currentName);
                    if (error == null) {
                      input = name;
                      Navigator.of(context).pop();
                    } else {
                      setState(() {
                        errorText = error;
                        focusNode.requestFocus();
                      });
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
    return input;
  }

  // Validasi nama kolam
  String? _validateKolamName(String name, String? currentName) {
    if (name.isEmpty) {
      return 'Nama tidak boleh kosong';
    }
    if (name.length > 30) {
      return 'Nama tidak boleh lebih dari 30 karakter';
    }
    if (!RegExp(r'^[a-zA-Z0-9\s]+$').hasMatch(name)) {
      return 'Nama hanya boleh berisi huruf, angka, dan spasi';
    }
    if (kolams.any((kolam) => kolam.name == name && kolam.name != currentName)) {
      return 'Nama sudah digunakan';
    }
    return null;
  }

  // Menampilkan detail kolam dalam dialog
  void _showKolamDetail(Kolam kolam) {
    final originalCallback = mqttService.onDataReceived;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            mqttService.onDataReceived = (data) {
              final String? namaKolam = data['kolam'] as String?;
              final String? kolamId = data['id'] as String?;
              if (namaKolam == kolam.name || kolamId == kolam.id) {
                setStateDialog(() {
                  kolam.data = SensorData(
                    suhu: (data['suhu'] as num?)?.toDouble() ?? kolam.data.suhu,
                    ph: (data['ph'] as num?)?.toDouble() ?? kolam.data.ph,
                    dissolvedOxygen: (data['do'] as num?)?.toDouble() ??
                        kolam.data.dissolvedOxygen,
                    berat: (data['berat_pakan'] as num?)?.toDouble() ??
                        kolam.data.berat,
                    tinggiAir: (data['level_air'] as num?)?.toDouble() ??
                        kolam.data.tinggiAir,
                    sensorType:
                        data['sensorType'] as String? ?? kolam.data.sensorType,
                    value:
                        (data['value'] as num?)?.toDouble() ?? kolam.data.value,
                  );
                  lastUpdateTimes[kolam.name] = DateTime.now();
                  kolam.updateSensorCards();
                });
              }
            };

            return AlertDialog(
              title: Text('Dashboard ${kolam.name}'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  itemCount: kolam.sensorData.length,
                  itemBuilder: (context, index) {
                    final sensorKey = kolam.sensorData.keys.elementAt(index);
                    final data = kolam.sensorData[sensorKey]!;
                    final statusKey = sensorKey;
                    final status =
                        kolam.data.getStatusMap(thresholds)[statusKey] ??
                            SensorStatus.normal;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: SensorCard(
                        label: data.label,
                        value: data.value,
                        unit: data.label == 'Suhu'
                            ? '°C'
                            : data.label == 'DO'
                                ? 'mg/L'
                                : data.label == 'Berat Pakan'
                                    ? 'Kg'
                                    : data.label == 'Level Air'
                                        ? '%'
                                        : '',
                        status: status,
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    mqttService.onDataReceived = originalCallback;
                  },
                  child: const Text('Tutup'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      mqttService.onDataReceived = originalCallback;
    });
  }

  // Menghapus kolam dari daftar
  void _removeKolam(int index) {
    final removedKolam = kolams.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => SizeTransition(
        sizeFactor: animation,
        child: _buildKolamTile(removedKolam, index),
      ),
      duration: const Duration(milliseconds: 300),
    );
    setState(() {
      historyNotifier.value = List.from(historyNotifier.value)
        ..removeWhere((entry) => entry['kolamName'] == removedKolam.name);
      _saveKolams();
      _saveHistory();
    });
  }

  // Membangun tile untuk kolam
  Widget _buildKolamTile(Kolam kolam, int index) {
    return GestureDetector(
      onTap: () => _showKolamDetail(kolam),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.cyan.shade100,
            child: const FaIcon(FontAwesomeIcons.water,
                color: Colors.cyan, size: 20),
          ),
          title: Text(
            kolam.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          subtitle: Text(
            'Tap untuk melihat detail',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'edit') {
                _editKolamName(index);
              } else if (value == 'delete') {
                _removeKolam(index);
              } else if (value == 'info') {
                _showKolamInfo(kolam);
              }
            },
            itemBuilder: (BuildContext context) {
              return const [
                PopupMenuItem<String>(
                  value: 'info',
                  child: Text('Info'),
                ),
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Hapus'),
                ),
              ];
            },
            icon: Icon(Icons.more_vert, color: Colors.grey.shade700),
          ),
        ),
      ),
    );
  }

  // Menampilkan informasi kolam dalam dialog
  void _showKolamInfo(Kolam kolam) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Info Kolam ${kolam.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nama Kolam: ${kolam.name}'),
              Text('ID: ${kolam.id}'),
              const SizedBox(height: 10),
              ...kolam.sensorData.entries
                  .map((entry) => Text('${entry.value.label}: ${entry.value.value}')),
              const SizedBox(height: 10),
              Text('Status: ${kolam.data.getStatusMap(thresholds).toString()}'),
              Text(
                  'Waktu Terakhir Update: ${lastUpdateTimes[kolam.name]?.toLocal() ?? DateTime.now().toLocal()}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  // Mengedit nama kolam
  void _editKolamName(int index) async {
    final String? newName = await _showInputDialog(currentName: kolams[index].name);
    if (newName != null && newName.isNotEmpty) {
      setState(() {
        final oldName = kolams[index].name;
        kolams[index].name = newName;
        historyNotifier.value = historyNotifier.value.map((entry) {
          if (entry['kolamName'] == oldName) {
            return {...entry, 'kolamName': newName};
          }
          return entry;
        }).toList();
        _saveKolams();
        _saveHistory();
      });
    }
  }

  // Membangun daftar kolam dengan animasi
  Widget _buildDashboardList() {
    return kolams.isEmpty
        ? const Center(
            child: Text(
              'Belum ada kolam ditambahkan.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          )
        : AnimatedList(
            key: _listKey,
            initialItemCount: kolams.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index, animation) {
              final kolam = kolams[index];
              return SizeTransition(
                sizeFactor: animation,
                child: _buildKolamTile(kolam, index),
              );
            },
          );
  }

  // Daftar halaman untuk navigasi
  List<Widget> get _pages => [
        _buildDashboardList(),
        StreamBuilder<MqttConnectionState>(
          stream: mqttService.connectionStatus,
          initialData: mqttService.getConnectionStatus(),
          builder: (context, snapshot) {
            return ConnectionPage(
              mqttService: mqttService,
              onConnected: () => setState(() {}),
            );
          },
        ),
        ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: historyNotifier,
          builder: (context, history, child) {
            return HistoryPage(
              history: history,
              onHistoryChanged: (updatedHistory) {
                historyNotifier.value = updatedHistory;
                _saveHistory();
              },
            );
          },
        ),
        SettingsPage(
          mqttService: mqttService,
          onThresholdsChanged: (newThresholds) {
            setState(() {
              thresholds = newThresholds;
              for (var kolam in kolams) {
                kolam.thresholds = thresholds;
                kolam.updateSensorCards();
              }
            });
          },
        ),
      ];

  // Membersihkan sumber daya
  @override
  void dispose() {
    _saveKolamsTimer?.cancel();
    _saveHistoryTimer?.cancel();
    mqttService.dispose();
    historyNotifier.dispose();
    super.dispose();
  }

  // Membangun UI dashboard
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MqttConnectionState>(
      stream: mqttService.connectionStatus,
      initialData: mqttService.getConnectionStatus(),
      builder: (context, snapshot) {
        final connectionStatus = snapshot.data ?? MqttConnectionState.disconnected;
        if (connectionStatus == MqttConnectionState.disconnected &&
            mqttService.reconnectAttempts >= mqttService.maxReconnectAttempts) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gagal terhubung ke MQTT. Silakan periksa koneksi.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
            }
          });
        }
        return Scaffold(
          body: _pages[_selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
            selectedItemColor: Colors.cyan,
            unselectedItemColor: Colors.grey.shade500,
            backgroundColor: Colors.white,
            currentIndex: _selectedIndex >= 2 ? _selectedIndex + 1 : _selectedIndex,
            onTap: (index) {
              const int addButtonIndex = 2;
              if (index == addButtonIndex) {
                _addKolam();
              } else {
                setState(() {
                  _selectedIndex = index > addButtonIndex ? index - 1 : index;
                });
              }
            },
            type: BottomNavigationBarType.fixed,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(
                  Icons.link,
                  color: connectionStatus == MqttConnectionState.connected
                      ? Colors.green
                      : Colors.red,
                ),
                label: 'Koneksi',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.add_circle, color: Colors.cyan),
                label: '',
                activeIcon: Icon(Icons.add_circle, color: Colors.cyan.shade700),
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'History',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Pengaturan',
              ),
            ],
          ),
        );
      },
    );
  }
}