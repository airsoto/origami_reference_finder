import SwiftUI
import WebKit

private let ink = Color(red: 0.03, green: 0.43, blue: 0.48)
private let foldColor = Color(red: 0.88, green: 0.29, blue: 0.20)

struct ContentView: View {
    @StateObject private var model = SearchModel()
    @State private var showingAbout = false
    @State private var showingCP = false
    @State private var advanced = false
    @State private var expressions = false
    @FocusState private var field: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Reference type", selection: $model.input.line) {
                            Text("Point").tag(false)
                            Text("Line").tag(true)
                        }.pickerStyle(.segmented)
                        PaperPreview(input: $model.input)
                            .frame(height: 260)
                        HStack {
                            Label(model.input.line ? "First point" : "Target point", systemImage: "scope")
                                .font(.headline)
                            Spacer()
                            Button {
                                let previousX = model.input.x
                                model.input.x = model.input.y
                                model.input.y = previousX
                            } label: {
                                Image(systemName: "arrow.left.arrow.right")
                            }.accessibilityLabel("Swap X and Y")
                        }
                        coordinates(x: $model.input.x, y: $model.input.y, prefix: "first")
                        if model.input.line {
                            Text("Second point").font(.headline)
                            coordinates(x: $model.input.x2, y: $model.input.y2, prefix: "second")
                        }
                        if previewNumber(model.input.x) == nil || previewNumber(model.input.y) == nil {
                            Text("Live preview uses numbers and simple fractions. Full math expressions are evaluated when you search.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        HStack {
                            Toggle("Math keyboard", isOn: $expressions).font(.caption)
                                .onChange(of: expressions) { _ in field = nil }
                        }
                        Text("Tap the paper to place \(model.input.line ? "the first point" : "your point"). Origin: bottom left.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.card().disabled(model.isSearching)
                    VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                dimension("Width", text: $model.input.width)
                                dimension("Height", text: $model.input.height)
                            }
                            Picker("Search depth", selection: $model.input.rank) {
                                Text("Quick").tag(2)
                                Text("Balanced").tag(3)
                                Text("Deeper").tag(4)
                            }.pickerStyle(.segmented)
                            Text("Balanced is faster to start. Deeper explores more constructions. Rank measures construction complexity, not the number of diagrams.")
                                .font(.caption).foregroundStyle(.secondary)
                    }.card().disabled(model.isSearching)
                    if model.isSearching {
                        VStack(spacing: 12) {
                            ProgressView().tint(ink)
                            Text("Finding your folds…").font(.headline)
                            Text("The first search builds a local reference library.")
                                .font(.caption).foregroundStyle(.secondary)
                            Button("Cancel search", role: .cancel) { model.cancel() }
                        }.frame(maxWidth: .infinity).card()
                    } else {
                        Button { field = nil; model.search() } label: {
                            Label("Find folds", systemImage: "sparkle.magnifyingglass")
                                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                        }.buttonStyle(.borderedProminent).tint(ink).controlSize(.large)
                    }
                    if let error = model.error {
                        Label(error, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red).font(.subheadline).card()
                    }
                    if let response = model.response, let solutions = response.solutions {
                        results(solutions, response: response)
                    }
                    if !model.history.isEmpty {
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(Array(model.history.enumerated()), id: \.offset) { _, request in
                                    Button {
                                        field = nil; model.input = request
                                        model.response = nil; model.error = nil
                                    } label: {
                                        HStack {
                                            Image(systemName: request.line ? "line.diagonal" : "scope")
                                            Text(request.summary).font(.subheadline)
                                            Spacer()
                                            Image(systemName: "arrow.up.left").font(.caption)
                                        }.frame(minHeight: 32)
                                    }
                                }
                                Button("Clear history", role: .destructive) { model.clearHistory() }
                            }.padding(.top, 14)
                        } label: {
                            Label("Recent searches", systemImage: "clock").font(.subheadline.bold())
                        }.card().disabled(model.isSearching)
                    }
                    Text("ReferenceFinder by Robert J. Lang\nUploaded for iOS by Ángel Soto")
                        .font(.caption2).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                }.padding(12).frame(maxWidth: 650).frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Reference Finder").navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingCP = true } label: {
                        HStack(spacing: 5) { Image(systemName: "square.dashed.inset.filled"); Text("CP Points").font(.subheadline.bold()) }.fixedSize(horizontal: true, vertical: false)
                    }
                    .accessibilityLabel("Points in CP: import and mark a crease pattern")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAbout = true } label: { Image(systemName: "info.circle") }
                        .accessibilityLabel("Help and credits")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if !expressions {
                        Button("/") { appendToFocused("/") }.accessibilityLabel("Insert fraction bar")
                        Button("(") { appendToFocused("(") }
                        Button(")") { appendToFocused(")") }
                        Button("√2") { appendToFocused("sqrt(2)") }
                    }
                    Spacer()
                    DoneButton { field = nil }
                }
            }.sheet(isPresented: $showingAbout) { AboutView() }
             .sheet(isPresented: $showingCP) { CPPointsView() }
             .tint(ink)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Find your folds").font(.system(size: 23, weight: .bold, design: .rounded))
            Text("Enter a reference and choose your search depth.")
                .font(.subheadline).foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine)
    }

    private func coordinates(x: Binding<String>, y: Binding<String>, prefix: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            coordinate("X", text: x, key: prefix + "X", color: ink)
            coordinate("Y", text: y, key: prefix + "Y", color: foldColor)
        }
    }

    private func coordinate(_ name: String, text: Binding<String>, key: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(name).font(.headline).foregroundStyle(color)
                Text(name == "X" ? "across" : "up").font(.caption).foregroundStyle(.secondary)
            }
            TextField("0…1", text: text)
                .font(.system(size: 25, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.6).lineLimit(1)
                .keyboardType(expressions ? .asciiCapable : .decimalPad)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($field, equals: key).id(expressions)
                .accessibilityLabel("\(key.hasPrefix("second") ? "Second point" : "Target") \(name) coordinate")
            HStack(spacing: 0) {
                ForEach(["0", "1/3", "1/2", "1"], id: \.self) { value in
                    Button { text.wrappedValue = value } label: {
                        Text(value).font(.caption2.bold()).frame(maxWidth: .infinity, minHeight: 34)
                    }.buttonStyle(.plain).foregroundStyle(color)
                }
            }
        }.padding(12).background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    private func dimension(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, text: text).keyboardType(.decimalPad)
                .focused($field, equals: title).textFieldStyle(.roundedBorder)
                .accessibilityLabel("Paper \(title)")
        }
    }

    private func appendToFocused(_ value: String) {
        switch field {
        case "firstX": model.input.x += value
        case "firstY": model.input.y += value
        case "secondX": model.input.x2 += value
        case "secondY": model.input.y2 += value
        case "Width": model.input.width += value
        case "Height": model.input.height += value
        default: break
        }
    }

    private func results(_ solutions: [FoldSolution], response: SearchResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your folding routes").font(.title2.bold())
            if let request = model.lastInput { Text(request.summary).font(.subheadline).foregroundStyle(.secondary) }
            if solutions.isEmpty { Text("No solutions found. Try a deeper search.") }
            ForEach(Array(solutions.enumerated()), id: \.offset) { index, solution in
                NavigationLink {
                    SolutionView(solution: solution, number: index + 1, input: model.lastInput ?? model.input)
                } label: {
                    HStack(spacing: 14) {
                        Text(String(index + 1)).font(.title3.bold())
                            .frame(width: 44, height: 44).background(ink.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(solution.error < 1e-8 ? "Exact reference (within tolerance)" : "Approximate reference").font(.headline)
                            Text("\(solution.steps.count) diagrams · rank \(solution.rank)")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text("Error \(String(format: "%.5f", locale: Locale(identifier: "en_US_POSIX"), solution.error))")
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption.bold())
                    }.card()
                }.buttonStyle(.plain)
            }
            Text("Reference library: \(response.marks ?? 0) points · \(response.lines ?? 0) lines").font(.caption).foregroundStyle(.secondary)
            Text("Errors are displayed to five decimal places in paper units. Exact means below 0.00000001 units, not a mathematical proof; a displayed 0.00000 may be approximate.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private extension View {
    func card() -> some View {
        self.padding(16).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}

// A deliberately small preview parser; the engine still accepts full expressions.
private func previewNumber(_ text: String) -> Double? {
    let text = text.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")
        .replacingOccurrences(of: "sqrt(2)", with: String(2.0.squareRoot()))
    let parts = text.split(separator: "/", omittingEmptySubsequences: false)
    let result: Double?
    if parts.count == 1 { result = Double(text) }
    else if parts.count == 2, let a = Double(parts[0]), let b = Double(parts[1]), b != 0 { result = a / b }
    else { result = nil }
    guard let value = result, value.isFinite else { return nil }
    return value
}

private struct PaperPreview: View {
    @Binding var input: SearchInput
    var body: some View {
        GeometryReader { geo in
            let w = previewNumber(input.width) ?? 1
            let h = previewNumber(input.height) ?? 1
            let validPaper = w >= 0.25 && w <= 2 && h >= 0.25 && h <= 2 && max(w, h) / min(w, h) <= 4
            let width = validPaper ? w : 1
            let height = validPaper ? h : 1
            let scale = min((geo.size.width - 40) / width, (geo.size.height - 35) / height)
            let rect = CGRect(x: (geo.size.width - width * scale) / 2,
                              y: 8, width: width * scale, height: height * scale)
            let x = previewNumber(input.x)
            let y = previewNumber(input.y)
            ZStack {
                Canvas { ctx, _ in
                    ctx.fill(Path(rect), with: .color(.white))
                    for fraction in [0.25, 0.5, 0.75] {
                        var grid = Path()
                        grid.move(to: CGPoint(x: rect.minX + rect.width * fraction, y: rect.minY))
                        grid.addLine(to: CGPoint(x: rect.minX + rect.width * fraction, y: rect.maxY))
                        grid.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * fraction))
                        grid.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * fraction))
                        ctx.stroke(grid, with: .color(.gray.opacity(0.16)), lineWidth: 1)
                    }
                    ctx.stroke(Path(rect), with: .color(.gray.opacity(0.5)), lineWidth: 1.5)
                    if let x, let y, validPaper, x >= 0, x <= width, y >= 0, y <= height {
                        let point = CGPoint(x: rect.minX + x * scale, y: rect.maxY - y * scale)
                        var guides = Path()
                        guides.move(to: CGPoint(x: rect.minX, y: point.y)); guides.addLine(to: point)
                        guides.addLine(to: CGPoint(x: point.x, y: rect.maxY))
                        ctx.stroke(guides, with: .color(ink.opacity(0.45)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        if input.line, let x2 = previewNumber(input.x2), let y2 = previewNumber(input.y2),
                           x2 >= 0, x2 <= width, y2 >= 0, y2 <= height {
                            let other = CGPoint(x: rect.minX + x2 * scale, y: rect.maxY - y2 * scale)
                            var segment = Path(); segment.move(to: point); segment.addLine(to: other)
                            ctx.stroke(segment, with: .color(foldColor), lineWidth: 3)
                            ctx.fill(Path(ellipseIn: CGRect(x: other.x - 5, y: other.y - 5, width: 10, height: 10)), with: .color(foldColor))
                        }
                        ctx.fill(Path(ellipseIn: CGRect(x: point.x - 11, y: point.y - 11, width: 22, height: 22)), with: .color(ink.opacity(0.15)))
                        ctx.fill(Path(ellipseIn: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)), with: .color(ink))
                    }
                    ctx.draw(Text("0").font(.caption2).foregroundColor(.gray), at: CGPoint(x: rect.minX - 9, y: rect.maxY + 10))
                    ctx.draw(Text("X →").font(.caption.bold()).foregroundColor(ink), at: CGPoint(x: rect.midX, y: rect.maxY + 14))
                    ctx.draw(Text("Y ↑").font(.caption.bold()).foregroundColor(foldColor), at: CGPoint(x: rect.minX - 16, y: rect.midY))
                }
            }
            // Handle taps and continuous drags before the enclosing ScrollView.
            // Use the entire preview's coordinate system, not a positioned
            // overlay's local coordinates, to avoid offset/drift.
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { event in
                        let localX = min(rect.maxX, max(rect.minX, event.location.x))
                        let localY = min(rect.maxY, max(rect.minY, event.location.y))
                        input.x = String(format: "%.5f", locale: Locale(identifier: "en_US_POSIX"),
                                         (localX - rect.minX) / scale)
                        input.y = String(format: "%.5f", locale: Locale(identifier: "en_US_POSIX"),
                                         (rect.maxY - localY) / scale)
                    }
            )
            .accessibilityElement(children: .ignore)
                .accessibilityLabel("Paper preview. \(input.summary). Edit the X and Y fields to set exact coordinates.")
        }
    }
}

// Explicit intrinsic width keeps the textual toolbar action comfortably oval,
// including on systems that automatically add round toolbar backgrounds.
struct DoneButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text("Done")
                .font(.body.weight(.semibold))
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 18)
                .frame(minWidth: 82, minHeight: 44)
                .foregroundStyle(.white)
                .background(ink, in: Capsule())
        }.buttonStyle(.plain)
    }
}

struct SolutionView: View {
    let solution: FoldSolution
    let number: Int
    let input: SearchInput
    @AppStorage("origami.sequence.columns") private var preferredColumns = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var stepIndex = 0
    @State private var expanded = false

    private var shareText: String {
        "Origami Reference Finder — \(input.summary)\nPaper: \(input.width) × \(input.height)\nRank: \(solution.rank)\nError: \(String(format: "%.5f", locale: Locale(identifier: "en_US_POSIX"), solution.error))\n\n\(solution.instructions)\n\nEngine: Robert J. Lang. Uploaded for iOS by Ángel Soto."
    }

    var body: some View {
        GeometryReader { geometry in
            let count = columnCount(for: geometry.size)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(input.summary).font(.title2.bold())
                        Text("Rank \(solution.rank) · error \(String(format: "%.5f", locale: Locale(identifier: "en_US_POSIX"), solution.error))")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    if !solution.steps.isEmpty {
                        sequenceHeader
                        legend
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: count),
                                  alignment: .leading, spacing: 20) {
                            ForEach(solution.steps.indices, id: \.self) { index in
                                stepCard(at: index)
                            }
                        }
                    } else {
                        Label("This reference is already on the original paper.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(ink).card()
                    }
                    DisclosureGroup("Text instructions") {
                        Text(solution.instructions).font(.body).textSelection(.enabled).padding(.top, 12)
                    }.card()
                    ShareLink(item: shareText) {
                        Label("Share instructions", systemImage: "square.and.arrow.up")
                            .frame(minHeight: 36)
                    }.buttonStyle(.bordered).frame(maxWidth: .infinity)
                }
                .padding(20)
                .frame(maxWidth: 1200)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Route \(number)")
        .navigationBarTitleDisplayMode(.inline)
        .tint(ink)
        .sheet(isPresented: $expanded) {
            SequenceStepDetail(solution: solution, stepIndex: $stepIndex)
        }
    }

    // Geometry, rather than device orientation notifications, also handles
    // iPad multitasking and window resizing. Larger accessibility text stays readable.
    private func columnCount(for size: CGSize) -> Int {
        if dynamicTypeSize.isAccessibilitySize { return 1 }
        if (1...4).contains(preferredColumns) { return preferredColumns }
        let width = min(size.width, 1200)
        if size.width > size.height { return width >= 1000 ? 4 : 3 }
        return width >= 600 ? 2 : 1
    }

    private var sequenceHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center) {
                    Text("Full folding sequence").font(.title3.bold())
                    Spacer()
                    columnPicker
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Full folding sequence").font(.title3.bold())
                    columnPicker
                }
            }
            Text("All \(solution.steps.count) steps in folding order. Tap any diagram to enlarge.")
                .font(.subheadline).foregroundStyle(.secondary)
            if dynamicTypeSize.isAccessibilitySize {
                Text("One column is used with larger accessibility text.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var columnPicker: some View {
        Menu {
            Picker("Columns", selection: $preferredColumns) {
                Text("Auto").tag(0)
                ForEach(1...4, id: \.self) { count in
                    Text("\(count) \(count == 1 ? "column" : "columns")").tag(count)
                }
            }
        } label: {
            Label(preferredColumns == 0 ? "Columns: Auto" : "Columns: \(preferredColumns)",
                  systemImage: "square.grid.2x2")
                .font(.subheadline)
                .frame(minHeight: 44)
        }
        .disabled(dynamicTypeSize.isAccessibilitySize)
        .accessibilityLabel("Number of diagram columns")
    }

    private func stepCard(at index: Int) -> some View {
        let step = solution.steps[index]
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("STEP \(index + 1)").font(.caption.bold()).tracking(1.5)
                Spacer()
                Image(systemName: "arrow.up.left.and.arrow.down.right").font(.caption)
            }.foregroundStyle(ink)
            Button {
                stepIndex = index
                expanded = true
            } label: {
                DiagramView(svg: step.svg)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .aspectRatio(1, contentMode: .fit)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(.gray.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Step \(index + 1). \(step.caption)")
            .accessibilityHint("Opens an enlarged folding diagram")
            Text(step.caption)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .card()
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("Teal: references to align", systemImage: "circle.fill").foregroundStyle(ink)
            Label("Orange: new fold or result", systemImage: "line.diagonal").foregroundStyle(foldColor)
            Label("Gray: existing creases · arrows: fold direction", systemImage: "arrow.turn.up.right")
                .foregroundStyle(.secondary)
        }.font(.caption)
    }
}

private struct SequenceStepDetail: View {
    let solution: FoldSolution
    @Binding var stepIndex: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if solution.steps.indices.contains(stepIndex) {
                let step = solution.steps[stepIndex]
                GeometryReader { geometry in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            DiagramStage(step: step)
                                .frame(height: max(240, min(geometry.size.width - 32, geometry.size.height * 0.65)))
                            Text(step.caption).font(.body).textSelection(.enabled)
                            HStack {
                                Button { stepIndex -= 1 } label: {
                                    Label("Back", systemImage: "chevron.left").frame(minHeight: 36)
                                }.disabled(stepIndex == 0)
                                Spacer()
                                Text("\(stepIndex + 1) / \(solution.steps.count)")
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                Spacer()
                                Button { stepIndex += 1 } label: {
                                    Label("Next", systemImage: "chevron.right").frame(minHeight: 36)
                                }.disabled(stepIndex == solution.steps.count - 1)
                            }.buttonStyle(.bordered).controlSize(.large)
                        }.padding(16).frame(maxWidth: 1000).frame(maxWidth: .infinity)
                    }
                }
                .navigationTitle("Step \(stepIndex + 1)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { DoneButton { dismiss() } }
                }
            }
        }.tint(ink)
    }
}

private struct DiagramStage: View {
    let step: FoldStep
    @State private var zoomed = false
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                ScrollView([.horizontal, .vertical]) {
                    DiagramView(svg: step.svg)
                        .frame(width: geo.size.width * (zoomed ? 2 : 1), height: geo.size.height * (zoomed ? 2 : 1))
                }
                Button { zoomed.toggle() } label: {
                    Image(systemName: zoomed ? "minus.magnifyingglass" : "plus.magnifyingglass")
                        .font(.title3).padding(12).background(.white.opacity(0.95), in: Circle())
                }.padding(8).accessibilityLabel(zoomed ? "Zoom out" : "Zoom in")
            }.background(.white).clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.gray.opacity(0.15)))
        }.onChange(of: step.svg) { _ in zoomed = false }
    }
}

// Local SVG only. Reuse the web view and reload only when the step changes.
struct DiagramView: UIViewRepresentable {
    let svg: String
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        let web = WKWebView(frame: .zero, configuration: config)
        web.scrollView.isScrollEnabled = false
        web.isOpaque = false
        web.backgroundColor = .white
        return web
    }
    func updateUIView(_ web: WKWebView, context: Context) {
        guard context.coordinator.svg != svg else { return }
        context.coordinator.svg = svg
        web.accessibilityLabel = "Folding diagram"
        web.loadHTMLString("""
        <!doctype html><html lang="en"><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'">
        <style>html,body{margin:0;width:100%;height:100%;background:white;overflow:hidden}svg{display:block;width:100%;height:100%}</style>
        </head><body>\(svg)</body></html>
        """, baseURL: nil)
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var svg = "" }
}


// MARK: - Points in CP
// A CP is used as a coordinate backdrop, never as a source of automatically
// detected folds. A user-defined image region maps to the engine's unit square.
import UniformTypeIdentifiers
import PDFKit

private enum CPReferencePalette {
    static let colors: [UIColor] = [
        .systemPurple, .systemBlue, .systemRed, .systemGreen,
        .systemOrange, .systemPink, .systemTeal, .systemIndigo
    ]
    static func lineColor(_ number: Int) -> UIColor {
        colors[(max(1, number) - 1) % colors.count]
    }
}

private struct CPReference: Identifiable {
    let id = UUID()
    var position: CGPoint // normalized top-left-origin paper coordinates
    var endpoint: CGPoint? = nil // second endpoint for a line
}

private struct CPPointsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var sourceLabel = ""
    @State private var firstCorner: CGPoint?
    @State private var paperRegion: CGRect?
    @State private var references: [CPReference] = []
    @State private var mode: CPMode = .paper
    @State private var showingImporter = false
    @State private var internetAddress = ""
    @State private var loading = false
    @State private var problem: String?
    @State private var showRoutes = false
    @State private var searchRank = 3
    @State private var editingCorner: Int?
    @State private var editingPoint: Int?
    @State private var referenceKind: CPReferenceKind = .point
    @State private var pendingLineStart: CGPoint?
    @State private var editingEndpoint: Int?
    @State private var movingLineAnchor: CGPoint?

    enum CPMode { case paper, points }
    enum CPReferenceKind: String, CaseIterable { case point = "Point", line = "Line" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Import a crease pattern and mark the square paper area. Then add points or lines to solve.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button { showingImporter = true } label: {
                            Label("Files / PDF", systemImage: "doc")
                        }.buttonStyle(.bordered)
                        Button { pasteImage() } label: {
                            Label("Paste", systemImage: "doc.on.clipboard")
                        }.buttonStyle(.bordered)
                    }
                    HStack {
                        TextField("https://… image or PDF URL", text: $internetAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .textFieldStyle(.roundedBorder)
                        Button("Load") { loadFromURL() }
                            .disabled(loading || internetAddress.isEmpty)
                    }
                    if loading { ProgressView("Loading CP…") }
                    if let problem { Text(problem).foregroundStyle(.red).font(.caption) }
                    if let image {
                        Text(sourceLabel).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        Label("Pinch to zoom and pan. Tap to add; select a marker or line endpoint to reposition. Zoom for precision.", systemImage: "hand.draw").font(.caption).foregroundStyle(.secondary)
                        CPSelectionCanvas(image: image, region: paperRegion, corner: firstCorner,
                                          references: references, mode: mode, onTouch: handleTouch)
                            .frame(height: 440)
                            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                        if paperRegion == nil {
                            Label(firstCorner == nil ?
                                  "Tap the first corner of the paper square." :
                                  "Tap the opposite corner to finish the paper square.",
                                  systemImage: "viewfinder")
                                .font(.subheadline)
                        } else {
                            HStack {
                                Label("Paper area selected", systemImage: "checkmark.square")
                                Spacer()
                                Button("Edit corners") { mode = .paper; editingCorner = nil; editingPoint = nil; editingEndpoint = nil; pendingLineStart = nil }
                                Button("Redefine") {
                                    paperRegion = nil; firstCorner = nil; references = []; mode = .paper
                                    editingCorner = nil; editingPoint = nil
                                }
                            }.font(.subheadline)
                            if mode == .paper {
                                Text(editingCorner == nil ? "Tap an orange corner to select it, then tap its new position." :
                                     "Corner selected. Tap its new position in the image.")
                                    .font(.caption).foregroundStyle(.secondary)
                                Button("Finish paper adjustment") { mode = .points; editingCorner = nil }
                                    .buttonStyle(.borderedProminent)
                            } else {
                                Picker("Reference", selection: $referenceKind) {
                                    ForEach(CPReferenceKind.allCases, id: \.self) { kind in
                                        Text(kind.rawValue).tag(kind)
                                    }
                                }.pickerStyle(.segmented)
                                    .onChange(of: referenceKind) { _ in
                                        pendingLineStart = nil
                                        editingPoint = nil
                                        editingEndpoint = nil
                                        movingLineAnchor = nil
                                    }
                                Text(editingPoint != nil ? (editingEndpoint == 2 ? "Tap the new center of the line." : "Tap a new position for the selected handle.") :
                                     referenceKind == .line ? (pendingLineStart == nil ?
                                     "Tap the first line endpoint, then the second." :
                                     "Tap the second endpoint to complete the line.") :
                                     "Tap to add a point. Tap a marker to edit it.")
                                    .font(.caption).foregroundStyle(.secondary)
                                if pendingLineStart != nil {
                                    Button("Cancel unfinished line") { pendingLineStart = nil }
                                }
                                ForEach(Array(references.enumerated()), id: \.element.id) { index, reference in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            HStack(spacing: 6) {
                                                if reference.endpoint != nil {
                                                    Circle()
                                                        .fill(Color(uiColor: CPReferencePalette.lineColor(
                                                            references.prefix(index + 1).filter { $0.endpoint != nil }.count)).opacity(0.75))
                                                        .frame(width: 10, height: 10)
                                                }
                                                Text("\(reference.endpoint == nil ? "Point" : "Line") \(references.prefix(index + 1).filter { ($0.endpoint != nil) == (reference.endpoint != nil) }.count)")
                                                    .fontWeight(.semibold)
                                            }
                                            Spacer()
                                            Button {
                                                references.remove(at: index)
                                                editingPoint = nil
                                                editingEndpoint = nil
                                            } label: { Image(systemName: "minus.circle") }
                                        }
                                        Text(String(format: "X1 %.5f · Y1 %.5f", reference.position.x, 1 - reference.position.y))
                                            .font(.caption.monospacedDigit())
                                        if let end = reference.endpoint {
                                            Text(String(format: "X2 %.5f · Y2 %.5f", end.x, 1 - end.y))
                                                .font(.caption.monospacedDigit())
                                        }
                                        HStack {
                                            Button("Move start") { editingPoint = index; editingEndpoint = 0 }
                                            if reference.endpoint != nil {
                                                Button("Move end") { editingPoint = index; editingEndpoint = 1 }
                                                Button("Move line") {
                                                    editingPoint = index
                                                    editingEndpoint = 2
                                                    movingLineAnchor = CGPoint(x: (reference.position.x + (reference.endpoint?.x ?? 0)) / 2,
                                                                               y: (reference.position.y + (reference.endpoint?.y ?? 0)) / 2)
                                                }
                                            }
                                        }.font(.caption).buttonStyle(.bordered)
                                        HStack {
                                            ForEach(0..<(reference.endpoint == nil ? 2 : 4), id: \.self) { coordinate in
                                                let isEnd = coordinate >= 2
                                                let isX = coordinate % 2 == 0
                                                let value = isEnd ? (reference.endpoint ?? .zero) : reference.position
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text("\(isX ? "X" : "Y")\(isEnd ? "2" : "1")").font(.caption2)
                                                    TextField("0…1", text: Binding(
                                                        get: { String(format: "%.5f", isX ? value.x : 1 - value.y) },
                                                        set: { raw in
                                                            guard let n = Double(raw.replacingOccurrences(of: ",", with: ".")),
                                                                  n.isFinite, (0...1).contains(n),
                                                                  references.indices.contains(index) else { return }
                                                            var p = isEnd ? (references[index].endpoint ?? .zero) : references[index].position
                                                            if isX { p.x = n } else { p.y = 1 - n }
                                                            if isEnd { references[index].endpoint = p }
                                                            else { references[index].position = p }
                                                        }))
                                                        .keyboardType(.decimalPad)
                                                        .textFieldStyle(.roundedBorder)
                                                        .font(.caption.monospacedDigit())
                                                }
                                            }
                                        }
                                    }.padding(8).background(.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                                }
                                HStack {
                                    Button("Undo last") { _ = references.popLast(); pendingLineStart = nil }
                                        .disabled(references.isEmpty && pendingLineStart == nil)
                                    Button("Clear references", role: .destructive) {
                                        references.removeAll(); pendingLineStart = nil
                                    }.disabled(references.isEmpty && pendingLineStart == nil)
                                }.buttonStyle(.bordered)
                                Picker("Search depth", selection: $searchRank) {
                                    Text("Quick").tag(2)
                                    Text("Balanced").tag(3)
                                    Text("Deeper").tag(4)
                                }.pickerStyle(.segmented)
                                Button { showRoutes = true } label: {
                                    Label("Solve \(references.count) reference\(references.count == 1 ? "" : "s")",
                                          systemImage: "sparkles")
                                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(references.isEmpty)
                            }
                        }
                    } else {
                        Label("Choose an image or PDF, paste a copied image, or load an HTTPS URL.", systemImage: "square.dashed").font(.subheadline).foregroundStyle(.secondary).padding()
                    }
                    Text("CP Points finds folding references for the points and lines you select. It does not automatically infer the folding order of the entire crease pattern.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(16).frame(maxWidth: 700).frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Points in CP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { DoneButton { dismiss() } }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.image, .pdf]) { result in
                switch result {
                case .success(let file):
                    let granted = file.startAccessingSecurityScopedResource()
                    defer { if granted { file.stopAccessingSecurityScopedResource() } }
                    do { try decode(data: Data(contentsOf: file), name: file.lastPathComponent) }
                    catch { problem = "Could not open file: \(error.localizedDescription)" }
                case .failure(let error):
                    problem = error.localizedDescription
                }
            }
            .navigationDestination(isPresented: $showRoutes) {
                CPPointsResultsView(points: references, rank: searchRank)
            }
        }
    }

    private func handleTouch(_ point: CGPoint) {
        guard image != nil else { return }
        problem = nil
        if mode == .paper, let region = paperRegion {
            let corners = [
                CGPoint(x: region.minX, y: region.minY),
                CGPoint(x: region.maxX, y: region.minY),
                CGPoint(x: region.maxX, y: region.maxY),
                CGPoint(x: region.minX, y: region.maxY)
            ]
            if editingCorner == nil {
                guard let index = corners.indices.min(by: {
                    hypot(corners[$0].x - point.x, corners[$0].y - point.y) <
                    hypot(corners[$1].x - point.x, corners[$1].y - point.y)
                }), hypot(corners[index].x - point.x, corners[index].y - point.y) < 0.08 else {
                    problem = "Tap one of the four orange corner handles."
                    return
                }
                editingCorner = index
                return
            }
            guard let selected = editingCorner else { return }
            let fixed = corners[(selected + 2) % 4]
            let dx = abs(point.x - fixed.x)
            let dy = abs(point.y - fixed.y)
            guard dx > 0.015, dy > 0.015 else {
                problem = "The paper area is too small."
                return
            }
            let imageSize = image!.size
            let side = min(dx * imageSize.width, dy * imageSize.height)
            let w = side / imageSize.width
            let h = side / imageSize.height
            let originX = point.x < fixed.x ? fixed.x - w : fixed.x
            let originY = point.y < fixed.y ? fixed.y - h : fixed.y
            guard originX >= 0, originY >= 0, originX + w <= 1, originY + h <= 1 else {
                problem = "Keep the square within the image."
                return
            }
            paperRegion = CGRect(x: originX, y: originY, width: w, height: h)
            editingCorner = nil
            return
        }
        if mode == .paper {
            guard let firstCorner else {
                self.firstCorner = point
                return
            }
            let left = min(firstCorner.x, point.x)
            let top = min(firstCorner.y, point.y)
            let width = abs(firstCorner.x - point.x)
            let height = abs(firstCorner.y - point.y)
            guard width > 0.04, height > 0.04 else {
                problem = "Select opposite corners of the paper, farther apart."
                return
            }
            // Enforce a square in original image coordinates, even when
            // the imported image has a rectangular aspect ratio.
            let pixelSide = min(width * image!.size.width, height * image!.size.height)
            paperRegion = CGRect(x: left, y: top,
                                 width: pixelSide / max(image!.size.width, 1),
                                 height: pixelSide / max(image!.size.height, 1))
            self.firstCorner = nil
            references = []
            mode = .points
        } else if let paperRegion {
            let normalized = CGPoint(
                x: min(1, max(0, (point.x - paperRegion.minX) / paperRegion.width)),
                y: min(1, max(0, (point.y - paperRegion.minY) / paperRegion.height)))
            if let selected = editingPoint {
                guard paperRegion.contains(point) else { problem = "Place the point inside the square."; return }
                if editingEndpoint == 2, let end = references[selected].endpoint {
                    let start = references[selected].position
                    let mid = movingLineAnchor ?? CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
                    let dx = normalized.x - mid.x
                    let dy = normalized.y - mid.y
                    let movedStart = CGPoint(x: start.x + dx, y: start.y + dy)
                    let movedEnd = CGPoint(x: end.x + dx, y: end.y + dy)
                    guard [movedStart, movedEnd].allSatisfy({ (0...1).contains($0.x) && (0...1).contains($0.y) }) else {
                        problem = "Keep the entire line inside the paper."
                        return
                    }
                    references[selected].position = movedStart
                    references[selected].endpoint = movedEnd
                } else if editingEndpoint == 1 {
                    guard hypot(references[selected].position.x - normalized.x,
                                references[selected].position.y - normalized.y) > 0.0001 else {
                        problem = "Line endpoints must differ."
                        return
                    }
                    references[selected].endpoint = normalized
                } else {
                    if let end = references[selected].endpoint,
                       hypot(end.x - normalized.x, end.y - normalized.y) <= 0.0001 {
                        problem = "Line endpoints must differ."
                        return
                    }
                    references[selected].position = normalized
                }
                editingPoint = nil
                editingEndpoint = nil
                movingLineAnchor = nil
                return
            }
            // Select the closest point or either line endpoint.
            let handles = references.indices.flatMap { i -> [(Int, Int, CGPoint)] in
                var result = [(i, 0, references[i].position)]
                if let end = references[i].endpoint { result.append((i, 1, end)) }
                return result
            }
            if let closest = handles.min(by: { lhs, rhs in
                hypot(lhs.2.x - normalized.x, lhs.2.y - normalized.y) <
                hypot(rhs.2.x - normalized.x, rhs.2.y - normalized.y)
            }), hypot(closest.2.x - normalized.x, closest.2.y - normalized.y) < 0.035 {
                editingPoint = closest.0
                editingEndpoint = closest.1
            } else if let index = references.indices.first(where: { i in
                guard let end = references[i].endpoint else { return false }
                let start = references[i].position
                let dx = end.x - start.x, dy = end.y - start.y
                let lengthSquared = dx * dx + dy * dy
                guard lengthSquared > 0 else { return false }
                let t = min(1, max(0, ((normalized.x - start.x) * dx + (normalized.y - start.y) * dy) / lengthSquared))
                return hypot(normalized.x - (start.x + t * dx), normalized.y - (start.y + t * dy)) < 0.018
            }) {
                editingPoint = index
                editingEndpoint = 2
                if let end = references[index].endpoint {
                    movingLineAnchor = CGPoint(x: (references[index].position.x + end.x) / 2,
                                               y: (references[index].position.y + end.y) / 2)
                }
            } else if paperRegion.contains(point) {
                if referenceKind == .point {
                    references.append(CPReference(position: normalized))
                } else if let start = pendingLineStart {
                    guard hypot(start.x - normalized.x, start.y - normalized.y) > 0.0001 else {
                        problem = "Choose two different endpoints."; return
                    }
                    references.append(CPReference(position: start, endpoint: normalized))
                    pendingLineStart = nil
                } else {
                    pendingLineStart = normalized
                }
            }
        }
    }

    private func pasteImage() {
        if let pasted = UIPasteboard.general.image {
            reset(with: pasted, name: "Clipboard image")
        } else if let url = UIPasteboard.general.url {
            internetAddress = url.absoluteString
            loadFromURL()
        } else if let text = UIPasteboard.general.string,
                  let url = URL(string: text), url.scheme?.lowercased() == "https" {
            internetAddress = text
            loadFromURL()
        } else {
            problem = "Copy an image or an HTTPS image/PDF link before pasting."
        }
    }

    private func loadFromURL() {
        guard let url = URL(string: internetAddress),
              url.scheme?.lowercased() == "https",
              url.host != nil else {
            problem = "Enter a valid HTTPS image or PDF URL."
            return
        }
        loading = true; problem = nil
        Task {
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 20
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    throw CPImportError.invalidResponse
                }
                try decode(data: data, name: url.lastPathComponent)
            } catch {
                problem = "Unable to load image/PDF: \(error.localizedDescription)"
            }
            loading = false
        }
    }

    private enum CPImportError: LocalizedError {
        case unsupported, invalidResponse, tooLarge
        var errorDescription: String? {
            switch self {
            case .unsupported: return "This file is not a valid image or PDF."
            case .invalidResponse: return "The server did not return a successful response."
            case .tooLarge: return "Image/PDF is too large (20 MB maximum)."
            }
        }
    }

    private func decode(data: Data, name: String) throws {
        guard data.count <= 20_000_000 else { throw CPImportError.tooLarge }
        if let image = UIImage(data: data) {
            reset(with: image, name: name)
        } else if let document = PDFDocument(data: data),
                  let page = document.page(at: 0) {
            let size = page.bounds(for: .mediaBox).size
            let factor = min(3, 2400 / max(size.width, size.height, 1))
            reset(with: page.thumbnail(of: CGSize(width: size.width * factor,
                                                   height: size.height * factor), for: .mediaBox),
                  name: name + " · page 1")
        } else {
            throw CPImportError.unsupported
        }
    }

    private func reset(with newImage: UIImage, name: String) {
        image = newImage
        sourceLabel = name
        firstCorner = nil
        paperRegion = nil
        references = []
        pendingLineStart = nil
        mode = .paper
        editingCorner = nil
        editingPoint = nil
        problem = nil
    }
}

private struct CPSelectionCanvas: UIViewRepresentable {
    let image: UIImage
    let region: CGRect?
    let corner: CGPoint?
    let references: [CPReference]
    let mode: CPPointsView.CPMode
    let onTouch: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onTouch: onTouch) }

    func makeUIView(context: Context) -> CPZoomScrollView {
        let scroll = CPZoomScrollView()
        scroll.delegate = context.coordinator
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 10
        scroll.bouncesZoom = true
        scroll.contentInsetAdjustmentBehavior = .never
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didTap(_:)))
        scroll.paperView.addGestureRecognizer(tap)
        scroll.paperView.isUserInteractionEnabled = true
        return scroll
    }

    func updateUIView(_ scroll: CPZoomScrollView, context: Context) {
        context.coordinator.onTouch = onTouch
        scroll.setImageIfNeeded(image)
        scroll.paperView.region = region
        scroll.paperView.corner = corner
        scroll.paperView.references = references.enumerated().map { ($0.offset + 1, $0.element.position, $0.element.endpoint) }
        scroll.paperView.setNeedsDisplay()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var onTouch: (CGPoint) -> Void
        init(onTouch: @escaping (CGPoint) -> Void) { self.onTouch = onTouch }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? CPZoomScrollView)?.paperView
        }
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            (scrollView as? CPZoomScrollView)?.centerPaper()
        }
        @objc func didTap(_ gesture: UITapGestureRecognizer) {
            guard let paper = gesture.view, paper.bounds.width > 0, paper.bounds.height > 0 else { return }
            let p = gesture.location(in: paper)
            let x = p.x / paper.bounds.width
            let y = p.y / paper.bounds.height
            guard (0...1).contains(x), (0...1).contains(y) else { return }
            onTouch(CGPoint(x: x, y: y))
        }
    }
}

private final class CPZoomScrollView: UIScrollView {
    let paperView = CPAnnotatedPaperView()
    private var displayedImage: UIImage?
    private var previousSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(paperView)
        paperView.contentMode = .redraw
    }
    required init?(coder: NSCoder) { fatalError("Not used") }

    func setImageIfNeeded(_ image: UIImage) {
        guard displayedImage !== image else { return }
        displayedImage = image
        paperView.image = image
        zoomScale = 1
        previousSize = .zero
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let image = displayedImage, bounds.width > 0, bounds.height > 0 else { return }
        if previousSize != bounds.size {
            previousSize = bounds.size
            let fit = min(bounds.width / max(image.size.width, 1),
                          bounds.height / max(image.size.height, 1))
            let size = CGSize(width: image.size.width * fit, height: image.size.height * fit)
            zoomScale = 1
            paperView.frame = CGRect(origin: .zero, size: size)
            contentSize = size
        }
        centerPaper()
    }

    func centerPaper() {
        let x = max(0, (bounds.width - contentSize.width) / 2)
        let y = max(0, (bounds.height - contentSize.height) / 2)
        contentInset = UIEdgeInsets(top: y, left: x, bottom: y, right: x)
    }
}

private final class CPAnnotatedPaperView: UIView {
    var image: UIImage?
    var region: CGRect?
    var corner: CGPoint?
    var references: [(Int, CGPoint, CGPoint?)] = []

    override func draw(_ rect: CGRect) {
        guard let image, let context = UIGraphicsGetCurrentContext() else { return }
        image.draw(in: bounds)
        if let corner {
            let x = corner.x * bounds.width, y = corner.y * bounds.height
            context.setFillColor(UIColor.systemOrange.cgColor)
            context.fillEllipse(in: CGRect(x: x - 5, y: y - 5, width: 10, height: 10))
        }
        guard let region else { return }
        let area = CGRect(x: region.minX * bounds.width, y: region.minY * bounds.height,
                          width: region.width * bounds.width, height: region.height * bounds.height)
        context.setStrokeColor(UIColor.systemOrange.cgColor)
        context.setLineWidth(2)
        context.setLineDash(phase: 0, lengths: [6, 4])
        context.stroke(area)
        context.setLineDash(phase: 0, lengths: [])
        for handle in [CGPoint(x: area.minX, y: area.minY),
                       CGPoint(x: area.maxX, y: area.minY),
                       CGPoint(x: area.maxX, y: area.maxY),
                       CGPoint(x: area.minX, y: area.maxY)] {
            context.setFillColor(UIColor.systemOrange.cgColor)
            context.fillEllipse(in: CGRect(x: handle.x - 6, y: handle.y - 6, width: 12, height: 12))
        }
        var pointIndex = 0
        var lineIndex = 0
        for (_, point, endpoint) in references {
            let x = (region.minX + point.x * region.width) * bounds.width
            let y = (region.minY + point.y * region.height) * bounds.height
            let label: String
            let center: CGPoint
            let fill: UIColor

            if let endpoint {
                lineIndex += 1
                label = "L\(lineIndex)"
                let ex = (region.minX + endpoint.x * region.width) * bounds.width
                let ey = (region.minY + endpoint.y * region.height) * bounds.height
                center = CGPoint(x: (x + ex) / 2, y: (y + ey) / 2)
                let color = CPReferencePalette.lineColor(lineIndex)
                fill = color.withAlphaComponent(0.70)
                context.setStrokeColor(color.withAlphaComponent(0.64).cgColor)
                context.setLineWidth(2.2)
                context.move(to: CGPoint(x: x, y: y))
                context.addLine(to: CGPoint(x: ex, y: ey))
                context.strokePath()
                // Small semi-transparent endpoint handles.
                context.setFillColor(color.withAlphaComponent(0.52).cgColor)
                for p in [CGPoint(x: x, y: y), CGPoint(x: ex, y: ey)] {
                    context.fillEllipse(in: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8))
                }
            } else {
                pointIndex += 1
                label = "\(pointIndex)"
                center = CGPoint(x: x, y: y)
                fill = UIColor(red: 0.03, green: 0.43, blue: 0.48, alpha: 0.58)
            }
            // Compact semi-transparent labels preserve the image beneath.
            let diameter: CGFloat = endpoint == nil ? 18 : 21
            let badge = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                               width: diameter, height: diameter)
            context.setFillColor(fill.cgColor)
            context.fillEllipse(in: badge)
            context.setStrokeColor(UIColor.white.withAlphaComponent(0.65).cgColor)
            context.setLineWidth(0.8)
            context.strokeEllipse(in: badge)
            let text = label as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: endpoint == nil ? 10 : 9),
                .foregroundColor: UIColor.white
            ]
            let size = text.size(withAttributes: attrs)
            text.draw(at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2),
                      withAttributes: attrs)
        }
    }
}

private struct CPPointsResultsView: View {
    let points: [CPReference]
    let rank: Int
    @AppStorage("origami.cp.columns") private var columns = 1
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("References for \(points.count) CP targets")
                            .font(.headline)
                        Spacer()
                        Menu {
                            Picker("Columns", selection: $columns) {
                                ForEach(1...4, id: \.self) { count in
                                    Text("\(count) columns").tag(count)
                                }
                            }
                        } label: {
                            Label("\(columns) columns", systemImage: "square.grid.2x2")
                        }
                    }
                    Text("Each point or line is solved independently. Open a route for its numbered folding sequence.")
                        .font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top),
                                              count: max(1, min(4, columns))),
                              alignment: .leading, spacing: 12) {
                        ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                            CPPointResultCard(index: index + 1,
                                              number: points.prefix(index + 1).filter {
                                                  ($0.endpoint != nil) == (point.endpoint != nil)
                                              }.count,
                                              point: point, rank: rank)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: 1200)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("CP folding routes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CPPointResultCard: View {
    let index: Int
    let number: Int
    let point: CPReference
    let rank: Int
    @StateObject private var model = SearchModel()
    @State private var started = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                if point.endpoint != nil {
                    Circle()
                        .fill(Color(uiColor: CPReferencePalette.lineColor(number)).opacity(0.75))
                        .frame(width: 10, height: 10)
                }
                Text("\(point.endpoint == nil ? "POINT" : "LINE") \(number)")
                    .font(.headline).foregroundStyle(ink)
            }
            Text(String(format: "X %.5f\nY %.5f", point.position.x, 1 - point.position.y))
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            if let end = point.endpoint {
                Text(String(format: "X2 %.5f\nY2 %.5f", end.x, 1 - end.y))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            if model.isSearching {
                ProgressView("Searching…").font(.caption)
            } else if let error = model.error {
                Text(error).font(.caption).foregroundStyle(.red)
                Button("Retry") { model.search() }.font(.caption)
            } else if let solutions = model.response?.solutions {
                if solutions.isEmpty {
                    Text("No solutions found. Try a deeper search.")
                        .font(.caption)
                }
                ForEach(Array(solutions.enumerated()), id: \.offset) { route, solution in
                    NavigationLink {
                        SolutionView(solution: solution, number: route + 1,
                                     input: model.lastInput ?? model.input)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Route \(route + 1)")
                                .font(.subheadline.bold())
                            Text("\(solution.steps.count) diagrams · rank \(solution.rank)")
                            Text(String(format: "Error %.5f", solution.error))
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(ink.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
        .onAppear {
            guard !started else { return }
            started = true
            model.input = SearchInput(
                x: String(format: "%.10f", point.position.x),
                y: String(format: "%.10f", 1 - point.position.y),
                x2: String(format: "%.10f", point.endpoint?.x ?? 1),
                y2: String(format: "%.10f", 1 - (point.endpoint?.y ?? (2.0 / 3.0))),
                width: "1", height: "1",
                line: point.endpoint != nil, rank: rank)
            model.search()
        }
    }
}
