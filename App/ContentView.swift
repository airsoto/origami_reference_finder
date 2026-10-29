import SwiftUI
import WebKit

struct ContentView: View {
    @StateObject private var model = SearchModel()
    @State private var showingAbout = false
    @FocusState private var editing: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Una referencia. Una secuencia de pliegues.", systemImage: "square.on.square.dashed")
                            .font(.headline)
                        Text("Localiza puntos y rectas en tu papel mediante los siete axiomas de Huzita–Justin.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.vertical, 6)
                }
                Section("Qué quieres encontrar") {
                    Picker("Referencia", selection: $model.input.line) {
                        Text("Punto").tag(false)
                        Text("Recta").tag(true)
                    }.pickerStyle(.segmented)
                    coordinate("X", text: $model.input.x)
                    coordinate("Y", text: $model.input.y)
                    if model.input.line {
                        coordinate("X del segundo punto", text: $model.input.x2)
                        coordinate("Y del segundo punto", text: $model.input.y2)
                    }
                    Text("Origen en la esquina inferior izquierda. Admite decimales, 1/3, sqrt(2)/2 y operaciones + − * / ^.")
                        .font(.caption).foregroundStyle(.secondary)
                    if !model.input.line {
                        HStack {
                            Text("Ejemplos").font(.caption).foregroundStyle(.secondary)
                            ForEach(["1/3", "1/5", "1/7"], id: \.self) { fraction in
                                Button(fraction) { model.input.x = "0"; model.input.y = fraction }
                                    .buttonStyle(.bordered).controlSize(.small)
                            }
                        }
                    }
                }.disabled(model.isSearching)
                Section("Papel y búsqueda") {
                    coordinate("Anchura", text: $model.input.width)
                    coordinate("Altura", text: $model.input.height)
                    Stepper("Rango máximo: \(model.input.rank)", value: $model.input.rank, in: 2...4)
                    Text("1 × 1 es un cuadrado. Un rango mayor explora más construcciones. El rango expresa la complejidad de la construcción; el número de diagramas puede ser diferente.")
                        .font(.caption).foregroundStyle(.secondary)
                }.disabled(model.isSearching)
                Section {
                    if model.isSearching {
                        HStack(spacing: 12) { ProgressView(); Text("Construyendo y buscando referencias…") }
                            .accessibilityElement(children: .combine)
                        Button("Cancelar", role: .cancel) { model.cancel() }
                    } else {
                        Button { editing = false; model.search() } label: {
                            Label("Encontrar pliegues", systemImage: "sparkle.magnifyingglass")
                                .frame(maxWidth: .infinity).font(.headline)
                        }
                    }
                    if let error = model.error { Text(error).foregroundStyle(.red).accessibilityLabel("Error: " + error) }
                }
                if let response = model.response, let solutions = response.solutions {
                    Section {
                        if let request = model.lastInput {
                            Text(request.summary).font(.subheadline)
                            Text("Papel \(request.width) × \(request.height) · rango máximo \(request.rank)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if solutions.isEmpty { Text("No se encontraron soluciones con estos límites.") }
                        ForEach(Array(solutions.enumerated()), id: \.offset) { index, solution in
                            NavigationLink {
                                SolutionView(solution: solution, number: index+1, input: model.lastInput ?? model.input)
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Solución \(index+1)").font(.headline)
                                    Text("Rango \(solution.rank) · \(solution.steps.count) diagramas")
                                        .font(.subheadline)
                                    Text("Error: \(solution.error.formatted(.number.precision(.significantDigits(1...6))))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }.padding(.vertical, 4)
                            }
                        }
                        Text("Base: \(response.marks ?? 0) puntos y \(response.lines ?? 0) rectas. Los resultados son aproximaciones; el error se expresa en las unidades del papel. La búsqueda está limitada a 100 000 puntos y 100 000 rectas.")
                            .font(.caption).foregroundStyle(.secondary)
                    } header: { Text("Soluciones") }
                }
                if !model.history.isEmpty {
                    Section("Búsquedas recientes") {
                        ForEach(Array(model.history.enumerated()), id: \.offset) { _, request in
                            Button { model.input = request; model.response = nil; model.error = nil } label: {
                                VStack(alignment: .leading) {
                                    Text(request.summary)
                                    Text("\(request.width) × \(request.height) · rango \(request.rank)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        Button("Borrar historial", role: .destructive) { model.clearHistory() }
                    }.disabled(model.isSearching)
                }
                Section {
                    Text("Motor original: Robert J. Lang · Adaptación histórica para iPhone: Jérôme Laheurte · Subido para iOS por Ángel Soto.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Origami Reference Finder")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAbout = true } label: { Image(systemName: "info.circle") }
                        .accessibilityLabel("Ayuda y créditos")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer(); Button("Listo") { editing = false }
                }
            }
            .sheet(isPresented: $showingAbout) { AboutView() }
        }
    }
    private func coordinate(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, text: text)
                .multilineTextAlignment(.trailing).textInputAutocapitalization(.never)
                .autocorrectionDisabled().keyboardType(.asciiCapable)
                .focused($editing).frame(maxWidth: 180)
                .accessibilityLabel(label)
        }
    }
}

struct SolutionView: View {
    let solution: FoldSolution
    let number: Int
    let input: SearchInput
    @State private var stepIndex = 0

    private var shareText: String {
        "Origami Reference Finder — \(input.summary)\nPapel: \(input.width) × \(input.height)\nRango: \(solution.rank)\nError: \(solution.error)\n\n\(solution.instructions)\n\nMotor: Robert J. Lang. Subido para iOS por Ángel Soto."
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(input.summary).font(.title3.bold())
                Text("Error \(solution.error.formatted(.number.precision(.significantDigits(1...6)))) · rango \(solution.rank)")
                    .foregroundStyle(.secondary)
                if !solution.steps.isEmpty {
                    let step = solution.steps[min(stepIndex, solution.steps.count-1)]
                    Text("Paso \(stepIndex+1) de \(solution.steps.count)").font(.headline)
                    DiagramView(svg: step.svg)
                        .frame(height: 320).background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.gray.opacity(0.2)))
                        .accessibilityLabel("Diagrama del paso \(stepIndex+1). \(step.caption)")
                    Text(step.caption).font(.body).textSelection(.enabled)
                    HStack {
                        Button { stepIndex -= 1 } label: { Label("Anterior", systemImage: "chevron.left") }
                            .disabled(stepIndex == 0)
                        Spacer()
                        Button { stepIndex += 1 } label: { Label("Siguiente", systemImage: "chevron.right") }
                            .disabled(stepIndex == solution.steps.count-1)
                    }.buttonStyle(.bordered)
                } else {
                    Label("Esta referencia ya existe en el papel inicial.", systemImage: "checkmark.circle")
                }
                Text("Leyenda").font(.headline)
                Text("Azul: referencias que debes alinear. Rojo discontinuo: nuevo pliegue de valle. Gris: pliegues previos. Las flechas indican el movimiento del papel.")
                    .font(.subheadline).foregroundStyle(.secondary)
                DisclosureGroup("Ver todas las instrucciones") {
                    Text(solution.instructions).font(.body.monospaced()).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                }
                Text("Las instrucciones geométricas del motor original se conservan en inglés.")
                    .font(.caption).foregroundStyle(.secondary)
                ShareLink(item: shareText) { Label("Compartir instrucciones", systemImage: "square.and.arrow.up") }
                    .buttonStyle(.borderedProminent)
            }.padding().frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
        }.navigationTitle("Solución \(number)").navigationBarTitleDisplayMode(.inline)
    }
}

// Local SVG only; no remote pages, scripts, or network resources.
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
        web.loadHTMLString("""
        <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'">
        <style>html,body{margin:0;width:100%;height:100%;background:white}svg{display:block}</style>
        </head><body>\(svg)</body></html>
        """, baseURL: nil)
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var svg = "" }
}
