# Performance baseline

Status: **Partial**. No comparable device run was possible because ADB could not start in the sandbox; no measurements are fabricated.

Existing artifacts dated 2026-10-15 were found: Flutter debug APK 193,265,532 bytes (~184.3 MiB) and release APK 64,524,358 bytes (~61.5 MiB). The release is debug-signed, so it is not a production-store download-size measurement. The Phase 0 native debug APK is 11,758,178 bytes (~11.2 MiB), but it contains no features and is not a valid comparative result. Flutter/Dart version reporting hung during the audit and the source was not rebuilt because it is read-only and already contains user changes.

Cold/warm startup, steady-state memory, frame timing/jank, database latency, crash evidence, and background reliability are **Blocked** pending a working device/emulator and repeatable release-signed builds.

Phase 1 protocol: same physical device/OS and seeded dataset; airplane/network conditions recorded; release/profile builds only; at least 10 cold and 10 warm starts; median and p95; Macrobenchmark startup/frame metrics; `dumpsys meminfo`; comparable universal APK and Play download estimates; Room query benchmarks; notification/sync endurance tests. Goals are ≥20% faster cold start, ≥15% smaller comparable download, ≥10% lower steady-state memory, no UI regression, complete tested data preservation, and no critical functional regression. These are evaluation targets, not promises.
