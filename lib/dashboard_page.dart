import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'graphics_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
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
        title: const Text("Dashboard Médico"),
        backgroundColor: const Color(0xFF0072FF),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Ver Gráficas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GraphicsPage()),
              );
            },
          ),
        ],
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
            
            final medicoNombre = userData?['nombre_completo'] ?? 
                               user.displayName ?? 
                               user.email ?? 
                               'Médico';

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
                
                // Filtrar citas del médico actual
                // Opción 1: Por especialista (si el campo especialista coincide con el nombre del médico)
                // Opción 2: Mostrar todas las citas si no hay filtro específico
                final todasLasCitas = citasSnapshot.hasData ? citasSnapshot.data!.docs : <QueryDocumentSnapshot>[];
                
                // Por ahora, mostramos todas las citas para que el médico vea todas
                // En producción, esto debería filtrarse por un campo médico_id o similar
                final citasDelMedico = todasLasCitas;

                // Calcular los 3 indicadores requeridos
                // 1. Total de citas creadas (del médico)
                final totalCitas = citasDelMedico.length;
                
                // 2. Citas próximas/pendientes (del médico)
                    final hoy = DateTime.now();
                final citasProximas = citasDelMedico.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final estado = (data['estado'] ?? 'pendiente').toString().toLowerCase();
                  // Solo contar citas pendientes o próximas (no canceladas ni completadas)
                              if (estado == 'cancelada' || estado == 'completada') return false;
                              
                  // Si tiene fecha, verificar que sea futura
                  if (data['inicio_ts'] != null) {
                              final fechaCita = (data['inicio_ts'] as Timestamp).toDate();
                    return fechaCita.isAfter(hoy);
                  }
                  // Si no tiene fecha pero está pendiente, contarla
                  return estado == 'pendiente' || estado.isEmpty;
                }).length;
                
                // 3. Total de pacientes registrados (únicos que tienen citas con este médico)
                final pacientesUnicos = <String>{};
                for (final doc in citasDelMedico) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nombrePaciente = data['nombre']?.toString() ?? '';
                  final emailPaciente = data['email']?.toString() ?? '';
                  if (nombrePaciente.isNotEmpty) {
                    pacientesUnicos.add(nombrePaciente);
                  } else if (emailPaciente.isNotEmpty) {
                    pacientesUnicos.add(emailPaciente);
                  }
                }
                final totalPacientes = pacientesUnicos.length;
                
                // Métricas adicionales para el dashboard
                final citasPendientes = citasDelMedico.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final estado = (data['estado'] ?? 'pendiente').toString().toLowerCase();
                  return estado == 'pendiente' || estado.isEmpty;
                }).length;
                
                final citasCompletadas = citasDelMedico.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return (data['estado'] ?? '').toString().toLowerCase() == 'completada';
                }).length;
                
                final citasCanceladas = citasDelMedico.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return (data['estado'] ?? '').toString().toLowerCase() == 'cancelada';
                }).length;
                
                final inicioDia = DateTime(hoy.year, hoy.month, hoy.day);
                final finDia = inicioDia.add(const Duration(days: 1));
                final citasHoy = citasDelMedico.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final estado = (data['estado'] ?? 'pendiente').toString().toLowerCase();
                              if (estado == 'cancelada' || estado == 'completada') return false;
                              if (data['inicio_ts'] == null) return false;
                              final fechaCita = (data['inicio_ts'] as Timestamp).toDate();
                  return fechaCita.isAfter(inicioDia) && fechaCita.isBefore(finDia);
                }).length;

                return StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('usuarios').snapshots(),
                  builder: (context, usuariosSnapshot) {
                    // Si no hay citas, mostrar mensaje informativo
                    if (totalCitas == 0) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildHeader(medicoNombre),
                          const SizedBox(height: 24),
                          // Los 3 indicadores principales (mostrar 0)
                          _buildMainIndicators(
                            totalCitas: 0,
                            citasProximas: 0,
                            totalPacientes: 0,
                          ),
                          const SizedBox(height: 24),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                children: [
                                  Icon(Icons.info_outline, size: 48, color: Colors.blue.shade300),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No hay citas registradas',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Las citas aparecerán aquí cuando los pacientes las agenden.',
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

                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Header
                        _buildHeader(medicoNombre),
                        const SizedBox(height: 24),
                        
                        // Los 3 indicadores principales requeridos (destacados)
                        _buildMainIndicators(
                          totalCitas: totalCitas,
                          citasProximas: citasProximas,
                          totalPacientes: totalPacientes,
                        ),
                        const SizedBox(height: 24),
                        
                        // Botón para ver gráficas
                        _buildGraphicsButton(),
                        const SizedBox(height: 24),
                        
                        // Métricas adicionales
                        _buildMetricsGrid(
                          totalCitas: totalCitas,
                          citasPendientes: citasPendientes,
                          citasCompletadas: citasCompletadas,
                          citasCanceladas: citasCanceladas,
                          citasHoy: citasHoy,
                          totalPacientes: totalPacientes,
                          citasProximas: citasProximas,
                        ),
                        const SizedBox(height: 24),
                        
                        // Sección de citas de hoy
                        if (citasHoy > 0) ...[
                          _buildTodayAppointments(citasDelMedico),
                          const SizedBox(height: 24),
                        ],
                        
                        // Sección de próximas citas
                        if (citasProximas > 0) ...[
                          _buildUpcomingAppointments(citasDelMedico),
                        ],
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Los 3 indicadores principales requeridos
  Widget _buildMainIndicators({
    required int totalCitas,
    required int citasProximas,
    required int totalPacientes,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Indicadores Principales",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MainIndicatorCard(
                title: "Total de Citas",
                value: totalCitas.toString(),
                icon: Icons.calendar_today,
                color: const Color(0xFF0072FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MainIndicatorCard(
                title: "Citas Próximas",
                value: citasProximas.toString(),
                icon: Icons.upcoming,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MainIndicatorCard(
                title: "Total Pacientes",
                value: totalPacientes.toString(),
                icon: Icons.people,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(String medicoNombre) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Dashboard Médico",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          medicoNombre,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Estadísticas en tiempo real",
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid({
    required int totalCitas,
    required int citasPendientes,
    required int citasCompletadas,
    required int citasCanceladas,
    required int citasHoy,
    required int totalPacientes,
    required int citasProximas,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Métricas Principales",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.3,
          children: [
            _MetricCard(
              title: "Total Citas",
              value: totalCitas.toString(),
              icon: Icons.calendar_today,
              color: const Color(0xFF0072FF),
            ),
            _MetricCard(
              title: "Citas Pendientes",
              value: citasPendientes.toString(),
              icon: Icons.pending_actions,
              color: Colors.orange,
            ),
            _MetricCard(
              title: "Citas Hoy",
              value: citasHoy.toString(),
              icon: Icons.today,
              color: Colors.green,
            ),
            _MetricCard(
              title: "Próximas 7 Días",
              value: citasProximas.toString(),
              icon: Icons.upcoming,
              color: Colors.teal,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Segunda fila con métricas adicionales
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.3,
          children: [
            _MetricCard(
              title: "Citas Completadas",
              value: citasCompletadas.toString(),
              icon: Icons.check_circle,
              color: Colors.green.shade700,
            ),
            _MetricCard(
              title: "Citas Canceladas",
              value: citasCanceladas.toString(),
              icon: Icons.cancel,
              color: Colors.red.shade700,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTodayAppointments(List<QueryDocumentSnapshot> citasDelMedico) {
    final hoy = DateTime.now();
    final inicioDia = DateTime(hoy.year, hoy.month, hoy.day);
    final finDia = inicioDia.add(const Duration(days: 1));
    
    final citasHoy = citasDelMedico
        .where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // Solo mostrar citas pendientes (no canceladas ni completadas)
          final estado = (data['estado'] ?? 'pendiente').toString().toLowerCase();
          if (estado == 'cancelada' || estado == 'completada') return false;
          
          if (data['inicio_ts'] == null) return false;
          final fechaCita = (data['inicio_ts'] as Timestamp).toDate();
          return fechaCita.isAfter(inicioDia) && 
                 fechaCita.isBefore(finDia);
        })
        .toList();
    
    if (citasHoy.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Citas de Hoy",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...citasHoy.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return _AppointmentCard(
            nombre: data['nombre'] ?? 'Sin nombre',
            especialista: data['especialista'] ?? 'Sin especialista',
            fecha: data['fecha'] ?? '',
            hora: data['hora'] ?? '',
            motivo: data['motivo'] ?? '',
          );
        }),
      ],
    );
  }

  Widget _buildUpcomingAppointments(List<QueryDocumentSnapshot> citasDelMedico) {
    final hoy = DateTime.now();
    final proximos7Dias = hoy.add(const Duration(days: 7));
    
    final citasProximas = citasDelMedico
        .where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // Solo mostrar citas pendientes (no canceladas ni completadas)
          final estado = (data['estado'] ?? 'pendiente').toString().toLowerCase();
          if (estado == 'cancelada' || estado == 'completada') return false;
          
          if (data['inicio_ts'] == null) return false;
          final fechaCita = (data['inicio_ts'] as Timestamp).toDate();
          return fechaCita.isAfter(hoy) && 
                 fechaCita.isBefore(proximos7Dias);
        })
        .toList()
      ..sort((a, b) {
        final fechaA = (a.data() as Map<String, dynamic>)['inicio_ts'] as Timestamp?;
        final fechaB = (b.data() as Map<String, dynamic>)['inicio_ts'] as Timestamp?;
        if (fechaA == null || fechaB == null) return 0;
        return fechaA.compareTo(fechaB);
      });
    
    if (citasProximas.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Próximas Citas (7 días)",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...citasProximas.take(5).map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return _AppointmentCard(
            nombre: data['nombre'] ?? 'Sin nombre',
            especialista: data['especialista'] ?? 'Sin especialista',
            fecha: data['fecha'] ?? '',
            hora: data['hora'] ?? '',
            motivo: data['motivo'] ?? '',
          );
        }),
      ],
    );
  }

  Widget _buildGraphicsButton() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GraphicsPage()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple.shade400,
                Colors.blue.shade400,
              ],
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bar_chart,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Ver Gráficas y Estadísticas",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Visualiza datos interactivos de tus citas",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card para mostrar los 3 indicadores principales requeridos
class _MainIndicatorCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MainIndicatorCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.15),
              color.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card para mostrar una métrica individual
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.1),
              color.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card para mostrar información de una cita
class _AppointmentCard extends StatelessWidget {
  final String nombre;
  final String especialista;
  final String fecha;
  final String hora;
  final String motivo;

  const _AppointmentCard({
    required this.nombre,
    required this.especialista,
    required this.fecha,
    required this.hora,
    required this.motivo,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF0072FF).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.calendar_today,
            color: Color(0xFF0072FF),
          ),
        ),
        title: Text(
          nombre,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              especialista,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '$fecha - $hora',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            if (motivo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                motivo,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}