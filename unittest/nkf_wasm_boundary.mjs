// Exercise the shipped bridge itself, including a C allocation failure import
// that unwinds a reactor and requires a fresh instance before recovery.
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { createNkfBridge } from '../docs/nkf.mjs';

const module = await WebAssembly.compile(readFileSync(process.argv[2]));
let memory = new WebAssembly.Memory({ initial: 16, maximum: 256 });
let bump = 1024;
const allocate = length => {
  const pointer = bump;
  bump += (length + 7) & ~7;
  if (bump > memory.buffer.byteLength) memory.grow(Math.ceil((bump - memory.buffer.byteLength) / 65536));
  return pointer;
};
const input = bytes => {
  const pointer = allocate(4 + bytes.length);
  new DataView(memory.buffer).setInt32(pointer, bytes.length, true);
  new Uint8Array(memory.buffer).set(bytes, pointer + 4);
  return pointer;
};
const option = value => {
  const bytes = new TextEncoder().encode(value + '\0');
  const pointer = allocate(bytes.length);
  new Uint8Array(memory.buffer).set(bytes, pointer);
  return pointer;
};
const result = pointer => {
  const length = new DataView(memory.buffer).getInt32(pointer, true);
  return [...new Uint8Array(memory.buffer, pointer + 4, length)];
};
const instances = [];
const NativeInstance = WebAssembly.Instance;
try {
  WebAssembly.Instance = class extends NativeInstance {
    constructor(...args) { super(...args); instances.push(this); }
  };
  const bridge = createNkfBridge(module, () => memory, allocate);
  let failures = 0;
  for (let at = 0; at < 40; ++at) {
    memory = new WebAssembly.Memory({ initial: 16, maximum: 256 }); bump = 1024;
    const before = instances.at(-1);
    before.exports.mr_nkf_test_fail_after(BigInt(at));
    let status = bridge.mr_nkf_reset(0);
    if (!status) status = bridge.mr_nkf_options(option('-w -MB'));
    if (!status) status = bridge.mr_nkf_convert(input(new Uint8Array(2000).fill(65)));
    assert.ok(status === 0 || status === 2);
    if (status === 2) {
      ++failures;
      assert.notEqual(instances.at(-1), before, 'aborted C stack must be discarded');
    }
    const current = instances.at(-1);
    current.exports.mr_nkf_test_fail_after(-1n);
    assert.equal(bridge.mr_nkf_clear_result(), 0);
    assert.equal(bridge.mr_nkf_reset(0), 0);
    assert.equal(bridge.mr_nkf_options(option('-w')), 0);
    assert.equal(bridge.mr_nkf_convert(input([227, 129, 130, 0, 65])), 0);
    assert.deepEqual(result(bridge.mr_nkf_result()), [227, 129, 130, 0, 65]);
    assert.equal(new TextDecoder().decode(new Uint8Array(result(bridge.mr_nkf_encoding_bytes()))), 'UTF-8');
    assert.equal(new TextDecoder().decode(new Uint8Array(result(bridge.mr_nkf_base_encoding_bytes()))), 'UTF-8');
    assert.equal(bridge.mr_nkf_cleanup(), 0);
    assert.equal(current.exports.mr_nkf_test_allocations(), 0);
    assert.equal(bridge.mr_nkf_cleanup(), 0);
  }
  assert.ok(failures >= 8);
  console.log(`Wasm bridge: 40 allocation controls, ${failures} reactor replacements, binary recovery and cleanup passed`);
} finally {
  WebAssembly.Instance = NativeInstance;
}
