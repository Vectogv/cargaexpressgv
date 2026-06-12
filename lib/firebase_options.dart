import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCQPBGK0CuoidlFBewtH7Fk2C8Als1kwII',
    appId: '1:848686850284:web:REEMPLAZAR_CON_APP_ID',
    messagingSenderId: '848686850284',
    projectId: 'app-cargaexpress',
    authDomain: 'app-cargaexpress.firebaseapp.com',
    storageBucket: 'app-cargaexpress.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCQPBGK0CuoidlFBewtH7Fk2C8Als1kwII',
    appId: '1:848686850284:android:d5c68a1b3b489b813d45c9',
    messagingSenderId: '848686850284',
    projectId: 'app-cargaexpress',
    storageBucket: 'app-cargaexpress.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCQPBGK0CuoidlFBewtH7Fk2C8Als1kwII',
    appId: '1:848686850284:ios:REEMPLAZAR_CON_APP_ID',
    messagingSenderId: '848686850284',
    projectId: 'app-cargaexpress',
    storageBucket: 'app-cargaexpress.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCQPBGK0CuoidlFBewtH7Fk2C8Als1kwII',
    appId: '1:848686850284:ios:REEMPLAZAR_CON_APP_ID',
    messagingSenderId: '848686850284',
    projectId: 'app-cargaexpress',
    storageBucket: 'app-cargaexpress.firebasestorage.app',
  );
}
