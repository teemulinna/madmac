import { EditorView } from "@codemirror/view";
import { Extension } from "@codemirror/state";

/**
 * WKWebView bridge for communication between the CM6 editor and Swift shell.
 *
 * JS -> Swift: window.webkit.messageHandlers.MadMac.postMessage(payload)
 * Swift -> JS: MacmdEditor.createEditor(), .setContent(), .getContent(), etc.
 */

interface WebKitMessageHandler {
  postMessage(message: unknown): void;
}

interface WebKitMessageHandlers {
  MadMac: WebKitMessageHandler;
}

interface WebKitNamespace {
  messageHandlers: WebKitMessageHandlers;
}

declare global {
  interface Window {
    webkit?: WebKitNamespace;
  }
}

/**
 * Send a message to the Swift shell via WKWebView message handler.
 * No-ops silently if not running inside WKWebView.
 */
export function postToSwift(type: string, payload?: Record<string, unknown>): void {
  try {
    if (
      typeof window !== "undefined" &&
      window.webkit?.messageHandlers?.MadMac
    ) {
      window.webkit.messageHandlers.MadMac.postMessage({ type, ...payload });
    }
  } catch {
    // Silently ignore — not in WKWebView
  }
}

/**
 * CM6 extension that notifies Swift whenever the document content changes.
 * Dispatches "contentChanged" with the new content length.
 */
export function contentChangeNotifier(): Extension {
  return EditorView.updateListener.of((update) => {
    if (update.docChanged) {
      const content = update.state.doc.toString();
      postToSwift("contentChanged", {
        length: content.length,
        lineCount: update.state.doc.lines,
      });
    }
  });
}

/**
 * Notify Swift that the editor is ready.
 */
export function notifyReady(): void {
  postToSwift("editorReady");
}

/**
 * Notify Swift that the mode changed.
 */
export function notifyModeChanged(mode: string): void {
  postToSwift("modeChanged", { mode });
}

/**
 * Notify Swift that the theme changed.
 */
export function notifyThemeChanged(theme: string): void {
  postToSwift("themeChanged", { theme });
}
