import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("Cómo utilizarla") {
                    Text("1. Indica un punto (X, Y) o una recta mediante dos puntos distintos.")
                    Text("2. Usa un cuadrado 1 × 1 o ajusta las dimensiones del rectángulo. Las coordenadas usan las mismas unidades.")
                    Text("3. Pulsa Encontrar pliegues y elige una de las soluciones. Sigue los diagramas con Anterior y Siguiente.")
                    Text("Puedes escribir 1/3, sqrt(2)/2, sin(deg2rad(30)) o (1+sqrt(5))/4. El origen está abajo a la izquierda.")
                    Text("La búsqueda es finita y puede devolver una aproximación. No se garantiza la construcción óptima ni exacta para cualquier coordenada.")
                }
                Section("Créditos") {
                    credit("Robert J. Lang", "Creador de ReferenceFinder y autor del motor geométrico y de búsqueda original.")
                    credit("Carlos A. Furuti", "Analizador de expresiones matemáticas del motor original.")
                    credit("Jérôme Laheurte", "Autor de la adaptación histórica ReferenceFinder 4 para iPhone (2009). Su código se estudió como referencia; esta interfaz se ha escrito de nuevo.")
                    credit("Mu-Tsun Tsai", "Crédito por la corrección del motor señalada por Robert J. Lang en su actualización de 2024.")
                    Text("Subido para iOS por Ángel Soto").font(.headline)
                    credit("HuxleyBerry", "Repositorio web revisado como referencia técnica. No se incorpora su código a esta aplicación.")
                }
                Section("Fuentes y licencia") {
                    Link("ReferenceFinder · Robert J. Lang", destination: URL(string: "https://langorigami.com/article/referencefinder/")!)
                    Link("Código del motor oficial", destination: URL(string: "https://github.com/bugfolder/ReferenceFinder")!)
                    Link("Repositorio de HuxleyBerry", destination: URL(string: "https://github.com/HuxleyBerry/origami-reference-finder")!)
                    NavigationLink("Licencia GNU GPLv2") { LicenseView() }
                    Text("Este proyecto incorpora software GPLv2 y conserva sus avisos de autoría. Sin garantía. Esta versión es independiente; no implica respaldo de los autores originales.")
                        .font(.footnote)
                }
                Section("Privacidad") {
                    Text("Las búsquedas y los diagramas se calculan en el dispositivo. El historial se guarda únicamente en el almacenamiento local de la app y puedes borrarlo desde la pantalla principal. No hay cuentas, anuncios, analítica ni servidores propios. Compartir y abrir enlaces son acciones voluntarias.")
                }
                Section { Text("Origami Reference Finder 1.0 · Subido para iOS por Ángel Soto").font(.footnote) }
            }.navigationTitle("Ayuda y créditos")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { dismiss() } } }
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
            return "No se ha podido cargar la licencia. Consulta el archivo LICENSE.txt del código fuente."
        }
        return text
    }
    var body: some View {
        ScrollView { Text(license).font(.footnote.monospaced()).textSelection(.enabled).padding() }
            .navigationTitle("GNU GPLv2")
    }
}
