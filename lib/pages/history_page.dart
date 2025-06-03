import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatelessWidget {
  final List<Map<String, dynamic>> history;

  const HistoryPage({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: history.isEmpty
          ? const Center(
              child: Text(
                'Belum ada data history.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final entry = history[index];
                final kolamName = entry['kolamName'] as String;
                final kolamId = entry['id'] as String?;
                final data = entry['data'] as Map<String, dynamic>;
                final timestamp = DateTime.parse(entry['timestamp'] as String);

                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              kolamName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.cyan,
                              ),
                            ),
                            Text(
                              DateFormat('dd MMM yyyy, HH:mm:ss').format(timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        if (kolamId != null)
                          Text(
                            'ID: $kolamId',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text('Suhu: ${data['suhu']} °C'),
                        Text('pH: ${data['ph']}'),
                        Text('DO: ${data['dissolvedOxygen']} mg/L'),
                        Text('Berat Pakan: ${data['berat']} Kg'),
                        Text('Level Air: ${data['tinggiAir']} %'),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}