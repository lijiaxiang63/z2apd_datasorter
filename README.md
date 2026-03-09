# z2apd_datasorter

> **For internal use only.** This tool is not intended for public distribution.

Flutter desktop app for converting DICOM folders to BIDS-style NIfTI outputs using `dcm2niix`, with optional post-conversion ZIP archiving.

## Version
- Current app version: `1.1.2+1`
- Version constants used by the UI live in `lib/app_info.dart`
- Pub version metadata lives in `pubspec.yaml`

## Changelog

### v1.1.2
- Renamed app to `z2apd_datasorter`
- Added self-update: app checks GitHub Releases on startup and can download and install updates in-place
- Added "Check for Updates..." item in the macOS application menu
- Added update tests for `UpdateService` and `UpdateProvider`

### v1.1.1
- Added CT modality support
- Fallback patient ID from HospitalID field
- StudyDescription fallback for session naming

### v1.1.0
- Initial public release

## What This App Does
- Accepts a root folder by drag-and-drop or folder picker.
- Detects DICOM folders with `dcm2niix` quick scans.
- Converts each detected folder to NIfTI (`.nii.gz`) and JSON sidecars.
- Builds BIDS-like output paths using patient/date metadata.
- Supports rule-based mapping from SeriesDescription patterns to modalities.
- Optionally archives each processed source folder to `.zip` and deletes the original folder.

## Conversion Behavior
- Patient ID is extracted from DICOM `PatientName` using `:bah:` as delimiter.
- Session is derived from `SeriesDate` (fallback: `AcquisitionDateTime`).
- If no rules are configured, all series are converted to `anat/T1w`.
- If rules are configured:
- SeriesDescription is matched with case-insensitive glob patterns (`*`, `?`).
- Matched series are mapped to modality/subfolder (`anat`, `func`, `dwi`).
- Unmatched series are skipped when `only matched` is enabled, otherwise forced to `T1w`.

## Runtime Dependencies
- `dcm2niix` binary:
- macOS debug path: `dependency/dcm2niix`
- Windows debug path: `dependency/dcm2niix.exe`
- 7-Zip binary for archive mode:
- macOS debug path: `dependency/7zz`
- Windows debug path: `dependency/7za.exe`
- Rules are persisted as JSON in the app support directory (`apd_modality_rules.json`).

## Local Development
1. Install Flutter SDK (Dart 3.11+ as defined in `pubspec.yaml`).
2. Ensure binaries exist in the local `dependency/` directory.
3. Install packages:

```bash
flutter pub get
```

4. Run app:

```bash
flutter run -d macos
```

Supported app targets in this repository are desktop platforms (`macos`, `windows`, `linux`).

5. Run tests:

```bash
flutter test
```

## Key Source Files
- Entry point: `lib/main.dart`
- Main screen: `lib/screens/home_screen.dart`
- Conversion orchestration: `lib/providers/conversion_provider.dart`
- DICOM execution wrapper: `lib/services/dcm2niix_service.dart`
- BIDS organization logic: `lib/services/bids_organizer.dart`
- Binary path resolution: `lib/services/binary_locator.dart`
- Rules persistence: `lib/services/rules_persistence.dart`

## Notes
- Linux runtime lookup for bundled binaries is not implemented in `BinaryLocator` (currently macOS/Windows only).
- The UI is built around local filesystem workflows (desktop-first behavior).
