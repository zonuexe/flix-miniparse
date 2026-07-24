///
/// Left-recursive packrat (Warth-style *growing*).
///
/// Naive left recursion:
///
/// ```text
/// E <- E "+" n  /  n
/// ```
///
/// loops forever: `E` at offset `p` calls `E` at the same offset before making
/// progress. Plain packrat memoization alone is not enough — the first call
/// would block on its own incomplete memo entry.
///
/// **Growing seed algorithm** (Warth et al.):
/// 1. Seed `memo[p] = failure`.
/// 2. Evaluate the rule body (recursive uses of `E` at `p` read the seed).
/// 3. If the result reaches *farther* than the previous best, store it and goto 2.
/// 4. Otherwise return the best result.
///
/// This yields classical left-associative structure for `1+2+3`:
/// `Add(Add(Lit(1), Lit(2)), Lit(3))`.
///
/// For comparison, `parseRight` uses the right-recursive grammar
/// `E <- n "+" E / n` (no growth needed) → `Add(Lit(1), Add(Lit(2), Lit(3)))`.
///
mod Examples.LeftRec {

    use MiniParse.Core.{ParseError, Position}

    pub enum Expr with Eq, ToString {
        case Lit(Int32),
        case Add(Expr, Expr)
    }

    enum Cell {
        case Ok(Expr, Int32), // value, end offset
        case Err
    }

    ///////////////////////////////////////////////////////////////////////////
    // Left-recursive packrat with growth
    ///////////////////////////////////////////////////////////////////////////

    pub def parseLeft(input: String): Result[ParseError, Expr] =
        region rc {
            let table: MutMap[Int32, Cell, rc] = MutMap.empty(rc);

            /// Apply rule `E` at `off` (starts growth when unseen).
            /// Nested locals cannot mutually recurse as siblings, so growth and
            /// the rule body are inlined under a single recursive `e`.
            def e(off: Int32): Result[ParseError, (Expr, Int32)] \ rc =
                match MutMap.get(off, table) {
                    case Some(Cell.Ok(v, end)) => Ok((v, end))
                    case Some(Cell.Err) =>
                        Err(ParseError.Error(posAt(input, off), "expression" :: Nil))
                    case None => {
                        // Seed failure so recursive left calls terminate.
                        MutMap.put(off, Cell.Err, table);

                        /// Body: `E "+" n  /  n`
                        def body(): Result[ParseError, (Expr, Int32)] \ rc = {
                            // left-recursive alternative: `E "+" n`
                            let leftPlus = match e(off) {
                                case Err(er) => Err(er)
                                case Ok((left, off1)) =>
                                    match eatPlus(input, off1) {
                                        case Err(er) => Err(er)
                                        case Ok(off2) =>
                                            match number(input, off2) {
                                                case Err(er) => Err(er)
                                                case Ok((n, off3)) =>
                                                    Ok((Expr.Add(left, Expr.Lit(n)), off3))
                                            }
                                    }
                            };
                            match leftPlus {
                                case Ok(v)  => Ok(v)
                                case Err(_) =>
                                    match number(input, off) {
                                        case Ok((n, end)) => Ok((Expr.Lit(n), end))
                                        case Err(er)      => Err(er)
                                    }
                            }
                        };

                        /// Warth-style growth loop at this offset.
                        def loop(best: Option[(Expr, Int32)]): Result[ParseError, (Expr, Int32)] \ rc = {
                            let ans = body();
                            match (ans, best) {
                                case (Ok((v, end)), None) => {
                                    MutMap.put(off, Cell.Ok(v, end), table);
                                    loop(Some((v, end)))
                                }
                                case (Ok((v, end)), Some((_, bestEnd))) =>
                                    if (end > bestEnd) {
                                        MutMap.put(off, Cell.Ok(v, end), table);
                                        loop(Some((v, end)))
                                    } else
                                        // No further growth — keep previous best in table.
                                        match best {
                                            case Some(b) => Ok(b)
                                            case None    =>
                                                Err(ParseError.Error(posAt(input, off), "expression" :: Nil))
                                        }
                                case (Err(_), Some(b)) =>
                                    Ok(b)
                                case (Err(er), None) => {
                                    MutMap.put(off, Cell.Err, table);
                                    Err(er)
                                }
                            }
                        };
                        loop(None)
                    }
                };

            finish(input, e(0))
        }

    ///////////////////////////////////////////////////////////////////////////
    // Right-recursive control (no growth)
    ///////////////////////////////////////////////////////////////////////////

    /// `E <- n "+" E / n` — naturally right-associative.
    pub def parseRight(input: String): Result[ParseError, Expr] = {
        def e(off: Int32): Result[ParseError, (Expr, Int32)] =
            match number(input, off) {
                case Err(er) => Err(er)
                case Ok((n, off1)) =>
                    match eatPlus(input, off1) {
                        case Err(_) =>
                            Ok((Expr.Lit(n), off1))
                        case Ok(off2) =>
                            match e(off2) {
                                case Err(er) => Err(er)
                                case Ok((right, off3)) =>
                                    Ok((Expr.Add(Expr.Lit(n), right), off3))
                            }
                    }
            };
        finish(input, e(0))
    }

    ///////////////////////////////////////////////////////////////////////////
    // Shared lexical helpers
    ///////////////////////////////////////////////////////////////////////////

    def number(input: String, off: Int32): Result[ParseError, (Int32, Int32)] = {
        def digits(i: Int32, acc: Int32, any: Bool): Result[ParseError, (Int32, Int32)] =
            match String.nth(i, input) {
                case Some(c) if Char.isAsciiDigit(c) =>
                    match Char.digit(radix = 10, c) {
                        case Some(d) => digits(i + 1, acc * 10 + d, true)
                        case None    => digits(i + 1, acc, any)
                    }
                case _ =>
                    if (any)
                        Ok((acc, i))
                    else
                        Err(ParseError.Error(posAt(input, off), "number" :: Nil))
            };
        digits(off, 0, false)
    }

    def eatPlus(input: String, off: Int32): Result[ParseError, Int32] =
        match String.nth(off, input) {
            case Some('+') => Ok(off + 1)
            case _ =>
                Err(ParseError.Error(posAt(input, off), "+" :: Nil))
        }

    def finish(
        input: String,
        res: Result[ParseError, (Expr, Int32)]
    ): Result[ParseError, Expr] = match res {
        case Ok((e, end)) =>
            if (end >= String.length(input))
                Ok(e)
            else
                Err(ParseError.Error(posAt(input, end), "end of input" :: Nil))
        case Err(er) => Err(er)
    }

    def posAt(input: String, off: Int32): Position = {
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

    /// Pretty depth-1 check helpers for tests / demos.
    pub def isLeftAssoc123(e: Expr): Bool = match e {
        case Expr.Add(Expr.Add(Expr.Lit(1), Expr.Lit(2)), Expr.Lit(3)) => true
        case _ => false
    }

    pub def isRightAssoc123(e: Expr): Bool = match e {
        case Expr.Add(Expr.Lit(1), Expr.Add(Expr.Lit(2), Expr.Lit(3))) => true
        case _ => false
    }

}
