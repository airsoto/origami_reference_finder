import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("Quick start") {
                    Text("1. Enter X and Y, or tap the paper to place a point. For a line, enter two distinct points.")
                    Text("2. Use the default unit square or open Paper & search to set a rectangle. Coordinates use the same units as the paper.")
                    Text("3. Tap Find folds, choose a solution, and follow the large diagrams using Back and Next. Expand or zoom a diagram to inspect it.")
                    Text("Expressions include 1/3, sqrt(2)/2, sin(deg2rad(30)), and (1+sqrt(5))/4. The origin is the bottom-left corner. The live paper preview supports numbers, fractions, and sqrt(2) expressions.")
                    Text("Search is finite and may return an approximation. Exact or globally optimal constructions are not guaranteed. Balanced search uses rank 3; choose Deeper (rank 4) to explore more constructions.")
                }
                Section("Credits") {
                    credit("Robert J. Lang", "Creator of ReferenceFinder and author of the original geometry and search engine.")
                    credit("Carlos A. Furuti", "Mathematical expression parser in the original engine.")
                    credit("Jérôme Laheurte", "Author of the historical ReferenceFinder 4 iPhone port (2009). His code was studied as a reference; this interface was newly written.")
                    credit("Mu-Tsun Tsai", "Credited for the engine bug fix acknowledged by Robert J. Lang in his 2024 update.")
                    Text("Uploaded for iOS by Ángel Soto").font(.headline)
                    credit("HuxleyBerry", "Web repository reviewed as a technical reference. Its code is not included in this app.")
                }
                Section("Sources & license") {
                    Link("ReferenceFinder · Robert J. Lang", destination: URL(string: "https://langorigami.com/article/referencefinder/")!)
                    Link("Original engine source", destination: URL(string: "https://github.com/bugfolder/ReferenceFinder")!)
                    Link("HuxleyBerry repository", destination: URL(string: "https://github.com/HuxleyBerry/origami-reference-finder")!)
                    NavigationLink("GNU GPLv2 license") { LicenseView() }
                    Text("This project includes GPLv2 software and preserves its copyright notices. Provided without warranty. This independent version does not imply endorsement by the original authors.")
                        .font(.footnote)
                }
                Section("Privacy") {
                    Text("Searches and diagrams are calculated on your device. Recent searches are stored locally and can be cleared from the home screen. No accounts, ads, analytics, or developer-operated servers. Sharing and external links are optional.")
                }
                Section { Text("Origami Reference Finder 1.1 · Uploaded for iOS by Ángel Soto").font(.footnote) }
            }.navigationTitle("Help & credits")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func credit(_ name: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name).font(.headline)
            Text(description).font(.subheadline).foregroundStyle(.secondary)
        }.padding(.vertical, 3)
    }
}
struct LicenseView: View {
    private var license: String {
        guard let url = Bundle.main.url(forResource: "LICENSE", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "Unable to load the license. See LICENSE.txt in the source repository."
        }
        return text
    }
    var body: some View {
        ScrollView { Text(license).font(.footnote.monospaced()).textSelection(.enabled).padding() }
            .navigationTitle("GNU GPLv2")
    }
}
