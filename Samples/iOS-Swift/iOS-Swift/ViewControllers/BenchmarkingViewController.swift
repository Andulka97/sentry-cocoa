import BigInt
import CryptoKit
import Sentry
import UIKit
import SwiftUI

class BenchmarkingViewController: UIViewController {
    private let imageView = UIImageView(frame: .zero)

    private lazy var scenarioSelectionTableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "ScenarioCell")
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.delegate = self
        return tv
    }()

    private lazy var scrollScenarioTableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        return tv
    }()

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        addTableView(scenarioSelectionTableView)

        view.backgroundColor = .white
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let session = URLSession(configuration: .default)

    var testTextString: String {
        try! String(contentsOf: testFileURL)
    }

    var testData: Data {
        try! Data(contentsOf: testFileURL)
    }

    var testFileURL: URL {
        Bundle.main.url(forResource: "huge", withExtension: "json")!
    }
}

// MARK: Helpers
private extension BenchmarkingViewController {
    func inBenchmarkedTransaction(for scenario: Scenario, block: () -> Void) {
        let span = startTest(scenario: scenario)
        block()
        stopTest(span: span)
    }

    func startTest(scenario: Scenario) -> Span {
        let span = SentrySDK.startTransaction(name: scenario.transactionName, operation: scenario.operation)
        SentryBenchmarking.startBenchmark()
        return span
    }

    func stopTest(span: Span, cleanup: (() -> Void)? = nil) {
        func showAlert(with result: String) {
            let alert = UIAlertController(title: "Benchmark results", message: nil, preferredStyle: .alert)
            alert.addTextField {
                $0.accessibilityLabel = "io.sentry.benchmark.value-marshaling-text-field"
                $0.text = result
            }
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }

        defer {
            cleanup?()
            span.finish()
        }

        guard let value = SentryBenchmarking.stopBenchmark() else {
            showAlert(with: "Only one CPU sample was taken, can't calculate benchmark deltas.")
            return
        }

        showAlert(with: "\(value)")
    }
}

// MARK: Scenarios
private extension BenchmarkingViewController {
    enum Scenario: String, CaseIterable {
        case cpu_idle

        /// Compute a factorial.
        case cpu_work

        /// Write a large amount of text to disk
        case fileIO_write

        /// Read a large file from disk
        case fileIO_read

        case fileIO_copy
        case fileIO_delete

        /// Compress a large amount of data
        case data_compress

        /// Encrypt a large amount of data
//        case data_encrypt
//        case data_decrypt

        /// Compute the SHA sum of a large amount of data
        case data_shasum

        case data_json_serialize
        case data_json_deserialize

        /*
         TODO: implement the functions for these the following suggested cases:

        /// Scroll a table view containing basic cells containing lorem ipsum text.
        case scrollTableView

        /// Render an image in a `UIImageView`.
        case renderImage

        /// Download a file from the Internet.
        case network_download
        case network_upload
        case network_stream_up
        case network_stream_down
        case network_stream_both

        /// Render a website in a view containing a `WKWebView`.
        case renderWebpageInWebKit

        case coreData_loadDB_Empty
        case coreData_loadDB_WithEntities

        case coreData_entity_create
        case coreData_entity_fetch
        case coreData_entity_update
        case coreData_entity_delete
         */

        // TODO: more scenarios, basic components of apps, Apple framework (e.g. CoreImage, CoreLocation), combinations of components like CoreData/Networking/UICollectionView, etc

        var transactionName: String {
            "\(operation).\(rawValue)"
        }

        var operation: String {
            "io.sentry.ios-swift.benchmark"
        }

        static var sections: [(name: String, rows: [Scenario])] =
        [
            ("CPU", [.cpu_work, .cpu_idle]),
            ("File I/O", [.fileIO_write, .fileIO_read, .fileIO_copy, .fileIO_delete]),
//            ("UIKit", [.scrollTableView, .renderImage]),
            ("JSON", [.data_json_serialize, .data_json_deserialize]),
//            ("Networking", [.network_download, .network_upload, .network_stream_up, .network_stream_down, .network_stream_both]),
//            ("WebKit", [.renderWebpageInWebKit]),
//            ("CoreData", [.coreData_loadDB_Empty, .coreData_loadDB_WithEntities, .coreData_entity_create, .coreData_entity_fetch, .coreData_entity_update, .coreData_entity_delete]),
            ("Data", [.data_compress, /*.data_encrypt, .data_decrypt,*/ .data_shasum]),
        ]
    }

    func info(for scenario: Scenario) -> (description: String, action: () -> Void) {
        switch scenario {
        case .fileIO_write: return ("File write", writeFile)
        case .fileIO_read: return ("File read", readFile)
        case .fileIO_copy: return ("File copy", readFile)
        case .fileIO_delete: return ("File delete", readFile)
//        case .scrollTableView: return ("Scroll UITableView", scrollTableView)
//        case .renderImage: return ("Render image", renderImage)
//        case .network_download: return ("Network download", networkDownload)
//        case .network_upload: return ("Network upload", networkUpload)
//        case .network_stream_up: return ("Network stream up", networkStreamUp)
//        case .network_stream_down: return ("Network stream down", networkStreamDown)
//        case .network_stream_both: return ("Network stream mixed", networkStreamBoth)
//        case .renderWebpageInWebKit: return ("WebKit render", webkitRender)
//        case .coreData_loadDB_Empty: return ("Load empty DB", loadEmptyDB)
//        case .coreData_loadDB_WithEntities: return ("Load DB with entities", loadDBWithEntities)
//        case .coreData_entity_create: return ("Create entity", createEntity)
//        case .coreData_entity_fetch: return ("Fetch entity", fetchEntity)
//        case .coreData_entity_update: return ("Update entity", updateEntity)
//        case .coreData_entity_delete: return ("Delete entity", deleteEntity)
        case .cpu_work: return ("CPU work", factorial)
        case .cpu_idle: return ("CPU idle", cpuIdle)
        case .data_compress: return ("Data compression", dataCompress)
//        case .data_encrypt: return ("Data encrypt", dataEncrypt)
//        case .data_decrypt: return ("Data decrypt", dataDecrypt)
        case .data_shasum: return ("Data SHA1 sum", dataSHA)
        case .data_json_serialize: return ("JSON Encode", jsonEncode)
        case .data_json_deserialize: return ("JSON Decode", jsonDecode)
        }
    }

    func sectionInfo(for scenario: Scenario) -> (index: NSInteger, name: String) {
        switch scenario {
        case .cpu_work, .cpu_idle: return (0, "CPU")
        case .fileIO_write, .fileIO_read, .fileIO_copy, .fileIO_delete: return (1, "File I/O")
//        case .scrollTableView, .renderImage: return (2, "UI Events")
        case .data_json_serialize, .data_json_deserialize: return (2, "JSON")
//        case .network_download, .network_upload, .network_stream_up, .network_stream_down, .network_stream_both: return (3, "Networking")
//        case .renderWebpageInWebKit: return (4, "WebKit")
//        case .coreData_loadDB_Empty, .coreData_loadDB_WithEntities, .coreData_entity_create, .coreData_entity_fetch, .coreData_entity_update, .coreData_entity_delete: return (5, "CoreData")
        case .data_compress, /*.data_encrypt, .data_decrypt,*/ .data_shasum: return (6, "Data")
        }
    }
}

// MARK: CPU
private extension BenchmarkingViewController {

    func factorial() {
        func _factorial(x: BigInt) -> BigInt {
            (1 ... x).map { BigInt($0) }.reduce(BigInt(1), *)
        }
        inBenchmarkedTransaction(for: .cpu_work) {
            let _ = _factorial(x: 10_000)
        }
    }

    func cpuIdle() {
        let span = startTest(scenario: .cpu_idle)
        SentryBenchmarking.startBenchmark()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.stopTest(span: span)
        }
    }
}

// MARK: File I/O
private extension BenchmarkingViewController {
    func writeFile() {
        let s = testTextString // do this before starting the span, we don't want to profile/benchmark the file read
        inBenchmarkedTransaction(for: .fileIO_write) {
            try! s.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mobydickcopy.txt"), atomically: false, encoding: String.Encoding.utf8)
        }
    }

    func readFile() {
        inBenchmarkedTransaction(for: .fileIO_read) {
            let _ = testTextString
        }
    }

    func copyFile() {
        inBenchmarkedTransaction(for: .fileIO_read) {
            try! FileManager.default.copyItem(at: testFileURL, to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mobydickcopy.txt"))
        }
    }

    func deleteFile() {
        var destinations = [URL]()
        let fm = FileManager.default
        let userDocuments = try! fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        for i in 1...100 {
            let copyURL = userDocuments.appendingPathComponent("mobydickcopy\(i)").appendingPathExtension("txt")
            destinations.append(copyURL)
            try! fm.copyItem(at: testFileURL, to: copyURL)
        }
        inBenchmarkedTransaction(for: .fileIO_read) {
            for i in 1...100 {
                try! fm.removeItem(at: destinations[i])
            }

        }
    }
}

// MARK: UIKit
extension BenchmarkingViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == scenarioSelectionTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ScenarioCell", for: indexPath)
            let scenario = Scenario.sections[indexPath.section].rows[indexPath.row]
            cell.textLabel?.text = info(for: scenario).description
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            cell.textLabel?.text = UUID().uuidString
            return cell
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        if tableView == scenarioSelectionTableView {
            return Scenario.sections.count
        } else {
            return 1
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if tableView == scenarioSelectionTableView {
            return Scenario.sections[section].name
        } else {
            return nil
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == scenarioSelectionTableView {
            return Scenario.sections[section].rows.count
        } else {
            return 10_000_000
        }
    }

    func addTableView(_ tv: UITableView) {
        view.addSubview(tv)
        var constraints = [
            tv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ]
        if #available(iOS 11.0, *) {
            constraints.append(contentsOf: [
                tv.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                tv.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
            ])
        } else {
            constraints.append(contentsOf: [
                tv.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
                tv.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor)
            ])
        }
        NSLayoutConstraint.activate(constraints)
    }

//    func scrollTableView() {
//        addTableView(scrollScenarioTableView)
//        scrollScenarioTableView.pintToSuperviewEdges()
//        let span = startTest(scenario: .scrollTableView)
//        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
//            self.stopTest(span: span) {
//                self.scrollScenarioTableView.removeFromSuperview()
//            }
//        }
//    }
//
//    func renderImage() {
//        inBenchmarkedTransaction(for: .renderImage) {
//            imageView.image = UIImage(imageLiteralResourceName: "Tongariro")
//        }
//    }
}

extension BenchmarkingViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView == scenarioSelectionTableView {
            let action = info(for: Scenario.sections[indexPath.section].rows[indexPath.row]).action
            action()
        }
    }
}

extension UIView {
    func pintToSuperviewEdges() {
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: superview!.topAnchor),
            bottomAnchor.constraint(equalTo: superview!.bottomAnchor),
            leadingAnchor.constraint(equalTo: superview!.leadingAnchor),
            trailingAnchor.constraint(equalTo: superview!.trailingAnchor)
        ])
    }
}

// MARK: Networking
private extension BenchmarkingViewController {
    func networkDownload() {
//        let span = startTest(scenario: .network_download)
//        let task = session.dataTask(with: URL(string: "https://ia801602.us.archive.org/11/items/Rick_Astley_Never_Gonna_Give_You_Up/Rick_Astley_Never_Gonna_Give_You_Up.mpg")!) { data, response, error in
//            span.finish()
//        }
//        task.resume()
    }

    func networkUpload() {

    }

    func networkStreamUp() {

    }

    func networkStreamDown() {

    }

    func networkStreamBoth() {

    }

    func networkWebSocketWrite() {

    }

    func networkWebSocketRead() {

    }

    func networkWebSocketOpen() {

    }

    func networkWebSocketClose() {

    }
}

extension BenchmarkingViewController: URLSessionDelegate {

}

extension BenchmarkingViewController: URLSessionDataDelegate {

}

extension BenchmarkingViewController: URLSessionTaskDelegate {

}

extension BenchmarkingViewController: URLSessionStreamDelegate {

}

extension BenchmarkingViewController: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    }
}

extension BenchmarkingViewController: URLSessionWebSocketDelegate {

}

// MARK: WebKit
private extension BenchmarkingViewController {
    func webkitRender() {

    }
}

// MARK: CoreData
private extension BenchmarkingViewController {
    func loadEmptyDB() {

    }

    func loadDBWithEntities() {

    }

    func createEntity() {

    }

    func fetchEntity() {

    }

    func updateEntity() {

    }

    func deleteEntity() {

    }
}

// MARK: Data
private extension BenchmarkingViewController {
    func dataCompress() {
        let data = testData
        inBenchmarkedTransaction(for: .data_compress) {
            let _ = try! (data as NSData).compressed(using: .lzma)
        }
    }

    func dataUncompress() {
        let data = testData
        let compressed = try! (data as NSData).compressed(using: .lzma)
        inBenchmarkedTransaction(for: .data_compress) {
            let _ = try! compressed.decompressed(using: .lzma)
        }
    }

    // !!!: currently crashes with error: invalid key size
//    func dataEncrypt() {
//        let data = testData
//        if #available(iOS 13.0, *) {
//            let keyString = UUID().uuidString + ISO8601DateFormatter().string(from: Date())
//            let key = SymmetricKey(data: Array(keyString.utf8))
//            let encrypted = try! CryptoKit.AES.GCM.seal(data, using: key)
//            inBenchmarkedTransaction(for: .data_encrypt) {
//                let _ = try! CryptoKit.AES.GCM.open(encrypted, using: key)
//            }
//        } else {
//            fatalError("Only available on iOS 13 or later.")
//        }
//    }
//
//    func dataDecrypt() {
//        let data = testData
//        if #available(iOS 13.0, *) {
//            let keyString = UUID().uuidString + ISO8601DateFormatter().string(from: Date())
//            let key = SymmetricKey(data: Array(keyString.utf8))
//            inBenchmarkedTransaction(for: .data_encrypt) {
//                let _ = try! CryptoKit.AES.GCM.seal(data, using: key)
//            }
//        } else {
//            fatalError("Only available on iOS 13 or later.")
//        }
//    }

    func dataSHA() {
        let data = testData
        if #available(iOS 13.0, *) {
            inBenchmarkedTransaction(for: .data_shasum) {
                
                var hasher = SHA256()
                hasher.update(data: data)
                let _ = hasher.finalize()
            }
        } else {
            fatalError("Only available on iOS 13 or later.")
        }
    }
}

// MARK: JSON

struct JSONEntry: Codable {
    var id: String
    var type: String
    var `public`: Bool
    var created_at: String
}

private extension BenchmarkingViewController {
    func jsonDecode() {
        let jsonData = try! Data(contentsOf: testFileURL)
        inBenchmarkedTransaction(for: .data_json_serialize) {
            let _ = try! JSONDecoder().decode([JSONEntry].self, from: jsonData)
        }
    }

    func jsonEncode() {
        let jsonData = try! Data(contentsOf: testFileURL)
        let decodedDict = try! JSONDecoder().decode([JSONEntry].self, from: jsonData)
        inBenchmarkedTransaction(for: .data_json_serialize) {
            let _ = try! JSONEncoder().encode(decodedDict)
        }
    }
}
