// ui-review.mjs — the STANDARD way QA verifies a running UI.
// Captures a screenshot, collects console/page errors, and can run simple
// behavioral assertions (click a selector, expect a download). The orchestrator
// then Reads the PNG and judges it — verify BEHAVIOR, not just a passing build.
//
// Usage:
//   node ui-review.mjs --url <url> --name <shot> [--click <selector>]
//                      [--wait <ms>] [--expect-download] [--out <dir>]
//                      [--viewport desktop,mobile|1440x900] [--json]
//
// Requires playwright resolvable from the cwd or this kit (npm i -D playwright once per
// project; the chromium binary is cached globally after first install).
//
// Output: human text by default, JSON with --json. Exits nonzero on failed navigation,
// failed click, console/page errors, or missing expected download.
import { mkdir } from 'node:fs/promises';
import { createRequire } from 'node:module';

function arg(flag, def = undefined) {
  const i = process.argv.indexOf(flag);
  return i !== -1 ? (process.argv[i + 1] ?? true) : def;
}
function has(flag) {
  return process.argv.includes(flag);
}
function viewportSpec(raw) {
  const aliases = {
    desktop: { label: 'desktop', width: 1440, height: 900 },
    tablet: { label: 'tablet', width: 768, height: 1024 },
    mobile: { label: 'mobile', width: 390, height: 844 },
  };
  if (aliases[raw]) return aliases[raw];
  const m = /^(\d+)x(\d+)$/.exec(raw);
  if (!m) throw new Error(`bad viewport: ${raw}`);
  return { label: raw, width: Number(m[1]), height: Number(m[2]) };
}
async function loadChromium() {
  try {
    return (await import('playwright')).chromium;
  } catch (kitError) {
    try {
      return createRequire(`${process.cwd()}/package.json`)('playwright').chromium;
    } catch (cwdError) {
      const error = new Error('Playwright is not installed. Run `npm i -D playwright` in the project or install it in agent-kit.');
      error.cause = { kitError, cwdError };
      throw error;
    }
  }
}

const url = arg('--url', process.env.REVIEW_URL);
const name = arg('--name', 'shot');
const clickSel = arg('--click', '');
const waitMs = Number(arg('--wait', 1500));
const expectDownload = has('--expect-download');
const outDir = arg('--out', 'shots');
const json = has('--json');
const viewports = String(arg('--viewport', 'desktop')).split(',').filter(Boolean).map(viewportSpec);

if (!url) {
  const report = { ok: false, error: '--url required' };
  console.log(json ? JSON.stringify(report, null, 2) : 'ERROR: --url required');
  process.exit(2);
}

await mkdir(outDir, { recursive: true });
let chromium;
try {
  chromium = await loadChromium();
} catch (error) {
  const report = { ok: false, error: String(error.message || error) };
  console.log(json ? JSON.stringify(report, null, 2) : `ERROR: ${report.error}`);
  process.exit(2);
}
const browser = await chromium.launch();
const results = [];

for (const viewport of viewports) {
  const page = await browser.newPage({ viewport: { width: viewport.width, height: viewport.height } });
  const errors = [];
  let clickError = '';
  let downloadResult = '';
  let downloadFilename = '';
  let gotoError = '';

  page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
  page.on('pageerror', (e) => errors.push(String(e)));

  await page.goto(url, { waitUntil: 'networkidle' }).catch((e) => { gotoError = String(e); });

  if (expectDownload) {
    const dl = page.waitForEvent('download', { timeout: 15000 }).catch(() => null);
    if (clickSel) {
      await page.click(clickSel, { timeout: 5000 }).catch((e) => { clickError = String(e); });
    }
    if (clickError) {
      downloadResult = 'NO_DOWNLOAD';
    } else {
      const d = await dl;
      if (d) {
        downloadResult = 'DOWNLOAD_OK';
        downloadFilename = d.suggestedFilename();
      } else {
        downloadResult = 'NO_DOWNLOAD';
      }
    }
  } else if (clickSel) {
    await page.click(clickSel, { timeout: 5000 }).catch((e) => { clickError = String(e); });
  }

  await page.waitForTimeout(waitMs);
  const suffix = viewports.length > 1 ? `-${viewport.label}` : '';
  const path = `${outDir}/${name}${suffix}.png`;
  await page.screenshot({ path });
  await page.close();

  const ok = !gotoError && !clickError && errors.length === 0 && (!expectDownload || downloadResult === 'DOWNLOAD_OK');
  results.push({
    ok,
    viewport,
    screenshot: path,
    gotoError,
    clickError,
    consoleErrors: errors,
    download: expectDownload ? { result: downloadResult, filename: downloadFilename } : null,
  });
}
await browser.close();

const report = { ok: results.every((r) => r.ok), url, results };

if (json) {
  console.log(JSON.stringify(report, null, 2));
} else {
  for (const result of results) {
    console.log(`SHOT ${result.screenshot} ${result.viewport.label} ${result.viewport.width}x${result.viewport.height}`);
    if (result.download) {
      console.log(result.download.result + (result.download.filename ? ` filename=${result.download.filename}` : ''));
    }
    if (result.gotoError) console.log(`GOTO_ERROR ${result.gotoError}`);
    if (result.clickError) console.log(`CLICK_ERROR ${result.clickError}`);
    if (result.consoleErrors.length) console.log('CONSOLE_ERRORS:\n' + result.consoleErrors.join('\n'));
    else console.log('OK no console/page errors');
  }
}

process.exit(report.ok ? 0 : 1);
