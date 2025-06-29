
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

// Konfigurasi sensor yang digunakan di kedua halaman
const _sensorConfigs = [
  {'key': 'suhu', 'label': 'Suhu', 'unit': '°C', 'color': Colors.blue},
  {'key': 'ph', 'label': 'pH', 'unit': '', 'color': Colors.green},
  {'key': 'dissolvedOxygen', 'label': 'DO', 'unit': 'mg/L', 'color': Colors.purple},
  {'key': 'berat', 'label': 'Berat Pakan', 'unit': 'Kg', 'color': Colors.orange},
  {'key': 'tinggiAir', 'label': 'Level Air', 'unit': '%', 'color': Colors.teal},
];

// Halaman untuk menampilkan riwayat data sensor
class HistoryPage extends StatefulWidget {
  final List<Map<String, dynamic>> history;
  final Function(List<Map<String, dynamic>>) onHistoryChanged;

  /// Konstruktor dengan parameter wajib untuk riwayat dan callback saat riwayat berubah.
  const HistoryPage({
    super.key,
    required this.history,
    required this.onHistoryChanged,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _searchQuery = '';
  late List<Map<String, dynamic>> _history;
  Map<String, List<Map<String, dynamic>>>? _cachedGroupedHistory;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _history = widget.history;
    _updateGroupedHistory();
  }

  @override
  void didUpdateWidget(covariant HistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.history != oldWidget.history) {
      setState(() {
        _history = widget.history;
        _updateGroupedHistory();
      });
    }
  }

  /// Mengelompokkan riwayat berdasarkan nama kolam dan mengurutkan berdasarkan timestamp.
  void _updateGroupedHistory() {
    try {
      _cachedGroupedHistory = {};
      for (var entry in _history) {
        final kolamName = entry['kolamName'] as String? ?? 'Unknown';
        _cachedGroupedHistory!.putIfAbsent(kolamName, () => []).add(entry);
      }
      _cachedGroupedHistory!.forEach((key, value) {
        value.sort((a, b) {
          final aTime = DateTime.tryParse(a['timestamp'] as String? ?? '');
          final bTime = DateTime.tryParse(b['timestamp'] as String? ?? '');
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memproses riwayat: $e'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      _cachedGroupedHistory = {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredKolams = _cachedGroupedHistory!.keys
        .where((name) => name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: const Text(
          'Riwayat Data Sensor',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.cyan.shade600,
        elevation: 3,
        shadowColor: Colors.cyan.shade200.withOpacity(0.4),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
            tooltip: 'Segarkan Data',
            splashRadius: 22,
          ),
          const SizedBox(width: 8),
        ],
      ),

      backgroundColor: Colors.grey.shade100,
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari nama kolam...',
                    prefixIcon: const Icon(Icons.search, color: Colors.cyan),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: filteredKolams.isEmpty
                      ? Center(
                          key: const ValueKey('empty'),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                FontAwesomeIcons.clockRotateLeft,
                                size: 50,
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
                          key: const ValueKey('list'),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filteredKolams.length,
                          itemBuilder: (context, index) {
                            final kolamName = filteredKolams[index];
                            final kolamHistory =
                                _cachedGroupedHistory![kolamName]!.take(5).toList();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildKolamCard(kolamName, kolamHistory),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.cyan),
              ),
            ),
        ],
      ),
    );
  }

  /// Membangun kartu untuk setiap kolam dengan ringkasan riwayat.
  Widget _buildKolamCard(String kolamName, List<Map<String, dynamic>> kolamHistory) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => HistoryDetailPage(
              kolamName: kolamName,
              history: _history
                  .where((entry) => entry['kolamName'] == kolamName)
                  .toList(),
              onHistoryChanged: (updatedHistory) {
                setState(() {
                  _history = updatedHistory;
                  _updateGroupedHistory();
                  widget.onHistoryChanged(_history);
                });
              },
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 8),
        shadowColor: Colors.black12,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Nama Kolam + Menu
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
                            content: Text('Hapus semua riwayat untuk "$kolamName"?'),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Batal'),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _history.removeWhere((entry) => entry['kolamName'] == kolamName);
                                    _updateGroupedHistory();
                                    widget.onHistoryChanged(_history);
                                  });
                                  Navigator.pop(context);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Riwayat untuk "$kolamName" dihapus'),
                                        backgroundColor: Colors.red.shade400,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Hapus', style: TextStyle(color: Colors.red)),
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
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Waktu Terakhir Update
              if (kolamHistory.isNotEmpty &&
                  DateTime.tryParse(kolamHistory.first['timestamp'] as String? ?? '') != null)
                Text(
                  'Terakhir diperbarui: ${DateFormat('dd MMM yyyy, HH:mm:ss').format(DateTime.parse(kolamHistory.first['timestamp']).toLocal())}',
                  style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600),
                ),

              const SizedBox(height: 12),

              // Ringkasan Perubahan
              ...kolamHistory.asMap().entries.map((entry) {
                final data = entry.value['data'] as Map<String, dynamic>;
                final prevData = entry.key < kolamHistory.length - 1
                    ? kolamHistory[entry.key + 1]['data'] as Map<String, dynamic>
                    : null;
                final changes = _getSensorChanges(data, prevData);
                return changes.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• ${changes.join(', ')}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      );
              }),
            ],
          ),
        ),
      ),
    );
  }

  /// Mendapatkan perubahan sensor antara data saat ini dan sebelumnya.
  List<String> _getSensorChanges(Map<String, dynamic> data, Map<String, dynamic>? prevData) {
    final changes = <String>[];
    if (prevData == null) return changes;
    for (var sensor in _sensorConfigs) {
      final key = sensor['key'] as String;
      if (data[key] != prevData[key]) {
        changes.add(
            '${sensor['label']}: ${prevData[key] ?? '-'}${sensor['unit']} → ${data[key] ?? '-'}${sensor['unit']}');
      }
    }
    return changes;
  }

  /// Menyegarkan data riwayat dari sumber data (misalnya, MQTT).
  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // TODO: Implementasikan pengambilan data dari MQTT atau sumber lain
      // Contoh: final newData = await mqttService.fetchHistory();
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _updateGroupedHistory();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data riwayat diperbarui'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui data: $e'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// Halaman detail untuk riwayat sensor per kolam
class HistoryDetailPage extends StatefulWidget {
  final String kolamName;
  final List<Map<String, dynamic>> history;
  final Function(List<Map<String, dynamic>>) onHistoryChanged;

  /// Konstruktor untuk halaman detail riwayat.
  const HistoryDetailPage({
    super.key,
    required this.kolamName,
    required this.history,
    required this.onHistoryChanged,
  });

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> {
  String _selectedDateFilter = 'Semua';
  final List<String> _selectedSensors = [];
  bool _showAllValues = false;
  late List<Map<String, dynamic>> _history;
  int _currentPage = 1;
  final int _itemsPerPage = 50;
  List<Map<String, dynamic>>? _cachedFilteredHistory;
  bool _isLoading = false;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _history = widget.history;
    _updateFilteredHistory();
  }

  /// Memperbarui riwayat yang difilter berdasarkan tanggal dan sensor.
  void _updateFilteredHistory() {
    setState(() {
      _isLoading = true;
    });
    try {
      _cachedFilteredHistory = _history
          .where((entry) {
            final timestamp = DateTime.tryParse(entry['timestamp'] as String? ?? '');
            if (timestamp == null) return false;
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
                dateMatch = timestamp.isAfter(weekStart) ||
                    timestamp.isAtSameMomentAs(weekStart);
                break;
              case 'Bulan Ini':
                dateMatch = timestamp.month == now.month && timestamp.year == now.year;
                break;
            }

            if (_selectedSensors.isEmpty) return dateMatch;
            final data = entry['data'] as Map<String, dynamic>? ?? {};
            final index = _history.indexOf(entry);
            final prevEntry = index < _history.length - 1 ? _history[index + 1] : null;
            final prevData =
                prevEntry != null ? prevEntry['data'] as Map<String, dynamic>? : null;
            if (_showAllValues) {
              return dateMatch && _selectedSensors.any((sensor) => data.containsKey(sensor));
            }
            return dateMatch &&
                _selectedSensors.any(
                    (sensor) => prevData != null && data[sensor] != prevData[sensor]);
          })
          .toList()
        ..sort((a, b) {
          final aTime = DateTime.tryParse(a['timestamp'] as String? ?? '');
          final bTime = DateTime.tryParse(b['timestamp'] as String? ?? '');
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memfilter riwayat: $e'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      _cachedFilteredHistory = [];
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedHistory = _cachedFilteredHistory!.take(_currentPage * _itemsPerPage).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.cyan.shade600,
            pinned: true,
            expandedHeight: 120.0,
            elevation: 4,
            shadowColor: Colors.cyan.shade200.withOpacity(0.3),
            leading: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Kembali',
                splashRadius: 22,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _refreshData,
                tooltip: 'Segarkan Data',
                splashRadius: 22,
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
              title: Hero(
                tag: 'kolam_${widget.kolamName}',
                child: Text(
                  'Riwayat ${widget.kolamName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filter Riwayat',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedDateFilter,
                        decoration: const InputDecoration(
                          labelText: 'Periode Waktu',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today, color: Colors.cyan),
                        ),
                        items: [
                          'Semua',
                          'Hari Ini',
                          'Kemarin',
                          'Minggu Ini',
                          'Bulan Ini'
                        ].map((filter) {
                          return DropdownMenuItem(value: filter, child: Text(filter));
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedDateFilter = value!;
                            _currentPage = 1;
                            _updateFilteredHistory();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Pilih Sensor',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _sensorConfigs.map((sensor) {
                          final key = sensor['key'] as String;
                          return FilterChip(
                            label: Text(sensor['label'] as String),
                            selected: _selectedSensors.contains(key),
                            selectedColor: Colors.cyan.withOpacity(0.2),
                            checkmarkColor: Colors.cyan,
                            labelStyle: TextStyle(
                              color: _selectedSensors.contains(key)
                                  ? Colors.cyan
                                  : Colors.black87,
                            ),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedSensors.add(key);
                                } else {
                                  _selectedSensors.remove(key);
                                }
                                _currentPage = 1;
                                _updateFilteredHistory();
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tampilkan Semua Nilai',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          Switch(
                            value: _showAllValues,
                            activeColor: Colors.cyan,
                            onChanged: (value) {
                              setState(() {
                                _showAllValues = value;
                                _currentPage = 1;
                                _updateFilteredHistory();
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          displayedHistory.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FontAwesomeIcons.database,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tidak ada riwayat untuk ${widget.kolamName}.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == displayedHistory.length &&
                          _cachedFilteredHistory!.length > displayedHistory.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          child: _isLoadingMore
                              ? const Center(
                                  child: CircularProgressIndicator(color: Colors.cyan),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () async {
                                    setState(() {
                                      _isLoadingMore = true;
                                    });
                                    await Future.delayed(const Duration(milliseconds: 500));
                                    setState(() {
                                      _currentPage++;
                                      _isLoadingMore = false;
                                    });
                                  },
                                  icon: const Icon(Icons.expand_more, color: Colors.white),
                                  label: const Text('Muat Lebih Banyak'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.cyan,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                        );
                      }
                      final entry = displayedHistory[index];
                      return AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: _buildHistoryCard(entry, index),
                      );
                    },
                    childCount: displayedHistory.length +
                        (_cachedFilteredHistory!.length > displayedHistory.length ? 1 : 0),
                  ),
                ),
        ],
      ),
      floatingActionButton: _cachedFilteredHistory!.isNotEmpty
          ? FloatingActionButton(
              onPressed: () {
                Scrollable.ensureVisible(
                  context,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              },
              backgroundColor: Colors.cyan,
              child: const Icon(Icons.arrow_upward, color: Colors.white),
              tooltip: 'Kembali ke Atas',
            )
          : null,
    );
  }

  /// Membangun kartu untuk setiap entri riwayat.
  Widget _buildHistoryCard(Map<String, dynamic> entry, int index) {
    final data = entry['data'] as Map<String, dynamic>? ?? {};
    final timestamp = DateTime.tryParse(entry['timestamp'] as String? ?? '');
    if (timestamp == null) return const SizedBox.shrink();
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm:ss').format(timestamp.toLocal());
    final prevEntry = index < _history.length - 1 ? _history[index + 1] : null;
    final prevData =
        prevEntry != null ? prevEntry['data'] as Map<String, dynamic>? : null;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.cyan.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(FontAwesomeIcons.trash, color: Colors.red),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Hapus Entri Riwayat'),
                        content: const Text('Hapus entri riwayat ini?'),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
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
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Entri riwayat dihapus'),
                                    backgroundColor: Colors.blue,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            child: const Text(
                              'Hapus',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  tooltip: 'Hapus Entri',
                ),
              ],
            ),
            const Divider(height: 16, thickness: 1),
            ..._sensorConfigs.map((sensor) {
              final key = sensor['key'] as String;
              if (!_showAllValues &&
                  _selectedSensors.isNotEmpty &&
                  !_selectedSensors.contains(key)) {
                return const SizedBox.shrink();
              }
              final value = data[key]?.toString() ?? '-';
              final prevValue = prevData != null ? prevData[key]?.toString() : null;
              final changed = prevValue != null && value != prevValue;
              final displayText = changed
                  ? '${sensor['label']}: $prevValue${sensor['unit']} → $value${sensor['unit']}'
                  : '${sensor['label']}: $value${sensor['unit']}';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            color: changed ? Colors.red : sensor['color'] as Color,
                            fontWeight: FontWeight.w600,
                            backgroundColor: changed ? Colors.red.shade100 : null,
                          ),
                        ),
                        if (changed && prevValue != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              (double.tryParse(value) ?? 0) >
                                      (double.tryParse(prevValue) ?? 0)
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
  }

  /// Menyegarkan data riwayat dari sumber data (misalnya, MQTT).
  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // TODO: Implementasikan pengambilan data dari MQTT atau sumber lain
      // Contoh: final newData = await mqttService.fetchHistory();
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _updateFilteredHistory();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data riwayat diperbarui'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui data: $e'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}