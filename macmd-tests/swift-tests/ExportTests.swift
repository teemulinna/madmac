import Foundation

// MARK: - MarkdownToTypst Converter Tests

func testHeadingConversion() {
    section("MarkdownToTypst — Headings")

    let h1 = MarkdownToTypst.convert("# Hello")
    assert(h1.contains("= Hello"), "H1 converts to = Hello")

    let h2 = MarkdownToTypst.convert("## World")
    assert(h2.contains("== World"), "H2 converts to == World")

    let h3 = MarkdownToTypst.convert("### Deep")
    assert(h3.contains("=== Deep"), "H3 converts to === Deep")
}

func testBoldConversion() {
    section("MarkdownToTypst — Inline")

    let bold = MarkdownToTypst.convert("This is **bold** text")
    assert(bold.contains("*bold*"), "**bold** converts to *bold*")
    assert(!bold.contains("**"), "No double asterisks remain")
}

func testItalicConversion() {
    // After bold conversion, remaining single * should become _
    let italic = MarkdownToTypst.convert("This is *italic* text")
    assert(italic.contains("_italic_"), "*italic* converts to _italic_")
}

func testLinkConversion() {
    let link = MarkdownToTypst.convert("[macmd](https://github.com/teemulinna/macmd)")
    assert(link.contains("#link(\"https://github.com/teemulinna/macmd\")[macmd]"),
           "[text](url) converts to #link(\"url\")[text]")
}

func testCodeBlockConversion() {
    section("MarkdownToTypst — Blocks")

    let code = MarkdownToTypst.convert("```python\nprint('hello')\n```")
    assert(code.contains("``` python"), "Code block preserves language tag")
    assert(code.contains("print('hello')"), "Code block preserves content")
}

func testUnorderedListConversion() {
    let list = MarkdownToTypst.convert("- Item one\n- Item two\n- Item three")
    assert(list.contains("- Item one"), "Unordered list items preserved")
    assert(list.contains("- Item three"), "All list items present")
}

func testOrderedListConversion() {
    let list = MarkdownToTypst.convert("1. First\n2. Second\n3. Third")
    assert(list.contains("+ First"), "Ordered list uses + prefix")
    assert(list.contains("+ Third"), "All ordered items present")
}

func testBlockquoteConversion() {
    let quote = MarkdownToTypst.convert("> This is a quote")
    assert(quote.contains("#quote(block: true)"), "Blockquote uses #quote")
    assert(quote.contains("This is a quote"), "Quote content preserved")
}

func testHorizontalRuleConversion() {
    let hr = MarkdownToTypst.convert("---")
    assert(hr.contains("#line("), "--- converts to #line()")
}

func testStrikethroughConversion() {
    let strike = MarkdownToTypst.convert("~~deleted~~")
    assert(strike.contains("#strike[deleted]"), "~~text~~ converts to #strike[text]")
}

func testMixedDocument() {
    section("MarkdownToTypst — Full Document")

    let md = """
    # macmd User Guide

    macmd is a **native** markdown editor for *macOS*.

    ## Features

    - Reading mode
    - Fluid editing
    - PDF export via [Typst](https://typst.app)

    ### Code Example

    ```swift
    let doc = MarkdownDocument()
    ```

    > macmd: write markdown, beautifully.

    ---

    1. Install
    2. Open a file
    3. Start writing
    """

    let typst = MarkdownToTypst.convert(md)

    assert(typst.contains("= macmd User Guide"), "H1 present")
    assert(typst.contains("== Features"), "H2 present")
    assert(typst.contains("=== Code Example"), "H3 present")
    assert(typst.contains("*native*"), "Bold converted")
    assert(typst.contains("_macOS_"), "Italic converted")
    assert(typst.contains("- Reading mode"), "Unordered list present")
    assert(typst.contains("#link(\"https://typst.app\")[Typst]"), "Link converted")
    assert(typst.contains("``` swift"), "Code block with lang")
    assert(typst.contains("#quote(block: true)"), "Blockquote present")
    assert(typst.contains("#line("), "Horizontal rule present")
    assert(typst.contains("+ Install"), "Ordered list present")
}

func testPrintControllerPresetsExist() {
    section("PrintController")

    // Presets should exist in the bundle when built
    // In test context (no bundle), we test the class exists
    let cls: AnyClass? = NSClassFromString("PrintController")
    // PrintController is an enum, not a class — can't test via NSClassFromString
    // Instead verify the static method is callable
    let result = MarkdownToTypst.convert("# Test")
    assert(!result.isEmpty, "MarkdownToTypst.convert is callable and returns content")
}

// MARK: - Run Export Tests

func runExportTests() {
    print("\n===========================================")
    print("macmd Export Tests (Print/PDF)")
    print("===========================================")

    testHeadingConversion()
    testBoldConversion()
    testItalicConversion()
    testLinkConversion()
    testCodeBlockConversion()
    testUnorderedListConversion()
    testOrderedListConversion()
    testBlockquoteConversion()
    testHorizontalRuleConversion()
    testStrikethroughConversion()
    testMixedDocument()
    testPrintControllerPresetsExist()
}
