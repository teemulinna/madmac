import AppKit
import UniformTypeIdentifiers

// MARK: - Minimal Test Harness

var passed = 0
var failed = 0
var total = 0

func assert(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    total += 1
    if condition {
        passed += 1
        print("  PASS \(message)")
    } else {
        failed += 1
        print("  FAIL \(message) (\(file):\(line))")
    }
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String, file: String = #file, line: Int = #line) {
    total += 1
    if a == b {
        passed += 1
        print("  PASS \(message)")
    } else {
        failed += 1
        print("  FAIL \(message) — expected \(b), got \(a) (\(file):\(line))")
    }
}

func assertThrows(_ block: () throws -> Void, containing substring: String? = nil, _ message: String, file: String = #file, line: Int = #line) {
    total += 1
    do {
        try block()
        failed += 1
        print("  FAIL \(message) — expected throw, but succeeded (\(file):\(line))")
    } catch {
        if let substring = substring {
            let desc = error.localizedDescription
            if desc.contains(substring) {
                passed += 1
                print("  PASS \(message)")
            } else {
                failed += 1
                print("  FAIL \(message) — error '\(desc)' does not contain '\(substring)' (\(file):\(line))")
            }
        } else {
            passed += 1
            print("  PASS \(message)")
        }
    }
}

func section(_ name: String) {
    print("\n\(name)")
    print(String(repeating: "-", count: name.count))
}

// MARK: - Tests: MarkdownDocument.read(from:ofType:)

func testReadValidUTF8() {
    section("MarkdownDocument.read(from:ofType:)")

    let doc = MarkdownDocument()
    let markdown = "# Hello World\n\nThis is a **test** document.\n"
    let data = markdown.data(using: .utf8)!
    do {
        try doc.read(from: data, ofType: "net.daringfireball.markdown")
        assertEqual(doc.content, markdown, "Valid UTF-8 markdown sets content correctly")
    } catch {
        assert(false, "Valid UTF-8 markdown sets content correctly — unexpected error: \(error)")
    }
}

func testReadNonUTF8Throws() {
    let doc = MarkdownDocument()
    // Create bytes that are not valid UTF-8: 0xFE and 0xFF are never valid in UTF-8
    let invalidBytes: [UInt8] = [0xFE, 0xFF, 0x80, 0x81, 0x82]
    let data = Data(invalidBytes)
    assertThrows(
        { try doc.read(from: data, ofType: "net.daringfireball.markdown") },
        containing: "not valid UTF-8",
        "Non-UTF-8 data throws error with 'not valid UTF-8' message"
    )
}

func testReadEmptyFile() {
    let doc = MarkdownDocument()
    let data = Data()
    do {
        try doc.read(from: data, ofType: "net.daringfireball.markdown")
        assertEqual(doc.content, "", "Empty file results in empty string content")
    } catch {
        assert(false, "Empty file results in empty string content — unexpected error: \(error)")
    }
}

func testReadLargeFile() {
    let doc = MarkdownDocument()
    let lines = (0..<10000).map { "Line \($0): Lorem ipsum dolor sit amet, consectetur adipiscing elit." }
    let largeContent = lines.joined(separator: "\n")
    let data = largeContent.data(using: .utf8)!
    do {
        try doc.read(from: data, ofType: "net.daringfireball.markdown")
        assertEqual(doc.content, largeContent, "Large file (10000 lines) reads without error")
    } catch {
        assert(false, "Large file (10000 lines) reads without error — unexpected error: \(error)")
    }
}

// MARK: - Tests: MarkdownDocument.data(ofType:)

func testDataReturnsUTF8() {
    section("MarkdownDocument.data(ofType:)")

    let doc = MarkdownDocument()
    let content = "# Test\n\nSome content here.\n"
    doc.content = content
    do {
        let data = try doc.data(ofType: "net.daringfireball.markdown")
        let roundtripped = String(data: data, encoding: .utf8)
        assertEqual(roundtripped, content, "data() returns correct UTF-8 encoded Data")
    } catch {
        assert(false, "data() returns correct UTF-8 encoded Data — unexpected error: \(error)")
    }
}

func testDataUnicodeRoundtrip() {
    let doc = MarkdownDocument()
    // Finnish, Japanese, and emoji content
    let content = "Tervetuloa maailmaan!\nこんにちは世界\n🎉🚀💡 Emoji test\nCafé résumé naïve\n"
    doc.content = content
    do {
        let data = try doc.data(ofType: "net.daringfireball.markdown")
        let roundtripped = String(data: data, encoding: .utf8)
        assertEqual(roundtripped, content, "Unicode content (Finnish, Japanese, emoji) roundtrips correctly")
    } catch {
        assert(false, "Unicode content roundtrips correctly — unexpected error: \(error)")
    }
}

func testDataEmptyContent() {
    let doc = MarkdownDocument()
    doc.content = ""
    do {
        let data = try doc.data(ofType: "net.daringfireball.markdown")
        assertEqual(data.count, 0, "Empty content returns empty Data")
    } catch {
        assert(false, "Empty content returns empty Data — unexpected error: \(error)")
    }
}

// MARK: - Tests: UTType Registration

func testReadableTypes() {
    section("UTType Registration")

    let types = MarkdownDocument.readableTypes
    assert(types.contains("net.daringfireball.markdown"), "readableTypes contains 'net.daringfireball.markdown'")
}

func testAutosavesInPlace() {
    assertEqual(MarkdownDocument.autosavesInPlace, true, "autosavesInPlace is true")
}

// MARK: - Tests: NSDocumentController Integration

func testDocumentControllerKnowsDocumentClass() {
    section("NSDocumentController Integration")

    // The @objc(MarkdownDocument) annotation makes the class findable by name.
    // This is what NSDocumentController uses when Info.plist specifies the document class.
    let cls: AnyClass? = NSClassFromString("MarkdownDocument")
    assert(cls != nil, "NSClassFromString('MarkdownDocument') resolves the class")

    if let cls = cls {
        assert(cls is NSDocument.Type, "MarkdownDocument is an NSDocument subclass")
    }
}

// MARK: - Tests: read/data roundtrip

func testReadDataRoundtrip() {
    section("Read/Data Roundtrip")

    let original = "# Roundtrip Test\n\nContent with **bold** and *italic*.\n\n- Item 1\n- Item 2\n"
    let inputData = original.data(using: .utf8)!

    let doc = MarkdownDocument()
    do {
        try doc.read(from: inputData, ofType: "net.daringfireball.markdown")
        let outputData = try doc.data(ofType: "net.daringfireball.markdown")
        let result = String(data: outputData, encoding: .utf8)
        assertEqual(result, original, "read() then data() roundtrips markdown content exactly")
    } catch {
        assert(false, "read() then data() roundtrips markdown content exactly — unexpected error: \(error)")
    }
}

// MARK: - Main

func runAllTests() {
    print("===========================================")
    print("macmd Document Model Tests")
    print("===========================================")

    // read(from:ofType:)
    testReadValidUTF8()
    testReadNonUTF8Throws()
    testReadEmptyFile()
    testReadLargeFile()

    // data(ofType:)
    testDataReturnsUTF8()
    testDataUnicodeRoundtrip()
    testDataEmptyContent()

    // UTType registration
    testReadableTypes()
    testAutosavesInPlace()

    // NSDocumentController integration
    testDocumentControllerKnowsDocumentClass()

    // Roundtrip
    testReadDataRoundtrip()

    // Workspace (WP-2)
    runWorkspaceTests()

    // Export (Print/PDF)
    runExportTests()

    print("\n===========================================")
    print("Results: \(passed) passed, \(failed) failed, \(total) total")
    print("===========================================")

    if failed > 0 {
        exit(1)
    } else {
        exit(0)
    }
}

@main
struct RunTests {
    static func main() {
        runAllTests()
    }
}
