// The web boot smoke (Story 1.13 D7, AR53): headless Chromium against a build folder's web/ and
// web_debug/, served by serve.js. tools/export.sh runs it after the exports; it also runs alone:
//   B="$PWD/builds/<version>"; (cd tools/web_smoke && BUILD_DIR="$B" npx playwright test)
// Correctness only: headless WebGL runs on SwiftShader, so it says nothing about performance.
// @ts-check
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { defineConfig } = require('@playwright/test');

// 8061, so a laptop tunnel's serve.js on 8060 never fails a build (D8).
const PORT = Number(process.env.PORT || 8061);
const BUILD_DIR = process.env.BUILD_DIR ? path.resolve(process.env.BUILD_DIR) : '';
const missing = ['web', 'web_debug'].filter((d) => !BUILD_DIR || !fs.existsSync(path.join(BUILD_DIR, d, 'index.html')));
if (missing.length) {
  throw new Error(`web smoke: set BUILD_DIR to a build folder holding web/ and web_debug/ (BUILD_DIR=${BUILD_DIR || '(unset)'}; missing ${missing.join(', ')})`);
}

const baseURL = `http://127.0.0.1:${PORT}`;

module.exports = defineConfig({
  testDir: '.',
  workers: 1,
  retries: 0,
  reporter: 'line',
  // Playwright's 30 s default would cut the 60 s boot budget each page gets (smoke.spec.js).
  timeout: 150_000,
  expect: { timeout: 60_000 },
  use: { headless: true, baseURL },
  // No channel: the --only-shell install has the headless shell and no full Chromium. No launch
  // args: Playwright adds --enable-unsafe-swiftshader itself, and WebGL2 works with it (probed).
  projects: [{ name: 'chromium', use: { browserName: 'chromium' } }],
  webServer: {
    command: 'node serve.js',
    // A real file: a / that answered 404 would hang this wait.
    url: `${baseURL}/web/index.html`,
    reuseExistingServer: false,
    env: { BUILD_DIR, PORT: String(PORT) },
  },
});
