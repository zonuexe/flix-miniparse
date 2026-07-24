///
/// Packrat memoization helpers: typed tables in a `Region`.
///
/// Each nonterminal that should be memoized owns a `Table[a, r]` (result type
/// `a`, keyed by input offset). Build and query tables inside a `region` so
/// mutation does not leak into the public pure API of the rest of the library.
///
/// Full grammar-level memoization (with effectful recursive parsers) is shown
/// in `Examples.Packrat`, which measures exponential vs linear body entries.
///
/// Note: wrapping a pure `Parser[a]` with region-local `MutMap` ops cannot stay
/// inside the pure `Parser` abstraction (`mkParser` expects a pure function).
/// Prefer region-local recursive functions (as in the example) for real memoization.
///
mod MiniParse.Packrat {

    use MiniParse.Core.{ParseError, State}

    /// Memo cell: store the full success `State` so positions stay accurate.
    pub enum Cell[a] {
        case Ok(a, State),
        case Err(ParseError)
    }

    /// Offset → result for one nonterminal of result type `a`.
    /// Region parameter `r` has kind `Eff` (MutMap's third type argument).
    pub type alias Table[a: Type, r: Eff] = MutMap[Int32, Cell[a], r]

    /// Allocate an empty memo table in region `rc`.
    pub def newTable(rc: Region[r]): Table[a, r] \ r =
        MutMap.empty(rc)

}
