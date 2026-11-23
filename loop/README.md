# loop/ — one record per change

From 2026-11-23, a change's LOOP record goes in **its own file here**, not at the
end of `LOOP.md`. Nearly every PR used to conflict with every other PR in
`LOOP.md`, because they all appended to the same place. Separate files do not
conflict.

`LOOP.md` stays as it is: the history up to 2026-11-23. Do not append to it.
A PR that was opened before this change and already appends to `LOOP.md` may
keep its record there.

## Naming

`loop/YYYY-MM-DD-<branch>.md`, for example `loop/2026-11-23-stage10-r50.md`.
One file per PR. A later round on the same branch adds a section to the same
file. Start the file with one `#` heading that says what the change is, the same
way the `## ` headings of `LOOP.md` did. Headings must not repeat inside a file
(`mspec/record_hygiene.sh` checks this).

## Corpus numbers

Each work stream takes corpus numbers from its own range, so nobody has to
announce a number before using it.

| range | stream |
|---|---|
| 806–849 | VM and JIT |
| 850–889 | AST, Prism and parser speed |
| 890–929 | C API and native extensions |
| 930–959 | Rails: activesupport, activemodel, actionview, actionpack, activejob, actionmailer (Rails-1) |
| 960–979 | Rails: activerecord (Rails-2) |
| 980–999 | process, CI and anything else |

When a range runs out, add the next free block of 50 for that stream to this
table in the same PR that first needs it.
