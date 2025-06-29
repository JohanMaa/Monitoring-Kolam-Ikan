import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  static const String baseUrl = "http://192.168.163.1/api_kolam_ikan/"; // Ganti dengan IP lokal Anda

  // Fungsi untuk menyimpan data riwayat ke database
  Future<void> saveHistory(Map<String, dynamic> historyData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/save_history.php'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(historyData),
    );

    if (response.statusCode != 200) {
      throw Exception('Gagal menyimpan riwayat: ${response.body}');
    }

    final result = json.decode(response.body);
    if (result['status'] != 'success') {
      throw Exception('Gagal menyimpan riwayat: ${result['message']}');
    }
  }

  // Fungsi untuk mengambil data riwayat dari database
  Future<List<Map<String, dynamic>>> fetchHistory(String? kolamName) async {
    final url = kolamName != null 
        ? '$baseUrl/get_history.php?kolam_name=$kolamName'
        : '$baseUrl/get_history.php';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Gagal mengambil riwayat: ${response.body}');
    }
  }
}