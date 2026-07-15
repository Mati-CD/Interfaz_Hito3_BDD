import 'dart:convert';
import 'dart:io';
import 'package:postgres/postgres.dart';

void main() async {
  print('----------------------------------------------------');
  print('🚀 Mega Electric - Importador de Base de Datos');
  print('----------------------------------------------------');

  final file = File('bd/iniciar_bd.sql');
  if (!await file.exists()) {
    print('❌ Error: No se encontró el archivo bd/iniciar_bd.sql');
    exit(1);
  }

  print('📖 Leyendo bd/iniciar_bd.sql (5 MB)...');
  final sqlContent = await file.readAsString();

  // Configuración por defecto
  Map<String, dynamic> config = {
    'DB_HOST': 'localhost',
    'DB_PORT': 5432,
    'DB_NAME': 'registro_costos_marginales',
    'DB_USER': 'postgres',
    'DB_PASSWORD': 'tu_contraseña',
  };

  // Intentar cargar la configuración local de db_config.json
  final configFile = File('db_config.json');
  if (await configFile.exists()) {
    try {
      final content = await configFile.readAsString();
      final parsed = jsonDecode(content) as Map<String, dynamic>;
      config.addAll(parsed);
      print('📝 Cargada configuración desde db_config.json');
    } catch (e) {
      print('⚠️ Advertencia: No se pudo leer db_config.json, usando valores por defecto: $e');
    }
  } else {
    print('💡 No se encontró db_config.json. Usando valores por defecto.');
    print('💡 Puedes copiar db_config.example.json como db_config.json para personalizar.');
  }

  final host = config['DB_HOST'] as String;
  final port = config['DB_PORT'] as int;
  final database = config['DB_NAME'] as String;
  final user = config['DB_USER'] as String;
  final password = config['DB_PASSWORD'] as String;

  print('📖 Procesando sentencias SQL...');
  final lines = const LineSplitter().convert(sqlContent);
  final List<String> statements = [];
  
  // Agregar caída del esquema si ya existe para evitar conflictos en re-ejecuciones
  statements.add('DROP SCHEMA IF EXISTS registro_costos_marginales CASCADE;');
  
  var currentStatement = StringBuffer();
  var insideDollarQuote = false;
  
  for (var line in lines) {
    final trimmed = line.trim();
    if (trimmed.contains('\$\$')) {
      insideDollarQuote = !insideDollarQuote;
    }
    currentStatement.writeln(line);
    if (!insideDollarQuote && trimmed.endsWith(';')) {
      final stmtText = currentStatement.toString().trim();
      currentStatement.clear();
      
      if (stmtText.isEmpty) continue;
      if (stmtText.toLowerCase().contains('transaction_timeout')) continue;
      
      statements.add(stmtText);
    }
  }
  if (currentStatement.toString().trim().isNotEmpty) {
    final stmtText = currentStatement.toString().trim();
    if (!stmtText.toLowerCase().contains('transaction_timeout')) {
      statements.add(stmtText);
    }
  }

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
    print('✅ Conexión exitosa a PostgreSQL.');
  } catch (e) {
    print('❌ Error al conectar a PostgreSQL: $e');
    print('\n💡 POR FAVOR VERIFICA:');
    print('1. Que tu servidor local de PostgreSQL esté encendido.');
    print('2. Que la base de datos "$database" ya exista. Si no existe, debes crearla primero.');
    print('3. Que las credenciales (especialmente la contraseña) sean correctas.');
    exit(1);
  }

  print('⏳ Importando ${statements.length} sentencias en una transacción. Esto puede tomar unos segundos...');
  final stopwatch = Stopwatch()..start();
  
  try {
    await conn.runTx((session) async {
      var count = 0;
      for (final stmt in statements) {
        await session.execute(stmt);
        count++;
        if (count % 5000 == 0) {
          print('⏳ Importados $count / ${statements.length} comandos...');
        }
      }
    });
    print('🎉 ¡Base de datos importada correctamente en el esquema "registro_costos_marginales" en ${stopwatch.elapsed.inSeconds} segundos!');
  } catch (e) {
    print('❌ Error durante la importación: $e');
  } finally {
    await conn.close();
  }
}
