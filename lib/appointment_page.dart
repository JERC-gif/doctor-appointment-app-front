import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppointmentPage extends StatefulWidget {
  const AppointmentPage({super.key, this.citaId});
  final String? citaId; // null => crear; no-null => editar

  @override
  State<AppointmentPage> createState() => _AppointmentPageState();
}

class _AppointmentPageState extends State<AppointmentPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController reasonController = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String? selectedSpecialist;

  bool _loading = false;
  bool get _isEditing => widget.citaId != null;

  final List<String> specialists = const [
    "Cardiólogo",
    "Dermatólogo",
    "Pediatra",
    "Dentista",
    "Psicólogo",
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadAppointment();
  }

  Future<void> _loadAppointment() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('citas')
          .doc(widget.citaId)
          .get();
      if (!snap.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('La cita no existe')),
          );
          Navigator.pop(context);
        }
        return;
      }
      final data = snap.data()!;
      nameController.text = (data['nombre'] ?? '').toString();
      reasonController.text = (data['motivo'] ?? '').toString();
      selectedSpecialist = (data['especialista'] ?? '') as String?;

      // Cargar fecha/hora (prioriza campos normalizados si existen)
      DateTime? inicio;

      if (data['inicio_ts'] is Timestamp) {
        inicio = (data['inicio_ts'] as Timestamp).toDate();
      } else if (data['fecha_completa'] is Timestamp) {
        final d = (data['fecha_completa'] as Timestamp).toDate();
        if (data['hora_completa'] is String) {
          final p = (data['hora_completa'] as String).split(':');
          final h = int.tryParse(p[0]) ?? 9;
          final m = int.tryParse(p[1]) ?? 0;
          inicio = DateTime(d.year, d.month, d.day, h, m);
        }
      }

      if (inicio != null) {
        selectedDate = DateTime(inicio.year, inicio.month, inicio.day);
        selectedTime = TimeOfDay(hour: inicio.hour, minute: inicio.minute);
      }

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2027),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => selectedTime = picked);
  }

  DateTime? _merge(DateTime? d, TimeOfDay? t) {
    if (d == null || t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  String _fmtHHmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Valida que no exista otra cita en el mismo especialista, misma fecha y misma hora.
  Future<bool> _existeDuplicado({
    required String especialista,
    required DateTime fechaSolo,
    required String hhmm,
    String? exceptId,
  }) async {
    // Usamos igualdad sobre fecha_completa (sin hora) + misma hora_completa
    final qs = await FirebaseFirestore.instance
        .collection('citas')
        .where('especialista', isEqualTo: especialista)
        .where('fecha_completa',
            isEqualTo: Timestamp.fromDate(DateTime(fechaSolo.year, fechaSolo.month, fechaSolo.day)))
        .where('hora_completa', isEqualTo: hhmm)
        .get();

    for (final d in qs.docs) {
      if (d.id == exceptId) continue;
      return true; // hay otra cita en ese mismo slot
    }
    return false;
  }

  Future<void> _saveAppointment() async {
    if (!_formKey.currentState!.validate() ||
        selectedDate == null ||
        selectedTime == null ||
        selectedSpecialist == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos")),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario no autenticado')),
      );
      return;
    }

    final inicio = _merge(selectedDate, selectedTime)!;
    final fechaSolo = DateTime(inicio.year, inicio.month, inicio.day);
    final hhmm = _fmtHHmm(selectedTime!);

    setState(() => _loading = true);

    try {
      // Validación de duplicado exacto
      final duplicado = await _existeDuplicado(
        especialista: selectedSpecialist!,
        fechaSolo: fechaSolo,
        hhmm: hhmm,
        exceptId: widget.citaId,
      );
      if (duplicado) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ya existe una cita en esa fecha y hora para ese especialista')),
        );
        return;
      }

      final fechaLegible = '${fechaSolo.day}/${fechaSolo.month}/${fechaSolo.year}';
      final horaLegible = selectedTime!.format(context);

      final payload = {
        'usuario_id': user.uid,
        'nombre': nameController.text.trim(),
        'especialista': selectedSpecialist,
        'motivo': reasonController.text.trim(),
        // Legibles
        'fecha': fechaLegible,
        'hora': horaLegible,
        // Normalizados (útiles para orden y filtros)
        'fecha_completa': Timestamp.fromDate(fechaSolo),
        'hora_completa': hhmm,
        'inicio_ts': Timestamp.fromDate(inicio),
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('citas')
            .doc(widget.citaId)
            .update(payload);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cita actualizada")),
          );
        }
      } else {
        await FirebaseFirestore.instance.collection('citas').add({
          ...payload,
          'created_at': FieldValue.serverTimestamp(),
          'estado': 'pendiente',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "Cita agendada con $selectedSpecialist el ${fechaSolo.day}/${fechaSolo.month} a las ${horaLegible}"),
            ),
          );
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al guardar la cita: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? "Editar Cita" : "Agendar Cita"),
        backgroundColor: const Color(0xFF0072FF),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(), // dismiss keyboard on tap outside
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Información del paciente",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: "Nombre completo",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.isEmpty ? "Campo requerido" : null,
                      ),
                      const SizedBox(height: 20),

                      DropdownButtonFormField<String>(
                        value: selectedSpecialist,
                        decoration: InputDecoration(
                          labelText: "Especialista",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: specialists
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (value) => setState(() => selectedSpecialist = value),
                        validator: (value) => value == null ? "Selecciona un especialista" : null,
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onLongPress: () {
                                setState(() => selectedDate = null);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Fecha limpiada')),
                                );
                              },
                              child: Text(
                                selectedDate == null
                                    ? "Selecciona una fecha"
                                    : "Fecha: ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _selectDate,
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0072FF)),
                            child: const Text("Elegir fecha", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onLongPress: () {
                                setState(() => selectedTime = null);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Hora limpiada')),
                                );
                              },
                              child: Text(
                                selectedTime == null
                                    ? "Selecciona una hora"
                                    : "Hora: ${selectedTime!.format(context)}",
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _selectTime,
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0072FF)),
                            child: const Text("Elegir hora", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: reasonController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: "Motivo de la consulta",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.isEmpty ? "Campo requerido" : null,
                      ),
                      const SizedBox(height: 30),

                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle, color: Colors.white),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0072FF),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          onPressed: _saveAppointment,
                          label: Text(
                            _isEditing ? "Guardar cambios" : "Guardar Cita",
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
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
