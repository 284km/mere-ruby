// Run one Ruby program through the SHIPPED playground: docs/mere-ruby.wasm,
// driven by docs/index.html's own host code, without a browser.
//
//   node docs/smoke.mjs 'puts 1 + 1'
//   node --stack-size=8000 docs/smoke.mjs "$(cat prog.rb)"
//
// The host is not reimplemented here -- formatFloat and makeInstance are lifted
// out of index.html at run time, so this cannot drift from what the page does.
// A paraphrased host tests the paraphrase: an earlier version of this file
// printed -2 where the page prints -2.0, and answered "not a float" for "nan".
//
// A deep program needs a bigger JS stack than node's default (the parser and
// the evaluator recurse); --stack-size is the browser-side equivalent of the
// native build's -Wl,-stack_size. See PAIN.md §M9.
import { readFileSync } from "fs";

const here = new URL(".", import.meta.url);
const page = readFileSync(new URL("index.html", here), "utf8");
const lift = (open, close) => {
  const i = page.indexOf(open);
  if (i < 0) throw new Error(`smoke: ${open.trim()} is not in index.html any more`);
  const j = page.indexOf(close, i);
  return page.slice(i, j + close.length);
};
// the page's own values for what makeInstance closes over
const SENTINEL = (page.match(/const SENTINEL = "([^"]+)"/) || [])[1];
const PAGE = (page.match(/const PAGE = (\d+)/) || [])[1] ?? "65536";
if (!SENTINEL) throw new Error("smoke: no SENTINEL in index.html");

const code = [
  `const SENTINEL = ${JSON.stringify(SENTINEL)};`,
  `const PAGE = ${PAGE};`,
  `export let currentSrc = "";`,
  `export const setSrc = (s) => { currentSrc = s; };`,
  lift("    function formatFloat(f) {", "\n    }\n"),
  lift("    function makeInstance() {", "\n    }\n"),
  `export { makeInstance };`,
].join("\n");
const mod = await import("data:text/javascript," + encodeURIComponent(code));

mod.setSrc(process.argv[2] ?? "puts 1 + 1");
const wasm = process.env.SMOKE_WASM ?? new URL("mere-ruby.wasm", here);
const host = mod.makeInstance();
const { instance } = await WebAssembly.instantiate(readFileSync(wasm), { env: host.env });
host.bind(instance);
// `exit(status)` lowers to `unreachable` on this backend, so a NORMAL program
// ends in a trap once its output is flushed -- the page treats a trap that
// produced output as success, and so does this.
let trapped = false;
try { instance.exports.main(); } catch (e) { trapped = true; }
const out = host.getOut();
process.stdout.write(out);
if (out === "") {
  console.error("smoke: no output" + (trapped ? " (trapped before printing anything)" : ""));
  process.exit(1);
}
