# The framework runner takes `--env NAME=VALUE` for both sides, recorded and publishable

**Why.** Rails-2 runs activerecord with the sqlite3 adapter, which its tests choose with `ARCONN=sqlite3`. `run.py` builds each side's environment from a scrubbed one. It drops `RAILS_*`, `CI` and the like, and gives mere-ruby `MERE_RUBY_*` only through `--mere-env` (#181), so there was no way to set a component's own variable.

**The change.**

- `run --env NAME=VALUE`, repeatable, gives the setting to both sides alike, after the runner's own settings (`side_environment`).
- `results.json` records it under `env`.
- Because the record is published, `shared_settings` refuses:
  - a NAME the runner makes for each side: the gem home, `RUBYOPT`, `RUBYLIB`, `TMPDIR`, `BUNDLE_*` and the others in `RESERVED`;
  - `MERE_RUBY_*`, which belongs to `--mere-env`;
  - a NAME that looks like a secret (`TOKEN`, `SECRET`, `PASSW…`, `API_KEY`, …);
  - a VALUE that holds a path of this machine (one starting with `/` or `~`, or containing `/Users/`, `/home/`, …).
- `check.py` covers both sides getting the value, the runner's own settings winning, and each refusal.
- The README says so.

**Corpus ranges.** `loop/README.md` splits Rails's 930–979 between the two Rails streams, as agreed with Rails-1:

- 930–959 for Rails-1: activesupport, activemodel, actionview, actionpack, activejob and actionmailer.
- 960–979 for Rails-2: activerecord.
