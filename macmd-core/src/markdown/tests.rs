use super::*;

// ---- TDD: Red-Green-Refactor ----
// These tests are written BEFORE implementation changes.
// Run: cargo test

#[test]
fn render_heading_to_html() {
    let html = render_to_html("# Hello World");
    assert!(html.contains("<h1>"));
    assert!(html.contains("Hello World"));
    assert!(html.contains("</h1>"));
}

#[test]
fn render_heading_levels() {
    for level in 1..=6 {
        let md = format!("{} Heading {}", "#".repeat(level), level);
        let html = render_to_html(&md);
        assert!(
            html.contains(&format!("<h{level}>")),
            "Expected h{level} tag for input: {md}"
        );
    }
}

#[test]
fn render_bold_text() {
    let html = render_to_html("This is **bold** text");
    assert!(html.contains("<strong>bold</strong>"));
}

#[test]
fn render_italic_text() {
    let html = render_to_html("This is *italic* text");
    assert!(html.contains("<em>italic</em>"));
}

#[test]
fn render_bold_italic_text() {
    let html = render_to_html("This is ***bold italic*** text");
    assert!(html.contains("<em><strong>bold italic</strong></em>"));
}

#[test]
fn render_strikethrough() {
    let html = render_to_html("This is ~~deleted~~ text");
    assert!(html.contains("<del>deleted</del>"));
}

#[test]
fn render_inline_code() {
    let html = render_to_html("Use `println!` here");
    assert!(html.contains("<code>println!</code>"));
}

#[test]
fn render_link() {
    let html = render_to_html("[Example](https://example.com)");
    assert!(html.contains(r#"<a href="https://example.com">Example</a>"#));
}

#[test]
fn render_image() {
    let html = render_to_html("![Alt text](image.png)");
    assert!(html.contains(r#"<img src="image.png" alt="Alt text""#));
}

#[test]
fn render_unordered_list() {
    let html = render_to_html("- Item one\n- Item two\n- Item three");
    assert!(html.contains("<ul>"));
    assert!(html.contains("<li>Item one</li>"));
    assert!(html.contains("<li>Item three</li>"));
}

#[test]
fn render_ordered_list() {
    let html = render_to_html("1. First\n2. Second\n3. Third");
    assert!(html.contains("<ol>"));
    assert!(html.contains("<li>First</li>"));
}

#[test]
fn render_task_list() {
    let html = render_to_html("- [ ] Unchecked\n- [x] Checked");
    assert!(html.contains(r#"type="checkbox""#));
    assert!(html.contains(r#"checked=""#));
}

#[test]
fn render_blockquote() {
    let html = render_to_html("> This is a quote");
    assert!(html.contains("<blockquote>"));
    assert!(html.contains("This is a quote"));
}

#[test]
fn render_code_block_with_language() {
    let html = render_to_html("```python\ndef hello():\n    pass\n```");
    assert!(html.contains("<pre>"));
    assert!(html.contains("<code"));
    assert!(html.contains("def hello():"));
}

#[test]
fn render_table() {
    let md = "| Name | Age |\n|------|-----|\n| Alice | 30 |";
    let html = render_to_html(md);
    assert!(html.contains("<table>"));
    assert!(html.contains("<th>"));
    assert!(html.contains("Alice"));
}

#[test]
fn render_horizontal_rule() {
    let html = render_to_html("Above\n\n---\n\nBelow");
    assert!(html.contains("<hr"));
}

#[test]
fn render_footnote() {
    let html = render_to_html("Text[^1]\n\n[^1]: Footnote content");
    assert!(html.contains("Footnote content"));
}

#[test]
fn render_empty_input() {
    let html = render_to_html("");
    assert!(html.is_empty() || html.trim().is_empty());
}

#[test]
fn render_unicode_content() {
    let html = render_to_html("# Hyvää päivää\n\nこんにちは 🎉");
    assert!(html.contains("Hyvää päivää"));
    assert!(html.contains("こんにちは"));
    assert!(html.contains("🎉"));
}

#[test]
fn render_nested_list() {
    let html = render_to_html("- Parent\n  - Child\n    - Grandchild");
    assert!(html.contains("<ul>"));
    // Nested list should have nested <ul> elements
    let ul_count = html.matches("<ul>").count();
    assert!(ul_count >= 2, "Expected nested <ul> tags, found {ul_count}");
}

// ---- Property-based tests ----

#[cfg(test)]
mod proptests {
    use super::super::*;
    use proptest::prelude::*;

    proptest! {
        #[test]
        fn never_panics_on_arbitrary_input(s in "\\PC{0,1000}") {
            // Parsing should never panic regardless of input
            let _ = render_to_html(&s);
        }

        #[test]
        fn output_is_valid_utf8(s in "[a-zA-Z0-9 #*_\\n]{0,500}") {
            let html = render_to_html(&s);
            // If we got here, it's valid UTF-8 (Rust strings are always UTF-8)
            assert!(html.len() <= s.len() * 10, "Output suspiciously large");
        }

        #[test]
        fn headings_always_produce_h_tags(level in 1u8..=6, text in "[a-zA-Z ]{1,50}") {
            let md = format!("{} {}", "#".repeat(level as usize), text);
            let html = render_to_html(&md);
            assert!(html.contains(&format!("<h{level}>")));
        }
    }
}
