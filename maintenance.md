# Project Arc — Developer & System Maintenance Guide

> **Version:** 1.0.0 (Production Release)  
> **Document Purpose:** Step-by-step developer maintenance guide covering SDK upgrades, dependency management, code generation, build commands, and troubleshooting.

---

## 1. Environment & SDK Upgrades

### Flutter & Dart SDK
- **Current Version**: Flutter 3.29.x / Dart 3.7.x
- **Upgrade Process**:
  ```bash
  flutter upgrade
  flutter pub outdated
  flutter pub get
  ```

### Regenerating Hive Type Adapters
When adding or modifying fields in Hive models (`@HiveType`, `@HiveField`):
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 2. Build Commands Reference

### Running Tests
```bash
flutter test
```

### Static Code Analysis
```bash
dart analyze
```

### Building Debug APK
```bash
flutter build apk --debug
```

### Building Release APK
```bash
flutter build apk --release
```

### Building Release AppBundle (Google Play)
```bash
flutter build appbundle --release
```

---

## 3. Common Troubleshooting Procedures

### 1. Hive Storage Cache Reset
- If local box keys become out-of-sync:
  1. Open app -> **Settings** -> **Data & Storage Diagnostics**.
  2. Tap **Clear Local Cache**.
  3. Hive indexes will refresh from raw storage without loss of user data.

### 2. Manual Firestore Sync Flush
- To force immediate background sync queue processing:
  1. Open app -> **Settings** -> **Data & Storage Diagnostics**.
  2. Tap **Sync Now**.
