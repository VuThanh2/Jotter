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

## Workspace and note tools

- Create and explicitly save plain-text notes; edit complete note content.
- Search note titles and content, with debounced server search when signed in.
- Browse all notes, pinned notes, notes shared with you, and labels.
- Switch between grid/list layouts and sort by last edit or title.
- Create, rename, and delete labels; assign/remove labels, pin/unpin, and confirm permanent note deletion.
- Open a note card's menu for **Files**, **Sharing**, **Protection**, and **Summary**. Upload, preview, download, or remove attachments; invite people and manage their permissions; enable/change/remove a note password or relock a note; generate a streaming AI summary or read its saved summary.
- Unlock protected notes through the existing API; respect read-only shared permissions and live access changes.
- Use **Ask your notes** in the sidebar for AI answers with citations that open the source notes.
- Retain an open draft when saving fails and confirm before discarding edits.
- Use Ctrl/Cmd+N for a new note, Ctrl/Cmd+F to focus search, Ctrl/Cmd+S to save in the editor, and Escape to close it with an unsaved-change guard. A browser may reserve some shortcuts.

Changes are saved with **Save note**. Conflicts offer comparison with the current server version and a linked copy to preserve an unprotected draft. Protected drafts remain open for recovery. No preview notes are uploaded automatically.

## Accounts and preferences

The sign-in dialog also offers **Create an account** and **Forgot password?**, including reset-code verification and a new password. An activation banner opens email-code verification and resend controls for an inactive account.

Open the account menu, then **Account settings** for your display name and photo, saved theme/font/default note color/grid-or-list preferences, and password changes. Light, dark, and system themes apply to the workspace and dialogs. Sign out is also in the account menu.

Email activation/recovery and AI use the existing back-end services. They require the API's email configuration and `Llm:ApiKey` respectively; this implementation does not change those settings.

## Offline sync and live updates

The sync indicator at the bottom of the sidebar opens pending changes, connection status, retry/discard controls, and conflict recovery. Signed-in users can keep editing their own unprotected notes during a network interruption. Cached notes and queued changes persist per account and synchronize when the connection returns, using the existing incremental sync API. Protected and shared note bodies, unlock credentials, and access tokens are never persisted.

After a page reload, sign in to the same account to restore its local cache and pending changes. Offline sign-in is not supported. Signing out clears that account's local cache and warns if changes remain pending. A draft that becomes protected while queued is kept only in memory, with a recovery warning.

WebSocket updates show editor presence, changed versions, permission changes, and revoked access. The editor also polls the note version when the live connection is unavailable. Remote edits prompt review without replacing your unsaved text.

## Validate

```powershell
flutter analyze
flutter test
flutter build web
```

Tests cover HTTP contracts, account flows, preferences, attachments/sharing/protection/AI, offline replay and conflict recovery, a local WebSocket connection, live access invalidation, note editing, workspace interactions, and narrow layouts. These use mocked API responses plus a local WebSocket server; a configured live API is still needed to verify email delivery and AI output.

To render representative widget previews using mocked data on Windows:

```powershell
flutter test tool/capture_previews.dart
```

The script writes account settings, mobile sharing, AI answers, and a dark workspace to `build/previews/`.

## Structure

- `lib/data/`: API adapters, session preview, local storage, queued changes, sync and realtime.
- `lib/models/`: notes, labels, accounts, preferences, note tools and sync status.
- `lib/screens/workspace_screen.dart`: navigation, async state, search and actions.
- `lib/widgets/`: note cards/editor, account and note-tool dialogs, AI answers and sync recovery.
- `lib/platform/`: file-save integration.
- `lib/theme.dart`: shared light/dark paper, ink, and terracotta design tokens.
