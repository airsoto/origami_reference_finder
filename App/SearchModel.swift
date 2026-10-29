import Foundation

struct FoldStep: Decodable, Identifiable {
    var id: String { svg + caption }
    let caption: String
    let svg: String
}
struct FoldSolution: Decodable, Identifiable {
    var id: String { instructions }
    let rank: Int
    let error: Double
    let instructions: String
    let steps: [FoldStep]
}
struct SearchResponse: Decodable {
    let error: String?
    let marks: Int?
    let lines: Int?
    let solutions: [FoldSolution]?
}

struct SearchInput: Codable, Equatable {
    var x = "1/3"
    var y = "1/3"
    var x2 = "1"
    var y2 = "1/3"
    var width = "1"
    var height = "1"
    var line = false
    var rank = 3
    var summary: String { line ? "Line (\(x), \(y)) → (\(x2), \(y2))" : "Point (\(x), \(y))" }
}

@MainActor
final class SearchModel: ObservableObject {
    @Published var input = SearchInput()
    @Published var isSearching = false
    @Published var error: String?
    @Published var response: SearchResponse?
    @Published var lastInput: SearchInput?
    @Published var history: [SearchInput] = []
    private let queue = DispatchQueue(label: "es.angelsoto.origami.engine", qos: .userInitiated)
    private var resultsCache: [(SearchInput, SearchResponse)] = []
    private let historyKey = "origami.recent.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let saved = try? JSONDecoder().decode([SearchInput].self, from: data) {
            history = Array(saved.prefix(12))
        }
    }
    func search() {
        guard !isSearching else { return }
        let request = input
        if let cached = resultsCache.first(where: { $0.0 == request }) {
            response = cached.1; lastInput = request; error = nil
            remember(request)
            return
        }
        isSearching = true; error = nil; response = nil
        queue.async {
            let result = RFBridge.search(x: request.x, y: request.y, x2: request.x2,
                y2: request.y2, width: request.width, height: request.height,
                line: request.line, rank: request.rank)
            let decoded = try? JSONDecoder().decode(SearchResponse.self, from: Data(result.utf8))
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isSearching = false
                guard let decoded else { self.error = "Unable to read the search results. Please try again."; return }
                if let error = decoded.error { self.error = error; return }
                self.response = decoded; self.lastInput = request
                self.resultsCache.insert((request, decoded), at: 0)
                self.resultsCache = Array(self.resultsCache.prefix(8))
                self.remember(request)
            }
        }
    }
    private func remember(_ request: SearchInput) {
        history.removeAll { $0 == request }
        history.insert(request, at: 0)
        history = Array(history.prefix(12))
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
    func cancel() { RFBridge.cancel() }
    func clearHistory() {
        history = []; resultsCache = []; UserDefaults.standard.removeObject(forKey: historyKey)
    }
}
