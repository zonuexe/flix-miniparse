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
/// | `MiniParse.ErrorFormat` | Caret-style error messages |
/// | `MiniParse.Stream` | Chunked input, restart-style `Await` |
/// | `MiniParse.Suspend` | Coroutine `CoParser` + deep-backtracking `orElse` |
///
/// Demo grammars and labs live under `Examples.*` (not part of the public
/// library contract). See `README.md` and `docs/`.
///
mod MiniParse {
}
