# Origami Reference Finder 1.2

## User-facing changes

- Every solution opens with the full folding sequence, with each diagram next to its numbered instructions.
- Auto layout: one column on portrait phones, two on wider portrait windows, three in landscape, four in wide landscape windows.
- Select Auto or 1–4 columns. The setting persists; accessibility text sizes use one column for readability.
- Tap any diagram to enlarge it. Zoom, pan, and Back/Next remain available in the detail sheet.
- "Text instructions" explicitly identifies the optional text-only transcript.
- Done actions have an 82-point minimum width, 44-point height, horizontal padding and a capsule background.
- New user-supplied app icon, resized to 1024 × 1024 with an opaque RGB background, preserving its artwork.
- All interface copy remains English; original credits and sharing attribution retained.

## Engine audit

Both 2024 Mu-Tsun Tsai corrections were **already present in version 1.1**. No geometry-engine replacement was needed.

- Axiom-5 second-root omission: https://github.com/bugfolder/ReferenceFinder/commit/946b6eb15e5abcf563e30edcbee066ca69da03ce
- Boundary key-generation collision: https://github.com/bugfolder/ReferenceFinder/commit/a1d109132313fb67a3e27f30ef4b8aff0c118698

The app's ReferenceFinder.cpp matches Lang's current implementation aside from its modification header and two `this->` C++17 compatibility qualifiers. See ENGINE_AUDIT.json for pinned commits and hashes.

The web version was reviewed through its source and change log. Its newer scoring, caching and other features are separate developments; this app is not claimed to be identical to that web fork.

## Validation

Run `python3 scripts/test_engine.py`: 17 search cases plus two behavior-based upstream-fix regressions.

The axiom-5 regression asks the generated rank-3 database for the second root of moving the bottom midpoint onto the right edge through the top midpoint. Reverting the fix loses that exact line. The boundary regression checks that a top-edge reference does not collide with an adjacent bottom-edge bucket.

Native UI compilation and device layout must be checked with `ios-check` and then on iPhone/iPad. This Linux workspace has no Xcode or iOS simulator. No build or public App Store submission was started automatically.
