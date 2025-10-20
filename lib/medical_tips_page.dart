import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MedicalTipsPage extends StatefulWidget {
  const MedicalTipsPage({super.key});

  @override
  State<MedicalTipsPage> createState() => _MedicalTipsPageState();
}

class _MedicalTipsPageState extends State<MedicalTipsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();
  Map<String, dynamic>? _currentTip;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadRandomTip();
  }

  Future<void> _loadRandomTip() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });
    }

    try {
      print('🔍 Cargando consejos desde Firestore...');
      
      final snapshot = await _firestore
          .collection('recomendaciones')
          .where('activo', isEqualTo: true)
          .get();

      print('📊 Documentos encontrados: ${snapshot.docs.length}');

      if (snapshot.docs.isEmpty) {
        print('❌ No hay documentos en la colección');
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'No hay consejos disponibles. Verifica la base de datos.';
            _isLoading = false;
          });
        }
        return;
      }

      final tips = snapshot.docs.map((doc) {
        final data = doc.data();
        print('📝 Tip: ${data['mensaje']}');
        return data;
      }).toList();

      // Seleccionar tip aleatorio
      final randomTip = tips[_random.nextInt(tips.length)];
      
      if (mounted) {
        setState(() {
          _currentTip = randomTip;
          _isLoading = false;
        });
      }

      print('✅ Tip cargado exitosamente');

    } catch (e) {
      print('❌ Error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _nextTip() {
    _loadRandomTip();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Consejos de Salud"),
        backgroundColor: const Color(0xFF0072FF),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const _TipsLoading()
          : _hasError
              ? _TipsError(
                  errorMessage: _errorMessage,
                  onRetry: _loadRandomTip,
                )
              : _currentTip == null
                  ? const _EmptyTips()
                  : _TipCard(
                      tip: _currentTip!,
                      onNext: _nextTip,
                    ),
    );
  }
}

class _TipsLoading extends StatelessWidget {
  const _TipsLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Cargando consejos de salud...',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _TipsError extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;

  const _TipsError({
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Error al cargar consejos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0072FF),
              ),
              child: const Text(
                'Reintentar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTips extends StatelessWidget {
  const _EmptyTips();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.health_and_safety, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No hay consejos disponibles',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega consejos a la base de datos Firebase',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final Map<String, dynamic> tip;
  final VoidCallback onNext;

  const _TipCard({
    required this.tip,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Header
          Card(
            color: const Color(0xFF0072FF).withOpacity(0.1),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.emoji_objects_outlined, color: Color(0xFF0072FF)),
                  SizedBox(width: 12),
                  Text(
                    'Consejo de Salud',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0072FF),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Tarjeta principal
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.health_and_safety,
                    size: 50,
                    color: const Color(0xFF0072FF),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tip['mensaje'] ?? 'Consejo de salud no disponible',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  if (tip['categoria'] != null) ...[
                    Chip(
                      label: Text(
                        tip['categoria'].toString().toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: const Color(0xFF0072FF),
                    ),
                    const SizedBox(height: 10),
                  ],
                  
                  if (tip['fuente'] != null) ...[
                    Text(
                      'Fuente: ${tip['fuente']}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          
          // Botón siguiente
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.autorenew),
              label: const Text('Siguiente Consejo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0072FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}