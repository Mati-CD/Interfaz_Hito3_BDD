import 'dart:convert';
import 'dart:io';
import 'package:postgres/postgres.dart';

void main() async {
  print('----------------------------------------------------');
  print('🌐 Mega Electric - Servidor Puente de Base de Datos');
  print('----------------------------------------------------');

  final configFile = File('db_config.json');
  if (!await configFile.exists()) {
    print('❌ Error: No se encontró el archivo db_config.json.');
    print('💡 Por favor, crea db_config.json basándote en db_config.example.json.');
    exit(1);
  }

  final configContent = await configFile.readAsString();
  final config = jsonDecode(configContent) as Map<String, dynamic>;

  final host = config['DB_HOST'] as String;
  final port = config['DB_PORT'] as int;
  final database = config['DB_NAME'] as String;
  final user = config['DB_USER'] as String;
  final password = config['DB_PASSWORD'] as String;

  print('🔌 Conectando a PostgreSQL en $host:$port...');
  print('🗄️ Base de datos: $database');
  print('👤 Usuario: $user');

  Connection? conn;
  try {
    final endpoint = Endpoint(
      host: host,
      port: port,
      database: database,
      username: user,
      password: password,
    );

    conn = await Connection.open(
      endpoint,
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );
    
    // Establecer el esquema predeterminado para la sesión del servidor API
    await conn.execute('SET search_path TO registro_costos_marginales, public;');
    
    print('✅ Conexión exitosa a PostgreSQL.');
  } catch (e) {
    print('❌ Error al conectar a PostgreSQL: $e');
    print('\n💡 POR FAVOR VERIFICA:');
    print('1. Que tu servidor local de PostgreSQL esté encendido.');
    print('2. Que las credenciales en db_config.json sean correctas.');
    exit(1);
  }

  final serverPort = 8080;
  HttpServer server;
  try {
    server = await HttpServer.bind(InternetAddress.anyIPv4, serverPort);
    print('🚀 Servidor API escuchando en http://localhost:$serverPort');
    print('💡 Tu app de Flutter Web ahora puede comunicarse con PostgreSQL a través de este servidor.');
    print('💡 Escribe "q", "exit" o "stop" y presiona Enter para apagar el servidor en cualquier momento.');

    // Escuchar la entrada de la terminal para cerrar el servidor de forma elegante
    stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((line) async {
      final cmd = line.trim().toLowerCase();
      if (cmd == 'q' || cmd == 'quit' || cmd == 'exit' || cmd == 'stop') {
        print('👋 Cerrando servidor puente y conexión a PostgreSQL...');
        await server.close(force: true);
        await conn?.close();
        exit(0);
      }
    });
  } catch (e) {
    print('❌ Error al iniciar el servidor HTTP: $e');
    await conn.close();
    exit(1);
  }

  await for (HttpRequest request in server) {
    // Agregar cabeceras CORS para permitir peticiones desde el navegador
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

    // Manejar preflight OPTIONS
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      continue;
    }

    if (request.method == 'POST' && request.uri.path == '/query') {
      try {
        final body = await utf8.decoder.bind(request).join();
        final payload = jsonDecode(body) as Map<String, dynamic>;
        
        final sql = payload['query'] as String;
        final params = payload['parameters'] as Map<String, dynamic>?;

        print('📝 Ejecutando consulta: ${sql.trim().replaceAll(RegExp(r'\s+'), ' ')}');
        if (params != null) {
          print('   Parámetros: $params');
        }

        final result = await conn.execute(
          Sql.named(sql),
          parameters: params,
        );

        final rows = result.map((row) => row.toColumnMap()).toList();
        
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.ok
          ..write(jsonEncode({'success': true, 'data': rows}));
          
        print('✅ Consulta ejecutada con éxito. Filas devueltas: ${rows.length}');
      } catch (e) {
        print('❌ Error en consulta: $e');
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.internalServerError
          ..write(jsonEncode({'success': false, 'error': e.toString()}));
      } finally {
        await request.response.close();
      }
    } else {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    }
  }
}
