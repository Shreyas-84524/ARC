# Project Arc — AI Assistant Development Guide

> **Version:** 1.0.0 (Production Release)  
> **Document Purpose:** Guidelines, behavioral rules, architectural constraints, and prompt templates for future AI assistants working on Project Arc.

---

## 1. Non-Negotiable Architectural Rules

When assisting with code modifications or feature additions on Project Arc, future AI assistants MUST observe these core rules:

1. **Maintain Single-User Local-First Architecture**: Never introduce mandatory authentication screens or force blocking network requests before writing to Hive.
2. **Preserve Repository & Provider Boundaries**:
   - UI widgets must NEVER call `FirebaseFirestore.instance` or `Hive.box()` directly.
   - UI widgets MUST consume Riverpod providers (`ref.watch`, `ref.read`) and call methods on `StateNotifier` or Repositories.
3. **Never Swallow Errors or Delete Tests**: Fix underlying root causes instead of commenting out assertions or masking exceptions.
4. **Follow `AppColors` Design System**: Never hardcode custom hex color codes in feature widgets. Use `AppColors.accent`, `AppColors.darkCard`, etc.
5. **Always Run Static Analysis**: Before declaring a task complete, run `dart analyze` and `flutter test` to ensure 0 errors and 0 warnings.

---

## 2. Recommended Prompt Templates

### Prompt Template for Adding a Feature
```text
I want to add [Feature Description] to Project Arc.
Please follow architecture.md and design.md:
1. Update/create the data model with HiveType and toJson/fromJson.
2. Extend the feature repository for Hive persistence and sync queue writing.
3. Expose Riverpod StateNotifier provider in global_providers.dart.
4. Build UI screen/widget consuming Riverpod providers and using AppColors design system.
5. Run dart analyze and flutter test.
```

### Prompt Template for Fixing a Bug
```text
I encountered an error in Project Arc: [Insert Error Stack Trace]
Please inspect the codebase, trace the root cause without using silent try/catch fallbacks, fix the underlying contract broken in the repository or provider, and verify with dart analyze and flutter test.
```
