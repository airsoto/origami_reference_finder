import SwiftUI
import WebKit

private let ink = Color(red: 0.03, green: 0.43, blue: 0.48)
private let foldColor = Color(red: 0.88, green: 0.29, blue: 0.20)

struct ContentView: View {
    @StateObject private var model = SearchModel()
    @State private var showingAbout = false
    @State private var advanced = false
    @State private var expressions = false
    @FocusState private var field: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Reference type", selection: $model.input.line) {
                            Text("Point").tag(false)
                            Text("Line").tag(true)
                        }.pickerStyle(.segmented)
                        PaperPreview(input: $model.input)
                            .frame(height: 220)
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
                    DisclosureGroup(isExpanded: $advanced) {
                        VStack(alignment: .leading, spacing: 14) {
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
                        }.padding(.top, 14)
                    } label: {
                        Label("Paper & search", systemImage: "slider.horizontal.3").font(.subheadline.bold())
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
                }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Reference Finder").navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
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
                    Button("Done") { field = nil }
                }
            }.sheet(isPresented: $showingAbout) { AboutView() }.tint(ink)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("From point\nto paper fold.").font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Place a reference. Follow the folds.")
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
                            Text(solution.error < 1e-8 ? "Exact reference" : "Approximate reference").font(.headline)
                            Text("\(solution.steps.count) diagrams · rank \(solution.rank)")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text("Error \(solution.error.formatted(.number.precision(.significantDigits(1...4))))")
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption.bold())
                    }.card()
                }.buttonStyle(.plain)
            }
            Text("Reference library: \(response.marks ?? 0) points · \(response.lines ?? 0) lines").font(.caption).foregroundStyle(.secondary)
            Text("Errors use paper units. Solutions are limited to the reference library explored; ‘exact’ means an error below 0.00000001 units.")
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
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .frame(width: rect.width, height: rect.height).position(x: rect.midX, y: rect.midY)
                    .gesture(DragGesture(minimumDistance: 0).onChanged { event in
                        input.x = String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), min(width, max(0, event.location.x / scale)))
                        input.y = String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), min(height, max(0, height - event.location.y / scale)))
                    })
            }.accessibilityElement(children: .ignore)
                .accessibilityLabel("Paper preview. \(input.summary). Edit the X and Y fields to set exact coordinates.")
        }
    }
}

struct SolutionView: View {
    let solution: FoldSolution
    let number: Int
    let input: SearchInput
    @State private var stepIndex = 0
    @State private var expanded = false

    private var shareText: String {
        "Origami Reference Finder — \(input.summary)\nPaper: \(input.width) × \(input.height)\nRank: \(solution.rank)\nError: \(solution.error)\n\n\(solution.instructions)\n\nEngine: Robert J. Lang. Uploaded for iOS by Ángel Soto."
    }
    private var currentStep: FoldStep? { solution.steps.indices.contains(stepIndex) ? solution.steps[stepIndex] : nil }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(input.summary).font(.title2.bold())
                Text("Rank \(solution.rank) · error \(solution.error.formatted(.number.precision(.significantDigits(1...4))))")
                    .font(.subheadline).foregroundStyle(.secondary)
                if let step = currentStep {
                    HStack {
                        Text("STEP \(stepIndex + 1) / \(solution.steps.count)")
                            .font(.caption.bold()).tracking(2).foregroundStyle(ink)
                        Spacer()
                        Button { expanded = true } label: { Label("Expand", systemImage: "arrow.up.left.and.arrow.down.right") }
                            .font(.caption.bold())
                    }
                    DiagramStage(step: step).frame(height: 360)
                    ProgressView(value: Double(stepIndex + 1), total: Double(solution.steps.count)).tint(ink)
                    Text(step.caption).font(.title3).textSelection(.enabled)
                    controls
                    legend
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(solution.steps.indices, id: \.self) { index in
                                Button { stepIndex = index } label: {
                                    Text(String(index + 1)).font(.subheadline.bold()).frame(width: 44, height: 44)
                                        .background(index == stepIndex ? ink : Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
                                        .foregroundStyle(index == stepIndex ? .white : ink)
                                }.accessibilityLabel("Go to step \(index + 1)")
                            }
                        }
                    }
                } else {
                    Label("This reference is already on the original paper.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(ink).card()
                }
                DisclosureGroup("All instructions") {
                    Text(solution.instructions).font(.body).textSelection(.enabled).padding(.top, 12)
                }.card()
                ShareLink(item: shareText) { Label("Share instructions", systemImage: "square.and.arrow.up") }
                    .buttonStyle(.bordered).frame(maxWidth: .infinity)
            }.padding(20).frame(maxWidth: 750).frame(maxWidth: .infinity)
        }.background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Route \(number)").navigationBarTitleDisplayMode(.inline).tint(ink)
            .sheet(isPresented: $expanded) {
                NavigationStack {
                    VStack(spacing: 16) {
                        if let step = currentStep {
                            DiagramStage(step: step)
                            Text(step.caption).font(.subheadline).padding(.horizontal)
                            controls.padding(.horizontal)
                        }
                    }.padding(.bottom).navigationTitle("Step \(stepIndex + 1)")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { expanded = false } } }
                }.tint(ink)
            }
    }
    private var controls: some View {
        HStack {
            Button { stepIndex -= 1 } label: { Label("Back", systemImage: "chevron.left").frame(minHeight: 36) }
                .disabled(stepIndex == 0)
            Spacer()
            Button { stepIndex += 1 } label: { Label("Next", systemImage: "chevron.right").frame(minHeight: 36) }
                .disabled(stepIndex >= solution.steps.count - 1)
        }.buttonStyle(.bordered).controlSize(.large)
    }
    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Teal: references to align", systemImage: "circle.fill").foregroundStyle(ink)
            Label("Orange: new fold or result", systemImage: "line.diagonal").foregroundStyle(foldColor)
            Label("Gray: existing creases · arrows: fold direction", systemImage: "arrow.turn.up.right").foregroundStyle(.secondary)
        }.font(.caption)
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
