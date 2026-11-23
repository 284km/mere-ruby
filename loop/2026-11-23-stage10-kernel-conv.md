# Kernel.Integer is Kernel's own conversion, not the caller's self's (a regression from round 94)

## The regression

main's CI corpus job failed all 249 cases of unittest/openssl_asn1_check.py with NoMethodError. `OpenSSL::ASN1.decode(der).to_der` goes through lib/openssl_asn1.rb's `tag = ::Kernel.Integer(tag)`, and inside OpenSSL::ASN1 that called the module function `OpenSSL::ASN1.Integer` (the ASN.1 INTEGER constructor) instead of Kernel's conversion.

- `Kernel.puts` / `::Kernel.Integer` reuse the bare call: the call runs as `Integer(x)` with the caller's self, unless that self has a method of the name, in which case it runs with Kernel as self. That check asked `dispatch_cls_of` of the self. For a module that is the module's instance methods, not its singleton class, so a module function was never seen there.
- Round 94 (#161) made a bare conversion function ask kernel_overridden first, which counts self's own methods, so that `Integer(30)` meets a program's definition (test_mandatory_only_redef). For a bare `Integer(x)` in OpenSSL::ASN1 that is right: ruby calls ASN1.Integer there. But `Kernel.Integer` went down the same path and met it too.

## The fix

- `Kernel.<conversion>` (`is_kernel_conv`: Integer, Float, String, Array, Hash, Rational, Complex) now calls kernel_conv_fn directly. It does not look at the caller's self, and it does not look at a program's `Kernel#Integer` either, which `Kernel.Integer` does not see in ruby.
- The check of the caller's self for the other Kernel module functions (`Kernel.load` inside a class that has `load`) now asks a class's or a module's singleton class, where its own methods are.

Corpus 807 has the cases. It differs on main's build on both executions.

**Why it was not seen.** main's CI cancelled each run when the next merge came, so no main run had finished since about #135. The PR's local checks list the corpus (run_corpus.sh), and that does not include the CI corpus job's OpenSSL checks (unittest/openssl_*_check.py). They are run below.

**Checked (local, Mere 0c083af0, on main ab350da1).**
- The CI corpus job's OpenSSL checks, with ruby 4.0.9 as the reference:
  - openssl_asn1_check: 874 cases match. main's build fails 249.
  - openssl_provider_check, openssl_formats_check, openssl_reinitialize_check, openssl_memory_check and openssl_wasm_check all pass.
- corpus 808/808; under MERE_RUBY_VM=1, 798 on the VM, 10 fallen back, 0 different. vm_check 245/245, and the gates.
- On both executions:
  - test_iseq: 68 tests, 1 failure, 2 errors, as in round 94. test_mandatory_only_redef passes.
  - test_float, test_rational and test_complex: no failures.
