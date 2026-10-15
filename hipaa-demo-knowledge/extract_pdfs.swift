import Foundation
import PDFKit

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1] : "hipaa-documents")
let source = root.appendingPathComponent("sources/hhs")
let output = root.appendingPathComponent("prepared/pdf-text")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let manifestData = try Data(contentsOf: source.appendingPathComponent("manifest.json"))
let manifest = try JSONSerialization.jsonObject(with: manifestData) as! [String: Any]
let records = manifest["records"] as! [String: [String: Any]]
var inputs = records.map { url, record -> [String: Any] in
    var input = record
    input["url"] = url
    input["relative_source"] = "sources/hhs/" + (record["path"] as? String ?? "")
    return input
}
let regulationManifest = try JSONSerialization.jsonObject(
    with: Data(contentsOf: root.appendingPathComponent("manifest.json"))) as! [String: Any]
for record in regulationManifest["files"] as! [[String: Any]] {
    guard let path = record["path"] as? String, path.hasSuffix(".pdf") else { continue }
    inputs.append([
        "url": record["source_url"] as! String, "status": 200,
        "path": URL(fileURLWithPath: path).lastPathComponent,
        "relative_source": path, "sha256": record["sha256"] as! String,
        "content_type": "application/pdf"
    ])
}
let supplementalURL = root.appendingPathComponent("sources/supplemental/manifest.json")
let supplemental = try JSONSerialization.jsonObject(
    with: Data(contentsOf: supplementalURL)) as! [String: Any]
for record in supplemental["files"] as! [[String: Any]] {
    let path = record["path"] as! String
    inputs.append([
        "url": record["source_url"] as! String, "status": 200,
        "path": URL(fileURLWithPath: path).lastPathComponent,
        "relative_source": path, "sha256": record["sha256"] as! String,
        "content_type": "application/pdf"
    ])
}
var count = 0
for record in inputs.sorted(by: { ($0["url"] as! String) < ($1["url"] as! String) }) {
    let url = record["url"] as! String
    guard record["status"] as? Int == 200,
          (record["content_type"] as? String ?? "").hasPrefix("application/pdf"),
          let name = record["path"] as? String else { continue }
    let relativeSource = record["relative_source"] as! String
    guard let document = PDFDocument(url: root.appendingPathComponent(relativeSource)),
          document.pageCount > 0 else {
        throw NSError(domain: "HIPAAExtraction", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Invalid PDF: \(url)"])
    }
    var pages = [String]()
    var missing = [Int]()
    for index in 0..<document.pageCount {
        guard let page = document.page(at: index) else {
            throw NSError(domain: "HIPAAExtraction", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Unreadable page: \(url)"])
        }
        let text = page.string ?? ""
        pages.append(text)
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missing.append(index + 1)
        }
    }
    let payload: [String: Any] = [
        "url": url, "source_path": relativeSource,
        "source_sha256": record["sha256"] as! String,
        "pages": pages, "pages_without_text": missing,
        "extraction": "macOS PDFKit; no OCR; original page order"
    ]
    let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    try data.write(to: output.appendingPathComponent(name + ".json"), options: .atomic)
    count += 1
}
print("Extracted \(count) official PDF responses to ignored local storage; missing text pages are explicit.")
