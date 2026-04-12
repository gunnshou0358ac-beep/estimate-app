import Foundation
import PDFKit
import Vision

// Usage: swift ocr_pdf.swift <pdf_path> <page_index>
// Outputs JSON array of {text, x, y, width, height} with normalized coords

func recognizeTextWithBoxes(in image: CGImage, completion: @escaping ([[String: Any]]) -> Void) {
    let request = VNRecognizeTextRequest { request, error in
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            completion([])
            return
        }
        var items: [[String: Any]] = []
        for obs in observations {
            guard let candidate = obs.topCandidates(1).first else { continue }
            let box = obs.boundingBox
            items.append([
                "text": candidate.string,
                "x": box.minX,
                "y": box.minY,
                "w": box.width,
                "h": box.height
            ])
        }
        completion(items)
    }
    request.recognitionLanguages = ["ja", "en"]
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false

    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    try? handler.perform([request])
}

guard CommandLine.arguments.count >= 3 else {
    print("[]")
    exit(1)
}

let pdfPath = CommandLine.arguments[1]
let pageIndex = Int(CommandLine.arguments[2]) ?? 0

guard let url = URL(string: "file://" + pdfPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!),
      let doc = PDFDocument(url: url),
      let page = doc.page(at: pageIndex) else {
    print("[]")
    exit(1)
}

let bounds = page.bounds(for: .mediaBox)
let scale: CGFloat = 200.0 / 72.0
let width = Int(bounds.width * scale)
let height = Int(bounds.height * scale)

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil, width: width, height: height,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { print("[]"); exit(1) }

context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: width, height: height))
context.scaleBy(x: scale, y: scale)

let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.current = nsContext
page.draw(with: .mediaBox, to: context)

guard let cgImage = context.makeImage() else { print("[]"); exit(1) }

let sema = DispatchSemaphore(value: 0)
var result: [[String: Any]] = []

recognizeTextWithBoxes(in: cgImage) { items in
    result = items
    sema.signal()
}
sema.wait()

let data = try! JSONSerialization.data(withJSONObject: result)
print(String(data: data, encoding: .utf8)!)
