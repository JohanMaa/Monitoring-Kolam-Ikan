import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/kolam.dart';
import '../models/sensor_data.dart';
import 'package:uuid/uuid.dart';
import '../widgets/sensor_card.dart';
import '../services/mqtt_service.dart';
import 'settings_page.dart';
import 'connection_page.dart';
import '../services/default_threshold.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  DashboardPageState createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late MqttService mqttService;
  int _selectedIndex = 0;
  List<Kolam> kolams = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  Map<String, SensorThreshold> thresholds = defaultThresholds;

  @override
  void initState() {
    super.initState();
    mqttService = MqttService();
    mqttService.onDataReceived = updateSensorData;
    mqttService.connect();
    _initialKolam();
  }

  List<SensorCardData> _initialSensorData(SensorData sensorData) {
    final statuses = sensorData.getStatusMap(thresholds);
    return [
      SensorCardData(
        icon: const Icon(Icons.thermostat),
        label: 'Suhu',
        value: '${sensorData.suhu.toStringAsFixed(1)} °C',
        color: getColorForStatus(statuses['suhu']!),
      ),
      SensorCardData(
        icon: const Icon(Icons.opacity),
        label: 'pH',
        value: '${sensorData.ph.toStringAsFixed(1)}',
        color: getColorForStatus(statuses['ph']!),
      ),
      SensorCardData(
        icon: const Icon(Icons.blur_on),
        label: 'Kekeruhan',
        value: '${sensorData.kekeruhan.toStringAsFixed(1)} NTU',
        color: getColorForStatus(statuses['kekeruhan']!),
      ),
      SensorCardData(
        icon: const Icon(Icons.waves),
        label: 'DO',
        value: '${sensorData.dissolvedOxygen.toStringAsFixed(1)} mg/L',
        color: getColorForStatus(statuses['dissolved_oxygen']!),
      ),
      SensorCardData(
        icon: const Icon(Icons.fastfood),
        label: 'Berat Pakan',
        value: '${sensorData.berat.toStringAsFixed(1)} Kg',
        color: getColorForStatus(statuses['berat']!),
      ),
      SensorCardData(
        icon: const Icon(Icons.water_drop),
        label: 'Level Air',
        value: '${sensorData.tinggiAir.toStringAsFixed(1)} %',
        color: getColorForStatus(statuses['tinggi_air']!),
      ),
    ];
  }

  void _initialKolam() {
    setState(() {
      final newKolam = Kolam(
        name: 'Kolam 1',
        data: SensorData(
          suhu: 0,
          ph: 0,
          kekeruhan: 0,
          dissolvedOxygen: 0,
          berat: 0,
          tinggiAir: 0,
          sensorType: 'Suhu',
          value: 0,
        ),
        thresholds: defaultThresholds,
        sensorData: [],
      );
      newKolam.updateSensorCards();
      kolams.add(newKolam);
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
    final kolamName = data['kolam'];
    if (kolamName == null) return;

    setState(() {
      for (var kolam in kolams) {
        if (kolam.name == kolamName) {
          kolam.data = SensorData(
            suhu: (data['suhu'] ?? kolam.data.suhu).toDouble(),
            ph: (data['ph'] ?? kolam.data.ph).toDouble(),
            kekeruhan: (data['kekeruhan'] ?? kolam.data.kekeruhan).toDouble(),
            dissolvedOxygen: (data['do'] ?? kolam.data.dissolvedOxygen).toDouble(),
            berat: (data['berat_pakan'] ?? kolam.data.berat).toDouble(),
            tinggiAir: (data['level_air'] ?? kolam.data.tinggiAir).toDouble(),
            sensorType: data['sensorType'] ?? kolam.data.sensorType,
            value: (data['value'] ?? kolam.data.value).toDouble(),
          );
          kolam.updateSensorCards();
        }
      }
    });
  }

  void _addKolam() async {
    final String kolamName = await _showInputDialog();
    if (kolamName.isNotEmpty) {
      final uuid = Uuid();
      final String kolamId = uuid.v4();
      final Kolam newKolam = Kolam.generate(kolamId, kolamName);

      newKolam.updateSensorCards();

      setState(() {
        kolams.add(newKolam);
      });
      _listKey.currentState?.insertItem(
        kolams.length - 1,
        duration: const Duration(milliseconds: 500),
      );
      _selectedIndex = 0;
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
              final String? namaKolam = data['kolam'];
              if (namaKolam == kolam.name) {
                setStateDialog(() {
                  kolam.data = SensorData(
                    suhu: (data['suhu'] ?? kolam.data.suhu).toDouble(),
                    ph: (data['ph'] ?? kolam.data.ph).toDouble(),
                    kekeruhan:
                        (data['kekeruhan'] ?? kolam.data.kekeruhan).toDouble(),
                    dissolvedOxygen:
                        (data['do'] ?? kolam.data.dissolvedOxygen).toDouble(),
                    berat: (data['berat_pakan'] ?? kolam.data.berat).toDouble(),
                    tinggiAir:
                        (data['level_air'] ?? kolam.data.tinggiAir).toDouble(),
                    sensorType: data['sensorType'] ?? kolam.data.sensorType,
                    value: (data['value'] ?? kolam.data.value).toDouble(),
                  );
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
                    final data = kolam.sensorData[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: SensorCard(
                        label: data.label,
                        value: data.value,
                        unit: data.label == 'Suhu'
                            ? '°C'
                            : data.label == 'DO'
                                ? 'mg/L'
                                : data.label == 'Kekeruhan'
                                    ? 'NTU'
                                    : data.label == 'Berat Pakan'
                                        ? 'Kg'
                                        : data.label == 'Level Air'
                                            ? '%'
                                            : '',
                        status: kolam.data
                                .getStatusMap(thresholds)[
                                    data.label.toLowerCase().replaceAll(' ', '_')] ??
                            SensorStatus.normal,
                        data: kolam.data,
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
              const SizedBox(height: 10),
              for (var data in kolam.sensorData)
                Text('${data.label}: ${data.value}'),
              const SizedBox(height: 10),
              Text('Status: ${kolam.data.getStatusMap(thresholds)}'),
              Text('Waktu Terakhir Update: ${DateTime.now().toLocal()}'),
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
        const Center(child: Text('Tidak ada notifikasi')),
        SettingsPage(mqttService: mqttService),
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
            icon: Icon(Icons.notifications),
            label: 'Notifikasi',
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