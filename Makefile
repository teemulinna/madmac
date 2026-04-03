.PHONY: all build test clean setup

# ── Setup ──────────────────────────────────────────
setup:
	cd macmd-editor && npm install
	cd macmd-core && cargo fetch

# ── Build ──────────────────────────────────────────
build: build-rust build-editor build-app

build-rust:
	cd macmd-core && cargo build --release

build-editor:
	cd macmd-editor && npm run build

build-app:
	cd macmd-app && xcodegen generate
	xcodebuild build -project macmd-app/macmd.xcodeproj -scheme macmd -configuration Debug

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
	rm -rf macmd-app/macmd.xcodeproj
