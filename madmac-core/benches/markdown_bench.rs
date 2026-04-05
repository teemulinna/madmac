use criterion::{black_box, criterion_group, criterion_main, Criterion};
use macmd_core::markdown::render_to_html;

fn bench_simple_document(c: &mut Criterion) {
    let md = "# Hello\n\nThis is **bold** and *italic*.\n\n- Item 1\n- Item 2\n";
    c.bench_function("simple_doc", |b| {
        b.iter(|| render_to_html(black_box(md)))
    });
}

fn bench_large_document(c: &mut Criterion) {
    let section = "## Section\n\nLorem ipsum dolor sit amet, **consectetur** adipiscing elit.\n\n```rust\nfn main() {}\n```\n\n";
    let md = section.repeat(100);
    c.bench_function("large_doc_100_sections", |b| {
        b.iter(|| render_to_html(black_box(&md)))
    });
}

fn bench_table_heavy(c: &mut Criterion) {
    let mut md = "| Col A | Col B | Col C |\n|-------|-------|-------|\n".to_string();
    for i in 0..50 {
        md.push_str(&format!("| val{i}a | val{i}b | val{i}c |\n"));
    }
    c.bench_function("table_50_rows", |b| {
        b.iter(|| render_to_html(black_box(&md)))
    });
}

criterion_group!(benches, bench_simple_document, bench_large_document, bench_table_heavy);
criterion_main!(benches);
