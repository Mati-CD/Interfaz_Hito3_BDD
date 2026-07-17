import 'package:interfaz_hito3_bdd/database_service.dart';

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
      map['nivel_tension_kv'] =
          double.tryParse(map['nivel_tension_kv']?.toString() ?? '') ?? 0.0;
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
    int anio,
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
        WHERE c.id_barra = @id AND c."año" = @anio
        GROUP BY b.id_bloquehorario, b.hora_inicio, b.hora_fin, periodo_estacional
        ORDER BY b.id_bloquehorario, periodo_estacional
      ''',
      parameters: {'id': idBarra, 'anio': anio},
    );

    return result.map((fila) {
      final map = Map<String, dynamic>.from(fila);
      map['avg_valor'] =
          double.tryParse(map['avg_valor']?.toString() ?? '') ?? 0.0;
      return map;
    }).toList();
  }

  // 6. DETALLE: Años con registros
  static Future<List<int>> getAniosDisponibles(int idBarra) async {
    final result = await DatabaseService.query(
      '''
        SELECT DISTINCT "año" as anio
        FROM costo_marginal
        WHERE id_barra = @id
        ORDER BY "año" DESC
      ''',
      parameters: {'id': idBarra},
    );
    return result
        .map((fila) => int.tryParse(fila['anio']?.toString() ?? '') ?? 0)
        .where((anio) => anio > 0)
        .toList();
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
      map['valor_cmg'] =
          double.tryParse(map['valor_cmg']?.toString() ?? '') ?? 0.0;
      return map;
    }).toList();
  }

  // 7. LOGIN: Obtener todos los encargados para autocompletado
  static Future<List<Map<String, dynamic>>> getTodosEncargados() async {
    final result = await DatabaseService.query(
      'SELECT rut_encargado, nombre_encargado FROM encargado ORDER BY nombre_encargado ASC',
    );
    return result.map((fila) => Map<String, dynamic>.from(fila)).toList();
  }

  // 8. DETALLE: Obtener costos promedio por hora para un bloque, año y barra específicos
  static Future<List<Map<String, dynamic>>> getCostosPorHora({
    required int idBarra,
    required int anio,
    required int idBloque,
  }) async {
    final result = await DatabaseService.query(
      '''
        SELECT 
          EXTRACT(HOUR FROM c.hora)::int as hora_num,
          CASE 
            WHEN t.nombre_temporada IN ('Otoño', 'Invierno') THEN 'Otoño/Invierno'
            ELSE 'Primavera/Verano'
          END as periodo_estacional,
          COALESCE(AVG(c.valor_cmg), 0.0) as avg_valor
        FROM costo_marginal c
        JOIN temporada t ON c.id_temporada = t.id_temporada
        WHERE c.id_barra = @idBarra 
          AND c."año" = @anio 
          AND c.id_bloquehorario = @idBloque
        GROUP BY hora_num, periodo_estacional
        ORDER BY hora_num, periodo_estacional
      ''',
      parameters: {
        'idBarra': idBarra,
        'anio': anio,
        'idBloque': idBloque,
      },
    );
    return result.map((fila) {
      final map = Map<String, dynamic>.from(fila);
      map['avg_valor'] = double.tryParse(map['avg_valor']?.toString() ?? '') ?? 0.0;
      return map;
    }).toList();
  }
}
