import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppointmentPage extends StatefulWidget {
  const AppointmentPage({super.key});

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

  final List<String> specialists = [
    "Cardiólogo",
    "Dermatólogo",
    "Pediatra",
    "Dentista",
    "Psicólogo",
  ];

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2026),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  /// Guardar cita en Firestore
  void _saveAppointment() async {
    if (_formKey.currentState!.validate() &&
        selectedDate != null &&
        selectedTime != null &&
        selectedSpecialist != null) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('Usuario no autenticado');
        }

        await FirebaseFirestore.instance.collection('citas').add({
          'usuario_id': user.uid, // ID del usuario autenticado
          'nombre': nameController.text,
          'especialista': selectedSpecialist,
          'fecha':
              '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
          'hora': selectedTime!.format(context),
          'motivo': reasonController.text,
          'created_at': FieldValue.serverTimestamp(),
          'estado': 'pendiente', // Estado de la cita
          'fecha_completa': Timestamp.fromDate(selectedDate!), // Para ordenamiento
          'hora_completa': '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}', // Para ordenamiento
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Cita agendada con $selectedSpecialist el ${selectedDate!.day}/${selectedDate!.month} a las ${selectedTime!.format(context)}"),
          ),
        );

        Navigator.pop(context); // Regresa al Home

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al guardar la cita: $e")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Agendar Cita"),
        backgroundColor: const Color(0xFF0072FF),
      ),
      body: SingleChildScrollView(
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
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? "Campo requerido" : null,
              ),
              const SizedBox(height: 20),

              /// Especialista
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: "Especialista",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: specialists
                    .map((e) =>
                        DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (value) => selectedSpecialist = value,
                validator: (value) =>
                    value == null ? "Selecciona un especialista" : null,
              ),
              const SizedBox(height: 20),

              /// Fecha
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedDate == null
                          ? "Selecciona una fecha"
                          : "Fecha: ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _selectDate,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0072FF)),
                    child: const Text("Elegir fecha",
                     style: TextStyle(color: Colors.white)
                     ),
                  )
                ],
              ),
              const SizedBox(height: 20),

              /// Hora
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedTime == null
                          ? "Selecciona una hora"
                          : "Hora: ${selectedTime!.format(context)}",
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _selectTime,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0072FF)),
                    child: const Text("Elegir hora",
                      style: TextStyle(color: Colors.white
                    ), 
                  )
                  )
                ],
              ),
              const SizedBox(height: 20),

              /// Motivo
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Motivo de la consulta",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? "Campo requerido" : null,
              ),
              const SizedBox(height: 30),

              /// Botón guardar
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0072FF),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  onPressed: _saveAppointment,
                  label: const Text(
                    "Guardar Cita",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
