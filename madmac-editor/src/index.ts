export {
  createEditor,
  setContent,
  getContent,
  setMode,
  setTheme,
  getMode,
  getTheme,
  getView,
  setFontSize,
  getFontSize,
  showLineNumbers,
  copySelectionAsRichText,
} from "./editor";
export type { EditorMode } from "./editor";
export type { ThemeVariant } from "./theme";
export { postToSwift } from "./bridge";
