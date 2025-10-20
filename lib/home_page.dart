import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'messages_page.dart';
import 'settings_page.dart';
import 'appointment_page.dart';
import 'appointments_list_page.dart';
import 'medical_tips_page.dart';
import 'doctors_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final user = FirebaseAuth.instance.currentUser;

  // Lista de páginas para cada opción del menú
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const _HomeContent(),
      const AppointmentsListPage(),
      const MessagesPage(),
      const SettingsPage(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MediCitas"),
        centerTitle: true,
        backgroundColor: const Color(0xFF0072FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF0072FF),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: "Inicio",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: "Citas",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_outlined),
            activeIcon: Icon(Icons.message),
            label: "Mensajes",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: "Ajustes",
          ),
        ],
      ),
    );
  }
}

/// CONTENIDO PRINCIPAL DEL HOME
class _HomeContent extends StatefulWidget {
  const _HomeContent();

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  String _userName = "Usuario";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  void _loadUserName() async {
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
            _userName = data['nombre_completo'] ?? user.displayName ?? user.email ?? "Usuario";
            _isLoading = false;
          });
        } else {
          setState(() {
            _userName = user.displayName ?? user.email ?? "Usuario";
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _userName = user.displayName ?? user.email ?? "Usuario";
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _userName = "Usuario";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de bienvenida
          _buildWelcomeHeader(),
          const SizedBox(height: 30),

          // Botones principales
          _buildMainActions(context),
          const SizedBox(height: 30),

          // Especialidades disponibles
          _buildSpecialtiesSection(context),
          const SizedBox(height: 20),

          // Estadísticas rápidas
          _buildQuickStats(),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "¡Hola!",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 4),
        _isLoading
            ? Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.grey.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Cargando...",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              )
            : Text(
                _userName,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
        const SizedBox(height: 8),
        Text(
          "¿En qué podemos ayudarte hoy?",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildMainActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Acciones Rápidas",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ActionCard(
              icon: Icons.calendar_month,
              title: "Agendar Cita",
              color: const Color(0xFF0072FF),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AppointmentPage()),
                );
              },
            ),
            _ActionCard(
              icon: Icons.medical_services,
              title: "Ver Doctores",
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DoctorsPage()),
                );
              },
            ),
            _ActionCard(
              icon: Icons.health_and_safety,
              title: "Consejos Salud",
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MedicalTipsPage()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpecialtiesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Especialidades Médicas",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Encuentra al especialista que necesitas",
          style: TextStyle(
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: [
            _SpecialtyCard(
              icon: Icons.favorite,
              title: "Cardiólogo",
              subtitle: "Especialistas en corazón y sistema cardiovascular",
              color: Colors.red.shade400,
              onTap: () {
                _showSpecialtyDoctors(context, "Cardiólogo");
              },
            ),
            _SpecialtyCard(
              icon: Icons.spa,
              title: "Dermatólogo",
              subtitle: "Cuidado de la piel, cabello y uñas",
              color: Colors.blue.shade400,
              onTap: () {
                _showSpecialtyDoctors(context, "Dermatólogo");
              },
            ),
            _SpecialtyCard(
              icon: Icons.child_care,
              title: "Pediatra",
              subtitle: "Salud infantil y desarrollo",
              color: Colors.green.shade400,
              onTap: () {
                _showSpecialtyDoctors(context, "Pediatra");
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tu Salud en Números",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  value: "5+",
                  label: "Doctores\nDisponibles",
                ),
                _StatItem(
                  value: "10+",
                  label: "Consejos\nSalud",
                ),
                _StatItem(
                  value: "24/7",
                  label: "Atención\nDisponible",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSpecialtyDoctors(BuildContext context, String specialty) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorsPage(),
      ),
    );
    
    // Opcional: Mostrar snackbar informativo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mostrando doctores de $specialty'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecialtyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SpecialtyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0072FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "Ver",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF0072FF),
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0072FF),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}