import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileFormPage extends StatefulWidget {
  const ProfileFormPage({super.key});

  @override
  State<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends State<ProfileFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController emergencyContactController = TextEditingController();
  final TextEditingController medicalConditionsController = TextEditingController();
  final TextEditingController allergiesController = TextEditingController();
  final TextEditingController medicationsController = TextEditingController();
  
  bool _isLoading = false;
  String? _selectedGender;
  String? _selectedBloodType;
  String _selectedRole = 'Paciente';

  final List<String> _genders = ['Masculino', 'Femenino', 'Otro'];
  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .get();
        
        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            nameController.text = data['nombre_completo'] ?? '';
            ageController.text = data['edad']?.toString() ?? '';
            phoneController.text = data['telefono'] ?? '';
            addressController.text = data['direccion'] ?? '';
            emergencyContactController.text = data['contacto_emergencia'] ?? '';
            medicalConditionsController.text = data['condiciones_medicas'] ?? '';
            allergiesController.text = data['alergias'] ?? '';
            medicationsController.text = data['medicamentos'] ?? '';
            _selectedGender = data['genero'];
            _selectedBloodType = data['tipo_sangre'];
            _selectedRole = data['rol'] ?? 'Paciente';
          });
        }
      } catch (e) {
        print('Error cargando datos: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "👤 Mi Perfil",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF0072FF),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0072FF),
                Color(0xFF0056CC),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Información Personal
              _buildSectionHeader("📋 Información Personal"),
              const SizedBox(height: 12),
              _buildTextField(nameController, "Nombre completo", Icons.person),
              _buildTextField(ageController, "Edad", Icons.cake, type: TextInputType.number),
              _buildTextField(phoneController, "Teléfono", Icons.phone),
              _buildTextField(addressController, "Dirección", Icons.location_on),
              _buildDropdownField("Rol", _selectedRole, ['Paciente', 'Médico'], (value) {
                if (value != null) {
                  setState(() => _selectedRole = value);
                }
              }, Icons.person_outline),
              
              const SizedBox(height: 24),
              
              // Información Médica
              _buildSectionHeader("🏥 Información Médica"),
              const SizedBox(height: 12),
              _buildDropdownField("Género", _selectedGender, _genders, (value) {
                setState(() => _selectedGender = value);
              }, Icons.person_outline),
              _buildDropdownField("Tipo de sangre", _selectedBloodType, _bloodTypes, (value) {
                setState(() => _selectedBloodType = value);
              }, Icons.bloodtype),
              _buildTextField(medicalConditionsController, "Condiciones médicas", Icons.medical_services, maxLines: 3),
              _buildTextField(allergiesController, "Alergias", Icons.warning, maxLines: 2),
              _buildTextField(medicationsController, "Medicamentos actuales", Icons.medication, maxLines: 2),
              
              const SizedBox(height: 24),
              
              // Contacto de Emergencia
              _buildSectionHeader("🚨 Contacto de Emergencia"),
              const SizedBox(height: 12),
              _buildTextField(emergencyContactController, "Nombre y teléfono del contacto", Icons.emergency),
              
              const SizedBox(height: 32),
              
              // Botón Guardar
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0072FF), Color(0xFF0056CC)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0072FF).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              "Guardar Perfil",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2D3748),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, 
      {TextInputType? type, int maxLines = 1}) {
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
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF0072FF)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(20),
        ),
        validator: (value) {
          if (label == "Nombre completo" || label == "Edad") {
            return value == null || value.isEmpty ? "Campo requerido" : null;
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdownField(String label, String? value, List<String> items, 
      Function(String?) onChanged, IconData icon) {
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
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF0072FF)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(20),
        ),
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'nombre_completo': nameController.text.trim(),
        'edad': int.tryParse(ageController.text.trim()) ?? 0,
        'telefono': phoneController.text.trim(),
        'direccion': addressController.text.trim(),
        'genero': _selectedGender,
        'tipo_sangre': _selectedBloodType,
        'rol': _selectedRole,
        'tipo_usuario': _selectedRole.toLowerCase(),
        'condiciones_medicas': medicalConditionsController.text.trim(),
        'alergias': allergiesController.text.trim(),
        'medicamentos': medicationsController.text.trim(),
        'contacto_emergencia': emergencyContactController.text.trim(),
        'ultima_actualizacion': FieldValue.serverTimestamp(),
        'perfil_completo': true,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Perfil guardado exitosamente'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
