# HALO architecture (sahyog only)

This structure lives on **`sahyog`**. Do not merge it onto `developer`, `main`, or other branches until sahyog is ready.

## Decision

Use **light Clean Architecture + Riverpod**, not a full rewrite.

- Max **3 folder levels**: `features/auth/domain`
- **Firebase only in `data/`**
- **One Riverpod notifier per feature** (not per widget)
- **New code** follows this layout. **Old screens stay** until that feature is migrated
- **Login method ≠ account type.** Type is `aspirant` | `guru` | `wellness`, chosen once
- Do not add a file unless a live screen imports it in the same change

```text
lib/
  core/                 # session, theme, splash
  widgets/              # shared UI (buttons, etc.)
  features/
    auth/
      domain/           # repository interface + mappers
      data/             # Firebase Auth + Firestore
      presentation/     # providers, gate, pages
```

Routing: `sessionProvider` → logged out / pick type / home (`StartupRouter` still owns interests).

## Order of work

1. Auth + session (current)
2. Profile (shared widgets, then repository)
3. Feed → Explore → post/upload
4. Chat / stories / booking
5. Video pipeline last
