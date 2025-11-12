import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        backgroundColor: const Color(0xFF0072FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Forzar actualización
          setState(() {});
        },
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('citas').snapshots(),
          builder: (context, citasSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('doctores').snapshots(),
              builder: (context, doctoresSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('usuarios').snapshots(),
                  builder: (context, usuariosSnapshot) {
                    // Calcular métricas
                    final totalCitas = citasSnapshot.hasData 
                        ? citasSnapshot.data!.docs.length 
                        : 0;
                    
                    final citasPendientes = citasSnapshot.hasData
                        ? citasSnapshot.data!.docs
                            .where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return data['estado'] == 'pendiente' || 
                                     data['estado'] == null;
                            })
                            .length
                        : 0;
                    
                    final citasCompletadas = citasSnapshot.hasData
                        ? citasSnapshot.data!.docs
                            .where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return data['estado'] == 'completada';
                            })
                            .length
                        : 0;
                    
                    final citasCanceladas = citasSnapshot.hasData
                        ? citasSnapshot.data!.docs
                            .where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return data['estado'] == 'cancelada';
                            })
                            .length
                        : 0;
                    
                    final hoy = DateTime.now();
                    final inicioDia = DateTime(hoy.year, hoy.month, hoy.day);
                    final finDia = inicioDia.add(const Duration(days: 1));
                    
                    final citasHoy = citasSnapshot.hasData
                        ? citasSnapshot.data!.docs
                            .where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              // Solo contar citas pendientes
                              final estado = (data['estado'] ?? 'pendiente').toString().toLowerCase();
                              if (estado == 'cancelada' || estado == 'completada') return false;
                              
                              if (data['inicio_ts'] == null) return false;
                              final fechaCita = (data['inicio_ts'] as Timestamp).toDate();
                              return fechaCita.isAfter(inicioDia) && 
                                     fechaCita.isBefore(finDia);
                            })
                            .length
                        : 0;
                    
                    final proximos7Dias = hoy.add(const Duration(days: 7));
                    final citasProximas = citasSnapshot.hasData
                        ? citasSnapshot.data!.docs
                            .where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              // Solo contar citas pendientes
                              final estado = (data['estado'] ?? 'pendiente').toString().toLowerCase();
                              if (estado == 'cancelada' || estado == 'completada') return false;
                              
                              if (data['inicio_ts'] == null) return false;
                              final fechaCita = (data['inicio_ts'] as Timestamp).toDate();
                              return fechaCita.isAfter(hoy) && 
                                     fechaCita.isBefore(proximos7Dias);
                            })
                            .length
                        : 0;
                    
                    final totalDoctores = doctoresSnapshot.hasData
                        ? doctoresSnapshot.data!.docs.length
                        : 0;
                    
                    final totalPacientes = usuariosSnapshot.hasData
                        ? usuariosSnapshot.data!.docs.length
                        : 0;

                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Header
                        _buildHeader(),
                        const SizedBox(height: 24),
                        
                        // Métricas principales
                        _buildMetricsGrid(
                          totalCitas: totalCitas,
                          citasPendientes: citasPendientes,
                          citasCompletadas: citasCompletadas,
                          citasCanceladas: citasCanceladas,
                          citasHoy: citasHoy,
                          totalDoctores: totalDoctores,
                          totalPacientes: totalPacientes,
                          citasProximas: citasProximas,
                        ),
                        const SizedBox(height: 24),
                        
                        // Sección de citas de hoy
                        if (citasHoy > 0) ...[
                          _buildTodayAppointments(citasSnapshot),
                          const SizedBox(height: 24),
                        ],
                        
                        // Sección de próximas citas
                        if (citasProximas > 0) ...[
                          _buildUpcomingAppointments(citasSnapshot),
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

  Widget _buildHeader() {
    final user = _auth.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Resumen General",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          user?.email ?? "Usuario",
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
    required int totalDoctores,
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
              title: "Total Médicos",
              value: totalDoctores.toString(),
              icon: Icons.medical_services,
              color: Colors.red,
            ),
            _MetricCard(
              title: "Total Pacientes",
              value: totalPacientes.toString(),
              icon: Icons.people,
              color: Colors.purple,
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

  Widget _buildTodayAppointments(AsyncSnapshot<QuerySnapshot> citasSnapshot) {
    if (!citasSnapshot.hasData) return const SizedBox.shrink();
    
    final hoy = DateTime.now();
    final inicioDia = DateTime(hoy.year, hoy.month, hoy.day);
    final finDia = inicioDia.add(const Duration(days: 1));
    
    final citasHoy = citasSnapshot.data!.docs
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

  Widget _buildUpcomingAppointments(AsyncSnapshot<QuerySnapshot> citasSnapshot) {
    if (!citasSnapshot.hasData) return const SizedBox.shrink();
    
    final hoy = DateTime.now();
    final proximos7Dias = hoy.add(const Duration(days: 7));
    
    final citasProximas = citasSnapshot.data!.docs
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
              color.withOpacity(0.1),
              color.withOpacity(0.05),
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
                      color: color.withOpacity(0.2),
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
            color: const Color(0xFF0072FF).withOpacity(0.1),
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

