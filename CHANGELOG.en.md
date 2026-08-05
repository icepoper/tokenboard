# Changelog

[简体中文](CHANGELOG.md) | [English](CHANGELOG.en.md)

This file records TokenBoard's release history and is the source of truth for the GitHub Releases notes (format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)).

## [Unreleased]

(none)

## [0.1.4] - 2026-08-05

### Added

- **Internationalization (Chinese / English)**: app UI, notifications and error messages fully support Chinese / English, following the system language
- **In-app language switch**: Settings -> Language (System / 中文 / English), takes effect after restarting
- **Bilingual README & GitHub Pages**: the landing page supports language switching; English mode uses the English screenshot

### Improved

- Removed the "Send test notification" button from release builds (kept in Debug builds)
- Settings now shows the version number dynamically (no longer hardcoded to 0.1.0)

### Quality

- 31/31 unit tests passing

## [0.1.3] - 2026-08-04

### Added

- **Last 7 days usage trend chart**: a day-by-day stacked bar chart (input / cache / output) below the add-on packs in the popover, consistent with the Qwen workbench "Usage details" metrics; click a bar to see the daily total, cache hit rate and output details
- Trend area states improved: loading / failed (with reason) / no data — three distinct states
- **Brand-new app icon**

### Fixed

- Compatible with the gateway's double-success markers (code==SUCCESS / success==true), fixing random "parse error" on the trend API
- Quota wording changed from "重置于" to "重置时间" (reset time), making the next reset time explicit

## [0.1.2] - 2026-08-04

### Improved

- **Dual-percentage menu bar capsule**: now shows `QW 5h% | 7d%` to tell the two windows apart at a glance, removing single-percentage ambiguity
- **Fixed progress bar semantics**: the popover progress bar previously filled by "used ratio" (a 1% bar at 99% remaining); now fills by "remaining ratio", consistent with the numbers and the official Qwen workbench

## [0.1.1] - 2026-08-04

### Fixed & Improved

- **Instant refresh**: after network changes (proxy reload, node switch, Wi-Fi switch, etc.) invalidate connections, clicking refresh now rebuilds the session and pulls the latest data immediately
- **Failure visibility**: on update failure, the menu bar shows "!" and the popover shows an orange error banner instead of silently showing stale data
- **More compact menu bar capsule**: status item width measured from content, placeholder width halved
- "Updated at" time now shows seconds

### Other

- Added 17 unit tests (FailureTracker / polling service / API parsing / data models)

---

## How to maintain

1. Before each release, record the changes under the `[Unreleased]` section at the top (categories: `Added` / `Improved` / `Fixed` / `Other`)
2. When releasing, rename `[Unreleased]` to `[version] - date` and create a fresh `[Unreleased]`
3. Copy the corresponding version's notes to the GitHub Release, **bilingual**: Chinese as the default body, English inside a `<details>` block that expands with one click (GitHub Releases has no automatic language switching; this is the closest to a "switch")
4. You can write them with `gh release create --notes-file` or `gh release edit --notes-file`
