# BeePack House Rules

The shared house rules come from skilletor — bundle `getty-cpan-dist@getty`: engineering
discipline, the delegation lock, the publish gate, karr coordination, CPAN release. They load
as `.claude/rules/.local.*.md`; if they are missing, run `skilletor sync` and publish nothing
until they load. This file adds what is true only here, and wins where it differs.

## What this repo is

Primitive MsgPack based key value storage. Read first: `lib/BeePack.pm` and `bin/bee` share one
behaviour surface (the type dispatch, the open/save model); read both before changing either.

## Agent team

| Task | Agent |
|---|---|
| Implement / refactor / debug `lib/BeePack.pm` or `bin/bee` (incl. POD) | `beepack-worker` (default) |
| Write or extend tests in `t/` | `beepack-test-writer` |
| Commits, `Changes`, card → done, pre-release audit | `beepack-release-manager` |
| Read-only research, audit, gap analysis | `beepack-worker` ("read-only, change nothing") |

Behavior-relevant = `lib/BeePack.pm`, `bin/bee`, their POD and the tests in `t/` — not
README/Changes prose. One board, no cross-repo handoff.

## Release

The tree's version is the *next* release: `dzil release` bumps and tags — never hand-bump it
outside a deliberate version-seeding change. The public tracker is GitHub
`cindustries/p5-beepack`.

## Hazards — locks here, mechanisms in `beepack-core`

- **`prove -l t/` is not recursive** — it silently skips subdirectory tests and exits 0. Use
  `dzil test` or `prove -lr t/`; reserve non-`-r` for a single named file.
- **The CDB backend is `CDB_File`** — self-contained, no system `libcdb` dependency, no CI
  system-library step.
- **The CLI and the library must not drift.** `bin/bee`'s type dispatch mirrors `set_type` in
  `lib/BeePack.pm`; a new value type is a paired edit in both.
- **`nil_exists` and the in-memory-buffer / rebuild-on-save model are deliberate** — they are
  load-bearing and tested, not dead-simple code worth collapsing.
- **A test that only checks an accessor cannot fail when MsgPack packing breaks.** Test the
  packed bytes.

## Perl conventions — reference, don't restate

Module loading, Moo patterns, dependency pinning, `$VERSION`, the `[@Author::GETTY]` release
workflow and BeePack's internals live in skills `getty-perl-core`, `getty-perl-moo`,
`getty-perl-release-author-getty`, `perl-release-dist-ini` and `beepack-core` — force-loaded per
lane.
