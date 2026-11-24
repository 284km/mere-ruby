# The lines after the last error, in a source with no final newline

From the review of #229. Prism's report of a syntax error shows two lines after the last error's line. In a source that does not end with a newline it showed one fewer here:

```ruby
eval("1\n/(x/\n3\n4", binding, "m.rb", 1)
```

ruby's message ends with `3 | 3` and `4 | 4`; this one ended with `3 | 3`.

`prism_report` took the source's last line to be the one before the last line start, which is right when the source ends with a newline (the start after it is no line) and one short when it does not. It now counts the lines the source has.

Corpus 817 has three more sources, of one, two and three lines after the error and no final newline, each as a required file and in an eval.

## Recorded, as on main, on both executions

Under `-W`, ruby says Prism's warnings of a multi-line eval ("possibly useless use of a literal in void context") before its SyntaxError. Here they are not said (from the review of #229).

## Checked

Against ruby 4.0.10 (tools/ref_ruby.sh), built with Mere 9dec2ff6, on main cdae4f60:
- corpus 871/871. Under MERE_RUBY_VM=1: 867 on the VM, 4 fell back, 0 different.
- Corpus 817 differs on main's build, on both executions.
- vm_check 245/245.
- The gates: dead defs, dup defs, gc roots, bracket depth.
- The CI corpus job's OpenSSL checks: asn1, provider, formats, reinitialize, memory, wasm.
