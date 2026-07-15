import 'package:flutter/material.dart';
import 'package:interfaz_hito3_bdd/database_service.dart';

void main() {
  runApp(const MegaElectricApp());
}

class MegaElectricApp extends StatelessWidget {
  const MegaElectricApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mega Electric CMG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const LoginScreen(),
    );
  }
}

class PostgresDatabase {
  // 1. LOGIN (Lectura directa de tu tabla 'encargado')
  static Future<Map<String, dynamic>?> login(String rut) async {
    final result = await DatabaseService.query(
      'SELECT * FROM encargado WHERE rut_encargado = @rut LIMIT 1',
      parameters: {'rut': rut},
    );

    if (result.isEmpty) return null;
    return result.first;
  }

  // 2. DASHBOARD: Barras asignadas al encargado
  static Future<List<Map<String, dynamic>>> getBarrasByEncargado(
    String rut,
  ) async {
    final result = await DatabaseService.query(
      'SELECT * FROM barra WHERE rut_encargado = @rut',
      parameters: {'rut': rut},
    );
    return result.map((fila) {
      final map = Map<String, dynamic>.from(fila);
      map['nivel_tension_kv'] = double.tryParse(map['nivel_tension_kv']?.toString() ?? '') ?? 0.0;
      return map;
    }).toList();
  }

  // 3. DETALLE: Resumen Estadístico Anual (Aprovechamos las funciones de PostgreSQL)
  static Future<Map<String, dynamic>> getResumenAnual(
    int idBarra,
    int anio,
  ) async {
    final result = await DatabaseService.query(
      '''
        SELECT
          COALESCE(AVG(valor_cmg), 0.0) as avg,
          COALESCE(MAX(valor_cmg), 0.0) as max,
          COALESCE(MIN(valor_cmg), 0.0) as min,
          COUNT(*) as count
        FROM costo_marginal
        WHERE id_barra = @id AND "año" = @anio
      ''',
      parameters: {'id': idBarra, 'anio': anio},
    );

    if (result.isEmpty) {
      return {'avg': 0.0, 'max': 0.0, 'min': 0.0, 'count': 0};
    }

    final fila = result.first;
    return {
      'avg': double.tryParse(fila['avg']?.toString() ?? '') ?? 0.0,
      'max': double.tryParse(fila['max']?.toString() ?? '') ?? 0.0,
      'min': double.tryParse(fila['min']?.toString() ?? '') ?? 0.0,
      'count': int.tryParse(fila['count']?.toString() ?? '') ?? 0,
    };
  }

  // 4. DETALLE: Comparativa Estacional
  static Future<Map<String, dynamic>> getComparativaEstacional(
    int idBarra,
  ) async {
    final result = await DatabaseService.query(
      '''
        SELECT
          COALESCE(AVG(c.valor_cmg), 0.0) as avg_global,
          COALESCE(AVG(CASE WHEN t.nombre_temporada = 'Verano' THEN c.valor_cmg END), 0.0) as avg_verano
        FROM costo_marginal c
        LEFT JOIN temporada t ON c.id_temporada = t.id_temporada
        WHERE c.id_barra = @id
      ''',
      parameters: {'id': idBarra},
    );

    final fila = result.first;
    return {
      'avg_verano': double.tryParse(fila['avg_verano']?.toString() ?? '') ?? 0.0,
      'avg_global': double.tryParse(fila['avg_global']?.toString() ?? '') ?? 0.0,
    };
  }

  // 5. DETALLE: Historial Cronológico
  static Future<List<Map<String, dynamic>>> getHistorial(int idBarra) async {
    final result = await DatabaseService.query(
      '''
        SELECT
          c.id_cmg,
          c.valor_cmg,
          c.unidad_medida,
          c."año" as año,
          c.mes,
          c.dia,
          c.hora::text as hora,
          c.id_barra,
          c.id_bloquehorario,
          t.nombre_temporada as temporada
        FROM costo_marginal c
        LEFT JOIN temporada t ON c.id_temporada = t.id_temporada
        WHERE c.id_barra = @id
        ORDER BY c."año" DESC, c.mes DESC, c.dia DESC, c.hora DESC
      ''',
      parameters: {'id': idBarra},
    );
    return result.map((fila) {
      final map = Map<String, dynamic>.from(fila);
      map['valor_cmg'] = double.tryParse(map['valor_cmg']?.toString() ?? '') ?? 0.0;
      return map;
    }).toList();
  }
}


// // ==========================================
// // 0. MOCK DATABASE (REPRESENTACIÓN DE TU DDL)
// // ==========================================
// class MockDatabase {
//   // Simulación Tabla: encargado
//   static const List<Map<String, dynamic>> encargados = [
//     {
//       'rut_encargado': '15.444.333-2',
//       'nombre_encargado': 'Sebastian Perez',
//       'correo_encargado': 'Sperez@megaelectric.cl'
//     },
//   ];

//   // Simulación Tabla: barra (Relacionada con el RUT del encargado)
//   static const List<Map<String, dynamic>> barras = [
//     {
//       'id_barra': 321,
//       'nombre_barra': 'Barra Biobío A',
//       'nivel_tension_kv': 110.0,
//       'rut_encargado': '15.444.333-2',
//       'id_subestacion': 1
//     },
//     {
//       'id_barra': 324,
//       'nombre_barra': 'Barra San Pedro',
//       'nivel_tension_kv': 220.0,
//       'rut_encargado': '15.444.333-2',
//       'id_subestacion': 2
//     },
//   ];

//   // Simulación Tabla: costo_marginal
//   static const List<Map<String, dynamic>> costosMarginales = [
//     // Registros para Barra Biobío A (id_barra: 321)
//     {'id_cmg': 1, 'valor_cmg': 50.0, 'año': 2025, 'mes': 1, 'dia': 15, 'hora': '10:00', 'id_barra': 321, 'temporada': 'Verano'},
//     {'id_cmg': 2, 'valor_cmg': 120.5, 'año': 2025, 'mes': 1, 'dia': 15, 'hora': '14:00', 'id_barra': 321, 'temporada': 'Verano'},
//     {'id_cmg': 3, 'valor_cmg': 10.0, 'año': 2025, 'mes': 7, 'dia': 10, 'hora': '03:00', 'id_barra': 321, 'temporada': 'Invierno'},
//     {'id_cmg': 4, 'valor_cmg': 85.0, 'año': 2025, 'mes': 7, 'dia': 10, 'hora': '19:00', 'id_barra': 321, 'temporada': 'Invierno'},

//     // Registros para Barra San Pedro (id_barra: 324)
//     {'id_cmg': 5, 'valor_cmg': 60.0, 'año': 2025, 'mes': 2, 'dia': 05, 'hora': '12:00', 'id_barra': 324, 'temporada': 'Verano'},
//     {'id_cmg': 6, 'valor_cmg': 45.2, 'año': 2025, 'mes': 2, 'dia': 05, 'hora': '18:00', 'id_barra': 324, 'temporada': 'Verano'},
//     {'id_cmg': 7, 'valor_cmg': 95.0, 'año': 2025, 'mes': 8, 'dia': 22, 'hora': '21:00', 'id_barra': 324, 'temporada': 'Invierno'},
//   ];

//   // --- QUERIES SIMULADAS (DML) ---

//   // SELECT * FROM encargado WHERE rut_encargado = ? LIMIT 1
//   static Future<Map<String, dynamic>?> login(String rut) async {
//     await Future.delayed(const Duration(milliseconds: 500)); // Simula latencia de red/disco
//     try {
//       return encargados.firstWhere((e) => e['rut_encargado'] == rut);
//     } catch (e) {
//       return null;
//     }
//   }

//   // SELECT * FROM barra WHERE rut_encargado = ?
//   static Future<List<Map<String, dynamic>>> getBarrasByEncargado(String rut) async {
//     await Future.delayed(const Duration(milliseconds: 500));
//     return barras.where((b) => b['rut_encargado'] == rut).toList();
//   }

//   // SELECT AVG(valor_cmg), MAX(valor_cmg), MIN(valor_cmg), COUNT(*) FROM costo_marginal WHERE id_barra = ? AND año = ?
//   static Future<Map<String, dynamic>> getResumenAnual(int idBarra, int anio) async {
//     await Future.delayed(const Duration(milliseconds: 600));
//     final registros = costosMarginales.where((c) => c['id_barra'] == idBarra && c['año'] == anio).toList();

//     if (registros.isEmpty) {
//       return {'avg': 0.0, 'max': 0.0, 'min': 0.0, 'count': 0};
//     }

//     double sum = 0;
//     double max = (registros.first['valor_cmg'] as num).toDouble();
//     double min = (registros.first['valor_cmg'] as num).toDouble();

//     for (var r in registros) {
//       double val = (r['valor_cmg'] as num).toDouble();
//       sum += val;
//       if (val > max) max = val;
//       if (val < min) min = val;
//     }

//     return {
//       'avg': sum / registros.length,
//       'max': max,
//       'min': min,
//       'count': registros.length
//     };
//   }

//   // Simulación de consulta comparativa: Promedio Verano vs Promedio Global por Barra
//   static Future<Map<String, dynamic>> getComparativaEstacional(int idBarra) async {
//     await Future.delayed(const Duration(milliseconds: 500));
//     final todos = costosMarginales.where((c) => c['id_barra'] == idBarra).toList();
//     final verano = todos.where((c) => c['temporada'] == 'Verano').toList();

//     double avgGlobal = 0.0;
//     if (todos.isNotEmpty) {
//       final sumGlobal = todos.map((c) => (c['valor_cmg'] as num).toDouble()).reduce((a, b) => a + b);
//       avgGlobal = sumGlobal / todos.length;
//     }

//     double avgVerano = 0.0;
//     if (verano.isNotEmpty) {
//       final sumVerano = verano.map((c) => (c['valor_cmg'] as num).toDouble()).reduce((a, b) => a + b);
//       avgVerano = sumVerano / verano.length;
//     }

//     return {
//       'avg_verano': avgVerano,
//       'avg_global': avgGlobal,
//     };
//   }

//   // SELECT * FROM costo_marginal WHERE id_barra = ? ORDER BY año, mes, dia, hora
//   static Future<List<Map<String, dynamic>>> getHistorial(int idBarra) async {
//     await Future.delayed(const Duration(milliseconds: 400));
//     return costosMarginales.where((c) => c['id_barra'] == idBarra).toList();
//   }
// }

// ==========================================
// 1. PANTALLA DE ACCESO (LOGIN)
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _rutController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  void _login() async {
    final rut = _rutController.text.trim();
    if (rut.isEmpty) {
      setState(() => _errorMessage = 'Por favor, ingrese un RUT.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Validación e inicio de sesión usando PostgresDatabase
      final user = await PostgresDatabase.login(rut);
      setState(() => _isLoading = false);

      if (user != null) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              rutEncargado: user['rut_encargado'],
              nombreEncargado: user['nombre_encargado'],
            ),
          ),
        );
      } else {
        setState(() => _errorMessage = 'RUT no registrado como encargado.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error de conexión: No se pudo conectar a la base de datos local.\n(Asegúrate de ejecutar en Windows Desktop con -d windows)';
      });
      print('❌ Error de login: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bolt, size: 80, color: Colors.blue),
                const SizedBox(height: 20),
                const Text(
                  'Mega Electric',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Sistema de Monitoreo CMG',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _rutController,
                  decoration: InputDecoration(
                    labelText: 'RUT Encargado (Ej: 15.444.333-2)',
                    errorText: _errorMessage,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 20),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          'Ingresar',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. DASHBOARD (AUDITORÍA DEL ENCARGADO)
// ==========================================
class DashboardScreen extends StatelessWidget {
  final String rutEncargado;
  final String nombreEncargado;

  const DashboardScreen({
    super.key,
    required this.rutEncargado,
    required this.nombreEncargado,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mega Electric CMG'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bienvenido, $nombreEncargado',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'RUT: $rutEncargado',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  const Divider(),
                  const SizedBox(height: 10),
                  const Text(
                    'Tus Barras Asignadas:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: PostgresDatabase.getBarrasByEncargado(rutEncargado),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Error al obtener barras: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No posees barras asignadas en el sistema.'),
                    );
                  }

                  final barras = snapshot.data!;
                  return ListView.builder(
                    itemCount: barras.length,
                    itemBuilder: (context, index) {
                      final barra = barras[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        elevation: 2,
                        child: ListTile(
                          leading: const Icon(
                            Icons.electric_meter,
                            color: Colors.blue,
                          ),
                          title: Text(
                            barra['nombre_barra'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Nivel de Tensión: ${barra['nivel_tension_kv']} kV',
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BarraDetailScreen(
                                  idBarra: barra['id_barra'],
                                  nombreBarra: barra['nombre_barra'],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. VISTA DE DETALLE (REPORTES POR BARRA)
// ==========================================
class BarraDetailScreen extends StatelessWidget {
  final int idBarra;
  final String nombreBarra;

  const BarraDetailScreen({
    super.key,
    required this.idBarra,
    required this.nombreBarra,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(nombreBarra),
          bottom: const TabBar(
            indicatorColor: Colors.blue,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.bar_chart), text: 'Anual'),
              Tab(icon: Icon(Icons.compare_arrows), text: 'Estacional'),
              Tab(icon: Icon(Icons.history), text: 'Historial'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildResumenAnualTab(),
            _buildComparativaTab(),
            _buildHistorialTab(),
          ],
        ),
      ),
    );
  }

  // Pestaña 1: Resumen Estadístico Anual (RF5)
  Widget _buildResumenAnualTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: PostgresDatabase.getResumenAnual(idBarra, 2025),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error al cargar el resumen: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          );
        }
        final data = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Resumen Estadístico - Año 2025',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.analytics, color: Colors.blue),
                      title: const Text('Costo Promedio'),
                      trailing: Text(
                        '${data['avg'].toStringAsFixed(2)} USD/MWh',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.trending_up, color: Colors.red),
                      title: const Text('Valor Máximo'),
                      trailing: Text(
                        '${data['max'].toStringAsFixed(2)} USD/MWh',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.red,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.trending_down,
                        color: Colors.green,
                      ),
                      title: const Text('Valor Mínimo'),
                      trailing: Text(
                        '${data['min'].toStringAsFixed(2)} USD/MWh',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.tag, color: Colors.grey),
                      title: const Text('Total Registros'),
                      trailing: Text(
                        '${data['count']} lecturas',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Pestaña 2: Comparativa Estacional vs Histórico (RF8)
  Widget _buildComparativaTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: PostgresDatabase.getComparativaEstacional(idBarra),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error al cargar la comparativa: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          );
        }
        final data = snapshot.data!;

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.compare_arrows_rounded,
                  size: 64,
                  color: Colors.blue,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Comparación de Desempeño',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                Text(
                  'Promedio Verano:',
                  style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                ),
                Text(
                  '${data['avg_verano'].toStringAsFixed(2)} USD/MWh',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Promedio Histórico Global:',
                  style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                ),
                Text(
                  '${data['avg_global'].toStringAsFixed(2)} USD/MWh',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Pestaña 3: Seguimiento Cronológico (RF6)
  Widget _buildHistorialTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: PostgresDatabase.getHistorial(idBarra),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error al cargar el historial: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No hay registros históricos para esta barra.'),
          );
        }

        final historial = snapshot.data!;
        return ListView.separated(
          itemCount: historial.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final registro = historial[index];
            return ListTile(
              leading: const Icon(Icons.schedule, color: Colors.blueGrey),
              title: Text(
                'Fecha: ${registro['año']}/${registro['mes'].toString().padLeft(2, '0')}/${registro['dia'].toString().padLeft(2, '0')}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Hora: ${registro['hora']} | Temporada: ${registro['temporada']}',
              ),
              trailing: Text(
                '${(registro['valor_cmg'] as num).toStringAsFixed(2)} USD/MWh',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
