# Git setup

Status: **Completed locally; remote push recorded in the final report**.

Preflight found `C:\dev\ARC-Kotlin` existed but was empty and was not a Git repository. `git ls-remote https://github.com/Shreyas-84524/ARC-Kotlin.git` returned no refs, confirming an empty reachable repository. The repository is initialized on `main` with `origin` set to that URL.

The `.gitignore` excludes Gradle/build output, IDE state, `local.properties`, signing material, Firebase configuration, service accounts, environment files, database dumps, packages, and profiling artifacts. `google-services.json` is intentionally absent.

Before every push: inspect `git status`, `git diff --cached`, search tracked/staged content for token/private-key patterns, and confirm the Flutter baseline in `C:\dev\ARC` is unchanged. Never force-push.
