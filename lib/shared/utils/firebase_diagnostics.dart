import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Outil de diagnostic pour vérifier la synchronisation Firebase
class FirebaseDiagnostics {
  static Future<void> checkConnection() async {
    print('🔍 === FIREBASE DIAGNOSTICS ===');
    
    // 1. Vérifier Firebase
    print('1️⃣ Firebase Status:');
    try {
      final firestore = FirebaseFirestore.instance;
      print('   ✅ Firestore connected');
      
      // 2. Vérifier l'authentification
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      
      if (user == null) {
        print('   ⚠️ User NOT authenticated (uid: null)');
        print('      → Data is likely hidden by Firestore security rules');
      } else {
        print('   ✅ User authenticated (uid: ${user.uid})');
      }
      
      // 3. Compter les collections
      print('\n2️⃣ Firestore Collections:');
      try {
        final coursesSnapshot = await firestore.collection('courses').get();
        print('   📚 Courses: ${coursesSnapshot.docs.length} documents');
        
        final homeworksSnapshot = await firestore.collection('homeworks').get();
        print('   📝 Homeworks: ${homeworksSnapshot.docs.length} documents');
        
        if (coursesSnapshot.docs.isEmpty && homeworksSnapshot.docs.isEmpty) {
          print('\n   ⚠️ Collections are EMPTY!');
          print('      → Either no data was added, or security rules deny access');
        }
      } catch (e) {
        print('   ❌ Error reading collections: $e');
        print('      → Check Firestore security rules');
      }
      
      // 4. Vérifier la connectivité
      print('\n3️⃣ Connectivity:');
      try {
        await firestore.collection('_test').doc('_test').get();
        print('   ✅ Firestore is reachable');
      } catch (e) {
        print('   ❌ Firestore is NOT reachable: $e');
      }
      
    } catch (e) {
      print('   ❌ Firebase error: $e');
    }
    
    print('🔍 === END DIAGNOSTICS ===\n');
  }
}
