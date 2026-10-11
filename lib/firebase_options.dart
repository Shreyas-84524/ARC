// File generated based on Firebase project SDK configuration.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCZopGQ1B_PsRDUAlp6xLXpLlI8AeMEEcM',
    appId: '1:729643761637:web:712a4edaec1a5743dc790c',
    messagingSenderId: '729643761637',
    projectId: 'arc-productivity-shreyas',
    authDomain: 'arc-productivity-shreyas.firebaseapp.com',
    storageBucket: 'arc-productivity-shreyas.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCTp6kyYEFN_yBX-cnRAR45E66dGk4UHVo',
    appId: '1:729643761637:android:39bc738c98a05bd4dc790c',
    messagingSenderId: '729643761637',
    projectId: 'arc-productivity-shreyas',
    storageBucket: 'arc-productivity-shreyas.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB8ui7aQdrTRKhV1mCNqt_k3sbIpvXNqgs',
    appId: '1:729643761637:ios:1f1fa53c132914cbdc790c',
    messagingSenderId: '729643761637',
    projectId: 'arc-productivity-shreyas',
    storageBucket: 'arc-productivity-shreyas.firebasestorage.app',
    iosBundleId: 'com.arc.arc',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCZopGQ1B_PsRDUAlp6xLXpLlI8AeMEEcM',
    appId: '1:729643761637:web:712a4edaec1a5743dc790c',
    messagingSenderId: '729643761637',
    projectId: 'arc-productivity-shreyas',
    authDomain: 'arc-productivity-shreyas.firebaseapp.com',
    storageBucket: 'arc-productivity-shreyas.firebasestorage.app',
  );
}
