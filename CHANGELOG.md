# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/zonuexe/flix-miniparse/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/zonuexe/flix-miniparse/releases/tag/v0.1.0
