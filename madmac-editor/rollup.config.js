import resolve from "@rollup/plugin-node-resolve";
import typescript from "@rollup/plugin-typescript";
import commonjs from "@rollup/plugin-commonjs";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Read the pre-built mermaid UMD bundle to inject into our output.
// This avoids bundling mermaid's chunked ESM architecture through rollup.
const mermaidJs = fs.readFileSync(
  path.resolve(__dirname, "node_modules/mermaid/dist/mermaid.min.js"),
  "utf-8",
);

// Read KaTeX CSS to inject as a style element
const katexCss = fs.readFileSync(
  path.resolve(__dirname, "node_modules/katex/dist/katex.min.css"),
  "utf-8",
);

// Create a script that injects KaTeX CSS into the document
const katexCssInjector = `
(function() {
  if (typeof document !== 'undefined' && !document.querySelector('style[data-katex]')) {
    var s = document.createElement('style');
    s.setAttribute('data-katex', '1');
    s.textContent = ${JSON.stringify(katexCss)};
    document.head.appendChild(s);
  }
})();
`;

export default {
  input: "src/index.ts",
  output: {
    file: "../madmac-app/Resources/editor/editor.js",
    format: "iife",
    name: "MacmdEditor",
    sourcemap: true,
    inlineDynamicImports: true,
    // Prepend the pre-built mermaid UMD and KaTeX CSS injector
    banner: mermaidJs + "\n" + katexCssInjector,
  },
  plugins: [
    resolve({ browser: true }),
    commonjs(),
    typescript({
      tsconfig: "./tsconfig.json",
      compilerOptions: {
        outDir: undefined,
        declaration: false,
      },
    }),
  ],
  // Mermaid is loaded via the UMD banner, not as a module import
  external: [],
};
