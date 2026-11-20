// The web boot smoke (Story 1.13 AC6, AR53). Both web builds boot in headless Chromium; the debug
// build is the runtime check, because a release web build prints parse and load errors but never
// runtime script errors (D5). Later stories add their checks here as test.describe blocks. Done:
// the DPR scale and keys that must not scroll (1.14: `Display scale`, `Web input`). To come: the
// click-to-play gate (1.33), SMOKE save ok (1.39), the pogo pitch (3.3).
// @ts-check
'use strict';

const { test: base, expect } = require('@playwright/test');

// console.error messages the smoke tolerates: exact regexes, each with a comment giving its
// reason. Godot sends push_warning, push_error, printerr and SCRIPT ERROR to console.error, so an
// entry here hides a whole class of real failure. Starts empty (AC6).
const ALLOWED_CONSOLE_ERRORS = [];

const BANNER = 'Godot Engine v4.7.2.stable'; // the pinned templates, checked on the web
const MARKER = '[room] SMOKE boot ok'; // DevTools, on World's first room_entered (D9)
const BOOT_MS = 60_000; // per page, every boot wait together (D7); an empty project boots in 2–4 s headless (research)
// After the boot, how long the page plays on before its checks: the release check's "5 s more
// with no error", and in debug the first seconds of play, whose runtime SCRIPT ERRORs come after
// the marker (it prints inside World's _ready, before the first physics tick).
const SETTLE_MS = 5_000;
// scripts/core/log.gd's `[category] message`, for any category, so a new one can't slip past the
// release check. Chromium's own messages start "[.WebGL-0x…]", which this doesn't match.
const LOG_LINE = /^\[[a-z_]+\] /;

// Every console message ({type, text}) and page error, collected from before the first goto, so
// a line that arrives early is never missed. On failure the whole console, Chromium's own warnings
// included (they are ignored otherwise), goes to the test's stdout, which the line reporter writes
// in full, so logs/web_smoke.log shows it. Not an attachment: the line reporter cuts those at 300
// characters (probed, 1.65.1), which is the banner and little else.
const test = base.extend({
  seen: async ({ page }, use, testInfo) => {
    const seen = { console: [], pageErrors: [] };
    page.on('console', (m) => seen.console.push({ type: m.type(), text: m.text() }));
    page.on('pageerror', (e) => seen.pageErrors.push(String((e && e.stack) || e)));
    await use(seen);
    if (testInfo.status !== testInfo.expectedStatus) {
      const lines = seen.console.map((m) => `[${m.type}] ${m.text}`);
      for (const e of seen.pageErrors) lines.push(`[pageerror] ${e}`);
      console.log(`--- browser console (${lines.length} lines) ---\n${lines.join('\n') || '(no console output)'}\n--- end of browser console ---`);
    }
  },
});

const texts = (seen) => seen.console.map((m) => m.text);

// Loads `url` and waits for the engine to start. #status-notice sits inside #status: a good boot
// removes both, a failed one (missing WebGL2, a bad download) fills the notice. One poll races
// the two, so a failed boot fails at once with its text instead of after the whole budget.
// Every wait shares one BOOT_MS deadline; returns the time left on it, for the page's own waits.
async function boot(page, seen, url) {
  const deadline = Date.now() + BOOT_MS;
  const left = () => Math.max(1, deadline - Date.now());
  const response = await page.goto(url, { timeout: left() });
  // A 404 page has no #status either, which the poll below would read as "booted".
  expect(response && response.status(), `${url} is served`).toBe(200);
  const handle = await page.waitForFunction(() => {
    if (!document.getElementById('status')) return 'booted';
    const notice = document.getElementById('status-notice');
    const text = notice ? notice.innerText.trim() : '';
    return text !== '' ? `notice: ${text}` : false;
  }, null, { timeout: left(), polling: 100 });
  expect(await handle.jsonValue(), 'the shell removes #status (the engine started) instead of showing a failure notice').toBe('booted');
  // Polled over the collected messages, never waitForEvent after goto: the line may be in already.
  await expect.poll(() => texts(seen).some((t) => t.startsWith(BANNER)), { message: `the console shows "${BANNER}…"`, timeout: left() }).toBe(true);
  return left;
}

// The checks every page gets, after its own waits.
async function expectClean(page, seen) {
  const notice = await page.evaluate(() => document.getElementById('status-notice')?.innerText.trim() ?? '');
  expect(notice, '#status-notice is empty or gone').toBe('');
  expect(seen.pageErrors, 'no page error').toEqual([]);
  const errors = seen.console
    .filter((m) => m.type === 'error' && !ALLOWED_CONSOLE_ERRORS.some((re) => re.test(m.text)))
    .map((m) => m.text);
  expect(errors, 'no console.error outside ALLOWED_CONSOLE_ERRORS (Godot prints warnings and errors there)').toEqual([]);
}

// The marker within the boot budget, then SETTLE_MS of play, then exactly one: a second marker (a
// broken one-shot) would come later too, and a poll for "1" passes the moment the first arrives.
async function expectMarker(page, seen, left) {
  const markers = () => texts(seen).filter((t) => t === MARKER).length;
  await expect.poll(markers, { message: `"${MARKER}" appears`, timeout: left() }).toBeGreaterThan(0);
  await page.waitForTimeout(SETTLE_MS);
  expect(markers(), `"${MARKER}" appears once, ${SETTLE_MS / 1000} s into play`).toBe(1);
}

test.describe('Web debug', () => {
  test('boots to its first room', async ({ page, seen }) => {
    const left = await boot(page, seen, '/web_debug/index.html');
    await expectMarker(page, seen, left);
    await expectClean(page, seen);
  });

  // DevTools' URL query path (Story 1.11), first run on the web here. --room alone is the plain
  // room (1.12: no perf run). Only ARGS keys are passed, so no foreign parameter can appear, and
  // any "WARNING: DevTools:" line fails (AC8: the ledger's foreign-parameter item).
  test('?room=perf_worst boots straight into that room', async ({ page, seen }) => {
    const left = await boot(page, seen, '/web_debug/index.html?room=perf_worst');
    await expectMarker(page, seen, left);
    const dev = texts(seen).filter((t) => t.startsWith('[room] dev: '));
    expect(dev, 'DevTools applied the query: one summary line, the room only').toEqual(['[room] dev: room perf_worst@spawn']);
    // AC6's literal check. A perf run logs its `[room] dev: perf …` line only when it ends, so this
    // can't fire this early; the summary line above is the proof, since a requested run shows in it.
    expect(texts(seen).filter((t) => t.startsWith('[room] dev: perf')), 'no perf run: it is the plain room').toEqual([]);
    expect(texts(seen).filter((t) => t.includes('WARNING: DevTools:')), 'no DevTools warning (no unknown or bad arg)').toEqual([]);
    await expectClean(page, seen);
  });
});

// Boot-only: a release web build skips runtime script errors silently (D5), so this proves the
// load and the parse, and that nothing errors for a few seconds more.
test.describe('Web (release)', () => {
  test('boots, and stays error-free for 5 s', async ({ page, seen }) => {
    await boot(page, seen, '/web/index.html');
    await page.waitForTimeout(SETTLE_MS);
    await expectClean(page, seen);
    // AC7: DevTools is absent and Log is silent in release. Log's own prefixes only: Chromium's GPU
    // messages also start with "[" ("[.WebGL-0x…]GL Driver Message …").
    expect(texts(seen).filter((t) => LOG_LINE.test(t)), 'no Log line: DevTools and Log are debug-only').toEqual([]);
  });
});

// --- Story 1.14 ------------------------------------------------------------------------------

// scripts/core/display.gd's line (D6). The newest one names the scale now: a step that keeps the
// whole scale (960×540 → 1000×600 at DPR 1) prints nothing new.
const DISPLAY_LINE = /^\[ui\] display: scale (\S+)/;
const newestScale = (seen) => {
  const lines = texts(seen).filter((t) => DISPLAY_LINE.test(t));
  return lines.length ? DISPLAY_LINE.exec(lines[lines.length - 1])[1] : null;
};

// What the engine really drew, from a device-pixel screenshot (D7): the box of non-black pixels
// (the letterbox is exactly 0,0,0, F4) and the colour of its outermost columns at mid-height. The
// browser decodes the PNG, so there is no npm dependency.
async function measure(page) {
  const png = await page.screenshot(); // scale: 'device' by default, so physical pixels
  return page.evaluate(async (b64) => {
    const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
    const bmp = await createImageBitmap(new Blob([bytes], { type: 'image/png' }));
    const W = bmp.width;
    const H = bmp.height;
    const ctx = new OffscreenCanvas(W, H).getContext('2d');
    ctx.drawImage(bmp, 0, 0);
    const d = ctx.getImageData(0, 0, W, H).data;
    let x0 = W, y0 = H, x1 = -1, y1 = -1;
    for (let y = 0; y < H; y++) {
      for (let x = 0; x < W; x++) {
        const i = (y * W + x) * 4;
        if (d[i] || d[i + 1] || d[i + 2]) {
          if (x < x0) x0 = x;
          if (x > x1) x1 = x;
          if (y < y0) y0 = y;
          if (y > y1) y1 = y;
        }
      }
    }
    if (x1 < 0) return { image: [W, H], box: null };
    const mid = Math.floor((y0 + y1) / 2);
    const rgb = (x) => { const i = (mid * W + x) * 4; return [d[i], d[i + 1], d[i + 2]].join(','); };
    return { image: [W, H], box: [x0, y0, x1 - x0 + 1, y1 - y0 + 1], left: rgb(x0), right: rgb(x1) };
  }, png.toString('base64'));
}

// One step's verdict: a 480·s × 270·s box (±1 px for the fit), centred to within 1 px, with both
// outermost gutter columns showing the same non-black colour, so nothing is cropped (F3 cut off
// the right gutter). Note for 1.25: if its HUD puts different pixels there, move the sample row.
function judge(m, scale) {
  const tol = scale < 1 ? 1 : 0;
  const want = [480 * scale, 270 * scale];
  if (!m.box) return { ok: false, why: 'no non-black pixel', ...m };
  const [x, y, w, h] = m.box;
  const [W, H] = m.image;
  const size = Math.abs(w - want[0]) <= tol && Math.abs(h - want[1]) <= tol;
  const centred = Math.abs(x - (W - w) / 2) <= 1 && Math.abs(y - (H - h) / 2) <= 1;
  // AC5: the same non-black colour; two black samples would pass a crop (code review of 1.14).
  const edges = m.left === m.right && m.left !== '0,0,0';
  return { ok: size && centred && edges, want: want.map((v) => +v.toFixed(1)), size, centred, edges, ...m };
}

// D7: expected values come from this table, never a JavaScript copy of the rule (one home:
// display.gd). `css` is the viewport; the physical size is css × dpr, which the engine sees (F1).
const DPR_ROWS = [
  { dpr: 1, steps: [{ css: [960, 540], scale: 2, token: '2' }, { css: [1000, 600], scale: 2, token: '2' },
    { css: [400, 225], scale: 400 / 480, token: '0.833' }, { css: [1000, 600], scale: 2, token: '2' }] },
  { dpr: 1.5, steps: [{ css: [960, 540], scale: 3, token: '3' }, { css: [1000, 600], scale: 3, token: '3' }] },
  // Integer: physical pixels decide, not CSS. 320×180 CSS is 640×360 physical, so ×1, not the fit.
  { dpr: 2, steps: [{ css: [960, 540], scale: 4, token: '4' }, { css: [320, 180], scale: 1, token: '1' }] },
];

test.describe('Display scale', () => {
  for (const row of DPR_ROWS) {
    test.describe(`DPR ${row.dpr}`, () => {
      const [w, h] = row.steps[0].css;
      test.use({ viewport: { width: w, height: h }, deviceScaleFactor: row.dpr });

      test(`${row.steps.map((s) => s.css.join('x')).join(' -> ')} at DPR ${row.dpr}`, async ({ page, seen }) => {
        const left = await boot(page, seen, '/web_debug/index.html');
        await expect.poll(() => newestScale(seen), { message: 'the first "[ui] display:" line', timeout: left() }).not.toBeNull();
        for (const step of row.steps) {
          const label = `${step.css.join('x')} CSS at DPR ${row.dpr}`;
          await page.setViewportSize({ width: step.css[0], height: step.css[1] });
          // A resize lands a frame or two later. Polled as text so a failure prints the whole
          // measurement (the box, the image size, both edge colours), not just `ok: false`.
          await expect.poll(async () => JSON.stringify(judge(await measure(page), step.scale)),
            { message: `${label}: the engine draws x${step.token}, centred, both gutters showing`, timeout: 10_000 })
            .toMatch(/^\{"ok":true,/);
          await expect.poll(() => newestScale(seen),
            { message: `${label}: the newest "[ui] display:" line names scale ${step.token}`, timeout: 10_000 }).toBe(step.token);
        }
        await expectClean(page, seen);
      });
    });
  }
});

// Story 1.14 D7: the release build in an itch-style host page, because the build that ships is
// the one that must not scroll the page. F11 and F12 are never pressed: browsers reserve them,
// and the headless shell isn't the real browser for them (the laptop look checks F11).
const KEYS = ['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space', 'PageUp', 'PageDown', 'Home', 'End',
  'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10'];
// Keyboard scrolling animates; long enough that an unguarded key has visibly moved the host.
const SCROLL_MS = 500;

// boot() for a game inside embed.html: the host page, then the game's frame by its path, then
// the same #status race in that frame. The page's console event carries the frame's messages
// (F11), so `seen` works unchanged. Returns the frame and the time left on the one deadline.
async function bootFrame(page, seen, url, gamePath) {
  const deadline = Date.now() + BOOT_MS;
  const left = () => Math.max(1, deadline - Date.now());
  const response = await page.goto(url, { timeout: left() });
  expect(response && response.status(), `${url} is served`).toBe(200);
  const find = () => page.frames().find((f) => { try { return new URL(f.url()).pathname === gamePath; } catch { return false; } });
  await expect.poll(() => !!find(), { message: `the host page holds a frame at ${gamePath}`, timeout: left() }).toBe(true);
  const frame = find();
  const handle = await frame.waitForFunction(() => {
    if (!document.getElementById('status')) return 'booted';
    const notice = document.getElementById('status-notice');
    const text = notice ? notice.innerText.trim() : '';
    return text !== '' ? `notice: ${text}` : false;
  }, null, { timeout: left(), polling: 100 });
  expect(await handle.jsonValue(), 'the frame removes #status (the engine started) instead of showing a failure notice').toBe('booted');
  await expect.poll(() => texts(seen).some((t) => t.startsWith(BANNER)), { message: `the console shows "${BANNER}…"`, timeout: left() }).toBe(true);
  return { frame, left };
}

test.describe('Web input', () => {
  test('keys never scroll the host page, focused or blurred (embed.html?build=web)', async ({ page, seen }) => {
    const { frame } = await bootFrame(page, seen, '/embed.html?build=web', '/web/index.html');
    const scrollY = () => page.evaluate(() => window.scrollY);
    const canvasActive = () => frame.evaluate(() => document.activeElement === document.getElementById('canvas'));
    // Bubble phase on the frame's window: it sees each key after Godot's and the guard's listeners.
    await frame.evaluate(() => {
      window.__keys = [];
      addEventListener('keydown', (e) => window.__keys.push(`${e.code}:${e.defaultPrevented}`));
    });
    const takeKeys = () => frame.evaluate(() => window.__keys.splice(0));
    const prevented = (keys) => keys.map((k) => `${k}:true`);

    // Focused: focusCanvas (F6) gave the canvas focus at boot.
    expect(await canvasActive(), 'the canvas has focus after boot').toBe(true);
    for (const k of KEYS) await page.keyboard.press(k);
    await page.waitForTimeout(SCROLL_MS);
    expect(await takeKeys(), 'canvas focused: every key reaches the frame prevented').toEqual(prevented(KEYS));
    expect(await scrollY(), 'canvas focused: the host page has not scrolled').toBe(0);

    // Blurred inside the frame: without the guard this scrolled the host by 619 px (F7).
    await frame.evaluate(() => document.activeElement.blur());
    expect(await frame.evaluate(() => document.activeElement === document.body), 'blur() moved focus to the frame\'s body').toBe(true);
    await page.keyboard.press('ArrowDown');
    await page.waitForTimeout(SCROLL_MS);
    expect(await scrollY(), 'blurred: ArrowDown leaves the host page at scrollY 0').toBe(0);
    expect(await canvasActive(), 'blurred: the guard gave the canvas focus back on the first key').toBe(true);
    const rest = KEYS.filter((k) => k !== 'ArrowDown');
    for (const k of rest) await page.keyboard.press(k);
    await page.waitForTimeout(SCROLL_MS);
    expect(await takeKeys(), 'blurred: every key reaches the frame prevented').toEqual(prevented(['ArrowDown', ...rest]));
    expect(await scrollY(), 'blurred: the host page has still not scrolled').toBe(0);

    // Blurred, then a game key (code review of 1.14): any key gives the canvas focus back, so Jump
    // and Attack recover without an arrow. The guard leaves an unguarded key alone (not prevented).
    await frame.evaluate(() => document.activeElement.blur());
    await page.keyboard.press('KeyZ');
    expect(await canvasActive(), 'blurred: a game key (KeyZ) also gives the canvas focus back').toBe(true);
    expect(await takeKeys(), 'blurred: the guard does not prevent a game key').toEqual(['KeyZ:false']);

    const notice = await frame.evaluate(() => document.getElementById('status-notice')?.innerText.trim() ?? '');
    expect(notice, 'the frame\'s #status-notice is empty or gone').toBe('');
    await expectClean(page, seen);
  });
});
