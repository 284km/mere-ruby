# Validation-only integration branch

This own experimental branch is never a main merge or release candidate.
It does not change another session's branch or PR. Runtime observations
remain tied to their exact source commits rather than this documentation tip.

- 54184e4e: C API-only dependency installation reaches the original wall bound.
- 153e64f5: C API plus the first SHA-2 provider implementation installs all 68
  gems, then migration stops at command registration.
- 5d1a0c95: current C API, bounded SHA-2 #120 and Class dispatch #125 install
  all 68 gems again; the original CLI passes registration and reaches the
  actual Hash missing-hook failure #123 during application loading.
- a9c8a2ff: the gem/Hash composition exposes the native-build child monitor
  fallback-ordering failure. Its failed cold record is preserved.
- 0b76e819: the intake restores fallback ordering before RubyGems startup;
  all 68 gems install and the CLI reaches JSON native feature selection #127.
- 61d01f6d: native selection #128 loads the actual locked JSON implementation.
  All 68 gems install again; the CLI next fails in ActiveModel because Ruby
  super misses Module's native included hook (#129). The ordinary gem-free
  hook probe reproduces it on the preceding Hash parent as well.

The latest reference passes all six original stages. Mere boot, app tests
and HTTP remain NOT_RUN. Source locks and 600-second / 2-GiB family bounds
are unchanged. Raw local artifacts are not committed. Portable records and
probes belong to independent intake PR #117. Production/runtime changes
belong to their separate reviewed PRs (#120, #125, #126 and #128).

Every historical record remains tied to its exact runtime source, binary and
startup inputs. The documentation tip does not supersede those measurements;
no direct-library or TracePoint diagnostic replaces an original CLI stage.
