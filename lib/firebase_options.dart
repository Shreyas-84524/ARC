// File generated manually based on Firebase project SDK configuration.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
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
}
