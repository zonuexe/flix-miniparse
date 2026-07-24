# Changelog

All notable changes to **miniparse** (`flix-miniparse`) are documented here.

Format inspired by [Keep a Changelog](https://keepachangelog.com/). Versioning follows SemVer for the package name `miniparse`.

## [0.1.0] — 2026-07-25

Initial public-shaped release of the educational lab.

### Library (`MiniParse.*`)

- **Core** — pure `Parser`, positions, furthest-style `ParseError`, `parse` / `parsePartial`
- **Combinator** — standard combinators including `sepBy`, `chainl1`/`chainr1`, `manyTill`, `oneOf`, …
- **Parsec** — `orElse`, `attempt` (explicit try)
- **PEG** — `choice`, `andPredicate`, `notPredicate`
- **Packrat** — `Region` + `MutMap` table helpers
- **ErrorFormat** — caret diagnostics
- **Stream** — chunked feed, restart-style `Await`
- **Suspend** — `CoParser` free monad, deep-backtracking `orElse`, `Peek` / `keyword`

### Labs (`Examples.*`)

Postal codes, JSON, arithmetic, keyword boundaries, packrat / left-recursion, MiniLang, streaming demos, CoLang, Stream vs Suspend cost comparison.

### Tooling

- Nix flake dev shell (Flix 0.75.1 + JDK 21)
- GitHub Actions build/test workflow
- EditorConfig for Flix sources
