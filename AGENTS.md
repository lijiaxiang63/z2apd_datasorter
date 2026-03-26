# AGENTS.md — z2apd_datasorter

## Project Overview

Flutter desktop app (macOS/Windows) that converts DICOM folders to BIDS-style NIfTI outputs using `dcm2niix`, with optional post-conversion ZIP archiving. **Internal use only.**

## Tech Stack

- **Language:** Dart 3.11+, Flutter SDK
- **State management:** `provider` (ChangeNotifier pattern)
- **Platforms:** macOS, Windows (Linux lookup not implemented)
- **External binaries:** `dcm2niix`, `7zz`/`7za.exe` (bundled in `dependency/`)
- **Key packages:** `path_provider`, `file_picker`, `desktop_drop`, `http`, `archive`, `pub_semver`

## Architecture

```
lib/
├── main.dart                  # App entry point, MultiProvider setup
├── app_info.dart              # Version constants, repo metadata
├── models/
│   ├── conversion_result.dart # ConversionResult + ConversionStatus enum
│   ├── conversion_target.dart # ConversionTarget + ConversionPlan
│   ├── dicom_series_meta.dart # Typed wrapper over raw DICOM JSON metadata
│   ├── modality_constants.dart# Modality choices and subfolder mapping
│   └── modality_rule.dart     # ModalityRule model with JSON serialization
├── providers/
│   ├── conversion_provider.dart # Conversion orchestration state + archive logic
│   ├── rules_provider.dart      # Rule CRUD + persistence
│   └── update_provider.dart     # Self-update state machine
├── services/
│   ├── archive_service.dart       # 7-Zip folder archiving
│   ├── bids_filename_builder.dart # BIDS filename stem construction
│   ├── bids_organizer.dart        # Main DICOM→BIDS conversion orchestrator
│   ├── binary_locator.dart        # Platform binary path resolution (debug/release)
│   ├── dcm2niix_service.dart      # dcm2niix process wrapper
│   ├── input_layout_resolver.dart # Resolves input folder structure to conversion plan
│   ├── modality_guesser.dart      # Auto-guess modality from SeriesDescription
│   ├── modality_rule_matcher.dart # fnmatch glob matching + rule lookup
│   ├── patient_id_parser.dart     # PatientID extraction from DICOM fields / paths
│   ├── rules_persistence.dart     # JSON file persistence for rules
│   └── update_service.dart        # GitHub release check, download, install
└── widgets/
    ├── action_bar.dart          # Convert/Clear/Archive controls
    ├── add_rule_dialog.dart     # Dialog for adding a single rule
    ├── drop_zone.dart           # Drag-and-drop folder target
    ├── log_panel.dart           # Scrollable conversion log output
    ├── path_selector.dart       # Folder path text field + browse button
    ├── progress_section.dart    # Progress bar + current folder label
    ├── rules_panel.dart         # Rules table with add/remove/scan
    ├── scan_series_dialog.dart  # Discovered series dialog with bulk select
    └── update_banner.dart       # Self-update notification banner
```

## Key Conventions

- **No-rules path:** All DICOM series convert to `anat/T1w`.
- **Rules path:** Series matched via case-insensitive glob patterns (`*`, `?`) are mapped to modality/subfolder. Unmatched series are skipped or forced to `T1w` based on `onlyMatched`.
- **PET path:** PatientID comes from folder path (not DICOM fields). Uses `trc-<tracer>` in filenames.
- **Session:** Derived from `SeriesDate` (YYYYMMDD → YYYYMM by stripping last 2 chars).
- **PatientID delimiter:** Non-PET IDs use `:bah:` as separator in `PatientName`, with fallback to `PatientID` field.

## Development Commands

```bash
flutter pub get          # Install dependencies
flutter run -d macos     # Run on macOS
flutter run -d windows   # Run on Windows
flutter test             # Run all tests
flutter analyze          # Static analysis
```

## Testing

Tests are in `test/`. They use `flutter_test` and mock services by subclassing (e.g., `FakeDcm2niixService`). No test mocking frameworks are used.

Key test files:
- `pet_naming_test.dart` — PET ID extraction, tracer parsing, filename building, series filtering
- `input_layout_resolver_test.dart` — Folder structure → conversion plan mapping
- `dcm2niix_service_layout_test.dart` — DICOM folder collection with nested layouts
- `dcm2niix_probe_test.dart` — isDicomFolder with fake binary script
- `update_test.dart` — UpdateService + UpdateProvider with mock HTTP client
- `scan_series_dialog_test.dart` — bulkSelectionState logic
- `widget_test.dart` — Basic app rendering

## Important Notes

- `bids_organizer.dart` re-exports functions from `modality_rule_matcher.dart` and `bids_filename_builder.dart` for backward compatibility with existing test imports.
- `BinaryLocator` uses an `assert`-based debug mode check (not `kDebugMode`) because it runs outside widget context.
- The `_getProjectRoot()` method walks up directories looking for `pubspec.yaml` — this is intentional for debug-mode binary resolution.
- `update_service.dart` calls `exit(0)` during update installation — this is by design.
- Temp directories are always cleaned up in `finally` blocks to avoid leaks.
