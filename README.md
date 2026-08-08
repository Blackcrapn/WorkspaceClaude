# WorkspaceClaude — Focus Flow

Offline-first Flutter task tracker for Android. Material 3, light/dark theme,
priority chips, swipe-to-delete, local persistence via `shared_preferences`.

## Get the APK

Every push to `main` runs the **Build Android APK** workflow, which:

1. Installs Flutter + JDK 17
2. Generates the `android/` platform folder (`flutter create --platforms=android`)
3. Builds `flutter build apk --release`
4. Uploads the APK as a workflow artifact **and** publishes it as a GitHub Release (`build-<run number>`)

Download it from the **Releases** page or from the run's **Artifacts** section.
You can also trigger it manually: Actions → Build Android APK → Run workflow.

## Run locally

```bash
flutter create . --platforms=android --project-name focus_flow --org com.blackcrapn
flutter pub get
flutter run
```

The `android/` folder is gitignored on purpose — CI regenerates it, so the repo
stays clean and there's nothing to keep in sync.
