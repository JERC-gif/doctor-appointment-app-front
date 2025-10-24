import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'appointment_page.dart';

class AppointmentsListPage extends StatefulWidget {
  const AppointmentsListPage({super.key});

  @override
  State<AppointmentsListPage> createState() => _AppointmentsListPageState();
}

class _AppointmentsListPageState extends State<AppointmentsListPage> {
  // Para que veas los 3, no filtramos por usuario.
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
        await FirebaseFirestore.instance.collection('citas').doc(id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cita cancelada')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cancelar: $e')));
        }
      }
    }
  }

  // ===== Helpers de formato / orden =====
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
    final diff = DateTime(d.year, d.month, d.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
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
        bg = Colors.blue.shade100; fg = Colors.blue.shade800; label = 'Confirmada'; break;
      case 'completada':
        bg = Colors.green.shade100; fg = Colors.green.shade800; label = 'Completada'; break;
      case 'cancelada':
        bg = Colors.red.shade100; fg = Colors.red.shade800; label = 'Cancelada'; break;
      default:
        bg = Colors.orange.shade100; fg = Colors.orange.shade800; label = 'Pendiente';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;

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

          // Orden local: fecha -> hora -> created
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final paciente = (data['nombre'] ?? 'Paciente').toString();
              final especialista =
                  (data['doctor_name'] ?? data['especialista'] ?? 'Especialista').toString();
              final when = _formatFechaHora(data);
              final estado = (data['estado'] ?? 'pendiente').toString();

              final meUser = me;
              final mineByUid = data['usuario_id'] != null && meUser != null && data['usuario_id'] == meUser.uid;
              final mineByMail = data['correoUsuario'] != null && meUser != null && data['correoUsuario'] == meUser.email;
              final isMine = mineByUid || mineByMail;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showAppointmentDetails(context, data, doc.id),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF0072FF), Color(0xFF0056CC)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.calendar_today,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            paciente,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2D3748),
                                            ),
                                          ),
                                        ),
                                        if (isMine)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Mía',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.purple.shade800,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Dr. $especialista',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _statusChip(estado),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Fecha / hora + relativo
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    when,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (data['fecha_completa'] is Timestamp)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0072FF).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _relativoDesdeFecha(data['fecha_completa']),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF0072FF),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          if ((data['motivo'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.description, size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    data['motivo'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 12),

                          // Acciones
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AppointmentPage(citaId: doc.id),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Editar'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _confirmAndDelete(doc.id),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  icon: const Icon(Icons.delete, color: Colors.white),
                                  label: const Text('Cancelar', style: TextStyle(color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
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
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0072FF), Color(0xFF0056CC)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white, size: 32),
                    const SizedBox(height: 12),
                    Text(
                      'Reserva con ${cita['especialista'] ?? cita['doctor_name'] ?? 'Especialista'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Contenido
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow(Icons.person, 'Paciente:', cita['nombre'] ?? 'No disponible'),
                    _detailRow(Icons.email, 'Correo usuario:', cita['correoUsuario'] ?? '—'),
                    _detailRow(Icons.medical_services, 'Especialista:',
                        cita['especialista'] ?? cita['doctor_name'] ?? 'No disponible'),
                    _detailRow(Icons.calendar_today, 'Fecha:',
                        cita['fecha'] ?? _formatDate(cita['fecha_completa'] ?? cita['timestamp'])),
                    _detailRow(Icons.access_time, 'Hora:',
                        cita['hora'] ?? (cita['hora_completa'] ?? 'No disponible')),
                    if ((cita['motivo'] ?? '').toString().isNotEmpty)
                      _detailRow(Icons.description, 'Motivo:', cita['motivo']),
                    if (cita['created_at'] != null || cita['timestamp'] != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0072FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF0072FF).withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info, color: Color(0xFF0072FF), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Creada el ${_formatDate(cita['created_at'] ?? cita['timestamp'])}',
                                style: const TextStyle(
                                  color: Color(0xFF0072FF),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Botones
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Cerrar',
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _confirmAndDelete(docId);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: const Text('Cancelar', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
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
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0072FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF0072FF)),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF4A5568),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
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
                    'Crea tu primera reserva desde “Agendar Cita”.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
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
