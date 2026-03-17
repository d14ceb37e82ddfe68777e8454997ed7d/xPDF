import PDFKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct xPDF: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var importing = false
    @State private var document: PDFDocument?
    @State private var scale = 4.0

    var body: some View {
        NavigationSplitView {
            Button("Import") {
                importing = true
            }.fileImporter(
                isPresented: $importing,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                let url = try! result.get()[0]
                if url.startAccessingSecurityScopedResource() {
                    document = PDFDocument(url: url)
                    url.stopAccessingSecurityScopedResource()
                }
            }
        } detail: {
            if let document = document, let documentURL = document.documentURL {
                VStack {
                    Text("Path:\(documentURL.path(percentEncoded: false))")
                    Text("Number of pages:\(document.pageCount)")
                    HStack {
                        Text("Scale:\(scale)")
                        Slider(value: $scale, in: 1...8, step: 0.5)
                    }
                    Button("Export") {
                        let downloadsURL = try! FileManager.default.url(
                            for: .downloadsDirectory,
                            in: .userDomainMask,
                            appropriateFor: nil,
                            create: false
                        )

                        let directoryURL =
                            downloadsURL.appending(component: "xPDF")
                            .appending(component: UUID().uuidString)

                        try! FileManager.default
                            .createDirectory(
                                at: directoryURL,
                                withIntermediateDirectories: true
                            )

                        for i in 0..<document.pageCount {
                            writePage(
                                page: document.page(at: i)!,
                                url: directoryURL.appending(
                                    component: "\(i+1).png"
                                ),
                                scale: scale
                            )
                        }
                        NSWorkspace.shared.open(directoryURL)
                        self.document = nil
                    }
                }
            }
        }
    }
}

func writePage(page: PDFPage, url: URL, scale: CGFloat) {
    page.toCGImage(scale: scale)
        .saveAsPNG(url: url)
}

extension PDFPage {
    func toCGImage(scale: CGFloat) -> CGImage {
        let rect = self.bounds(for: .mediaBox)
        return self.toCGImage(
            width: Int(rect.width * scale),
            height: Int(rect.height * scale),
            scale: scale
        )
    }

    func toCGImage(width: Int, height: Int, scale: CGFloat) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 4 * width,
            space: CGColorSpace(name: CGColorSpace.sRGB),
            bitmapInfo: CGBitmapInfo(alpha: CGImageAlphaInfo.premultipliedLast)
        )!
        context.scaleBy(x: scale, y: scale)
        self.draw(with: .mediaBox, to: context)
        return context.makeImage()!
    }
}

extension CGImage {
    func saveAsPNG(url: URL) {
        let imageDestination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )!
        CGImageDestinationAddImage(imageDestination, self, nil)
        CGImageDestinationFinalize(imageDestination)
    }
}
