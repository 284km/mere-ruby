# CI on main runs to the end (2026-11-23)

## What was wrong

Every workflow had `cancel-in-progress: true` in a concurrency group keyed by the PR number or, on main, by `refs/heads/main`. On main that meant each merge cancelled the run of the merge before it. With merges arriving faster than a full CI run finishes, no CI run on main has completed since around #135. The last run to finish on main is 2e2ab568 (2026-11-21).

The merge policy lets a PR in before its own CI finishes and relies on main's CI to catch what slipped through. That check was not happening. The one main run that got as far as its corpus job before being cancelled (c521aa58) shows a real failure there: `unittest/openssl_asn1_check.py` reports 249 differences.

## The change

`cancel-in-progress` is now `${{ github.event_name == 'pull_request' }}` in all twelve workflows that set it.

- On a PR, a new push still cancels the old run, as before.
- On main, the run in progress finishes. GitHub keeps at most one pending run per concurrency group, so a newer merge replaces a run that is still waiting, not one that is running. Each finished run is for some commit on main, and the latest commit always gets a run.

No runtime or test code changes.
