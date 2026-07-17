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
  int _selectedBlock = 1;
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
          children: [_buildResumenEstadisticoTab(), _buildHistorialTab()],
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
        PostgresDatabase.getComparativaEstacional(
          widget.idBarra,
          _selectedAnio!,
        ),
        PostgresDatabase.getCostosPorHora(
          idBarra: widget.idBarra,
          anio: _selectedAnio!,
          idBloque: 1000 + _selectedBlock,
        ),
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

        final Map<String, dynamic> dataAnual =
            snapshot.data![0] as Map<String, dynamic>;
        final List<Map<String, dynamic>> rowsEstacional =
            snapshot.data![1] as List<Map<String, dynamic>>;
        final List<Map<String, dynamic>> hourlyData =
            snapshot.data![2] as List<Map<String, dynamic>>;

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
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.blue,
                          ),
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          onChanged: (int? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedAnio = newValue;
                                _selectedBlock =
                                    1; // Reset to Block 1 when changing year
                              });
                            }
                          },
                          items: _aniosDisponibles.map<DropdownMenuItem<int>>((
                            int value,
                          ) {
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

              // Selector de bloques
              Center(
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment<int>(
                      value: 1,
                      label: Text('Bloque 1'),
                      icon: Icon(Icons.nightlight_round, size: 16),
                    ),
                    ButtonSegment<int>(
                      value: 2,
                      label: Text('Bloque 2'),
                      icon: Icon(Icons.wb_sunny, size: 16),
                    ),
                    ButtonSegment<int>(
                      value: 3,
                      label: Text('Bloque 3'),
                      icon: Icon(Icons.wb_twilight, size: 16),
                    ),
                  ],
                  selected: {_selectedBlock},
                  onSelectionChanged: (Set<int> newSelection) {
                    setState(() {
                      _selectedBlock = newSelection.first;
                    });
                  },
                  showSelectedIcon: false,
                ),
              ),
              const SizedBox(height: 20),

              // Gráfico de líneas correspondiente al bloque seleccionado
              _buildLineChartCard(hourlyData),
              const SizedBox(height: 20),

              // BlockCard condicional según el bloque seleccionado
              if (_selectedBlock == 1)
                _buildBlockCard(
                  title: 'Bloque Horario: 00:00 - 08:00',
                  subtitle: 'Periodo nocturno',
                  icon: Icons.nightlight_round,
                  iconColor: Colors.indigo,
                  avgAutumn: avg1001Autumn,
                  avgSpring: avg1001Spring,
                )
              else if (_selectedBlock == 2)
                _buildBlockCard(
                  title: 'Bloque Horario: 09:00 - 17:00',
                  subtitle: 'Periodo diurno',
                  icon: Icons.wb_sunny,
                  iconColor: Colors.amber,
                  avgAutumn: avg1002Autumn,
                  avgSpring: avg1002Spring,
                )
              else if (_selectedBlock == 3)
                _buildBlockCard(
                  title: 'Bloque Horario: 18:00 - 23:00',
                  subtitle: 'Periodo vespertino',
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

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
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

  Widget _buildLineChartCard(List<Map<String, dynamic>> hourlyData) {
    final List<FlSpot> autumnSpots = [];
    final List<FlSpot> springSpots = [];

    for (final row in hourlyData) {
      final int hour = row['hora_num'] as int;
      final double value = row['avg_valor'] as double;
      final String period = row['periodo_estacional'] as String;

      if (period == 'Otoño/Invierno') {
        autumnSpots.add(FlSpot(hour.toDouble(), value));
      } else {
        springSpots.add(FlSpot(hour.toDouble(), value));
      }
    }

    autumnSpots.sort((a, b) => a.x.compareTo(b.x));
    springSpots.sort((a, b) => a.x.compareTo(b.x));

    double maxVal = 100.0;
    if (autumnSpots.isNotEmpty || springSpots.isNotEmpty) {
      final double maxAutumn = autumnSpots.isEmpty
          ? 0.0
          : autumnSpots
                .map((s) => s.y)
                .reduce((curr, next) => curr > next ? curr : next);
      final double maxSpring = springSpots.isEmpty
          ? 0.0
          : springSpots
                .map((s) => s.y)
                .reduce((curr, next) => curr > next ? curr : next);
      final double calculatedMax = maxAutumn > maxSpring
          ? maxAutumn
          : maxSpring;
      if (calculatedMax > 0) {
        maxVal = calculatedMax;
      }
    }

    double calculateInterval(double max) {
      if (max <= 0) return 10;
      if (max <= 25) return 5;
      if (max <= 50) return 10;
      if (max <= 100) return 20;
      if (max <= 200) return 40;
      return 50;
    }

    final double yInterval = calculateInterval(maxVal);
    final double maxY = maxVal > 0
        ? ((maxVal * 1.2) / yInterval).ceil() * yInterval
        : 100.0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Evolución Horaria del Costo Promedio (USD/MWh) - Bloque $_selectedBlock',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: yInterval,
                    verticalInterval: 1.0,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withAlpha(30),
                      strokeWidth: 1,
                    ),
                    getDrawingVerticalLine: (value) => FlLine(
                      color: Colors.grey.withAlpha(30),
                      strokeWidth: 1,
                    ),
                  ),
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
                        reservedSize: 32,
                        interval: 1.0,
                        getTitlesWidget: (value, meta) {
                          final int hour = value.toInt();
                          final String label =
                              '${hour.toString().padLeft(2, '0')}:00';
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withAlpha(50),
                        width: 1,
                      ),
                      left: BorderSide(
                        color: Colors.grey.withAlpha(50),
                        width: 1,
                      ),
                    ),
                  ),
                  minX: _selectedBlock == 1
                      ? 0
                      : (_selectedBlock == 2 ? 9 : 18),
                  maxX: _selectedBlock == 1
                      ? 8
                      : (_selectedBlock == 2 ? 17 : 23),
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: autumnSpots,
                      isCurved: true,
                      color: Colors.blueAccent,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                              radius: 4,
                              color: Colors.blueAccent,
                              strokeWidth: 1.5,
                              strokeColor: Colors.white,
                            ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blueAccent.withAlpha(20),
                      ),
                    ),
                    LineChartBarData(
                      spots: springSpots,
                      isCurved: true,
                      color: Colors.amber,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                              radius: 4,
                              color: Colors.amber,
                              strokeWidth: 1.5,
                              strokeColor: Colors.white,
                            ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.amber.withAlpha(20),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => Colors.blueGrey.withAlpha(230),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((barSpot) {
                          final String period = barSpot.barIndex == 0
                              ? 'Otoño/Invierno'
                              : 'Primavera/Verano';
                          final String hourLabel =
                              '${barSpot.x.toInt().toString().padLeft(2, '0')}:00';
                          return LineTooltipItem(
                            '$period ($hourLabel)\n${barSpot.y.toStringAsFixed(2)} USD',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          );
                        }).toList();
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
                  'Otoño/Invierno (Abril - Septiembre)',
                  Colors.blueAccent,
                ),
                const SizedBox(width: 24),
                _buildLegendItem(
                  'Primavera/Verano (Octubre - Marzo)',
                  Colors.amber,
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
