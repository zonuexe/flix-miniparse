# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `MiniParse.Debug`: everyday `label` / `inContext` / `getPos` on pure `Parser`, plus traced `TParser` with `span` / `parseTraced` (Writer-like logs without monad transformers); `Examples.DebugLab` and `docs/debug.md` (+ `docs/ja/debug.md`).
- `MiniParse.RecoverCo`: panic-mode recovery for `CoParser` (`runProgramSkipping`, Co `resync`); `Examples.CoRecoverLab` compares pure Recover vs Co on the same MiniLang-shaped sample (chunks joined before recover).
- `CONTRIBUTING.md` for repository development (Nix shell, test/package commands); root `README` focused on library consumers.

### Changed

- Root `README.md`: development/Nix details moved to `CONTRIBUTING.md`.
- Root `README.md`: short beginner intro to Parsec- and PEG-style fronts (Wikipedia links) before the dependency section.

### Added

- `docs/tutorial.md`: walkthrough from combinators to Parsec vs PEG and where the labs fit.
- Japanese docs under `docs/ja/` (`tutorial`, `overview`, `recovery`, `suspend`, `design-doc`; Wikipedia ja links; no hard wrap; no CJK–Latin spacing).

## [0.3.0] - 2026-07-25

Educational release focused on **panic-mode recovery**, fuller **CoParser** combinators, learner docs, and an optional **bench** against flix-parsec.

### Added

- In-repo `bench/` nested project: wall-clock microbenchmarks vs sibling flix-parsec (`digits`, `many-a`, `skip-till`, `lines`, `csv-ones`).
- `MiniParse.Suspend` combinator expansion toward pure `Combinator` parity: `oneOf` / `noneOf`, `manyTill`, `sepBy` / `sepEndBy` / `endBy`, `chainr1`, `ws` / `lexeme` / `symbol` / `between`, `takeWhile` / `hexDigit` / `endOfLine`, and related helpers.
- `MiniParse.Recover`: panic-mode resync (`skipPastOneOf`, `resync`), `recover` / `manySkipping`, `WithErrors` results; `ErrorFormat.formatErrors` / `formatWithErrors`; `Examples.RecoverLab` (strict vs resilient MiniLang).
- Docs: `docs/recovery.md` (panic-mode recovery), `docs/suspend.md` (CoParser vs Stream / free monad), `docs/README.md` (index).

## [0.2.0] - 2026-07-25

Educational release focused on **Bridge**, full **CoLang** on the suspendable stack, and packing only library sources for dependents.

### Added

- CI and `scripts/check-fpkg.sh` guard that the published fpkg contains only `MiniParse.*` library sources.
- Shared diagnostics helpers for incomplete input versus hard parse errors across pure parse, Stream, and Suspend.
- MiniLang comparison operators (`==`, `!=`, `<`, `<=`, `>`, `>=`) and `while` / `do` loops (with an iteration safety cap).
- `MiniParse.Bridge` embeddings: `toParser` / `parseCo` (CoParser as pure `Parser`) and `fromParser` / `pureViaCo` (pure parser after buffering to EOF).
- `MiniParse.Suspend.delay` and `chainl1` for recursive / left-associative `CoParser` grammars.
- CoLang expanded to the full MiniLang surface (arithmetic, comparisons, `while`, blocks); shared MiniLang AST and interpreter; chunked `runSourceChunks` and Bridge interop demos.
- `Examples.LangCompare` lab: table comparing MiniLang (pure) vs CoLang (`CoParser`) parse AST and run results on a shared sample suite.

### Changed

- Moved demo modules out of the published package so consumers no longer pull `Main` or `Examples` from the fpkg.

## [0.1.0] - 2026-07-25

First educational release of **miniparse** (`flix-miniparse`): a Flix lab for learning parser combinators, Parsec- versus PEG-style backtracking, packrat memoization, streaming, and suspendable parsers.

### Added

- Pure `MiniParse.Core` engine with `Parser`, positions, parse errors, and full or partial `parse` entry points.
- Shared combinator suite (`map`, `flatMap`, `satisfy`, `many`, `sepBy`, `chainl1` / `chainr1`, `manyTill`, `oneOf`, and related helpers).
- Parsec-style front-end with commit-on-consume `orElse` and explicit `attempt` (try).
- PEG-style front-end with automatic ordered choice and `&` / `!` predicates.
- Packrat table helpers using Flix `Region` and `MutMap`, plus a demo of exponential versus memoized body counts.
- Left-recursive packrat growth (Warth-style) so additive expressions associate left, with a right-recursive control grammar for contrast.
- Caret-style error formatting with line and column context.
- Chunked streaming adapter that reports `Await` / `Done` / `Fail` by restarting a pure parser from the cursor.
- Suspendable `CoParser` free monad that resumes a stored continuation instead of restarting the whole parse.
- Deep-backtracking `orElse` on `CoParser` that rewinds consumed input (including across chunk boundaries) before trying the next alternative.
- Keyword and identifier helpers on `CoParser` (`Peek`, `keyword`, `ident`) so `if` and `ifa` are distinguished correctly.
- Educational example grammars: postal codes, JSON, arithmetic, keyword boundary, MiniLang, CoLang, streaming demos, and Stream versus Suspend scan-cost comparison.
- Nix flake development shell (Flix 0.75.1 and JDK 21), GitHub Actions CI, EditorConfig, package docs (`README`, `docs/overview.md`, `docs/design-doc.md`).

[Unreleased]: https://github.com/zonuexe/flix-miniparse/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/zonuexe/flix-miniparse/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/zonuexe/flix-miniparse/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/zonuexe/flix-miniparse/releases/tag/v0.1.0
