///
/// Step 3: packrat memoization demo.
///
/// Grammar (ordered choice, not left-recursive) — the classic highly-ambiguous
/// example (Ford / Wikipedia “Packrat parsing”):
///
/// ```text
/// S <- "a" S S  /  "a" S  /  "a"
/// ```
///
/// Full parses of `aⁿ` (n ≥ 1) explore many overlapping subproblems. Without
/// memoization the body of `S` runs exponentially often; with a packrat table
/// keyed by offset, each offset is solved once (linear in `n` body entries).
///
/// Implemented as a region-local recursive function (MutMap + Ref counters) so the
/// educational demo stays pure at the public API while using internal mutability.
///
mod Examples.Packrat {

    use MiniParse.Core.{ParseError, Position}

    /// value = number of `'a'` matched; bodyEntries = how often `S` was computed.
    pub enum Stats with Eq, ToString {
        case Stats(Int32, Int32)
    }

    enum Cell {
        case Ok(Int32, Int32), // value, endOffset
        case Err
    }

    ///////////////////////////////////////////////////////////////////////////
    // Naive (no memo)
    ///////////////////////////////////////////////////////////////////////////

    pub def parseNaive(input: String): Result[ParseError, Stats] =
        region rc {
            let counter = Ref.fresh(rc, 0);
            def s(off: Int32): Result[ParseError, (Int32, Int32)] \ rc = {
                Ref.put(Ref.get(counter) + 1, counter);
                // S <- "a" S S  /  "a" S  /  "a"
                match nest2(input, off, s) {
                    case Ok(v)  => Ok(v)
                    case Err(_) =>
                        match nest1(input, off, s) {
                            case Ok(v)  => Ok(v)
                            case Err(_) => leaf(input, off)
                        }
                }
            };
            finish(input, s(0), counter)
        }

    ///////////////////////////////////////////////////////////////////////////
    // Packrat (memo table)
    ///////////////////////////////////////////////////////////////////////////

    pub def parseMemo(input: String): Result[ParseError, Stats] =
        region rc {
            let counter = Ref.fresh(rc, 0);
            let table: MutMap[Int32, Cell, rc] = MutMap.empty(rc);
            def s(off: Int32): Result[ParseError, (Int32, Int32)] \ rc =
                match MutMap.get(off, table) {
                    case Some(Cell.Ok(v, end)) => Ok((v, end))
                    case Some(Cell.Err) =>
                        Err(ParseError.Error(posAt(input, off), "a" :: Nil))
                    case None => {
                        Ref.put(Ref.get(counter) + 1, counter);
                        let result =
                            match nest2(input, off, s) {
                                case Ok(v)  => Ok(v)
                                case Err(_) =>
                                    match nest1(input, off, s) {
                                        case Ok(v)  => Ok(v)
                                        case Err(_) => leaf(input, off)
                                    }
                            };
                        match result {
                            case Ok((v, end)) => {
                                MutMap.put(off, Cell.Ok(v, end), table);
                                Ok((v, end))
                            }
                            case Err(e) => {
                                MutMap.put(off, Cell.Err, table);
                                Err(e)
                            }
                        }
                    }
                };
            finish(input, s(0), counter)
        }

    /// `S <- "a" S S`
    def nest2(
        input: String,
        off: Int32,
        s: Int32 -> Result[ParseError, (Int32, Int32)] \ ef
    ): Result[ParseError, (Int32, Int32)] \ ef =
        match String.nth(off, input) {
            case Some('a') =>
                match s(off + 1) {
                    case Ok((v1, off1)) =>
                        match s(off1) {
                            case Ok((v2, off2)) => Ok((1 + v1 + v2, off2))
                            case Err(e)        => Err(e)
                        }
                    case Err(e) => Err(e)
                }
            case _ =>
                Err(ParseError.Error(posAt(input, off), "a" :: Nil))
        }

    /// `S <- "a" S`
    def nest1(
        input: String,
        off: Int32,
        s: Int32 -> Result[ParseError, (Int32, Int32)] \ ef
    ): Result[ParseError, (Int32, Int32)] \ ef =
        match String.nth(off, input) {
            case Some('a') =>
                match s(off + 1) {
                    case Ok((v1, off1)) => Ok((1 + v1, off1))
                    case Err(e)        => Err(e)
                }
            case _ =>
                Err(ParseError.Error(posAt(input, off), "a" :: Nil))
        }

    /// `S <- "a"`
    def leaf(input: String, off: Int32): Result[ParseError, (Int32, Int32)] =
        match String.nth(off, input) {
            case Some('a') => Ok((1, off + 1))
            case _ =>
                Err(ParseError.Error(posAt(input, off), "a" :: Nil))
        }

    def finish(
        input: String,
        res: Result[ParseError, (Int32, Int32)],
        counter: Ref[Int32, r]
    ): Result[ParseError, Stats] \ r =
        match res {
            case Ok((n, end)) =>
                if (end >= String.length(input))
                    Ok(Stats.Stats(n, Ref.get(counter)))
                else
                    Err(ParseError.Error(posAt(input, end), "end of input" :: Nil))
            case Err(e) => Err(e)
        }

    def posAt(input: String, off: Int32): Position = {
        // Approximate: scan for line/column (same rules as Core.advancePosition).
        def loop(i: Int32, line: Int32, col: Int32): Position =
            if (i >= off or i >= String.length(input))
                Position.Position(off, line, col)
            else
                match String.nth(i, input) {
                    case Some('\n') => loop(i + 1, line + 1, 1)
                    case _          => loop(i + 1, line, col + 1)
                };
        loop(0, 1, 1)
    }

    pub def memoIsFaster(input: String): Bool =
        match (parseNaive(input), parseMemo(input)) {
            case (Ok(Stats.Stats(_, c1)), Ok(Stats.Stats(_, c2))) => c2 < c1
            case _ => false
        }

}
