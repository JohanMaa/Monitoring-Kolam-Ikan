import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

// Halaman untuk menampilkan riwayat data sensor
class HistoryPage extends StatefulWidget {
  final List<Map<String, dynamic>> history;
  final Function(List<Map<String, dynamic>>) onHistoryChanged;

  // Konstruktor dengan parameter wajib
  const HistoryPage({super.key, required this.history, required this.onHistoryChanged});

  @override
  HistoryPageState createState() => HistoryPageState();
}

// State untuk mengelola logika halaman riwayat
class HistoryPageState extends State<HistoryPage> {
  String _searchQuery = '';
  late List<Map<String, dynamic>> _history;
  Map<String, List<Map<String, dynamic>>>? _cachedGroupedHistory;

  // Inisialisasi state
  @override
  void initState() {
    super.initState();
    _history = List.from(widget.history);
    _updateGroupedHistory();
  }

  // Memperbarui widget saat data history berubah
  @override
  void didUpdateWidget(covariant HistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.history != oldWidget.history) {
      setState(() {
        _history = List.from(widget.history);
        _updateGroupedHistory();
      });
    }
  }

  // Mengelompokkan riwayat berdasarkan nama kolam
  void _updateGroupedHistory() {
    _cachedGroupedHistory = {};
    for (var entry in _history) {
      final kolamName = entry['kolamName'] as String;
      _cachedGroupedHistory!.putIfAbsent(kolamName, () => []).add(entry);
    }
  }

  // Membangun UI halaman riwayat
  @override
  Widget build(BuildContext context) {
    final filteredKolams = _cachedGroupedHistory!.keys
        .where((name) => name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      // appBar: AppBar(
      //   title: const Text(
      //     'Riwayat Data Sensor',
      //     style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
      //   ),
      //   backgroundColor: Colors.cyan,
      //   elevation: 0,
      // ),
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari nama kolam...',
                prefixIcon: const Icon(Icons.search, color: Colors.cyan),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: filteredKolams.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FontAwesomeIcons.clockRotateLeft,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada data riwayat.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredKolams.length,
                    itemBuilder: (context, index) {
                      final kolamName = filteredKolams[index];
                      final kolamHistory = _cachedGroupedHistory![kolamName]!
                          .asMap()
                          .entries
                          .toList()
                        ..sort((a, b) => DateTime.parse(b.value['timestamp'])
                            .compareTo(DateTime.parse(a.value['timestamp'])));
                      final latestEntries = kolamHistory.take(5).toList();

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      HistoryDetailPage(
                                kolamName: kolamName,
                                history: kolamHistory.map((e) => e.value).toList(),
                                onHistoryChanged: (updatedHistory) {
                                  setState(() {
                                    _history = List.from(updatedHistory);
                                    _updateGroupedHistory();
                                    widget.onHistoryChanged(_history);
                                  });
                                },
                              ),
                              transitionsBuilder:
                                  (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                            ),
                          );
                        },
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Hero(
                                      tag: 'kolam_$kolamName',
                                      child: Text(
                                        kolamName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'delete') {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Hapus Riwayat'),
                                              content: Text(
                                                  'Hapus semua riwayat untuk $kolamName?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: const Text('Batal'),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      _history.removeWhere((entry) =>
                                                          entry['kolamName'] ==
                                                          kolamName);
                                                      _updateGroupedHistory();
                                                      widget
                                                          .onHistoryChanged(_history);
                                                    });
                                                    Navigator.pop(context);
                                                  },
                                                  child: const Text('Hapus',
                                                      style:
                                                          TextStyle(color: Colors.red)),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Hapus Riwayat'),
                                        ),
                                      ],
                                      icon: const Icon(Icons.more_vert,
                                          color: Colors.grey),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Terakhir diperbarui: ${DateFormat('dd MMM yyyy, HH:mm:ss').format(DateTime.parse(latestEntries.first.value['timestamp']).toLocal())}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...latestEntries.map((entry) {
                                  final data =
                                      entry.value['data'] as Map<String, dynamic>;
                                  final prevData = entry.key < kolamHistory.length - 1
                                      ? kolamHistory[entry.key + 1]
                                          .value['data'] as Map<String, dynamic>
                                      : null;
                                  final changes = <String>[];
                                  for (var key in [
                                    'suhu',
                                    'ph',
                                    'dissolvedOxygen',
                                    'berat',
                                    'tinggiAir'
                                  ]) {
                                    if (prevData != null && data[key] != prevData[key]) {
                                      final unit = key == 'suhu'
                                          ? '°C'
                                          : key == 'dissolvedOxygen'
                                              ? 'mg/L'
                                              : key == 'berat'
                                                  ? 'Kg'
                                                  : key == 'tinggiAir'
                                                      ? '%'
                                                      : '';
                                      changes.add(
                                          '$key: ${prevData[key]}$unit → ${data[key]}$unit');
                                    }
                                  }
                                  return changes.isEmpty
                                      ? const SizedBox.shrink()
                                      : Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Text(
                                            changes.join(', '),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        );
                                }),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Halaman detail untuk riwayat sensor per kolam
class HistoryDetailPage extends StatefulWidget {
  final String kolamName;
  final List<Map<String, dynamic>> history;
  final Function(List<Map<String, dynamic>>) onHistoryChanged;

  // Konstruktor dengan parameter wajib
  const HistoryDetailPage({
    super.key,
    required this.kolamName,
    required this.history,
    required this.onHistoryChanged,
  });

  @override
  HistoryDetailPageState createState() => HistoryDetailPageState();
}

// State untuk mengelola logika halaman detail riwayat
class HistoryDetailPageState extends State<HistoryDetailPage> {
  String _selectedDateFilter = 'Semua';
  final List<String> _selectedSensors = [];
  bool _showAllValues = false;
  late List<Map<String, dynamic>> _history;
  int _currentPage = 1;
  final int _itemsPerPage = 50;
  List<Map<String, dynamic>>? _cachedFilteredHistory;

  // Inisialisasi state
  @override
  void initState() {
    super.initState();
    _history = List.from(widget.history);
    _updateFilteredHistory();
  }

  // Memperbarui riwayat yang difilter berdasarkan tanggal dan sensor
  void _updateFilteredHistory() {
    try {
      final sortedHistory = List<Map<String, dynamic>>.from(_history)
        ..sort((a, b) => DateTime.parse(b['timestamp'])
            .compareTo(DateTime.parse(a['timestamp'])));

      _cachedFilteredHistory = sortedHistory.where((entry) {
        final timestamp = DateTime.parse(entry['timestamp']);
        final now = DateTime.now();
        bool dateMatch = true;
        switch (_selectedDateFilter) {
          case 'Hari Ini':
            dateMatch = timestamp.day == now.day &&
                timestamp.month == now.month &&
                timestamp.year == now.year;
            break;
          case 'Kemarin':
            final yesterday = now.subtract(const Duration(days: 1));
            dateMatch = timestamp.day == yesterday.day &&
                timestamp.month == yesterday.month &&
                timestamp.year == yesterday.year;
            break;
          case 'Minggu Ini':
            final weekStart = now.subtract(Duration(days: now.weekday - 1));
            dateMatch =
                timestamp.isAfter(weekStart) || timestamp.isAtSameMomentAs(weekStart);
            break;
          case 'Bulan Ini':
            dateMatch = timestamp.month == now.month && timestamp.year == now.year;
            break;
        }

        if (_selectedSensors.isEmpty) return dateMatch;
        final data = entry['data'] as Map<String, dynamic>;
        final prevEntry = sortedHistory.indexOf(entry) < sortedHistory.length - 1
            ? sortedHistory[sortedHistory.indexOf(entry) + 1]
            : null;
        final prevData =
            prevEntry != null ? prevEntry['data'] as Map<String, dynamic> : null;
        if (_showAllValues) {
          return dateMatch && _selectedSensors.any((sensor) => data.containsKey(sensor));
        }
        return dateMatch &&
            _selectedSensors
                .any((sensor) => prevData != null && data[sensor] != prevData[sensor]);
      }).toList();
    } catch (e) {
      print('Error filtering history: $e');
      _cachedFilteredHistory = [];
    }
  }

  // Membangun UI halaman detail riwayat
  @override
  Widget build(BuildContext context) {
    final displayedHistory = _cachedFilteredHistory!
        .take(_currentPage * _itemsPerPage)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Hero(
          tag: 'kolam_${widget.kolamName}',
          child: Text(
            'Riwayat ${widget.kolamName}',
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
        backgroundColor: Colors.cyan,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.grey.shade100,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButton<String>(
                  value: _selectedDateFilter,
                  isExpanded: true,
                  items: ['Semua', 'Hari Ini', 'Kemarin', 'Minggu Ini', 'Bulan Ini']
                      .map((filter) =>
                          DropdownMenuItem(value: filter, child: Text(filter)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedDateFilter = value!;
                      _currentPage = 1;
                      _updateFilteredHistory();
                    });
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    'suhu',
                    'ph',
                    'dissolvedOxygen',
                    'berat',
                    'tinggiAir'
                  ].map((sensor) {
                    final label = sensor == 'suhu'
                        ? 'Suhu'
                        : sensor == 'ph'
                            ? 'pH'
                            : sensor == 'dissolvedOxygen'
                                ? 'DO'
                                : sensor == 'berat'
                                    ? 'Berat Pakan'
                                    : 'Level Air';
                    return FilterChip(
                      label: Text(label),
                      selected: _selectedSensors.contains(sensor),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSensors.add(sensor);
                          } else {
                            _selectedSensors.remove(sensor);
                          }
                          _currentPage = 1;
                          _updateFilteredHistory();
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // ignore: prefer_const_constructors
                Row(
                  // children: [
                  //   const Text('Tampilkan semua nilai:'),
                  //   Switch(
                  //     value: _showAllValues,
                  //     onChanged: (value) {
                  //       setState(() {
                  //         _showAllValues = value;
                  //         _currentPage = 1;
                  //         _updateFilteredHistory();
                  //       });
                  //     },
                  //   ),
                  // ],
                ),
              ],
            ),
          ),
          Expanded(
            child: displayedHistory.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada riwayat untuk ${widget.kolamName}.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: displayedHistory.length +
                        (_cachedFilteredHistory!.length > displayedHistory.length
                            ? 1
                            : 0),
                    itemBuilder: (context, index) {
                      if (index == displayedHistory.length &&
                          _cachedFilteredHistory!.length > displayedHistory.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _currentPage++;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Muat Lebih Banyak'),
                          ),
                        );
                      }

                      final entry = displayedHistory[index];
                      final data = entry['data'] as Map<String, dynamic>;
                      final timestamp = DateTime.parse(entry['timestamp']);
                      final formattedDate = DateFormat('dd MMM yyyy, HH:mm:ss')
                          .format(timestamp.toLocal());
                      final prevData = index < displayedHistory.length - 1
                          ? displayedHistory[index + 1]['data'] as Map<String, dynamic>
                          : null;

                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    formattedDate,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.cyan.shade700,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Hapus Entri Riwayat'),
                                          content:
                                              const Text('Hapus entri riwayat ini?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Batal'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  _history.remove(entry);
                                                  _updateFilteredHistory();
                                                  widget.onHistoryChanged(_history);
                                                });
                                                Navigator.pop(context);
                                              },
                                              child: const Text('Hapus',
                                                  style:
                                                      TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...[
                                {
                                  'key': 'suhu',
                                  'label': 'Suhu',
                                  'unit': '°C',
                                  'color': Colors.blue
                                },
                                {
                                  'key': 'ph',
                                  'label': 'pH',
                                  'unit': '',
                                  'color': Colors.green
                                },
                                {
                                  'key': 'dissolvedOxygen',
                                  'label': 'DO',
                                  'unit': 'mg/L',
                                  'color': Colors.purple
                                },
                                {
                                  'key': 'berat',
                                  'label': 'Berat Pakan',
                                  'unit': 'Kg',
                                  'color': Colors.orange
                                },
                                {
                                  'key': 'tinggiAir',
                                  'label': 'Level Air',
                                  'unit': '%',
                                  'color': Colors.teal
                                },
                              ].map((sensor) {
                                final key = sensor['key'] as String;
                                final value = data[key].toString();
                                final prevValue =
                                    prevData != null ? prevData[key].toString() : null;
                                final changed =
                                    prevValue != null && value != prevValue;
                                final displayText = changed
                                    ? '${sensor['label']}: $prevValue${sensor['unit']} → $value${sensor['unit']}'
                                    : '${sensor['label']}: $value${sensor['unit']}';
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        sensor['label'] as String,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            displayText,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: changed
                                                  ? Colors.red
                                                  : sensor['color'] as Color,
                                              fontWeight: FontWeight.w600,
                                              backgroundColor:
                                                  changed ? Colors.red.shade100 : null,
                                            ),
                                          ),
                                          if (changed)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(left: 8),
                                              child: Icon(
                                                double.parse(value) >
                                                        double.parse(prevValue)
                                                    ? FontAwesomeIcons.arrowUp
                                                    : FontAwesomeIcons.arrowDown,
                                                size: 14,
                                                color: Colors.red,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}