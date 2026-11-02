import Foundation
import UIKit
import WebKit
import SwiftUI
import PDFKit

// CP-only PDF export. No external services are required; SVG diagrams are
// rendered by a local WKWebView with JavaScript disabled.
@MainActor
enum CPPDFExporter {
    private struct PlacedImage {
        let image: UIImage
        let frame: CGRect
        let step: Int
    }
    private struct PlacedHeading {
        let title: String
        let y: CGFloat
    }
    private struct Page {
        var headings: [PlacedHeading] = []
        var diagrams: [PlacedImage] = []
    }

    private static let width: CGFloat = 595.28
    private static let height: CGFloat = 841.89
    private static let margin: CGFloat = 42
    private static let footerY: CGFloat = 810
    private static let columns = 3
    private static let gap: CGFloat = 12
    private static let tile: CGFloat = (width - 2 * margin - 2 * gap) / 3
    private static let rowHeight: CGFloat = tile + 21
    private static let lineColors: [UIColor] = [.systemPurple, .systemBlue, .systemRed,
                                                 .systemGreen, .systemOrange, .systemPink,
                                                 .systemTeal, .systemIndigo]

    static func create(image: UIImage, region: CGRect,
                       references: [CPReference], solutions: [[FoldSolution]],
                       chosenRoutes: [Int?], title: String) async throws -> URL {
        guard references.count == solutions.count && chosenRoutes.count == references.count else {
            throw ExportError.invalidReferences
        }
        let converter = CPDiagramSnapshotter()
        var pages = [Page()]
        var y: CGFloat = 235

        var pointNumber = 0
        var lineNumber = 0
        for (index, reference) in references.enumerated() {
            if reference.endpoint == nil { pointNumber += 1 } else { lineNumber += 1 }
            let label = reference.endpoint == nil ? "POINT \(pointNumber)" : "LINE \(lineNumber)"
            let available = solutions[index]
            guard !available.isEmpty else { continue }
            let bestIndex = available.indices.min { a, b in
                let lhs = available[a]
                let rhs = available[b]
                if lhs.error != rhs.error { return lhs.error < rhs.error }
                if lhs.steps.count != rhs.steps.count { return lhs.steps.count < rhs.steps.count }
                return a < b
            }!
            let routeIndex = chosenRoutes[index].flatMap { available.indices.contains($0) ? $0 : nil } ?? bestIndex
            let route = available[routeIndex]
            do {
                if y + 32 + rowHeight > footerY - 22 {
                    pages.append(Page()); y = margin + 18
                }
                pages[pages.count - 1].headings.append(
                    PlacedHeading(title: "\(label)  ·  ROUTE \(routeIndex + 1)", y: y))
                y += 31
                for (stepIndex, step) in route.steps.enumerated() {
                    let column = stepIndex % columns
                    if column == 0 && y + rowHeight > footerY - 15 {
                        pages.append(Page()); y = margin + 18
                        pages[pages.count - 1].headings.append(
                            PlacedHeading(title: "\(label)  ·  ROUTE \(routeIndex + 1) (continued)", y: y))
                        y += 31
                    }
                    guard let originalDiagram = await converter.render(step.svg) else {
                        throw ExportError.invalidDiagram
                    }
                    // Highlight the target segment only on the LAST step of a line.
                    // This overlay does not alter the actual construction diagrams.
                    let diagram: UIImage
                    if stepIndex == route.steps.count - 1, let end = reference.endpoint {
                        diagram = highlightSegment(on: originalDiagram,
                                                  from: reference.position, to: end,
                                                  color: lineColors[(lineNumber - 1) % lineColors.count])
                    } else {
                        diagram = originalDiagram
                    }
                    let x = margin + CGFloat(column) * (tile + gap)
                    pages[pages.count - 1].diagrams.append(
                        PlacedImage(image: diagram,
                                    frame: CGRect(x: x, y: y, width: tile, height: tile),
                                    step: stepIndex + 1))
                    if column == columns - 1 || stepIndex == route.steps.count - 1 {
                        y += rowHeight
                    }
                }
                y += 14
            }
        }

        let original = image
        let annotated = annotatedCP(image: image, region: region, references: references)
        let pdf = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: width, height: height))
        let data = pdf.pdfData { context in
            for index in pages.indices {
                context.beginPage()
                drawText("ORIGAMI REFERENCE FINDER  |  CP POINTS",
                         at: CGPoint(x: margin, y: 23), font: .boldSystemFont(ofSize: 13))
                if index == 0 {
                    drawText(title.isEmpty ? "Crease pattern" : title,
                             at: CGPoint(x: margin, y: 46), font: .systemFont(ofSize: 10),
                             color: .darkGray)
                    let side: CGFloat = 170
                    let x1 = margin
                    let x2 = width - margin - side
                    drawFitted(original, in: CGRect(x: x1, y: 70, width: side, height: side - 12))
                    drawFitted(annotated, in: CGRect(x: x2, y: 70, width: side, height: side - 12))
                    drawText("Original CP", at: CGPoint(x: x1, y: 222),
                             font: .systemFont(ofSize: 9))
                    drawText("Annotated CP", at: CGPoint(x: x2, y: 222),
                             font: .systemFont(ofSize: 9))
                }
                for heading in pages[index].headings {
                    drawText(heading.title, at: CGPoint(x: margin, y: heading.y),
                             font: .boldSystemFont(ofSize: 11))
                }
                for entry in pages[index].diagrams {
                    UIColor.lightGray.setStroke()
                    UIBezierPath(roundedRect: entry.frame, cornerRadius: 3).stroke()
                    drawFitted(entry.image, in: entry.frame.insetBy(dx: 2, dy: 2))
                    drawText("Step \(entry.step)",
                             at: CGPoint(x: entry.frame.minX + 5, y: entry.frame.maxY + 2),
                             font: .systemFont(ofSize: 8), color: .darkGray)
                }
                UIColor.lightGray.setStroke()
                let line = UIBezierPath()
                line.move(to: CGPoint(x: margin, y: footerY - 9))
                line.addLine(to: CGPoint(x: width - margin, y: footerY - 9))
                line.stroke()
                drawText("ReferenceFinder · Robert J. Lang",
                         at: CGPoint(x: margin, y: footerY), font: .systemFont(ofSize: 8),
                         color: .darkGray)
                drawText("Page \(index + 1) of \(pages.count)",
                         at: CGPoint(x: width - margin - 80, y: footerY),
                         font: .systemFont(ofSize: 8), color: .darkGray)
            }
        }
        let name = "CP_Points_\(UUID().uuidString).pdf"
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: destination, options: .atomic)
        return destination
    }

    // The engine's SVG is a square sheet (0...1) viewed through the
    // viewBox (-0.12, -0.12, 1.24, 1.24). CP coordinates have a top-left origin.
    // Draw exactly the finite endpoint-to-endpoint target segment, never the
    // infinitely extended construction line.
    private static func highlightSegment(on original: UIImage,
                                         from start: CGPoint, to end: CGPoint,
                                         color: UIColor) -> UIImage {
        let canvasSize = original.size
        let scale = min(canvasSize.width, canvasSize.height)
        guard scale > 0 else { return original }
        let factor: CGFloat = 1.24
        func project(_ point: CGPoint) -> CGPoint {
            CGPoint(x: (point.x + 0.12) / factor * canvasSize.width,
                    y: (point.y + 0.12) / factor * canvasSize.height)
        }
        let a = project(start)
        let b = project(end)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { _ in
            original.draw(in: CGRect(origin: .zero, size: canvasSize))
            let path = UIBezierPath()
            path.move(to: a)
            path.addLine(to: b)
            path.lineWidth = max(2, scale * 0.007)
            path.lineCapStyle = .round
            color.withAlphaComponent(0.90).setStroke()
            path.stroke()
            for marker in [a, b] {
                let radius = max(3, scale * 0.010)
                color.setFill()
                UIBezierPath(ovalIn: CGRect(x: marker.x - radius, y: marker.y - radius,
                                            width: radius * 2, height: radius * 2)).fill()
            }
        }
    }

    private static func drawText(_ string: String, at point: CGPoint, font: UIFont,
                                 color: UIColor = .black) {
        (string as NSString).draw(at: point,
                                 withAttributes: [.font: font, .foregroundColor: color])
    }

    private static func drawFitted(_ image: UIImage, in rect: CGRect) {
        let factor = min(rect.width / max(1, image.size.width),
                         rect.height / max(1, image.size.height))
        let actual = CGSize(width: image.size.width * factor, height: image.size.height * factor)
        image.draw(in: CGRect(x: rect.midX - actual.width / 2,
                              y: rect.midY - actual.height / 2,
                              width: actual.width, height: actual.height))
    }

    private static func annotatedCP(image: UIImage, region: CGRect,
                                    references: [CPReference]) -> UIImage {
        let factor = min(1, 1400 / max(image.size.width, image.size.height, 1))
        let size = CGSize(width: image.size.width * factor, height: image.size.height * factor)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { result in
            image.draw(in: CGRect(origin: .zero, size: size))
            let context = result.cgContext
            let paper = CGRect(x: region.minX * size.width, y: region.minY * size.height,
                               width: region.width * size.width, height: region.height * size.height)
            context.setStrokeColor(UIColor.systemOrange.withAlphaComponent(0.85).cgColor)
            context.setLineWidth(2.5)
            context.setLineDash(phase: 0, lengths: [6, 4])
            context.stroke(paper)
            context.setLineDash(phase: 0, lengths: [])
            var pointIndex = 0
            var lineIndex = 0
            let colors: [UIColor] = [.systemPurple, .systemBlue, .systemRed, .systemGreen,
                                     .systemOrange, .systemPink, .systemTeal, .systemIndigo]
            for item in references {
                let start = CGPoint(x: (region.minX + item.position.x * region.width) * size.width,
                                    y: (region.minY + item.position.y * region.height) * size.height)
                var label = ""
                var center = start
                var fill = UIColor(red: 0.03, green: 0.43, blue: 0.48, alpha: 0.58)
                if let end = item.endpoint {
                    lineIndex += 1
                    label = "L\(lineIndex)"
                    let color = colors[(lineIndex - 1) % colors.count]
                    fill = color.withAlphaComponent(0.7)
                    let finish = CGPoint(x: (region.minX + end.x * region.width) * size.width,
                                         y: (region.minY + end.y * region.height) * size.height)
                    context.setStrokeColor(color.withAlphaComponent(0.65).cgColor)
                    context.setLineWidth(2.5)
                    context.move(to: start); context.addLine(to: finish); context.strokePath()
                    center = CGPoint(x: (start.x + finish.x) / 2, y: (start.y + finish.y) / 2)
                } else {
                    pointIndex += 1
                    label = "\(pointIndex)"
                }
                let diameter: CGFloat = item.endpoint == nil ? 20 : 25
                let box = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                                 width: diameter, height: diameter)
                context.setFillColor(fill.cgColor)
                context.fillEllipse(in: box)
                let text = label as NSString
                let font = UIFont.boldSystemFont(ofSize: item.endpoint == nil ? 12 : 11)
                let attrs: [NSAttributedString.Key: Any] =
                    [.font: font, .foregroundColor: UIColor.white]
                let length = text.size(withAttributes: attrs)
                text.draw(at: CGPoint(x: center.x - length.width / 2,
                                      y: center.y - length.height / 2), withAttributes: attrs)
            }
        }
    }

    private enum ExportError: LocalizedError {
        case invalidReferences, invalidDiagram
        var errorDescription: String? {
            switch self {
            case .invalidReferences: return "CP targets and results do not match."
            case .invalidDiagram: return "A folding diagram could not be rendered."
            }
        }
    }
}

@MainActor
private final class CPDiagramSnapshotter: NSObject, WKNavigationDelegate {
    private var pending: CheckedContinuation<UIImage?, Never>?
    private var web: WKWebView?
    func render(_ svg: String) async -> UIImage? {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 440, height: 440),
                             configuration: config)
        view.navigationDelegate = self
        view.isOpaque = false
        view.backgroundColor = .white
        web = view
        return await withCheckedContinuation { continuation in
            pending = continuation
            let html = "<html><head><meta name='viewport' content='width=device-width,initial-scale=1'></head><body style='margin:0;background:white;width:440px;height:440px'>\(svg)</body></html>"
            view.loadHTMLString(html, baseURL: nil)
        }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let config = WKSnapshotConfiguration()
        config.rect = CGRect(x: 0, y: 0, width: 440, height: 440)
        webView.takeSnapshot(with: config) { [weak self] image, _ in
            guard let self else { return }
            self.pending?.resume(returning: image)
            self.pending = nil
            self.web = nil
        }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        pending?.resume(returning: nil); pending = nil; web = nil
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        pending?.resume(returning: nil); pending = nil; web = nil
    }
}


struct CPPDFPreviewView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CPPDFKitView(url: url)
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle("CP PDF preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ShareLink(item: url) {
                            Label("Share / Save", systemImage: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

private struct CPPDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayDirection = .vertical
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .systemGroupedBackground
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
            view.autoScales = true
        }
    }
}
