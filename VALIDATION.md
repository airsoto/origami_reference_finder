# Version 1.1 validation — October 29, 2026

## Completed locally

- C++17 build of the engine and mobile SVG adapter.
- All 17 existing regression cases pass, including exact thirds, line references, invalid expressions, rectangular paper, rank changes and database rebuilds.
- Every generated diagram parsed as XML and checked for non-finite values.
- Representative folding diagrams rendered with MuPDF and visually inspected for contrast and label legibility.
- Xcode project regenerated with version 1.1 and English development language.
- Property lists, shared scheme XML, YAML and source checksums validated.

## Requires Codemagic / iPhone

- Compile the refreshed SwiftUI interface against the Apple SDK with ios-check. Xcode and swiftc are not installed in this Linux workspace.
- Check numeric and math keyboards, X/Y swapping, paper taps, fractions, rectangle sizing, small screens, landscape and Dynamic Type.
- Check step navigation, expansion, zoom/pan, cancellation, repeated-search caching, sharing and retained history.
- Run ios-release for signing and upload to TestFlight. This update did not trigger a build or submit an App Store review.

Earlier version 1.0 compiled and signed successfully in the user's Codemagic account; that does not validate the new SwiftUI changes.
