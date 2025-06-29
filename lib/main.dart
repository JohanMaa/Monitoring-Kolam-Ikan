import 'package:flutter/material.dart';
import 'pages/dashboard_page.dart';
import 'package:google_fonts/google_fonts.dart';

// Fungsi utama untuk menjalankan aplikasi
void main() {
  runApp(MonitoringKolamIkanApp());
}

// Class utama aplikasi (StatelessWidget)
class MonitoringKolamIkanApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Mengatur konfigurasi aplikasi
    return MaterialApp(
      title: 'Monitoring Kolam Ikan',
      theme: ThemeData(
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan),
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      home: const DashboardPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}