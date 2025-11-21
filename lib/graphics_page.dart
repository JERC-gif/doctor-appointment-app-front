import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class GraphicsPage extends StatefulWidget {
  const GraphicsPage({super.key});

  @override
  State<GraphicsPage> createState() => _GraphicsPageState();
}

class _GraphicsPageState extends State<GraphicsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Debes iniciar sesión')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Gráficas y Estadísticas"),
        backgroundColor: const Color(0xFF0072FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('usuarios').doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
            final userRole = userData?['rol'] ?? 'Paciente';
            
            // Verificar que el usuario sea médico
            if (userRole != 'Médico') {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.block, size: 64, color: Colors.red.shade400),
                      const SizedBox(height: 16),
                      const Text(
                        'Acceso Restringido',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Esta página es exclusiva para usuarios con rol "Médico".\nTu rol actual: $userRole',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('citas').snapshots(),
              builder: (context, citasSnapshot) {
                if (citasSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (citasSnapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'Error al cargar datos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            citasSnapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                final todasLasCitas = citasSnapshot.hasData 
                    ? citasSnapshot.data!.docs 
                    : <QueryDocumentSnapshot>[];

                if (todasLasCitas.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              Icon(Icons.bar_chart, size: 48, color: Colors.blue.shade300),
                              const SizedBox(height: 16),
                              const Text(
                                'No hay datos para mostrar',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Las gráficas aparecerán aquí cuando haya citas registradas.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                // Procesar datos para las gráficas
                final citasPorMes = _calcularCitasPorMes(todasLasCitas);
                final citasPorEstado = _calcularCitasPorEstado(todasLasCitas);
                final pacientesPorMedico = _calcularPacientesPorMedico(todasLasCitas);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Título
                    const Text(
                      "Análisis de Datos",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0072FF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Visualización de estadísticas en tiempo real",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Gráfica 1: Citas creadas por mes
                    _buildCitasPorMesChart(citasPorMes),
                    const SizedBox(height: 24),

                    // Gráfica 2: Citas completadas vs canceladas
                    _buildCitasPorEstadoChart(citasPorEstado),
                    const SizedBox(height: 24),

                    // Gráfica 3: Pacientes atendidos por médico
                    _buildPacientesPorMedicoChart(pacientesPorMedico),
                    const SizedBox(height: 24),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Calcula las citas agrupadas por mes (últimos 6 meses)
  Map<String, int> _calcularCitasPorMes(List<QueryDocumentSnapshot> citas) {
    final ahora = DateTime.now();
    final meses = <String, int>{};
    
    // Inicializar últimos 6 meses
    for (int i = 5; i >= 0; i--) {
      final fecha = DateTime(ahora.year, ahora.month - i, 1);
      final clave = '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}';
      meses[clave] = 0;
    }

    for (final doc in citas) {
      final data = doc.data() as Map<String, dynamic>;
      DateTime? fechaCita;

      // Intentar obtener fecha de diferentes campos
      if (data['inicio_ts'] is Timestamp) {
        fechaCita = (data['inicio_ts'] as Timestamp).toDate();
      } else if (data['fecha_completa'] is Timestamp) {
        fechaCita = (data['fecha_completa'] as Timestamp).toDate();
      } else if (data['created_at'] is Timestamp) {
        fechaCita = (data['created_at'] as Timestamp).toDate();
      } else if (data['timestamp'] is Timestamp) {
        fechaCita = (data['timestamp'] as Timestamp).toDate();
      }

      if (fechaCita != null) {
        final clave = '${fechaCita.year}-${fechaCita.month.toString().padLeft(2, '0')}';
        if (meses.containsKey(clave)) {
          meses[clave] = (meses[clave] ?? 0) + 1;
        }
      }
    }

    return meses;
  }

  /// Calcula las citas agrupadas por estado
  Map<String, int> _calcularCitasPorEstado(List<QueryDocumentSnapshot> citas) {
    final estados = <String, int>{
      'Completadas': 0,
      'Canceladas': 0,
      'Pendientes': 0,
    };

    for (final doc in citas) {
      final data = doc.data() as Map<String, dynamic>;
      final estado = (data['estado'] ?? 'pendiente').toString().toLowerCase();
      
      if (estado == 'completada') {
        estados['Completadas'] = (estados['Completadas'] ?? 0) + 1;
      } else if (estado == 'cancelada') {
        estados['Canceladas'] = (estados['Canceladas'] ?? 0) + 1;
      } else {
        estados['Pendientes'] = (estados['Pendientes'] ?? 0) + 1;
      }
    }

    return estados;
  }

  /// Calcula pacientes únicos atendidos por cada médico
  Map<String, int> _calcularPacientesPorMedico(List<QueryDocumentSnapshot> citas) {
    final pacientesPorMedico = <String, Map<String, bool>>{};

    for (final doc in citas) {
      final data = doc.data() as Map<String, dynamic>;
      final medico = (data['especialista'] ?? 'Sin especialista').toString();
      final nombrePaciente = (data['nombre'] ?? '').toString();
      final emailPaciente = (data['email'] ?? data['correoUsuario'] ?? '').toString();
      
      final pacienteId = nombrePaciente.isNotEmpty 
          ? nombrePaciente 
          : emailPaciente;

      if (pacienteId.isNotEmpty) {
        pacientesPorMedico.putIfAbsent(medico, () => <String, bool>{});
        pacientesPorMedico[medico]![pacienteId] = true;
      }
    }

    // Convertir a conteo
    final resultado = <String, int>{};
    pacientesPorMedico.forEach((medico, pacientes) {
      resultado[medico] = pacientes.length;
    });

    return resultado;
  }

  /// Widget para la gráfica de citas por mes
  Widget _buildCitasPorMesChart(Map<String, int> datos) {
    final mesesOrdenados = datos.keys.toList()..sort();
    final valores = mesesOrdenados.map((mes) => datos[mes]!.toDouble()).toList();
    
    // Formatear etiquetas de meses
    final etiquetas = mesesOrdenados.map((mes) {
      final partes = mes.split('-');
      final year = int.parse(partes[0]);
      final mesNum = int.parse(partes[1]);
      final nombresMeses = [
        'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
        'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
      ];
      return '${nombresMeses[mesNum - 1]}\n$year';
    }).toList();

    final maxY = valores.isEmpty ? 10.0 : (valores.reduce((a, b) => a > b ? a : b) * 1.2).ceilToDouble();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  "Citas Creadas por Mes",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.blue.shade700,
                      tooltipRoundedRadius: 8,
                      tooltipPadding: const EdgeInsets.all(8),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < etiquetas.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                etiquetas[index],
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                        reservedSize: 40,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade200,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(
                    valores.length,
                    (index) => BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: valores[index],
                          color: Colors.blue.shade400,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Muestra la cantidad de citas creadas en los últimos 6 meses",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
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

  /// Widget para la gráfica de citas por estado (completadas vs canceladas)
  Widget _buildCitasPorEstadoChart(Map<String, int> datos) {
    final completadas = datos['Completadas'] ?? 0;
    final canceladas = datos['Canceladas'] ?? 0;
    final pendientes = datos['Pendientes'] ?? 0;
    final total = completadas + canceladas + pendientes;

    if (total == 0) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.pie_chart, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No hay datos suficientes',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  "Citas por Estado",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 60,
                        sections: [
                          PieChartSectionData(
                            value: completadas.toDouble(),
                            title: '${((completadas / total) * 100).toStringAsFixed(1)}%',
                            color: Colors.green.shade400,
                            radius: 80,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            value: canceladas.toDouble(),
                            title: '${((canceladas / total) * 100).toStringAsFixed(1)}%',
                            color: Colors.red.shade400,
                            radius: 80,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            value: pendientes.toDouble(),
                            title: '${((pendientes / total) * 100).toStringAsFixed(1)}%',
                            color: Colors.orange.shade400,
                            radius: 80,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem(
                          'Completadas',
                          Colors.green.shade400,
                          completadas,
                        ),
                        const SizedBox(height: 12),
                        _buildLegendItem(
                          'Canceladas',
                          Colors.red.shade400,
                          canceladas,
                        ),
                        const SizedBox(height: 12),
                        _buildLegendItem(
                          'Pendientes',
                          Colors.orange.shade400,
                          pendientes,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Distribución de citas según su estado actual",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade900,
                      ),
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

  /// Widget para la gráfica de pacientes por médico
  Widget _buildPacientesPorMedicoChart(Map<String, int> datos) {
    if (datos.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.people, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No hay datos de pacientes por médico',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    final medicos = datos.keys.toList();
    final valores = medicos.map((medico) => datos[medico]!.toDouble()).toList();
    final maxY = valores.isEmpty 
        ? 10.0 
        : (valores.reduce((a, b) => a > b ? a : b) * 1.2).ceilToDouble();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                const Text(
                  "Pacientes Atendidos por Médico",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.purple.shade700,
                      tooltipRoundedRadius: 8,
                      tooltipPadding: const EdgeInsets.all(8),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < medicos.length) {
                            final nombre = medicos[index];
                            // Truncar nombres largos
                            final nombreCorto = nombre.length > 10 
                                ? '${nombre.substring(0, 10)}...' 
                                : nombre;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: RotatedBox(
                                quarterTurns: 1,
                                child: Text(
                                  nombreCorto,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                        reservedSize: 60,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade200,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(
                    valores.length,
                    (index) => BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: valores[index],
                          color: Colors.purple.shade400,
                          width: 30,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.purple.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Muestra la cantidad de pacientes únicos atendidos por cada especialista",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple.shade900,
                      ),
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

  /// Widget auxiliar para mostrar items de leyenda
  Widget _buildLegendItem(String label, Color color, int value) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}