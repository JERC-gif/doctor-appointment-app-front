import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorsPage extends StatefulWidget {
  final String? initialSpecialty;
  
  const DoctorsPage({super.key, this.initialSpecialty});

  @override
  State<DoctorsPage> createState() => _DoctorsPageState();
}

class _DoctorsPageState extends State<DoctorsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedSpecialty = 'Todos';

  final List<String> _specialties = [
    'Todos',
    'Cardiólogo',
    'Dermatólogo',
    'Pediatra',
  ];

  @override
  void initState() {
    super.initState();
    // Si viene una especialidad inicial, seleccionarla
    if (widget.initialSpecialty != null && _specialties.contains(widget.initialSpecialty)) {
      _selectedSpecialty = widget.initialSpecialty!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nuestros Doctores"),
        backgroundColor: const Color(0xFF0072FF),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filtro de especialidades
          _buildSpecialtyFilter(),
          const SizedBox(height: 8),
          
          // Lista de doctores
          Expanded(
            child: _buildDoctorsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialtyFilter() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _specialties.length,
        itemBuilder: (context, index) {
          final specialty = _specialties[index];
          final isSelected = _selectedSpecialty == specialty;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(specialty),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedSpecialty = selected ? specialty : 'Todos';
                });
              },
              backgroundColor: Colors.grey.shade200,
              selectedColor: const Color(0xFF0072FF),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDoctorsList() {
    Query<Map<String, dynamic>> doctorsQuery = _firestore.collection('doctores');

    print('DEBUG: Especialidad seleccionada: $_selectedSpecialty');

    if (_selectedSpecialty != 'Todos') {
      doctorsQuery = doctorsQuery.where('especialidad', isEqualTo: _selectedSpecialty);
      print('DEBUG: Aplicando filtro para especialidad: $_selectedSpecialty');
    }

    // Removemos orderBy para evitar problemas de índices
    // doctorsQuery = doctorsQuery.orderBy('nombre_completo');

    return StreamBuilder<QuerySnapshot>(
      stream: doctorsQuery.snapshots(),
      builder: (context, snapshot) {
        print('DEBUG: ConnectionState: ${snapshot.connectionState}');
        print('DEBUG: HasError: ${snapshot.hasError}');
        print('DEBUG: HasData: ${snapshot.hasData}');
        
        if (snapshot.hasData) {
          print('DEBUG: Docs count: ${snapshot.data!.docs.length}');
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            print('DEBUG: Doctor: ${data['nombre_completo']} - Especialidad: ${data['especialidad']}');
          }
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                            Icons.medical_services,
                            size: 48,
                            color: Color(0xFF0072FF),
                          ),
                        ),
                        const SizedBox(height: 24),
                Text(
                  'No hay doctores de $_selectedSpecialty',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                Text(
                          'Selecciona "Todos" para ver todos los doctores disponibles',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            height: 1.5,
                          ),
                  textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        // Debug info
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'DEBUG INFO:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Filtro activo: $_selectedSpecialty',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              Text(
                                'Total doctores encontrados: ${snapshot.data?.docs.length ?? 0}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0072FF), Color(0xFF0056CC)],
                            ),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0072FF).withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedSpecialty = 'Todos';
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: const Text(
                              'Ver Todos los Doctores',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
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

        final doctors = snapshot.data!.docs;
        
        // Ordenar los doctores por nombre localmente
        doctors.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aName = aData['nombre_completo'] ?? '';
          final bName = bData['nombre_completo'] ?? '';
          return aName.compareTo(bName);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: doctors.length,
          itemBuilder: (context, index) {
            final doctor = doctors[index].data() as Map<String, dynamic>;
            
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF0072FF),
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(
                  doctor['nombre_completo'] ?? 'Doctor',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor['especialidad'] ?? 'Especialidad',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.star, size: 16, color: Colors.amber.shade600),
                        const SizedBox(width: 4),
                        Text('${doctor['calificacion']?.toString() ?? '4.5'}'),
                        const SizedBox(width: 12),
                        Icon(Icons.work, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('${doctor['experiencia']?.toString() ?? '0'} años'),
                      ],
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '\$${doctor['costo_consulta']?.toString() ?? '0'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0072FF),
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'consulta',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  _showDoctorDetails(context, doctor);
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showDoctorDetails(BuildContext context, Map<String, dynamic> doctor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(doctor['nombre_completo'] ?? 'Doctor'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                doctor['especialidad'] ?? 'Especialidad',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              if (doctor['subespecialidad'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Subespecialidad: ${doctor['subespecialidad']}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                doctor['descripcion'] ?? 'Sin descripción disponible',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              _buildDetailRow(Icons.star, 'Calificación:', '${doctor['calificacion']?.toString() ?? '4.5'}', color: Colors.amber),
              _buildDetailRow(Icons.work, 'Experiencia:', '${doctor['experiencia'] ?? '0'} años'),
              _buildDetailRow(Icons.phone, 'Teléfono:', doctor['telefono'] ?? 'No disponible'),
              _buildDetailRow(Icons.business, 'Consultorio:', doctor['consultorio'] ?? 'No disponible'),
              _buildDetailRow(Icons.email, 'Email:', doctor['email'] ?? 'No disponible'),
              _buildDetailRow(
                Icons.circle, 
                'Estado:', 
                doctor['estado'] ?? 'No disponible',
                color: (doctor['estado'] == 'disponible') ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0072FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Costo de consulta:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '\$${doctor['costo_consulta']?.toString() ?? '0'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0072FF),
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Aquí puedes navegar a la página de agendar cita
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0072FF),
            ),
            child: const Text(
              'Agendar Cita',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}