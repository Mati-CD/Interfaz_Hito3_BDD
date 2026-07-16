import 'package:flutter/material.dart';
import 'package:interfaz_hito3_bdd/database_service.dart';
import 'package:fl_chart/fl_chart.dart';



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
  static Future<List<Map<String, dynamic>>> getComparativaEstacional(
    int idBarra,
  ) async {
    final result = await DatabaseService.query(
      '''
        SELECT 
          b.id_bloquehorario,
          b.hora_inicio::text as hora_inicio,
          b.hora_fin::text as hora_fin,
          CASE 
            WHEN t.nombre_temporada IN ('Otoño', 'Invierno') THEN 'Abril - Septiembre (Otoño/Invierno)'
            ELSE 'Octubre - Marzo (Primavera/Verano)'
          END as periodo_estacional,
          COALESCE(AVG(c.valor_cmg), 0.0) as avg_valor
        FROM costo_marginal c
        JOIN bloque_horario b ON c.id_bloquehorario = b.id_bloquehorario
        JOIN temporada t ON c.id_temporada = t.id_temporada
        WHERE c.id_barra = @id
        GROUP BY b.id_bloquehorario, b.hora_inicio, b.hora_fin, periodo_estacional
        ORDER BY b.id_bloquehorario, periodo_estacional
      ''',
      parameters: {'id': idBarra},
    );

    return result.map((fila) {
      final map = Map<String, dynamic>.from(fila);
      map['avg_valor'] = double.tryParse(map['avg_valor']?.toString() ?? '') ?? 0.0;
      return map;
    }).toList();
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
    return FutureBuilder<List<Map<String, dynamic>>>(
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

        final List<Map<String, dynamic>> rows = snapshot.data!;
        
        // Función auxiliar para obtener el promedio de un bloque y temporada específicos
        double getAvg(int blockId, String periodPattern) {
          final match = rows.firstWhere(
            (r) => r['id_bloquehorario'] == blockId && 
                   r['periodo_estacional'].toString().contains(periodPattern),
            orElse: () => {'avg_valor': 0.0},
          );
          return (match['avg_valor'] as num).toDouble();
        }

        final double avg1001Autumn = getAvg(1001, 'Abril');
        final double avg1001Spring = getAvg(1001, 'Octubre');
        
        final double avg1002Autumn = getAvg(1002, 'Abril');
        final double avg1002Spring = getAvg(1002, 'Octubre');
        
        final double avg1003Autumn = getAvg(1003, 'Abril');
        final double avg1003Spring = getAvg(1003, 'Octubre');

        final double maxVal = [
          avg1001Autumn, avg1001Spring,
          avg1002Autumn, avg1002Spring,
          avg1003Autumn, avg1003Spring
        ].reduce((curr, next) => curr > next ? curr : next);
        final double maxY = maxVal > 0 ? maxVal * 1.25 : 100.0;

        // Calcular un intervalo amigable y más detallado para el eje Y
        double calculateInterval(double max) {
          if (max <= 0) return 10;
          if (max <= 25) return 2.5;
          if (max <= 50) return 5;
          if (max <= 100) return 10;
          if (max <= 150) return 15;
          if (max <= 250) return 25;
          return 50;
        }
        final double yInterval = calculateInterval(maxVal);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Costo Promedio por Bloque Horario y Estacionalidad',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'A continuación se detallan los costos promedio (USD/MWh) obtenidos directamente de los registros de la base de datos para cada período.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              
              // Gráfico de Barras Agrupadas
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Comparación Gráfica (USD/MWh)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 200,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: maxY,
                            barGroups: [
                              BarChartGroupData(
                                x: 0,
                                barRods: [
                                  BarChartRodData(
                                    toY: avg1001Autumn,
                                    color: Colors.blueAccent,
                                    width: 14,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      topRight: Radius.circular(4),
                                    ),
                                  ),
                                  BarChartRodData(
                                    toY: avg1001Spring,
                                    color: Colors.amber,
                                    width: 14,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      topRight: Radius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                              BarChartGroupData(
                                x: 1,
                                barRods: [
                                  BarChartRodData(
                                    toY: avg1002Autumn,
                                    color: Colors.blueAccent,
                                    width: 14,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      topRight: Radius.circular(4),
                                    ),
                                  ),
                                  BarChartRodData(
                                    toY: avg1002Spring,
                                    color: Colors.amber,
                                    width: 14,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      topRight: Radius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                              BarChartGroupData(
                                x: 2,
                                barRods: [
                                  BarChartRodData(
                                    toY: avg1003Autumn,
                                    color: Colors.blueAccent,
                                    width: 14,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      topRight: Radius.circular(4),
                                    ),
                                  ),
                                  BarChartRodData(
                                    toY: avg1003Spring,
                                    color: Colors.amber,
                                    width: 14,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      topRight: Radius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            titlesData: FlTitlesData(
                              show: true,
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  interval: yInterval,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      '${value.toInt()}',
                                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                                    );
                                  },
                                ),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    switch (value.toInt()) {
                                      case 0:
                                        return const Padding(
                                          padding: EdgeInsets.only(top: 6.0),
                                          child: Text('00:00-08:00', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                        );
                                      case 1:
                                        return const Padding(
                                          padding: EdgeInsets.only(top: 6.0),
                                          child: Text('09:00-17:00', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                        );
                                      case 2:
                                        return const Padding(
                                          padding: EdgeInsets.only(top: 6.0),
                                          child: Text('18:00-23:00', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                        );
                                      default:
                                        return const Text('');
                                    }
                                  },
                                ),
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: Colors.grey[200]!,
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (_) => Colors.blueGrey.withAlpha(230),
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final String period = rodIndex == 0 ? 'Otoño/Invierno' : 'Primavera/Verano';
                                  return BarTooltipItem(
                                    '$period\n',
                                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                                    children: <TextSpan>[
                                      TextSpan(
                                        text: '${rod.toY.toStringAsFixed(2)} USD',
                                        style: const TextStyle(color: Colors.yellow, fontSize: 11, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLegendItem('Abril - Septiembre', Colors.blueAccent),
                          const SizedBox(width: 24),
                          _buildLegendItem('Octubre - Marzo', Colors.amber),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Bloque 1: 00:00 a 08:00
              _buildBlockCard(
                title: 'Bloque Horario: 00:00 - 08:00',
                subtitle: 'Periodo de madrugada y baja demanda',
                icon: Icons.nightlight_round,
                iconColor: Colors.indigo,
                avgAutumn: avg1001Autumn,
                avgSpring: avg1001Spring,
              ),
              
              const SizedBox(height: 16),
              
              // Bloque 2: 09:00 a 17:00
              _buildBlockCard(
                title: 'Bloque Horario: 09:00 - 17:00',
                subtitle: 'Periodo diario e influencia de generación solar',
                icon: Icons.wb_sunny,
                iconColor: Colors.amber,
                avgAutumn: avg1002Autumn,
                avgSpring: avg1002Spring,
              ),
              
              const SizedBox(height: 16),
              
              // Bloque 3: 18:00 a 23:00
              _buildBlockCard(
                title: 'Bloque Horario: 18:00 - 23:00',
                subtitle: 'Periodo de punta nocturna y mayor consumo',
                icon: Icons.wb_twilight,
                iconColor: Colors.deepOrange,
                avgAutumn: avg1003Autumn,
                avgSpring: avg1003Spring,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBlockCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required double avgAutumn,
    required double avgSpring,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                // Otoño/Invierno (Abril - Septiembre)
                Expanded(
                  child: Column(
                    children: [
                      const Icon(Icons.ac_unit, color: Colors.blueAccent, size: 20),
                      const SizedBox(height: 6),
                      const Text(
                        'Abril - Septiembre',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const Text(
                        '(Otoño / Invierno)',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${avgAutumn.toStringAsFixed(2)} USD/MWh',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                // Divisor vertical central
                Container(
                  height: 60,
                  width: 1,
                  color: Colors.grey[300],
                ),
                
                // Primavera/Verano (Octubre - Marzo)
                Expanded(
                  child: Column(
                    children: [
                      const Icon(Icons.wb_sunny_outlined, color: Colors.amber, size: 20),
                      const SizedBox(height: 6),
                      const Text(
                        'Octubre - Marzo',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const Text(
                        '(Primavera / Verano)',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${avgSpring.toStringAsFixed(2)} USD/MWh',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
      ],
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
