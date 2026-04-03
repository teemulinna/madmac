.PHONY: all build test clean setup run

# ── Setup ──────────────────────────────────────────
setup:
	cd macmd-editor && npm install
	cd macmd-core && cargo fetch

# ── Build ──────────────────────────────────────────
build:
	./scripts/build.sh

build-rust:
	cd macmd-core && cargo build --release

build-editor:
	cd macmd-editor && npm run build

# ── Run ────────────────────────────────────────────
run: build
	open build/macmd.app

run-with-demo: build
	open build/macmd.app --args "$(PWD)/test-files/demo.md"

# ── Test ───────────────────────────────────────────
test: test-rust test-editor

test-rust:
	cd macmd-core && cargo test

test-editor:
	cd macmd-editor && npx vitest run

test-watch-rust:
	cd macmd-core && cargo watch -x test

test-watch-editor:
	cd macmd-editor && npx vitest

# ── Bench ──────────────────────────────────────────
bench:
	cd macmd-core && cargo bench

# ── Clean ──────────────────────────────────────────
clean:
	cd macmd-core && cargo clean
	cd macmd-editor && rm -rf node_modules dist
	rm -rf build/
