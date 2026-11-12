import 'package:firebase_core/firebase_core.dart';

/// Your Firebase project's settings.
///
/// Fill these in from Firebase console → Project settings → Your apps → Web app
/// → "SDK setup and configuration" → Config. These values are meant to be public;
/// your data is protected by the rules in firestore.rules, not by hiding them.
class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: 'AIzaSyAr755xx0eOfCehPJpEUIsMUPqC52kBErM',
    appId: '1:102458149662:web:75959c586fbf165c6cd70f',
    messagingSenderId: '102458149662',
    projectId: 'spending-jar',
    authDomain: 'spending-jar.firebaseapp.com',
    storageBucket: 'spending-jar.firebasestorage.app',
  );

  static bool get isConfigured => !currentPlatform.apiKey.startsWith('PASTE');
}
