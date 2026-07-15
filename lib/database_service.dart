import 'dart:convert';
import 'package:http/http.dart' as http;

class DatabaseService {
  // Configuración de la API (nuestro servidor puente)
  static const String _apiUri = 'http://localhost:8080/query';

  // Métodos de compatibilidad si algún archivo lee las constantes antiguas
  static const String host = 'localhost';
  static const int port = 8080;
  static const String databaseName = 'postgres';
  static const String username = 'postgres';
  static const String password = '';

  // Método para ejecutar consultas en el servidor puente
  static Future<List<Map<String, dynamic>>> query(
    String sql, {
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUri),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': sql,
          'parameters': parameters,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List<dynamic> list = body['data'];
          return list.map((item) => Map<String, dynamic>.from(item)).toList();
        } else {
          throw Exception(body['error']);
        }
      } else {
        try {
          final body = jsonDecode(response.body);
          throw Exception(body['error'] ?? 'Error del servidor puente');
        } catch (_) {
          throw Exception('Error del servidor puente (Código ${response.statusCode})');
        }
      }
    } catch (e) {
      print('❌ Error de consulta a la API local: $e');
      rethrow;
    }
  }
}


