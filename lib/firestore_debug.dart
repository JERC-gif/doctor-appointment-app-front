import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Helper para debugging de Firestore
class FirestoreDebug {
  /// Prueba la conexión a Firestore y retorna información de diagnóstico
  static Future<Map<String, dynamic>> testConnection() async {
    final results = <String, dynamic>{
      'authenticated': false,
      'userId': null,
      'collections': <String, dynamic>{},
      'errors': <String>[],
    };

    try {
      // Verificar autenticación
      final user = FirebaseAuth.instance.currentUser;
      results['authenticated'] = user != null;
      results['userId'] = user?.uid;

      if (user == null) {
        results['errors'].add('Usuario no autenticado');
        return results;
      }

      // Probar cada colección
      final collections = ['citas', 'doctores', 'recomendaciones', 'usuarios'];

      for (final collectionName in collections) {
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection(collectionName)
              .limit(1)
              .get();

          results['collections'][collectionName] = {
            'accessible': true,
            'count': snapshot.docs.length,
            'error': null,
          };
        } catch (e) {
          results['collections'][collectionName] = {
            'accessible': false,
            'count': 0,
            'error': e.toString(),
          };
          results['errors'].add('Error en $collectionName: $e');
        }
      }
    } catch (e) {
      results['errors'].add('Error general: $e');
    }

    return results;
  }

  /// Obtiene información detallada de una colección
  static Future<Map<String, dynamic>> getCollectionInfo(String collectionName) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(collectionName)
          .limit(5)
          .get();

      final docs = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'fields': data.keys.toList(),
          'sample': data,
        };
      }).toList();

      return {
        'success': true,
        'count': snapshot.docs.length,
        'docs': docs,
        'error': null,
      };
    } catch (e) {
      return {
        'success': false,
        'count': 0,
        'docs': [],
        'error': e.toString(),
      };
    }
  }
}

