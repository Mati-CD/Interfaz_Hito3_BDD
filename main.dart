import 'package:flutter/material.dart';

void main() {
  runApp(const MegaElectricApp());
}

class MegaElectricApp extends StatelessWidget {
  const MegaElectricApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mega Electric CMG',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
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

  void _login() {
    final rut = _rutController.text.trim();
    if (rut.isNotEmpty) {
      // Aquí harías la validación contra la tabla encargado
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(rutEncargado: rut),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bolt, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text('Mega Electric', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              TextField(
                controller: _rutController,
                decoration: const InputDecoration(
                  labelText: 'RUT Encargado (Ej: 15.444.333-2)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: const Text('Ingresar'),
              ),
            ],
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

  const DashboardScreen({super.key, required this.rutEncargado});

  // Simula la consulta: SELECT * FROM barra WHERE rut_encargado = ?
  Future<List<Map<String, dynamic>>> _fetchBarras() async {
    await Future.delayed(const Duration(seconds: 1)); // Simula latencia
    return [
      {'id_barra': 321, 'nombre_barra': 'Barra Biobío A', 'nivel_tension_kv': 110.0},
      {'id_barra': 324, 'nombre_barra': 'Barra Biobío B', 'nivel_tension_kv': 220.0},
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Barras Asignadas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => const LoginScreen())),
          )
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchBarras(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No tienes barras asignadas.'));
          }

          final barras = snapshot.data!;
          return ListView.builder(
            itemCount: barras.length,
            itemBuilder: (context, index) {
              final barra = barras[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.electric_meter, color: Colors.blueGrey),
                  title: Text(barra['nombre_barra']),
                  subtitle: Text('Tensión: ${barra['nivel_tension_kv']} kV'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
    );
  }
}

// ==========================================
// 3. VISTA DE DETALLE (REPORTES POR BARRA)
// ==========================================
class BarraDetailScreen extends StatelessWidget {
  final int idBarra;
  final String nombreBarra;

  const BarraDetailScreen({super.key, required this.idBarra, required this.nombreBarra});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Detalle: $nombreBarra'),
          bottom: const TabBar(
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
    // Aquí iría el resultado del SELECT con AVG, MAX, MIN y COUNT
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Resumen Año 2025', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          ListTile(title: Text('Costo Promedio'), trailing: Text('64.26 USD/MWh')),
          ListTile(title: Text('Valor Máximo'), trailing: Text('625.30 USD/MWh', style: TextStyle(color: Colors.red))),
          ListTile(title: Text('Valor Mínimo'), trailing: Text('0.00 USD/MWh', style: TextStyle(color: Colors.green))),
          ListTile(title: Text('Total Registros'), trailing: Text('8754 lecturas')),
        ],
      ),
    );
  }

  // Pestaña 2: Comparativa Estacional vs Histórico (RF8)
  Widget _buildComparativaTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
          SizedBox(height: 16),
          Text('Promedio Verano 2025:', style: TextStyle(fontSize: 16)),
          Text('50.52 USD/MWh', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 24),
          Text('Promedio Histórico Global:', style: TextStyle(fontSize: 16)),
          Text('64.26 USD/MWh', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }

  // Pestaña 3: Seguimiento Cronológico (RF6)
  Widget _buildHistorialTab() {
    // Aquí iría un ListView con los registros de la tabla costo_marginal
    return ListView.separated(
      itemCount: 10, // Simulación de 10 registros
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        return ListTile(
          leading: const Icon(Icons.schedule),
          title: Text('Bloque ${index + 1} - 2025/01/15'),
          trailing: Text('${(15.0 + index * 2.5).toStringAsFixed(2)} USD/MWh'),
        );
      },
    );
  }
}