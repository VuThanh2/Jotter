# Jotter front end

A responsive Flutter notes workspace for the existing Jotter API. It opens in a clearly marked, session-only preview with six sample notes, so the interface can be explored without a running back end.

## Run

From `frontend/`, with Flutter installed:

```powershell
flutter pub get
flutter run -d chrome --web-port 3000
```

For Windows, use `flutter run -d windows`. The app also keeps the existing Android and iOS Flutter projects.

## Connect to an account

Click **Sign in**. The default API URL is `http://localhost:5080`, matching the existing .NET HTTP launch profile. Expand **Connection settings** in the dialog to change it; Docker normally exposes `http://localhost:8080`.

To set the initial URL at build or run time:

```powershell
flutter run -d chrome --web-port 3000 --dart-define=API_URL=http://localhost:8080
```

An existing seeded API provides `demo@jotter.app` / `Demo@123`; **Use demo credentials** fills those values without submitting them. A seeded protected note uses password `1234`. Preview data is separate from API data and is discarded on refresh, sign-in, or app exit. Access tokens stay in memory; reloading requires signing in again.

For a web build, the existing API CORS policy must allow the page origin. Its development configuration already allows all origins; an environment override can restrict it. `http://localhost:3000` matches the supplied `.env.example`. On Android emulators or a physical device, enter an API URL reachable from that device rather than its own `localhost`. HTTPS pages require an HTTPS API URL. Back-end code and configuration were not changed by this front-end implementation.

## Workspace

- Create and explicitly save plain-text notes; edit complete note content.
- Search note titles and content, with debounced server search when signed in.
- Browse all notes, pinned notes, notes shared with you, and labels.
- Switch between grid/list layouts and sort by last edit or title.
- Create labels, assign/remove labels, pin/unpin, and confirm permanent note deletion.
- Unlock protected notes through the existing API; respect read-only shared permissions.
- Retain an open draft when saving fails and confirm before discarding edits.
- Use Ctrl/Cmd+N for a new note, Ctrl/Cmd+F to focus search, Ctrl/Cmd+S to save in the editor, and Escape to close it with an unsaved-change guard. A browser may reserve some shortcuts.

Changes are saved with **Save note**. After a failed save, unprotected notes offer **Save a copy** to keep the draft in a new note; protected notes keep the draft open without creating an unprotected duplicate. Automatic conflict merging, background/offline sync, account registration, share management, attachment uploads, and AI features are outside this first workspace implementation. No preview notes are uploaded automatically.

## Validate

```powershell
flutter analyze
flutter test
flutter build web
```

Tests cover HTTP contracts and retries, version conflicts, permissions and locks, complete-content search, preview CRUD, note editing and draft recovery, sign-in validation, workspace interactions, and a 320px layout.

## Structure

- `lib/data/`: repository contract, API adapter, session preview, UUIDs.
- `lib/models/`: immutable notes, labels, accounts.
- `lib/screens/workspace_screen.dart`: navigation, async state, search and actions.
- `lib/widgets/`: note cards, note editor, account dialog.
- `lib/theme.dart`: shared paper, ink, and terracotta design tokens.
