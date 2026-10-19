# Installation guide

Status: **Completed for existing tooling; optional corrections remain**.

1. In Android Studio, open `C:\dev\ARC-Kotlin` and select the bundled JDK under Gradle settings. The command-line verification may use Temurin 17.
2. In SDK Manager verify Android SDK Platform 37, Android SDK Platform 36, Build Tools 36.0.0, Platform Tools, Emulator, and Command-line Tools (latest). Only the final item was not visible during audit.
3. Keep `local.properties` untracked. Android Studio can generate it; otherwise set `sdk.dir` to the local SDK path.
4. Build with `gradlew.bat`, never a machine-global Gradle installation.
5. Optional PATH correction: add the SDK `platform-tools` folder so `adb` resolves in new terminals. Do not globally change `JAVA_HOME` merely for this project.

The verified build uses Gradle 9.8.1, AGP 9.4.1, Kotlin/Compose compiler plugin 2.4.21, Compose BOM 2026.09.00, Google Maven and Maven Central, a version catalog, 2 GiB Gradle heap, parallel execution, and build caching. Dependency versions are centralized in `gradle/libs.versions.toml`.
