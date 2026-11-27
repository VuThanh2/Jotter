# Jotter

A cross-platform note-taking app for **Web** and **Android**, built from a single Flutter codebase with a custom ASP.NET Core backend.

| | |
| --- | --- |
| **Web app** | `<web-url>` |
| **API** | `<api-url>` (hosted on Railway) |
| **Android APK** | `<apk-file-name>` (package `com.tdtu.jotter`) |
| **Supported platforms** | Web (Chrome, Edge, Firefox) · Android |

## Overview

### Features

- **Accounts** – sign up, email activation, password reset via OTP, profile & avatar, theme and display preferences.
- **Notes** – auto-save, pin, labels, instant search, image/video/file attachments.
- **Protection** – lock individual notes with their own password.
- **Sharing** – share notes as *Read-only* or *Edit*, with real-time collaboration.
- **Offline-first** – keep working without a connection; changes sync when back online.
- **AI** – note summaries and Q&A across your notes with source citations.

### Tech Stack

| Layer | Technology |
| --- | --- |
| Frontend | Flutter 3.47.0 · Dart SDK 3.13.0 |
| Backend | ASP.NET Core (.NET 10) · EF Core · ASP.NET Core Identity + JWT |
| Database | PostgreSQL 17 |
| Realtime | WebSocket |
| AI | Google Gemini |

## Architecture

**Backend** – a layered monolith (Domain → Application → Infrastructure → API). All writes go through REST; the WebSocket channel only signals changes.

**Frontend** – a module-based structure, with one module per feature. **State management uses `flutter_bloc`** (Cubit/Bloc) on every screen. The UI talks to Cubits, and Cubits talk to repositories.

**Local storage & sync**

- The session is stored with `flutter_secure_storage`. Notes and pending offline changes (the *outbox*) are stored with `shared_preferences`, separately for each account. Signing out wipes that account's data.
- Content of locked notes and of notes shared with you is never stored on the device.
- When the app is back online, it pushes the outbox in order and then pulls server changes.
- **Conflict strategy:** if an offline edit is based on an outdated version, the server keeps its own version. The local edit is shown in *Sync status*, where you can save it as a new note named `<title> (conflict copy)`, so no edit is lost.

### Key Packages

`flutter_bloc` · `go_router` · `http` · `web_socket_channel` · `shared_preferences` · `flutter_secure_storage` · `image_picker` · `file_selector` · `video_player`

## Folder Structure

```
Jotter/
├── backend/
│   ├── src/
│   │   ├── Jotter.Domain/          # Entities, value objects, repository interfaces
│   │   ├── Jotter.Application/     # Use cases (commands/queries), validation
│   │   ├── Jotter.Infrastructure/  # EF Core, Identity, email, AI, storage, WebSocket
│   │   └── Jotter.Api/             # Controllers, middleware, Program.cs
│   ├── tests/                      # Unit & integration tests
│   └── Dockerfile
├── frontend/
│   ├── lib/
│   │   ├── app/                    # App entry, routing, theme, layout shell
│   │   ├── modules/                # Feature modules
│   │   ├── data/                   # Repositories, API clients, offline sync
│   │   ├── models/                 # Data models
│   │   └── shared/                 # Shared widgets & utilities
│   ├── test/                       # Unit & widget tests
│   └── integration_test/
├── docker-compose.yml              # postgres + api
└── .env.example                    # Environment variable template
```

## Getting Started

### Prerequisites

- Flutter 3.47+ (Dart 3.13+)
- .NET SDK 10
- Docker with Docker Compose v2
- Android SDK (only for running or building on Android)

### 1. Configure environment

```bash
cp .env.example .env
```

Then fill in `.env`:

| Variable | Description |
| --- | --- |
| `Jwt__Secret` | **Required.** At least 32 random characters (e.g. `openssl rand -base64 48`). |
| `Email__*` | SMTP settings. If `Email__Host` is empty, activation and OTP codes are only written to the API log. |
| `Llm__ApiKey` | Gemini API key. Without it, the AI features are unavailable and everything else still works. |

### 2. Run the backend

```bash
docker compose up -d --build
```

The API runs at `http://localhost:8080` and sets up the database and demo data on startup. To check that it is up, open `http://localhost:8080/health`. Swagger UI is at `/swagger` in Development.

<details>
<summary>Alternative: run the API with <code>dotnet run</code></summary>

```bash
docker compose up -d postgres
cd backend
# set ConnectionStrings__Default and Jwt__Secret (and optionally Llm__ApiKey) as environment variables
dotnet run --project src/Jotter.Api --launch-profile http
```

The API then runs at `http://localhost:5080`, which is the app's default `API_URL`.

</details>

### 3. Run the app

```bash
cd frontend
flutter pub get

# Web
flutter run -d chrome --web-port 3000 --dart-define=API_URL=http://localhost:8080

# Android emulator (10.0.2.2 points to the host machine's localhost)
flutter run -d <device-id> --dart-define=API_URL=http://10.0.2.2:8080
```

### Demo accounts

| Email | Password |
| --- | --- |
| `demo@jotter.app` | `Demo@123` |
| `friend@jotter.app` | `Demo@123` |

The demo account already has labels, pinned, shared and locked notes. The locked note *"Ghi chú bí mật"* uses the password `1234`.

## Testing

```bash
# Frontend
cd frontend
flutter test
flutter test integration_test -d <device-id>

# Backend (requires Docker to be running)
cd ../backend
dotnet test
```

## Build

```bash
cd frontend
flutter build web --release --dart-define=API_URL=https://<api-domain>
flutter build apk --release --dart-define=API_URL=https://<api-domain>
```

The outputs are `frontend/build/web/` and `frontend/build/app/outputs/flutter-apk/app-release.apk`.

## Known Limitations

- **Both platforms:** attachments, locked notes, sharing, real-time collaboration and AI require a connection.
- **Web:** the offline cache lives in `localStorage`, so its size is limited and it is lost when site data is cleared. There is no direct camera access; media is picked with the browser's file picker.
- **Android:** the release APK is signed with the debug keystore.