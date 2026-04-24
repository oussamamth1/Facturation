import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Web config — works immediately.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC6dSEsP6iRBFaXr8qjX13PVTt5Q17eZqM',
    appId: '1:516716068209:web:32c05182c91d1b7ee04ad0',
    messagingSenderId: '516716068209',
    projectId: 'testf-2497a',
    authDomain: 'testf-2497a.firebaseapp.com',
    storageBucket: 'testf-2497a.firebasestorage.app',
    measurementId: 'G-EJ2SLNRBQP',
  );

  // Android — add your google-services.json to android/app/ and update appId below.

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBYFpsZEOmnkT76tUfpQXqMKcArzALAzHU',
    appId: '1:516716068209:android:ac95c9d6644592c6e04ad0',
    messagingSenderId: '516716068209',
    projectId: 'testf-2497a',
    storageBucket: 'testf-2497a.firebasestorage.app',
  );

  // Steps: Firebase Console → Project settings → Add Android app → download google-services.json

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDnFX_km-sNeGlV-hMrnzGe3GBqe-qvltg',
    appId: '1:516716068209:ios:206b211bb97af9b9e04ad0',
    messagingSenderId: '516716068209',
    projectId: 'testf-2497a',
    storageBucket: 'testf-2497a.firebasestorage.app',
    iosBundleId: 'com.facturation.facturationApp',
  );

  // iOS — add GoogleService-Info.plist to ios/Runner/ and update appId below.
}