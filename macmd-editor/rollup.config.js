import resolve from "@rollup/plugin-node-resolve";
import typescript from "@rollup/plugin-typescript";

export default {
  input: "src/index.ts",
  output: {
    file: "../macmd-app/Resources/editor/editor.js",
    format: "iife",
    name: "MacmdEditor",
    sourcemap: true,
    inlineDynamicImports: true,
  },
  plugins: [
    resolve(),
    typescript({
      tsconfig: "./tsconfig.json",
      compilerOptions: {
        outDir: undefined,
        declaration: false,
      },
    }),
  ],
};
