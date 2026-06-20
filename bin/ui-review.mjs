// ui-review.mjs — the STANDARD way QA verifies a running UI.
// Captures a screenshot, collects console/page errors, and can run simple
// behavioral assertions (click a selector, expect a download). The orchestrator
// then Reads the PNG and judges it — verify BEHAVIOR, not just a passing build.
//
// Usage:
//   node ui-review.mjs --url <url> --name <shot> [--click <selector>]
//                      [--wait <ms>] [--expect-download] [--out <dir>]
//
// Requires playwright resolvable from the cwd (npm i -D playwright once per
// project; the chromium binary is cached globally after first install).
//
// Output: prints one of OK / CONSOLE_ERRORS / DOWNLOAD_OK / NO_DOWNLOAD and the
// screenshot path. Exit code is always 0 (the orchestrator reads the report).
import { chromium } from 'playwright';

function arg(flag, def = undefined) {
  const i = process.argv.indexOf(flag);
  return i !== -1 ? (process.argv[i + 1] ?? true) : def;
}
const url = arg('--url', process.env.REVIEW_URL);
const name = arg('--name', 'shot');
const clickSel = arg('--click', '');
const waitMs = Number(arg('--wait', 1500));
const expectDownload = process.argv.includes('--expect-download');
const outDir = arg('--out', 'shots');

if (!url) { console.log('ERROR: --url required'); process.exit(0); }

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
const errors = [];
page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
page.on('pageerror', (e) => errors.push(String(e)));

await page.goto(url, { waitUntil: 'networkidle' }).catch((e) => errors.push('goto: ' + e));

let downloadResult = '';
if (expectDownload) {
  const dl = page.waitForEvent('download', { timeout: 15000 }).catch(() => null);
  if (clickSel) await page.click(clickSel, { timeout: 5000 }).catch(() => {});
  const d = await dl;
  downloadResult = d ? `DOWNLOAD_OK filename=${d.suggestedFilename()}` : 'NO_DOWNLOAD';
} else if (clickSel) {
  await page.click(clickSel, { timeout: 5000 }).catch(() => {});
}

await page.waitForTimeout(waitMs);
const path = `${outDir}/${name}.png`;
await page.screenshot({ path });
await browser.close();

console.log(`SHOT ${path}`);
if (downloadResult) console.log(downloadResult);
if (errors.length) console.log('CONSOLE_ERRORS:\n' + errors.join('\n'));
else console.log('OK no console/page errors');
