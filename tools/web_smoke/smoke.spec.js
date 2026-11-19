// The web boot smoke (Story 1.13 AC6, AR53). Both web builds boot in headless Chromium; the debug
// build is the runtime check, because a release web build prints parse and load errors but never
// runtime script errors (D5). Later stories add their checks here as test.describe blocks: the
// DPR scale and keys that must not scroll (1.14), the click-to-play gate (1.33), SMOKE save ok
// (1.39), the pogo pitch (3.3).
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
