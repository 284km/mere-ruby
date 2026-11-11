// The same pinned C engine as the native build, with a fresh reactor per VM.
// Only byte wires cross the two memories; neither collector owns C pointers.
export function createNkfBridge(module, getMemory, allocate) {
  class NkfAbort extends Error {
    constructor(status) { super(`NKF allocation failure (${status})`); this.status = status; }
  }
  let instance;
  const reset = () => {
    instance = new WebAssembly.Instance(module, {
      env: { mr_nkf_abort: status => { throw new NkfAbort(status); } },
      wasi_snapshot_preview1: {
        fd_close: () => 8, fd_seek: () => 8, fd_write: () => 8,
        proc_exit: status => { throw new Error(`unexpected NKF reactor exit ${status}`); },
      },
    });
    instance.exports._initialize();
  };
  reset();
  const call = (name, ...args) => {
    try { return Number(instance.exports[name](...args)); }
    catch (error) {
      if (!(error instanceof NkfAbort)) throw error;
      // A thrown import unwinds through C without restoring its stack. Drop
      // that reactor completely before allowing the Ruby exception to recover.
      reset();
      return error.status;
    }
  };
  const argument = (pointer, string) => {
    const source = new Uint8Array(getMemory().buffer);
    let start = pointer, length;
    if (string) {
      let end = start;
      while (end < source.length && source[end] !== 0) ++end;
      if (end === source.length) throw new Error('unterminated NKF option');
      length = end - start + 1;
    } else {
      length = new DataView(source.buffer).getInt32(pointer, true);
      if (length < 0 || length > 0x7ffffffb) return null;
      length += 4;
    }
    if (start < 0 || start + length > source.length) throw new Error('invalid NKF input wire');
    const temporary = instance.exports.mr_nkf_wasm_alloc(length);
    if (!temporary) return null;
    new Uint8Array(instance.exports.memory.buffer).set(source.subarray(start, start + length), temporary);
    return temporary;
  };
  const withArgument = (name, pointer, string = false) => {
    const owner = instance;
    const temporary = argument(pointer, string);
    if (temporary === null) return 2;
    try { return call(name, temporary); }
    finally { if (instance === owner) owner.exports.mr_nkf_wasm_free(temporary); }
  };
  const result = name => {
    const pointer = instance.exports[name]();
    if (!pointer) throw new Error('missing NKF result wire');
    const memory = instance.exports.memory;
    const length = new DataView(memory.buffer).getInt32(pointer, true);
    if (length < 0 || pointer + 4 + length > memory.buffer.byteLength) throw new Error('invalid NKF result wire');
    const target = allocate(4 + length);
    const output = getMemory();
    new DataView(output.buffer).setInt32(target, length, true);
    new Uint8Array(output.buffer).set(new Uint8Array(memory.buffer, pointer + 4, length), target + 4);
    return target;
  };
  return {
    mr_nkf_reset: guessing => call('mr_nkf_reset', BigInt(guessing)),
    mr_nkf_options: pointer => withArgument('mr_nkf_options', pointer, true),
    mr_nkf_convert: pointer => withArgument('mr_nkf_convert', pointer),
    mr_nkf_guess: pointer => withArgument('mr_nkf_guess', pointer),
    mr_nkf_result: () => result('mr_nkf_result'),
    mr_nkf_encoding_bytes: () => result('mr_nkf_encoding_bytes'),
    mr_nkf_base_encoding_bytes: () => result('mr_nkf_base_encoding_bytes'),
    mr_nkf_clear_result: () => call('mr_nkf_clear_result'),
    mr_nkf_cleanup: () => call('mr_nkf_cleanup'),
  };
}
