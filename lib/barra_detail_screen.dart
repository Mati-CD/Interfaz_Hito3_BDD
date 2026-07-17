import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:interfaz_hito3_bdd/postgres_database.dart';

class BarraDetailScreen extends StatefulWidget {
  final int idBarra;
  final String nombreBarra;

  const BarraDetailScreen({
    super.key,
    required this.idBarra,
    required this.nombreBarra,
  });

  @override
  State<BarraDetailScreen> createState() => _BarraDetailScreenState();
}

class _BarraDetailScreenState extends State<BarraDetailScreen> {
  List<int> _aniosDisponibles = [];
  int? _selectedAnio;
  bool _loadingAnios = true;
  String? _errorAnios;

  @override
  void initState() {
    super.initState();
    _loadAnios();
  }

  void _loadAnios() async {
    try {
      final anios = await PostgresDatabase.getAniosDisponibles(widget.idBarra);
      setState(() {
        _aniosDisponibles = anios;
        if (anios.isNotEmpty) {
          _selectedAnio = anios.first; // Default to the most recent year
        }
        _loadingAnios = false;
      });
    } catch (e) {
      setState(() {
        _errorAnios = e.toString();
        _loadingAnios = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.nombreBarra),
          bottom: const TabBar(
            indicatorColor: Colors.blue,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.analytics), text: 'Resumen Estadístico'),
              Tab(icon: Icon(Icons.history), text: 'Historial'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildResumenEstadisticoTab(),
            _buildHistorialTab(),
          ],
        ),
      ),
    );
  }

  // Pestaña 1: Resumen Estadístico (Unifica Anual y Estacional con selección de año)
  Widget _buildResumenEstadisticoTab() {
    if (_loadingAnios) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorAnios != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Error al cargar años disponibles: $_errorAnios',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_selectedAnio == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No hay registros de costos marginales para esta barra.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        PostgresDatabase.getResumenAnual(widget.idBarra, _selectedAnio!),
        PostgresDatabase.getComparativaEstacional(widget.idBarra, _selectedAnio!),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error al cargar el resumen estadístico: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          );
        }

        final Map<String, dynamic> dataAnual = snapshot.data![0] as Map<String, dynamic>;
        final List<Map<String, dynamic>> rowsEstacional = snapshot.data![1] as List<Map<String, dynamic>>;

        // Lógica de cálculo estacional
        double getAvg(int blockId, String periodPattern) {
          final match = rowsEstacional.firstWhere(
            (r) =>
                r['id_bloquehorario'] == blockId &&
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
          avg1001Autumn,
          avg1001Spring,
          avg1002Autumn,
          avg1002Spring,
          avg1003Autumn,
          avg1003Spring,
        ].reduce((curr, next) => curr > next ? curr : next);

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

        // Ajustar maxY para que sea un múltiplo exacto del intervalo y evitar choque de etiquetas
        final double maxY = maxVal > 0
            ? ((maxVal * 1.25) / yInterval).ceil() * yInterval
            : 100.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera: Título y menú desplegable del año si hay más de uno
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Resumen Estadístico - Año $_selectedAnio',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_aniosDisponibles.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withAlpha(40)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedAnio,
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          onChanged: (int? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedAnio = newValue;
                              });
                            }
                          },
                          items: _aniosDisponibles.map<DropdownMenuItem<int>>((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text('Año $value'),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _buildStatsGrid(dataAnual),
              const SizedBox(height: 32),

              // 2. Comparativa Estacional
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 20.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Comparación Gráfica (USD/MWh)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
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
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.grey,
                                      ),
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
                                          child: Text(
                                            '00:00-08:00',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      case 1:
                                        return const Padding(
                                          padding: EdgeInsets.only(top: 6.0),
                                          child: Text(
                                            '09:00-17:00',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      case 2:
                                        return const Padding(
                                          padding: EdgeInsets.only(top: 6.0),
                                          child: Text(
                                            '18:00-23:00',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
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
                                getTooltipColor: (_) =>
                                    Colors.blueGrey.withAlpha(230),
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final String period = rodIndex == 0
                                      ? 'Otoño/Invierno'
                                      : 'Primavera/Verano';
                                  return BarTooltipItem(
                                    '$period\n',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                    children: <TextSpan>[
                                      TextSpan(
                                        text:
                                            '${rod.toY.toStringAsFixed(2)} USD',
                                        style: const TextStyle(
                                          color: Colors.yellow,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
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
                          _buildLegendItem(
                            'Abril - Septiembre',
                            Colors.blueAccent,
                          ),
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

  Widget _buildStatsGrid(Map<String, dynamic> data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth > 200 ? cardWidth : constraints.maxWidth,
              child: _buildStatCard(
                'Costo Promedio',
                '${data['avg'].toStringAsFixed(2)} USD/MWh',
                Icons.analytics,
                Colors.blue,
              ),
            ),
            SizedBox(
              width: cardWidth > 200 ? cardWidth : constraints.maxWidth,
              child: _buildStatCard(
                'Valor Máximo',
                '${data['max'].toStringAsFixed(2)} USD/MWh',
                Icons.trending_up,
                Colors.red,
              ),
            ),
            SizedBox(
              width: cardWidth > 200 ? cardWidth : constraints.maxWidth,
              child: _buildStatCard(
                'Valor Mínimo',
                '${data['min'].toStringAsFixed(2)} USD/MWh',
                Icons.trending_down,
                Colors.green,
              ),
            ),
            SizedBox(
              width: cardWidth > 200 ? cardWidth : constraints.maxWidth,
              child: _buildStatCard(
                'Total Registros',
                '${data['count']} lecturas',
                Icons.tag,
                Colors.grey,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withAlpha(26),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
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
                      const Icon(
                        Icons.ac_unit,
                        color: Colors.blueAccent,
                        size: 20,
                      ),
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
                Container(height: 60, width: 1, color: Colors.grey[300]),

                // Primavera/Verano (Octubre - Marzo)
                Expanded(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.wb_sunny_outlined,
                        color: Colors.amber,
                        size: 20,
                      ),
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
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Pestaña 2: Seguimiento Cronológico (RF6)
  Widget _buildHistorialTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: PostgresDatabase.getHistorial(widget.idBarra),
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
