# Environment audit

Status: **Completed with two runtime blockers**. Audited 2026-10-18 on Windows build `10.0.26200.9711`, 64-bit. Drive C: had 148,528,238,592 bytes free (~138.3 GiB).

## Installed

| Component | Verified result |
|---|---|
| Android Studio | `AI-261.26222.65.2614.16204760` (2026.1.4 family), installed in `C:\Program Files\Android\Android Studio` |
| Studio runtime | OpenJDK 25.0.3 in `Android Studio\jbr` |
| System JDK | Eclipse Temurin 17.0.20.1; `JAVA_HOME` points to it |
| Git | 2.55.0.windows.5 |
| Android SDK | `C:\Users\Kryo\AppData\Local\Android\Sdk` |
| Platforms | android-34, 35, 36, 37.0 |
| Build Tools | 35.0.0 and 36.0.0 |
| Platform Tools | ADB 1.0.41 / 37.0.1 |
| Emulator | 37.1.11.0 |
| AVDs | `Medium_Phone`, `New_Device`, `Pixel_7_Pro` |
| Flutter | Two PATH candidates: `C:\Learning some new stuf\01\flutter` and `C:\src\flutter` |

## Findings

- `adb` is not on PATH, although it is installed. Use the SDK absolute path or add `%LOCALAPPDATA%\Android\Sdk\platform-tools` to the user PATH.
- ADB server startup failed in the sandbox (`cannot connect to daemon`), so connected devices were not established.
- `gradle` is not globally installed; this is correct because this repository uses the wrapper.
- GitHub CLI (`gh`) is absent. Git HTTPS operations are still possible through Git credential manager; push authentication must be verified separately.
- `winget` exists as a WindowsApps shim but was inaccessible in the sandbox. No installation was necessary.
- `Get-ComputerInfo` CIM access was sandbox-blocked; `cmd /c ver` and the runtime architecture check supplied the OS facts.
- The duplicate Flutter PATH entries are ambiguous. Pin one SDK in terminal/profile configuration before Flutter maintenance.
- Android command-line tools were not present as a visible `cmdline-tools` directory; install “Android SDK Command-line Tools (latest)” in SDK Manager if CLI SDK administration is needed.

## Compatibility decision

AGP 9.4.1, Gradle 9.8.1, compile SDK 37, Build Tools 36.0.0, and JDK 17 bytecode were selected after lint identified the current stable patches. Target SDK remains 36 to match the verified 2026 Play requirement until API 37 behavior changes are tested. The project uses AGP built-in Kotlin and does not apply `org.jetbrains.kotlin.android`.
