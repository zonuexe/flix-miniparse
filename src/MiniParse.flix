///
/// **miniparse** — educational parser-combinator library for Flix.
///
/// ## Library modules
///
/// | Module | Role |
/// | --- | --- |
/// | `MiniParse.Core` | `Parser`, `State`, `Position`, `ParseError`, `parse` / `runParser` |
/// | `MiniParse.Combinator` | Shared combinators (`map`, `satisfy`, `sepBy`, `chainl1`, …) |
/// | `MiniParse.Parsec` | Explicit backtracking (`orElse`, `attempt`) |
/// | `MiniParse.PEG` | Automatic backtrack (`choice`, `&` / `!` predicates) |
/// | `MiniParse.Packrat` | Packrat table helpers (`Region` + `MutMap`) |
/// | `MiniParse.ErrorFormat` | Caret-style error messages (incl. multi-error) |
/// | `MiniParse.Debug` | `label` / `inContext`; traced `TParser` + `span` |
/// | `MiniParse.Recover` | Panic-mode recovery for pure `Parser` |
/// | `MiniParse.RecoverCo` | Same policy for `CoParser` (`runProgramSkipping`) |
/// | `MiniParse.Stream` | Chunked input, restart-style `Await` |
/// | `MiniParse.Suspend` | Coroutine `CoParser`, deep `orElse`, shared combinators |
/// | `MiniParse.Bridge` | Embed `CoParser` as pure `Parser` and vice versa |
///
/// Demo grammars and labs live under `Examples.*` in the repository
/// (`test/Examples/`), not part of the published library package.
/// See `README.md` and `docs/`.
///
mod MiniParse {
}
