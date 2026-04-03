use pulldown_cmark::{html, Options, Parser};

/// Render markdown source to HTML string.
///
/// Uses pulldown-cmark with GFM extensions enabled:
/// tables, footnotes, strikethrough, task lists, heading attributes.
pub fn render_to_html(markdown: &str) -> String {
    let options = Options::ENABLE_TABLES
        | Options::ENABLE_FOOTNOTES
        | Options::ENABLE_STRIKETHROUGH
        | Options::ENABLE_TASKLISTS
        | Options::ENABLE_HEADING_ATTRIBUTES;

    let parser = Parser::new_ext(markdown, options);
    let mut html_output = String::with_capacity(markdown.len() * 2);
    html::push_html(&mut html_output, parser);
    html_output
}
