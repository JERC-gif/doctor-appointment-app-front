import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Script de prueba para verificar la conexión a Firestore
class FirestoreTest {
  static Future<void> testConnection() async {
    final firestore = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    
    print('=== PRUEBA DE CONEXIÓN FIRESTORE ===');
    print('Usuario autenticado: ${auth.currentUser != null}');
    if (auth.currentUser != null) {
      print('UID: ${auth.currentUser!.uid}');
      print('Email: ${auth.currentUser!.email}');
    }
    
    // Probar cada colección
    final collections = ['doctores', 'citas', 'usuarios', 'recomendaciones', 'consejos', 'tips'];
    
    for (final collectionName in collections) {
      try {
        print('\n--- Probando colección: $collectionName ---');
        final snapshot = await firestore.collection(collectionName).limit(1).get();
        print('✅ Éxito: ${snapshot.docs.length} documentos encontrados');
        if (snapshot.docs.isNotEmpty) {
          print('   Primer documento ID: ${snapshot.docs.first.id}');
          print('   Datos: ${snapshot.docs.first.data()}');
        }
      } catch (e) {
        print('❌ Error: $e');
        if (e.toString().contains('permission-denied')) {
          print('   ⚠️ ERROR DE PERMISOS - Las reglas de Firestore necesitan actualizarse');
        }
      }
    }
    
    print('\n=== FIN DE PRUEBA ===');
  }
}

