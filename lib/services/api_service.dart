import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Android Emulator 访问 Windows 主机要用 10.0.2.2
  static const String baseUrl = 'http://10.0.2.2:8080';

  static Future<Map<String, dynamic>> askQuestion(String question) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/chat'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'question': question,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Failed to get answer';

      try {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['error'] != null) {
          message = data['error'].toString();
        }
      } catch (_) {}

      throw Exception(message);
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getDocuments() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/documents'),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load documents');
    }

    final data = jsonDecode(response.body);

    return data['documents'] ?? [];
  }
}
