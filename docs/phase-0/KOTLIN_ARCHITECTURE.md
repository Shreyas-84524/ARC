# Kotlin architecture

Use a single-activity Compose app and feature-oriented packages. Each feature owns presentation (screen, immutable UI state, ViewModel), domain (models/use cases only when logic merits it), and data (repository/source/mappers). Core packages provide database, Firebase, crypto, notifications, design system, and testing utilities.

Keep one `app` module initially. Extract modules only when ownership, build isolation, or dependency direction is demonstrated; likely later candidates are `core:model`, `core:database`, `core:firebase`, `core:designsystem`, and feature modules. UI observes `StateFlow`; repositories expose suspend functions/Flow; dispatchers and clocks are injectable. Room is the structured local source of truth, Firestore is remote synchronization, and pending mutations are explicit durable records. Data/domain models remain separate at migration boundaries.

The production namespace is `com.arc.arc`; debug suffix `.native.dev` prevents collision. Production ID and signing are enabled only for an approved upgrade/migration build.
