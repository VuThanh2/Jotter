# Jotter

Jotter is a Flutter notes client and ASP.NET Core API backed by PostgreSQL.
The same Flutter project contains Web, Android, iOS and Windows platform
directories. Web and Android releases must be built and tested for the target
environment; their presence in the repository is not a release guarantee.

## Requirements

- Flutter 3.47.5 and Dart 3.13.4 were used for the current local checks;
  pubspec.yaml requires Dart 3.13 or later in the 3.x series.
- Docker with Compose for the API and database, or .NET 10 SDK and PostgreSQL
  for running the backend directly.
- Android SDK and a device/emulator for Android builds and testing.

## Configure and run

From the repository root, copy .env.example to .env and set a random
Jwt__Secret of at least 32 characters and a PostgreSQL password. Never commit
.env. Configure Email__Host, Email__From and the other email settings to send
activation and reset codes; without SMTP the development transport logs them.
Configure Llm__ApiKey for AI features. Set the allowed web origin in CORS.

    docker compose up --build

The API listens on http://localhost:8080 by default. In another terminal:

    cd frontend
    flutter pub get
    flutter run -d edge --web-port 3000 --dart-define=API_URL=http://localhost:8080

For Android, use a backend URL reachable from the device (for an Android
emulator, the host is commonly 10.0.2.2 instead of localhost). HTTPS-hosted
Web builds require an HTTPS API and a matching CORS origin. Pass the public
API address using --dart-define=API_URL=https://your-api.example at build time.
The repository does not specify a verified public deployment URL or APK.

## Build and test

From frontend/:

    flutter analyze
    dart format --output=none --set-exit-if-changed lib test integration_test tool
    flutter test
    flutter test -d windows integration_test/offline_note_flow_test.dart
    flutter build web --dart-define=API_URL=https://your-api.example
    flutter build apk --release --dart-define=API_URL=https://your-api.example

The integration scenario uses a simulated API and in-memory storage; also test
offline/reconnect behavior with real persistent storage and a deployed API on
Web and Android. Backend tests can be run with `dotnet test backend/Jotter.slnx`
from the root; integration tests may need PostgreSQL and other test services.

## Architecture and sync

Flutter routes use go_router, screens use Bloc/Cubit, and repositories provide
API and local data access. The API separates domain, application,
infrastructure and HTTP layers. The client stores account-scoped snapshots and
an outbox using shared_preferences; the session uses flutter_secure_storage.
Owned unprotected notes can be cached and queued offline. Protected and shared
note bodies are not persisted in the workspace cache. Queued writes retain
idempotency keys for retries. Version conflicts surface to the user; the sync
dialog can preserve an eligible draft as a linked conflict copy, and the editor
offers choices when a newer version is detected. Explicitly choosing "Keep
mine" can overwrite the newer server version. Validate conflict handling on
two devices before relying on it for a release.

The project also uses http, web_socket_channel, image_picker, file_selector,
video_player and PostgreSQL. SMTP, AI credentials, deployment URLs, reviewer
accounts, release APK and platform-specific release limitations must be set
and verified for the actual submission environment.
