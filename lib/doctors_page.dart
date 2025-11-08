import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'dart:async';

/// Página que muestra la lista de doctores disponibles.
/// 
/// **GESTOS DISPONIBLES:**
/// 
/// 1. **Pull to Refresh (Arrastrar hacia abajo para recargar)**
///    - Acción: Arrastra hacia abajo desde la parte superior de la lista
///    - Funcionalidad: Recarga la lista de doctores
///    - Indicador visual: Ícono de refresh que rota mientras arrastras
///    - Activación: Se activa automáticamente al arrastrar más de 80 píxeles
///    - Compatibilidad: Funciona en web y móvil
/// 
/// 2. **Deslizar hacia la izquierda (Swipe Left - Reportar doctor)**
///    - Acción: Desliza un card de doctor hacia la izquierda
///    - Funcionalidad: Permite reportar un doctor
///    - Indicador visual: Fondo rojo con ícono de reporte
///    - Confirmación: Muestra un diálogo de confirmación antes de reportar
///    - Reversibilidad: Puedes deshacer la acción desde el SnackBar
/// 
/// 3. **Mantener presionado (Long Press - Marcar como favorito)**
///    - Acción: Mantén presionado el avatar circular del doctor durante 10 segundos
///    - Funcionalidad: Marca o desmarca un doctor como favorito
///    - Indicador visual: El avatar cambia a color dorado (amber) cuando es favorito
///    - Feedback: Muestra un SnackBar confirmando la acción
///    - Persistencia: Los favoritos se mantienen durante la sesión
///    - Delay: 10 segundos para permitir tomar captura de pantalla
/// 
/// **FILTROS:**
/// - Puedes filtrar doctores por especialidad usando los chips en la parte superior
/// - Especialidades disponibles: Todos, Cardiólogo, Dermatólogo, Pediatra
/// 
/// **INTERACCIONES:**
/// - Toca un card de doctor para ver sus detalles completos
/// - Los doctores se ordenan alfabéticamente por nombre
class DoctorsPage extends StatefulWidget {
  final String? initialSpecialty;
  
  const DoctorsPage({super.key, this.initialSpecialty});

  @override
  State<DoctorsPage> createState() => _DoctorsPageState();
}

class _DoctorsPageState extends State<DoctorsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedSpecialty = 'Todos';
  final ScrollController _scrollController = ScrollController();
  bool _isRefreshing = false;
  double _dragOffset = 0.0;
  Timer? _longPressTimer;
  String? _currentLongPressDocId;

  final List<String> _specialties = [
    'Todos',
    'Cardiólogo',
    'Dermatólogo',
    'Pediatra',
  ];

  // Favoritos locales (ids de documento)
  final Set<String> _favorites = {};

  @override
  void initState() {
    super.initState();
    // Si viene una especialidad inicial, seleccionarla
    if (widget.initialSpecialty != null && _specialties.contains(widget.initialSpecialty)) {
      _selectedSpecialty = widget.initialSpecialty!;
    }
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleLongPressStart(String docId) {
    // Iniciar timer con delay de 10 segundos para dar tiempo de tomar captura
    _currentLongPressDocId = docId;
    _longPressTimer?.cancel();
    _longPressTimer = Timer(const Duration(milliseconds: 10000), () {
      if (mounted && _currentLongPressDocId == docId) {
        _toggleFavorite(docId);
      }
    });
  }

  void _handleLongPressEnd() {
    // Cancelar el timer si el usuario suelta antes de tiempo
    _longPressTimer?.cancel();
    _currentLongPressDocId = null;
  }

  void _toggleFavorite(String docId) {
    setState(() {
      if (_favorites.contains(docId)) {
        _favorites.remove(docId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quitar de favoritos')),
        );
      } else {
        _favorites.add(docId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marcado como favorito')),
        );
      }
    });
    _currentLongPressDocId = null;
  }

  Future<void> _refreshDoctors() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });

    // Simular recarga de datos con una pausa para mostrar la animación
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (mounted) {
      setState(() {
        _isRefreshing = false;
        _dragOffset = 0.0;
        // Forzar actualización del stream
      });
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

          // Lista de doctores con pull-to-refresh
          Expanded(
            child: _buildDoctorsListWithRefresh(),
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

  /// Construye la lista de doctores con funcionalidad de Pull to Refresh.
  /// 
  /// **GESTO 1: Pull to Refresh**
  /// - Detecta cuando el usuario arrastra hacia abajo desde la parte superior
  /// - Muestra un indicador visual con ícono de refresh que rota
  /// - Se activa automáticamente al arrastrar más de 80 píxeles
  Widget _buildDoctorsListWithRefresh() {
    return Listener(
      onPointerMove: (event) {
        // Detectar movimiento del puntero cuando estamos en la parte superior
        if (_scrollController.hasClients &&
            _scrollController.position.pixels <= 0 &&
            event.delta.dy > 0) {
          // El usuario está moviendo el mouse hacia abajo desde la parte superior
          setState(() {
            _dragOffset = math.min(_dragOffset + event.delta.dy, 100.0);
          });
        }
      },
      onPointerUp: (event) {
        if (_dragOffset >= 80 && !_isRefreshing) {
          _refreshDoctors();
        } else {
          setState(() {
            _dragOffset = 0.0;
          });
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: (details) {
          if (_scrollController.hasClients &&
              _scrollController.position.pixels <= 0 &&
              details.primaryDelta != null &&
              details.primaryDelta! > 0) {
            // El usuario está arrastrando hacia abajo desde la parte superior
            setState(() {
              _dragOffset = math.min(_dragOffset + details.primaryDelta!, 100.0);
            });
          }
        },
        onVerticalDragEnd: (details) {
          if (_dragOffset >= 80 && !_isRefreshing) {
            _refreshDoctors();
          } else {
            setState(() {
              _dragOffset = 0.0;
            });
          }
        },
        child: Stack(
          children: [
            _buildDoctorsList(),
            // Indicador visual de refresh
            if (_dragOffset > 0 || _isRefreshing)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: math.max(_dragOffset, _isRefreshing ? 70.0 : 0.0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: _dragOffset > 0 || _isRefreshing
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: _isRefreshing
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0072FF)),
                          strokeWidth: 3.0,
                        )
                      : Transform.rotate(
                          angle: _dragOffset / 100 * 2 * math.pi,
                          child: Icon(
                            Icons.refresh,
                            color: const Color(0xFF0072FF).withOpacity(
                              math.min(_dragOffset / 80, 1.0),
                            ),
                            size: 28,
                          ),
                        ),
                ),
              ),
          ],
        ),
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

        // Usar ListView con contenido mínimo para que el gesto de refresh funcione
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              const SizedBox(height: 100), // Espacio extra para permitir scroll
            ],
          );
        }

        if (snapshot.hasError) {
          return ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 100), // Espacio extra para permitir scroll
            ],
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Center(
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
                ),
              ),
              const SizedBox(height: 100), // Espacio extra para permitir scroll
            ],
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
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 116), // Padding extra al final
          itemCount: doctors.length,
          itemBuilder: (context, index) {
            final docSnap = doctors[index];
            final doctor = docSnap.data() as Map<String, dynamic>;
            final docId = docSnap.id;

            // GESTO 2: Deslizar hacia la izquierda (Swipe Left) para reportar doctor
            // - Permite deslizar un card de doctor hacia la izquierda
            // - Muestra un fondo rojo con ícono de reporte
            // - Pide confirmación antes de reportar
            // - Permite deshacer la acción desde el SnackBar
            return Dismissible(
              key: ValueKey(docId),
              direction: DismissDirection.endToStart, // Solo permite deslizar hacia la izquierda
              confirmDismiss: (direction) async {
                // Pedir confirmación antes de marcar como reportado
                final res = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Reportar doctor'),
                    content: Text('¿Deseas reportar a ${doctor['nombre_completo'] ?? 'este doctor'}?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                      ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reportar')),
                    ],
                  ),
                );
                return res == true;
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.report, color: Colors.white),
              ),
              onDismissed: (direction) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${doctor['nombre_completo'] ?? 'Doctor'} reportado'),
                    action: SnackBarAction(
                      label: 'Deshacer',
                      onPressed: () {
                        // No eliminamos nada en la base de datos; solo una acción local.
                        setState(() {});
                      },
                    ),
                  ),
                );
              },
              child: Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  // GESTO 3: Mantener presionado (Long Press) en el avatar para marcar como favorito
                  // - Mantén presionado el avatar circular del doctor durante 10 segundos
                  // - Marca o desmarca como favorito
                  // - El avatar cambia a color dorado (amber) cuando es favorito
                  // - Muestra un SnackBar confirmando la acción
                  // - Delay de 10 segundos para permitir tomar captura
                  leading: GestureDetector(
                    onLongPressStart: (_) => _handleLongPressStart(docId),
                    onLongPressEnd: (_) => _handleLongPressEnd(),
                    child: CircleAvatar(
                      // El color cambia a dorado (amber) si es favorito, azul si no
                      backgroundColor: _favorites.contains(docId) ? Colors.amber.shade700 : const Color(0xFF0072FF),
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
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