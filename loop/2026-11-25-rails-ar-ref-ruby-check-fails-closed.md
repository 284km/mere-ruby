# The reference's gem-directory check stops when it cannot run

**Why.** #224's review (work2026-44, a Suggestion): `tools/ref_ruby.sh` runs a `ruby -e` script to list the gems in the reference's gem directory that ruby does not ship, with its stderr thrown away, and decides only by whether stdout is empty. If the script itself fails, it prints nothing, and the check passes: an open check.

**The change.** The script's stderr goes to the terminal, and its exit status is read. A non-zero status stops with exit 2 and says the check did not run (`REF_RUBY_EXTRA_GEMS_OK=1` still skips the check altogether).

**Checked.**

- On this machine's clean ruby 4.0.10 the check passes as before.
- With the script made to raise (a copy of `ref_ruby.sh` with `raise "boom"` put in), the RuntimeError shows on stderr, the message names the check, and the sourcing shell stops with exit 2. Before, the same copy passed with nothing said.
- `sh -n tools/ref_ruby.sh`. `mspec/record_hygiene.sh`.
