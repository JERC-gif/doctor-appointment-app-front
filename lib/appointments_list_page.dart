import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'appointment_page.dart';

class AppointmentsListPage extends StatefulWidget {
  const AppointmentsListPage({super.key});

  @override
  State<AppointmentsListPage> createState() => _AppointmentsListPageState();
}

class _AppointmentsListPageState extends State<AppointmentsListPage> {
  Stream<QuerySnapshot> _getAppointments() {
    return FirebaseFirestore.instance.collection('citas').snapshots();
  }

  Future<void> _confirmAndDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: const Text('¿Seguro que deseas cancelar esta cita?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, cancelar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        // Actualizar el estado a "cancelada" en lugar de eliminar
        await FirebaseFirestore.instance.collection('citas').doc(id).update({
          'estado': 'cancelada',
          'updated_at': FieldValue.serverTimestamp(),
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cita cancelada')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cancelar: $e')));
      }
    }
  }

  Future<void> _markAsCompleted(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Marcar como completada'),
        content: const Text('¿Deseas marcar esta cita como completada?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Sí, completar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await FirebaseFirestore.instance.collection('citas').doc(id).update({
          'estado': 'completada',
          'updated_at': FieldValue.serverTimestamp(),
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cita marcada como completada')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));
      }
    }
  }

  /// Verifica si se debe mostrar el botón de confirmar asistencia
  /// Solo se muestra si la cita ya pasó y está pendiente
  bool _shouldShowConfirmButton(Map<String, dynamic> data) {
    final estado = (data['estado'] ?? 'pendiente').toString().toLowerCase();
    
    // Solo mostrar si está pendiente
    if (estado != 'pendiente' && estado != '') return false;
    
    // Verificar si la cita ya pasó
    DateTime? fechaCita;
    
    if (data['inicio_ts'] != null && data['inicio_ts'] is Timestamp) {
      fechaCita = (data['inicio_ts'] as Timestamp).toDate();
    } else if (data['fecha_completa'] != null && data['fecha_completa'] is Timestamp) {
      final fecha = (data['fecha_completa'] as Timestamp).toDate();
      final horaStr = data['hora_completa'] as String?;
      if (horaStr != null && horaStr.contains(':')) {
        final partes = horaStr.split(':');
        final hora = int.tryParse(partes[0]) ?? 0;
        final minuto = int.tryParse(partes[1]) ?? 0;
        fechaCita = DateTime(fecha.year, fecha.month, fecha.day, hora, minuto);
      } else {
        fechaCita = fecha;
      }
    }
    
    if (fechaCita == null) return false;
    
    // La cita ya pasó si la fecha/hora es anterior a ahora
    return fechaCita.isBefore(DateTime.now());
  }

  /// Confirma la asistencia a la cita y la marca como completada
  Future<void> _confirmAttendance(BuildContext context, String id, Map<String, dynamic> data) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Confirmar Asistencia',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Confirmas que asististe a esta cita?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Especialista: ${data['especialista'] ?? data['doctor'] ?? 'N/A'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fecha: ${data['fecha'] ?? 'N/A'}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                  Text(
                    'Hora: ${data['hora'] ?? 'N/A'}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Sí, confirmar asistencia',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('citas').doc(id).update({
          'estado': 'completada',
          'asistencia_confirmada': true,
          'fecha_confirmacion': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('¡Asistencia confirmada! La cita ha sido marcada como completada.'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al confirmar asistencia: $e')),
          );
        }
      }
    }
  }

  String _formatFechaHora(Map<String, dynamic> d) {
    final f = (d['fecha'] ?? '').toString();
    final h = (d['hora'] ?? '').toString();

    if (f.isNotEmpty && h.isNotEmpty) return '$f  •  $h';
    if (f.isNotEmpty) return f;

    final ts = d['fecha_completa'];
    if (ts is Timestamp) {
      final dt = ts.toDate();
      final legible = '${dt.day}/${dt.month}/${dt.year}';
      return h.isNotEmpty ? '$legible  •  $h' : legible;
    }

    final ts2 = d['timestamp'];
    if (ts2 is Timestamp) {
      final dt = ts2.toDate();
      return '${dt.day}/${dt.month}/${dt.year}';
    }

    return 'Fecha no disponible';
  }

  String _relativoDesdeFecha(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    final now = DateTime.now();
    final diff = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Mañana';
    if (diff == -1) return 'Ayer';
    if (diff > 1) return 'En $diff días';
    return 'Hace ${-diff} días';
  }

  DateTime _normalizeDate(dynamic ts, dynamic fechaStr) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return DateTime(d.year, d.month, d.day);
    }
    if (fechaStr is String && fechaStr.contains('/')) {
      final p = fechaStr.split('/');
      final dd = int.tryParse(p[0]) ?? 1;
      final mm = int.tryParse(p[1]) ?? 1;
      final yy = int.tryParse(p.length > 2 ? p[2] : '1970') ?? 1970;
      return DateTime(yy, mm, dd);
    }
    return DateTime(2100);
  }

  int _normalizeMinutes(dynamic hhmm24, dynamic horaLegible) {
    if (hhmm24 is String && hhmm24.contains(':')) {
      final p = hhmm24.split(':');
      final h = int.tryParse(p[0]) ?? 0;
      final m = int.tryParse(p[1]) ?? 0;
      return h * 60 + m;
    }
    if (horaLegible is String && horaLegible.contains(':')) {
      final parts = horaLegible.trim().split(RegExp(r'\s+'));
      final hm = parts.first.split(':');
      int h = int.tryParse(hm[0]) ?? 0;
      final m = int.tryParse(hm[1]) ?? 0;
      final suffix = parts.length > 1 ? parts[1].toUpperCase() : '';
      final isPM = suffix.contains('PM');
      if (isPM && h < 12) h += 12;
      if (!isPM && h == 12) h = 0;
      return h * 60 + m;
    }
    return 0;
  }

  DateTime _normalizeTs(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Widget _statusChip(String estado) {
    Color bg, fg;
    String label;
    switch ((estado).toLowerCase()) {
      case 'confirmada':
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade800;
        label = 'Confirmada';
        break;
      case 'completada':
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
        label = 'Completada';
        break;
      case 'cancelada':
        bg = Colors.red.shade100;
        fg = Colors.red.shade800;
        label = 'Cancelada';
        break;
      default:
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade800;
        label = 'Pendiente';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Future<void> _refreshAppointments() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "📅 Mis Reservas",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: const Color(0xFF0072FF),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF0072FF), Color(0xFF0056CC)],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AppointmentPage()),
          );
        },
        backgroundColor: const Color(0xFF0072FF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nueva Cita',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getAppointments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = (snapshot.data?.docs ?? []).toList();

          if (docs.isEmpty) return _emptyState(context);

          docs.sort((a, b) {
            final A = a.data() as Map<String, dynamic>;
            final B = b.data() as Map<String, dynamic>;
            final fa = _normalizeDate(A['fecha_completa'], A['fecha']);
            final fb = _normalizeDate(B['fecha_completa'], B['fecha']);
            final cmpF = fa.compareTo(fb);
            if (cmpF != 0) return cmpF;
            final ha = _normalizeMinutes(A['hora_completa'], A['hora']);
            final hb = _normalizeMinutes(B['hora_completa'], B['hora']);
            final cmpH = ha.compareTo(hb);
            if (cmpH != 0) return cmpH;
            final ta = _normalizeTs(A['created_at'] ?? A['timestamp']);
            final tb = _normalizeTs(B['created_at'] ?? B['timestamp']);
            return ta.compareTo(tb);
          });

          return RefreshIndicator(
            onRefresh: _refreshAppointments,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final docSnap = docs[index];
                final data = docSnap.data() as Map<String, dynamic>;
                final id = docSnap.id;

                return Dismissible(
                  key: ValueKey(id),
                  direction: DismissDirection.horizontal,
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentPage(citaId: id)));
                      return false;
                    }

                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Cancelar cita'),
                        content: const Text('¿Estás seguro que deseas cancelar esta cita?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Sí, cancelar', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );

                    if (confirm != true) return false;

                    try {
                      // Actualizar el estado a "cancelada" en lugar de eliminar
                      await FirebaseFirestore.instance.collection('citas').doc(id).update({
                        'estado': 'cancelada',
                        'updated_at': FieldValue.serverTimestamp(),
                      });
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cita cancelada')));
                      return true;
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cancelar: $e')));
                      return false;
                    }
                  },
                  background: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(color: Colors.blue.shade600, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: const [Icon(Icons.edit, color: Colors.white), SizedBox(width: 8), Text('Editar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))]),
                  ),
                  secondaryBackground: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: const [Text('Cancelar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)), SizedBox(width: 8), Icon(Icons.cancel, color: Colors.white)]),
                  ),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentPage(citaId: id))),
                      onLongPress: () => _showAppointmentDetails(context, data, id),
                      onDoubleTap: () async {
                        final text = '${data['fecha'] ?? data['fecha_formateada'] ?? ''} ${data['hora'] ?? data['hora_formateada'] ?? ''}';
                        if (text.trim().isNotEmpty) {
                          await Clipboard.setData(ClipboardData(text: text));
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fecha y hora copiadas: $text')));
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(radius: 24, backgroundColor: Colors.blue.shade50, child: Icon(Icons.calendar_today, color: Colors.blue.shade700)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(data['nombre'] ?? data['paciente'] ?? 'Cita', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 6),
                                      Text('${data['fecha'] ?? data['fecha_formateada'] ?? ''} ${data['hora'] ?? data['hora_formateada'] ?? ''}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                                      if ((data['doctor'] ?? data['medico']) != null) ...[
                                        const SizedBox(height: 6),
                                        Text('Dr. ${data['doctor'] ?? data['medico']}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)), child: Text(data['costo_consulta'] != null ? '\$${data['costo_consulta']}' : '', style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w600))),
                                    const SizedBox(height: 8),
                                    (() {
                                      try {
                                        return _statusChip(data['estado'] ?? 'Pendiente');
                                      } catch (_) {
                                        return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)), child: Text(data['estado'] ?? 'Pendiente', style: TextStyle(fontSize: 12, color: Colors.orange.shade700)));
                                      }
                                    })(),
                                  ],
                                ),
                              ],
                            ),
                            // Botón para confirmar asistencia si la cita ya pasó y está pendiente
                            if (_shouldShowConfirmButton(data)) ...[
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _confirmAttendance(context, id, data),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.check_circle, color: Colors.white),
                                  label: const Text(
                                    'Confirmar que asistí a la cita',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showAppointmentDetails(BuildContext context, Map<String, dynamic> cita, String docId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 20,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0072FF), Color(0xFF0056CC)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white, size: 32),
                    const SizedBox(height: 12),
                    Text('Reserva con ${cita['especialista'] ?? cita['doctor_name'] ?? 'Especialista'}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow(Icons.person, 'Paciente:', cita['nombre'] ?? 'No disponible'),
                    _detailRow(Icons.email, 'Correo usuario:', cita['correoUsuario'] ?? '—'),
                    _detailRow(Icons.medical_services, 'Especialista:', cita['especialista'] ?? cita['doctor_name'] ?? 'No disponible'),
                    _detailRow(Icons.calendar_today, 'Fecha:', cita['fecha'] ?? _formatDate(cita['fecha_completa'] ?? cita['timestamp'])),
                    _detailRow(Icons.access_time, 'Hora:', cita['hora'] ?? (cita['hora_completa'] ?? 'No disponible')),
                    if ((cita['motivo'] ?? '').toString().isNotEmpty) _detailRow(Icons.description, 'Motivo:', cita['motivo']),
                    if (cita['created_at'] != null || cita['timestamp'] != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(0xFF0072FF).withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF0072FF).withOpacity(0.2))),
                        child: Row(children: [const Icon(Icons.info, color: Color(0xFF0072FF), size: 20), const SizedBox(width: 12), Expanded(child: Text('Creada el ${_formatDate(cita['created_at'] ?? cita['timestamp'])}', style: const TextStyle(color: Color(0xFF0072FF), fontWeight: FontWeight.w600, fontSize: 14)))]),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Mostrar botones según el estado de la cita
              Builder(
                builder: (context) {
                  final estado = (cita['estado'] ?? 'pendiente').toString().toLowerCase();
                  final isCompleted = estado == 'completada';
                  final isCancelled = estado == 'cancelada';
                  
                  if (isCompleted || isCancelled) {
                    // Si está completada o cancelada, solo mostrar cerrar y editar
                    return Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Cerrar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.pop(context);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => AppointmentPage(citaId: docId)),
                              );
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Editar'),
                          ),
                        ),
                      ],
                    );
                  }
                  
                  // Si está pendiente, mostrar todas las opciones
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Cerrar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                Navigator.pop(context);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => AppointmentPage(citaId: docId)),
                                );
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('Editar'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                Navigator.pop(context);
                                await _markAsCompleted(docId);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.check_circle, color: Colors.white),
                              label: const Text('Completar', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                Navigator.pop(context);
                                await _confirmAndDelete(docId);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.cancel, color: Colors.white),
                              label: const Text('Cancelar', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic ts) {
    try {
      if (ts is Timestamp) {
        final d = ts.toDate();
        return '${d.day}/${d.month}/${d.year}';
      }
      return ts?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF0072FF).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: const Color(0xFF0072FF))), const SizedBox(width: 12), Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2D3748), fontSize: 14)), const SizedBox(width: 8), Expanded(child: Text(value, style: const TextStyle(color: Color(0xFF4A5568), fontSize: 14, fontWeight: FontWeight.w500))) ]),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0072FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.calendar_today_outlined,
                      size: 48,
                      color: Color(0xFF0072FF),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '¡No hay citas registradas!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Crea tu primera reserva ahora mismo.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AppointmentPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0072FF),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                    label: const Text(
                      'Agendar Cita',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
}
