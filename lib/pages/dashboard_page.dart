import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:monitoring_kolam_ikan/models/kolam.dart';
import 'package:monitoring_kolam_ikan/models/sensor_data.dart';
import 'package:uuid/uuid.dart';
import 'package:monitoring_kolam_ikan/widgets/sensor_card.dart';
import 'package:monitoring_kolam_ikan/services/mqtt_service.dart';
import 'package:monitoring_kolam_ikan/pages/settings_page.dart';
import 'package:monitoring_kolam_ikan/pages/connection_page.dart';
import 'package:monitoring_kolam_ikan/pages/history_page.dart';
import 'package:monitoring_kolam_ikan/services/default_threshold.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  DashboardPageState createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late MqttService mqttService;
  int _selectedIndex = 0;
  List<Kolam> kolams = [];
  List<Map<String, dynamic>> history = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  Map<String, SensorThreshold> thresholds = defaultThresholds;
  Map<String, DateTime> lastUpdateTimes = {};

  @override
  void initState() {
    super.initState();
    mqttService = MqttService();
    mqttService.onDataReceived = updateSensorData;
    // Pastikan load data dari SharedPreferences sebelum membuat kolam awal
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadKolams();
      await _loadHistory();
      if (kolams.isEmpty) {
        _initialKolam();
      }
      mqttService.connect(); // Connect setelah memuat data
    });
  }

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
        print('Loaded kolams: ${kolams.map((k) => k.name).toList()}');
      } catch (e) {
        print('Error loading kolams: $e');
      }
    }
  }

  Future<void> _saveKolams() async {
    final prefs = await SharedPreferences.getInstance();
    final kolamsJson = kolams.map((kolam) => {
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
    }).toList();
    await prefs.setString('kolams', jsonEncode(kolamsJson));
    print('Saved kolams: ${kolams.map((k) => k.name).toList()}');
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString('history');
    if (historyJson != null) {
      try {
        setState(() {
          history = List<Map<String, dynamic>>.from(jsonDecode(historyJson));
        });
        print('Loaded history: $history');
      } catch (e) {
        print('Error loading history: $e');
      }
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('history', jsonEncode(history));
    print('Saved history: $history');
  }

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
      final newKolam = Kolam.generate('initial_kolam', 'Kolam 1', initialData: initialData);
      kolams.add(newKolam);
      _saveKolams();
    });
  }

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

  void updateSensorData(Map<String, dynamic> data) {
    final kolamName = data['kolam'] as String?;
    final kolamId = data['id'] as String?;
    if (kolamName == null && kolamId == null) {
      print('No kolam name or id in data: $data');
      return;
    }

    setState(() {
      Kolam? targetKolam;

      // Cari kolam berdasarkan id
      if (kolamId != null) {
        targetKolam = kolams.where((kolam) => kolam.id == kolamId).firstOrNull;
      }
      // Jika tidak ditemukan berdasarkan id, cari berdasarkan nama
      if (targetKolam == null && kolamName != null) {
        targetKolam = kolams.where((kolam) => kolam.name == kolamName).firstOrNull;
      }

      // Jika kolam tidak ditemukan, buat kolam baru
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
          suhu: (data['suhu'] ?? oldData.suhu).toDouble(),
          ph: (data['ph'] ?? oldData.ph).toDouble(),
          dissolvedOxygen: (data['do'] ?? oldData.dissolvedOxygen).toDouble(),
          berat: (data['berat_pakan'] ?? oldData.berat).toDouble(),
          tinggiAir: (data['level_air'] ?? oldData.tinggiAir).toDouble(),
          sensorType: data['sensorType'] ?? oldData.sensorType,
          value: (data['value'] ?? oldData.value).toDouble(),
        );

        // Periksa perubahan data sebelum menyimpan history
        if (oldData.suhu != newData.suhu ||
            oldData.ph != newData.ph ||
            oldData.dissolvedOxygen != newData.dissolvedOxygen ||
            oldData.berat != newData.berat ||
            oldData.tinggiAir != newData.tinggiAir) {
          history.add({
            'kolamName': targetKolam.name,
            'id': targetKolam.id,
            'data': {
              'suhu': oldData.suhu,
              'ph': oldData.ph,
              'dissolvedOxygen': oldData.dissolvedOxygen,
              'berat': oldData.berat,
              'tinggiAir': oldData.tinggiAir,
              'sensorType': oldData.sensorType,
              'value': oldData.value,
            },
            'timestamp': DateTime.now().toIso8601String(),
          });
          _saveHistory();
          print('History updated for ${targetKolam.name} (ID: ${targetKolam.id}): $history');
        }

        // Update data kolam
        targetKolam.data = newData;
        lastUpdateTimes[targetKolam.name] = DateTime.now();
        targetKolam.updateSensorCards();
        _saveKolams(); // Simpan data kolam setelah update
      } else {
        print('No matching or new kolam created for name: $kolamName or id: $kolamId');
      }
    });
  }

  void _addKolam() async {
    final String kolamName = await _showInputDialog();
    if (kolamName.isNotEmpty) {
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
      final Kolam newKolam = Kolam.generate(kolamId, kolamName, initialData: initialData);

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

  Future<String> _showInputDialog() async {
    String input = '';
    final TextEditingController controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nama Kolam Baru'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Masukkan nama kolam'),
          ),
          actions: [
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Simpan'),
              onPressed: () {
                input = controller.text.trim();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
    return input;
  }

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
                    suhu: (data['suhu'] ?? kolam.data.suhu).toDouble(),
                    ph: (data['ph'] ?? kolam.data.ph).toDouble(),
                    dissolvedOxygen: (data['do'] ?? kolam.data.dissolvedOxygen).toDouble(),
                    berat: (data['berat_pakan'] ?? kolam.data.berat).toDouble(),
                    tinggiAir: (data['level_air'] ?? kolam.data.tinggiAir).toDouble(),
                    sensorType: data['sensorType'] ?? kolam.data.sensorType,
                    value: (data['value'] ?? kolam.data.value).toDouble(),
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
                    final status = kolam.data.getStatusMap(thresholds)[statusKey] ?? SensorStatus.normal;
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
    );
  }

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
    setState(() {});
    _saveKolams();
  }

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
            child: const FaIcon(FontAwesomeIcons.water, color: Colors.cyan, size: 20),
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
                  child: Text('Delete'),
                ),
              ];
            },
            icon: Icon(Icons.more_vert, color: Colors.grey.shade700),
          ),
        ),
      ),
    );
  }

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
              ...kolam.sensorData.entries.map((entry) => Text('${entry.value.label}: ${entry.value.value}')),
              const SizedBox(height: 10),
              Text('Status: ${kolam.data.getStatusMap(thresholds).toString()}'),
              Text('Waktu Terakhir Update: ${lastUpdateTimes[kolam.name]?.toLocal() ?? DateTime.now().toLocal()}'),
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

  void _editKolamName(int index) async {
    final String newName = await _showInputDialog();
    if (newName.isNotEmpty) {
      setState(() {
        kolams[index].name = newName;
      });
      _saveKolams();
    }
  }

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

  List<Widget> get _pages => [
        _buildDashboardList(),
        ConnectionPage(
          mqttService: mqttService,
          onConnected: () => setState(() {}),
        ),
        HistoryPage(history: history),
        SettingsPage(mqttService: mqttService, onThresholdsChanged: (newThresholds) {
          setState(() {
            thresholds = newThresholds;
            for (var kolam in kolams) {
              kolam.thresholds = thresholds;
              kolam.updateSensorCards();
            }
          });
        }),
      ];

  @override
  void dispose() {
    mqttService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.link),
            label: 'Koneksi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle, color: Colors.cyan),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}