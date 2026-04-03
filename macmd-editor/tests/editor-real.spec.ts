import { test, expect } from "@playwright/test";
import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const BUNDLE_PATH = path.resolve(
  __dirname,
  "../../macmd-app/Resources/editor/editor.js",
);
const editorJs = fs.readFileSync(BUNDLE_PATH, "utf-8");

/**
 * Helper: inject the real editor.js bundle into a blank page and create
 * a host <div id="editor">.
 */
async function setupPage(page: import("@playwright/test").Page) {
  await page.goto("about:blank");

  // Mock window.webkit so bridge calls don't throw
  await page.evaluate(() => {
    (window as any).webkit = {
      messageHandlers: {
        macmd: {
          postMessage: (msg: unknown) => {
            ((window as any).__bridgeMessages ??= []).push(msg);
          },
        },
      },
    };
  });

  await page.addScriptTag({ content: editorJs });
  await page.evaluate(() => {
    const el = document.createElement("div");
    el.id = "editor";
    document.body.style.margin = "0";
    document.body.appendChild(el);
  });
}

// ---------------------------------------------------------------------------
// 1. Bundle loads without errors
// ---------------------------------------------------------------------------
test.describe("1 - Bundle loads without errors", () => {
  test("loads without console errors and exposes MacmdEditor", async ({
    page,
  }) => {
    const errors: string[] = [];
    page.on("pageerror", (err) => errors.push(err.message));

    await setupPage(page);

    expect(errors).toEqual([]);

    const keys = await page.evaluate(() => Object.keys((window as any).MacmdEditor));
    expect(keys).toContain("createEditor");
    expect(keys).toContain("getContent");
    expect(keys).toContain("setContent");
    expect(keys).toContain("setMode");
    expect(keys).toContain("setTheme");
    expect(keys).toContain("getMode");
    expect(keys).toContain("getTheme");
    expect(keys).toContain("getView");
  });
});

// ---------------------------------------------------------------------------
// 2. Editor creation works in real WebKit
// ---------------------------------------------------------------------------
test.describe("2 - Editor creation in real WebKit", () => {
  test("createEditor renders a .cm-editor element", async ({ page }) => {
    await setupPage(page);

    await page.evaluate(() => {
      (window as any).MacmdEditor.createEditor(
        document.getElementById("editor")!,
        "# Hello World",
        "reading",
      );
    });

    await expect(page.locator(".cm-editor")).toHaveCount(1);
  });

  test("getContent returns the initial content", async ({ page }) => {
    await setupPage(page);

    const content = await page.evaluate(() => {
      (window as any).MacmdEditor.createEditor(
        document.getElementById("editor")!,
        "# Hello World",
        "reading",
      );
      return (window as any).MacmdEditor.getContent();
    });

    expect(content).toBe("# Hello World");
  });

  test("reading mode editor is not editable", async ({ page }) => {
    await setupPage(page);

    await page.evaluate(() => {
      (window as any).MacmdEditor.createEditor(
        document.getElementById("editor")!,
        "Read-only text",
        "reading",
      );
    });

    // contenteditable should be false in reading mode
    const editable = await page.locator(".cm-content").getAttribute("contenteditable");
    expect(editable).toBe("false");
  });
});

// ---------------------------------------------------------------------------
// 3. Mode switching in real browser
// ---------------------------------------------------------------------------
test.describe("3 - Mode switching", () => {
  test("switching to fluid mode makes editor editable", async ({ page }) => {
    await setupPage(page);

    await page.evaluate(() => {
      (window as any).MacmdEditor.createEditor(
        document.getElementById("editor")!,
        "Hello",
        "reading",
      );
      (window as any).MacmdEditor.setMode("fluid");
    });

    const editable = await page.locator(".cm-content").getAttribute("contenteditable");
    expect(editable).toBe("true");

    const mode = await page.evaluate(() => (window as any).MacmdEditor.getMode());
    expect(mode).toBe("fluid");
  });

  test("typing in fluid mode updates content", async ({ page }) => {
    await setupPage(page);

    await page.evaluate(() => {
      (window as any).MacmdEditor.createEditor(
        document.getElementById("editor")!,
        "",
        "fluid",
      );
    });

    // Focus editor and type
    await page.locator(".cm-content").click();
    await page.keyboard.type("Typed text");

    const content = await page.evaluate(() =>
      (window as any).MacmdEditor.getContent(),
    );
    expect(content).toContain("Typed text");
  });

  test("switching back to reading mode makes it read-only", async ({
    page,
  }) => {
    await setupPage(page);

    await page.evaluate(() => {
      (window as any).MacmdEditor.createEditor(
        document.getElementById("editor")!,
        "Original",
        "fluid",
      );
    });

    // Type something in fluid mode
    await page.locator(".cm-content").click();
    await page.keyboard.type(" added");

    // Switch to reading mode
    await page.evaluate(() =>
      (window as any).MacmdEditor.setMode("reading"),
    );

    const editable = await page.locator(".cm-content").getAttribute("contenteditable");
    expect(editable).toBe("false");

    // Content should be preserved
    const content = await page.evaluate(() =>
      (window as any).MacmdEditor.getContent(),
    );
    expect(content).toContain("Original");
    expect(content).toContain("added");
  });

  test("content preserved across mode switches", async ({ page }) => {
    await setupPage(page);

    await page.evaluate(() => {
      (window as any).MacmdEditor.createEditor(
        document.getElementById("editor")!,
        "# Persistent content",
        "reading",
      );
    });

    // reading -> fluid -> reading
    await page.evaluate(() => {
      (window as any).MacmdEditor.setMode("fluid");
      (window as any).MacmdEditor.setMode("reading");
    });

    const content = await page.evaluate(() =>
      (window as any).MacmdEditor.getContent(),
    );
    expect(content).toBe("# Persistent content");
  });
});

// ---------------------------------------------------------------------------
// 4. Theme switching in real browser
// ---------------------------------------------------------------------------
test.describe("4 - Theme switching", () => {
  test("setTheme dark applies dark background", async ({ page }) => {
    await setupPage(page);

    await page.evaluate(() => {
      (window as any).MacmdEditor.createEditor(
        document.getElementById("editor")!,
        "Theme test",
        "reading",
        "light",
      );
    });

    // Switch to dark
    await page.evaluate(() =>
      (window as any).MacmdEditor.setTheme("dark"),
    );

    const bg = await page.locator(".cm-editor").evaluate((el) =>
      getComputedStyle(el).backgroundColor,
    );
    // Dark theme background is #1e1e1e = rgb(30, 30, 30)
    expect(bg).toBe("rgb(30, 30, 30)");

    const theme = await page.evaluate(() =>
      (window as any).MacmdEditor.getTheme(),
    );
    expect(theme).toBe("dark");
  });

  test("setTheme light applies light background", async ({ page }) => {
    await setupPage(page);

    await page.evaluate(() => {
      (window as any).MacmdEditor.createEditor(
        document.getElementById("editor")!,
        "Theme test",
        "reading",
        "dark",
      );
    });

    // Switch to light
    await page.evaluate(() =>
      (window as any).MacmdEditor.setTheme("light"),
    );

    const bg = await page.locator(".cm-editor").evaluate((el) =>
      getComputedStyle(el).backgroundColor,
    );
    // Light theme background is #ffffff = rgb(255, 255, 255)
    expect(bg).toBe("rgb(255, 255, 255)");

    const theme = await page.evaluate(() =>
      (window as any).MacmdEditor.getTheme(),
    );
    expect(theme).toBe("light");
  });

  test("dark theme applies light text color", async ({ page }) => {
    await setupPage(page);

    await page.evaluate(() => {
      (window as any).MacmdEditor.createEditor(
        document.getElementById("editor")!,
        "Color test",
        "reading",
        "dark",
      );
    });

    const color = await page.locator(".cm-editor").evaluate((el) =>
      getComputedStyle(el).color,
    );
    // Dark theme text is #e5e5e7 = rgb(229, 229, 231)
    expect(color).toBe("rgb(229, 229, 231)");
  });
});

// ---------------------------------------------------------------------------
// 5. Markdown syntax highlighting renders
// ---------------------------------------------------------------------------
test.describe("5 - Markdown syntax highlighting", () => {
  test("heading line gets cm-heading-* class", async ({ page }) => {
    await setupPage(page);

    await page.evaluate(() => {
      (window as any).MacmdEditor.createEditor(
        document.getElementById("editor")!,
        "# Heading 1\n## Heading 2\n### Heading 3",
        "reading",
      );
    });

    // Wait for decorations to apply
    await expect(page.locator(".cm-heading-1")).toHaveCount(1);
    await expect(page.locator(".cm-heading-2")).toHaveCount(1);
    await expect(page.locator(".cm-heading-3")).toHaveCount(1);
  });

  test("code blocks get cm-code-block class", async ({ page }) => {
    await setupPage(page);

    await page.evaluate(() => {
      (window as any).MacmdEditor.createEditor(
        document.getElementById("editor")!,
        "text\n\n```js\nconst x = 1;\n```\n\nmore text",
        "reading",
      );
    });

    await expect(page.locator(".cm-code-block").first()).toBeVisible();
  });

  test("blockquotes get cm-blockquote class", async ({ page }) => {
    await setupPage(page);

    await page.evaluate(() => {
      (window as any).MacmdEditor.createEditor(
        document.getElementById("editor")!,
        "> This is a quote",
        "reading",
      );
    });

    await expect(page.locator(".cm-blockquote")).toHaveCount(1);
  });
});

// ---------------------------------------------------------------------------
// 6. Fluid Mode decorations in real browser
// ---------------------------------------------------------------------------
test.describe("6 - Fluid Mode decorations", () => {
  test("heading syntax toggles visibility on click", async ({ page }) => {
    await setupPage(page);

    await page.evaluate(() => {
      (window as any).MacmdEditor.createEditor(
        document.getElementById("editor")!,
        "# Hello\n\nSome body text here",
        "fluid",
      );
    });

    // In fluid mode, the heading line should exist
    await expect(page.locator(".cm-heading-1")).toHaveCount(1);

    // Get the text content of the heading line before clicking
    const headingLine = page.locator(".cm-heading-1");
    await expect(headingLine).toBeVisible();

    // Click on the heading to enter block editing
    await headingLine.click();

    // After clicking, the heading syntax "# " should become visible
    // (the line text should contain the hash)
    const textAfterClick = await headingLine.textContent();
    expect(textAfterClick).toContain("#");
    expect(textAfterClick).toContain("Hello");

    // Click on body text to exit heading block editing
    const bodyLine = page.locator(".cm-line").filter({ hasText: "Some body text" });
    await bodyLine.click();

    // Give decorations time to update
    await page.waitForTimeout(200);

    // The heading line should still render Hello
    const headingTextAfter = await page.locator(".cm-heading-1").textContent();
    expect(headingTextAfter).toContain("Hello");
  });
});

// ---------------------------------------------------------------------------
// 7. Content change bridge
// ---------------------------------------------------------------------------
test.describe("7 - Content change bridge", () => {
  test("typing dispatches contentChanged message", async ({ page }) => {
    await setupPage(page);

    await page.evaluate(() => {
      (window as any).MacmdEditor.createEditor(
        document.getElementById("editor")!,
        "",
        "fluid",
      );
      // Reset bridge messages after createEditor (which sends editorReady)
      (window as any).__bridgeMessages = [];
    });

    await page.locator(".cm-content").click();
    await page.keyboard.type("x");

    const messages = await page.evaluate(
      () => (window as any).__bridgeMessages as any[],
    );

    const contentChanged = messages.filter(
      (m: any) => m.type === "contentChanged",
    );
    expect(contentChanged.length).toBeGreaterThan(0);
    expect(contentChanged[0]).toHaveProperty("length");
    expect(contentChanged[0]).toHaveProperty("lineCount");
  });

  test("editorReady message sent on create", async ({ page }) => {
    await setupPage(page);

    await page.evaluate(() => {
      // Reset messages before creating editor
      (window as any).__bridgeMessages = [];
      (window as any).MacmdEditor.createEditor(
        document.getElementById("editor")!,
        "hello",
        "reading",
      );
    });

    const messages = await page.evaluate(
      () => (window as any).__bridgeMessages as any[],
    );
    const ready = messages.filter((m: any) => m.type === "editorReady");
    expect(ready.length).toBe(1);
  });

  test("mode change dispatches modeChanged message", async ({ page }) => {
    await setupPage(page);

    await page.evaluate(() => {
      (window as any).MacmdEditor.createEditor(
        document.getElementById("editor")!,
        "hello",
        "reading",
      );
      (window as any).__bridgeMessages = [];
      (window as any).MacmdEditor.setMode("fluid");
    });

    const messages = await page.evaluate(
      () => (window as any).__bridgeMessages as any[],
    );
    const modeChanged = messages.filter(
      (m: any) => m.type === "modeChanged",
    );
    expect(modeChanged.length).toBe(1);
    expect(modeChanged[0].mode).toBe("fluid");
  });

  test("theme change dispatches themeChanged message", async ({ page }) => {
    await setupPage(page);

    await page.evaluate(() => {
      (window as any).MacmdEditor.createEditor(
        document.getElementById("editor")!,
        "hello",
        "reading",
        "light",
      );
      (window as any).__bridgeMessages = [];
      (window as any).MacmdEditor.setTheme("dark");
    });

    const messages = await page.evaluate(
      () => (window as any).__bridgeMessages as any[],
    );
    const themeChanged = messages.filter(
      (m: any) => m.type === "themeChanged",
    );
    expect(themeChanged.length).toBe(1);
    expect(themeChanged[0].theme).toBe("dark");
  });
});

// ---------------------------------------------------------------------------
// 8. Large document performance
// ---------------------------------------------------------------------------
test.describe("8 - Large document performance", () => {
  test("10000-line document loads in under 2 seconds", async ({ page }) => {
    await setupPage(page);

    const duration = await page.evaluate(() => {
      // Generate a 10000-line markdown document
      const lines: string[] = [];
      for (let i = 0; i < 10000; i++) {
        if (i % 100 === 0) lines.push(`## Section ${i / 100 + 1}`);
        else if (i % 50 === 0) lines.push("```\ncode block line\n```");
        else if (i % 10 === 0) lines.push(`> Blockquote line ${i}`);
        else lines.push(`This is line ${i} of the large document with some text.`);
      }
      const doc = lines.join("\n");

      const start = performance.now();
      (window as any).MacmdEditor.createEditor(
        document.getElementById("editor")!,
        doc,
        "reading",
      );
      const elapsed = performance.now() - start;
      return elapsed;
    });

    expect(duration).toBeLessThan(2000);
  });

  test("large document content is accessible", async ({ page }) => {
    await setupPage(page);

    const lineCount = await page.evaluate(() => {
      const lines: string[] = [];
      for (let i = 0; i < 10000; i++) {
        lines.push(`Line ${i}`);
      }
      const doc = lines.join("\n");
      (window as any).MacmdEditor.createEditor(
        document.getElementById("editor")!,
        doc,
        "reading",
      );
      const content = (window as any).MacmdEditor.getContent();
      return content.split("\n").length;
    });

    expect(lineCount).toBe(10000);
  });

  test("scrolling large document produces no errors", async ({ page }) => {
    const errors: string[] = [];
    page.on("pageerror", (err) => errors.push(err.message));

    await setupPage(page);

    await page.evaluate(() => {
      const lines: string[] = [];
      for (let i = 0; i < 10000; i++) {
        lines.push(`Line ${i} with some content to make it realistic.`);
      }
      (window as any).MacmdEditor.createEditor(
        document.getElementById("editor")!,
        lines.join("\n"),
        "reading",
      );
    });

    // Scroll down and back up
    const scroller = page.locator(".cm-scroller");
    await scroller.evaluate((el) => {
      el.scrollTop = 5000;
    });
    await page.waitForTimeout(100);
    await scroller.evaluate((el) => {
      el.scrollTop = el.scrollHeight;
    });
    await page.waitForTimeout(100);
    await scroller.evaluate((el) => {
      el.scrollTop = 0;
    });
    await page.waitForTimeout(100);

    expect(errors).toEqual([]);
  });
});
