# Contributing to flix-miniparse

This document is for people **working on this repository** (library authors, learners cloning the labs). If you only want to depend on `miniparse` from another Flix project, see the root [README.md](README.md).

## Requirements

- **JDK 21+**
- **Flix 0.75.1+** (must match `flix` in [`flix.toml`](flix.toml))

Optional but recommended for a reproducible shell:

- [Nix](https://nixos.org/) with flakes, and/or [direnv](https://direnv.net/)

## Development shell (Nix)

The repo provides a [flake.nix](flake.nix) with Flix and JDK 21:

```bash
nix develop          # or: direnv allow  (if you use .envrc)
flix --version
```

Without Nix, install JDK 21 and [Flix 0.75.1](https://github.com/flix/flix/releases) yourself and put `flix` on `PATH`.

## Day-to-day commands

| Command | Purpose |
| --- | --- |
| `flix check` | Type-check |
| `flix test` | Unit and lab tests |
| `flix run` | Guided tour of `Examples.*` (`Main.flix`) |
| `flix build-pkg` | Build `artifact/flix-miniparse.fpkg` (**library only**) |
| `bash scripts/check-fpkg.sh` | Guard: fpkg has no `Main` / `Examples` |

CI: [`.github/workflows/build-and-test.yaml`](.github/workflows/build-and-test.yaml) (JDK 21, Flix version from `flix.toml`).

## Project layout

```text
flix-miniparse/
├── flix.toml              # package manifest (name: miniparse)
├── flake.nix              # reproducible Flix + JDK 21 shell
├── Main.flix              # flix run tour (not shipped in fpkg)
├── src/
│   └── MiniParse/         # library (published in fpkg)
├── test/
│   ├── Examples/          # labs / demos (not shipped)
│   └── Test*.flix
├── bench/                 # nested microbench vs flix-parsec
├── docs/                  # user and design guides
├── scripts/check-fpkg.sh
├── CHANGELOG.md
├── LICENSE.md             # text packed into the fpkg
└── CONTRIBUTING.md        # this file
```

Published consumers should only rely on `src/MiniParse/**`. Keep demos out of the fpkg (`check-fpkg.sh` enforces this).

## Documentation

- [docs/README.md](docs/README.md) — index of guides
- [docs/design-doc.md](docs/design-doc.md) — architecture and roadmap
- [CHANGELOG.md](CHANGELOG.md) — Keep a Changelog; update `[Unreleased]` with user-facing notes

## Optional: microbench vs flix-parsec

Nested project under `bench/` (not part of the published package). Expects a sibling checkout of [flix-parsec](https://github.com/stephentetley/flix-parsec):

```text
repo/flix/
├── flix-miniparse/
└── flix-parsec/
```

```bash
bash bench/scripts/install-local-deps.sh
cd bench
export JAVA_OPTS="${JAVA_OPTS:-} -Xss8m"
flix run
```

Details: [bench/README.md](bench/README.md).

## Pull requests

1. Prefer small, focused changes (library vs docs vs labs).
2. Run `flix test` (and `check-fpkg.sh` after packaging changes).
3. Note user-visible changes under `CHANGELOG.md` → `[Unreleased]`.
4. Do not treat `Examples.*` as a stable public API in docs aimed at dependents.
