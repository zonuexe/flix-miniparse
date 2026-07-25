///
/// Coroutine-style *suspendable* parsers with **deep backtracking**.
///
/// Contrast with `MiniParse.Stream`:
/// - **Stream** restarts a pure `Parser` from the cursor on `Await`.
/// - **Suspend** stores a `Read` continuation (true suspension).
///
/// ## Deep `orElse` / `Choice`
///
/// `orElse(p1, p2)` is reified as `Choice(p1, p2)`. The interpreter runs `p1`
/// against an immutable buffer snapshot. If `p1` fails after consuming input,
/// `p2` is retried on the **original** buffer (deep backtrack / rewind).
///
/// If `p1` suspends mid-way, a `Branch` frame remembers `p2` and every character
/// committed so far; a later failure still rewinds and runs `p2` on
/// `committed ++ remaining`.
///
mod MiniParse.Suspend {

    use MiniParse.Core.{
        ParseError, Position, State, Parser,
        initialPosition, advancePosition, positionOffset,
        initState, stateOffset, statePos, stateInput, mkParser
    }

    ///////////////////////////////////////////////////////////////////////////
    // Free / coroutine parser
    ///////////////////////////////////////////////////////////////////////////

    /// Free program over character reads, with structural choice.
    pub enum CoParser[a] {
        case Pure(a),
        case Fail(String),
        case Read(Option[Char] -> CoParser[a]),
        /// Ordered choice with deep backtrack on failure of the left branch.
        case Choice(CoParser[a], CoParser[a]),
        /// Internal: left branch in progress after a suspension.
        /// `committed` = characters the left branch already consumed since the
        /// choice point (used to rebuild input for the right branch on failure).
        case Branch(CoParser[a], CoParser[a], Position, String),
        // p1cont, p2, snapPos, committed

        /// Look at the next character **without consuming** it (or EOF).
        case Peek(Option[Char] -> CoParser[a])
    }

    pub def pure(x: a): CoParser[a] =
        CoParser.Pure(x)

    pub def fail(expected: String): CoParser[a] =
        CoParser.Fail(expected)

    /// Deep-backtracking choice (Parsec `<|>` with automatic try on the left).
    pub def orElse(p1: CoParser[a], p2: CoParser[a]): CoParser[a] =
        CoParser.Choice(p1, p2)

    /// Multi-way ordered choice.
    pub def choice(ps: List[CoParser[a]]): CoParser[a] = match ps {
        case Nil         => fail("empty choice")
        case p :: Nil    => p
        case p :: q :: r => orElse(p, choice(q :: r))
    }

    pub def map(f: a -> b, p: CoParser[a]): CoParser[b] = match p {
        case CoParser.Pure(x) =>
            CoParser.Pure(f(x))
        case CoParser.Fail(e) =>
            CoParser.Fail(e)
        case CoParser.Read(k) =>
            CoParser.Read(c -> map(f, k(c)))
        case CoParser.Choice(p1, p2) =>
            CoParser.Choice(map(f, p1), map(f, p2))
        case CoParser.Branch(p1, p2, snap, comm) =>
            CoParser.Branch(map(f, p1), map(f, p2), snap, comm)
        case CoParser.Peek(k) =>
            CoParser.Peek(c -> map(f, k(c)))
    }

    pub def flatMap(f: a -> CoParser[b], p: CoParser[a]): CoParser[b] = match p {
        case CoParser.Pure(x) =>
            f(x)
        case CoParser.Fail(e) =>
            CoParser.Fail(e)
        case CoParser.Read(k) =>
            CoParser.Read(c -> flatMap(f, k(c)))
        case CoParser.Choice(p1, p2) =>
            CoParser.Choice(flatMap(f, p1), flatMap(f, p2))
        case CoParser.Branch(p1, p2, snap, comm) =>
            CoParser.Branch(flatMap(f, p1), flatMap(f, p2), snap, comm)
        case CoParser.Peek(k) =>
            CoParser.Peek(c -> flatMap(f, k(c)))
    }

    pub def andThen(p: CoParser[a], q: CoParser[b]): CoParser[b] =
        flatMap(_ -> q, p)

    pub def andThenL(p: CoParser[a], q: CoParser[b]): CoParser[a] =
        flatMap(x -> map(_ -> x, q), p)

    pub def product(p: CoParser[a], q: CoParser[b]): CoParser[(a, b)] =
        flatMap(x -> map(y -> (x, y), q), p)

    pub def replace(x: b, p: CoParser[a]): CoParser[b] =
        map(_ -> x, p)

    pub def void(p: CoParser[a]): CoParser[Unit] =
        map(_ -> (), p)

    /// Defer building a recursive `CoParser` until interpretation.
    ///
    /// Uses `Peek` so the thunk is not forced while the free program is being
    /// *constructed* (important for mutual recursion such as `stmt` / `expr`).
    pub def delay(thunk: Unit -> CoParser[a]): CoParser[a] =
        CoParser.Peek(_ -> thunk())

    /// Left-associative fold: `p (op p)*`.
    pub def chainl1(p: CoParser[a], op: CoParser[(a, a) -> a]): CoParser[a] =
        flatMap(x ->
            map(fs -> List.foldLeft((acc, f) -> f(acc), x, fs),
                many(flatMap(f -> map(y -> (acc -> f(acc, y)), p), op))),
            p
        )

    ///////////////////////////////////////////////////////////////////////////
    // Character combinators
    ///////////////////////////////////////////////////////////////////////////

    pub def satisfy(pred: Char -> Bool, label: String): CoParser[Char] =
        CoParser.Read(mc -> match mc {
            case None =>
                CoParser.Fail(label)
            case Some(c) =>
                if (pred(c)) CoParser.Pure(c) else CoParser.Fail(label)
        })

    pub def anyChar(): CoParser[Char] =
        satisfy(_ -> true, "any character")

    pub def char(expected: Char): CoParser[Char] =
        satisfy(c -> c == expected, Char.toString(expected))

    pub def digit(): CoParser[Char] =
        satisfy(Char.isAsciiDigit, "digit")

    pub def string(lit: String): CoParser[String] = {
        let n = String.length(lit);
        def loop(i: Int32): CoParser[String] =
            if (i >= n)
                pure(lit)
            else
                match String.nth(i, lit) {
                    case None    => fail("string")
                    case Some(c) => andThen(char(c), loop(i + 1))
                };
        if (n == 0) pure("") else loop(0)
    }

    pub def count(n: Int32, p: CoParser[a]): CoParser[List[a]] =
        if (n <= 0)
            pure(Nil)
        else
            flatMap(x -> map(xs -> x :: xs, count(n - 1, p)), p)

    pub def digits(n: Int32): CoParser[String] =
        map(cs -> List.join("", List.map(Char.toString, cs)), count(n, digit()))

    pub def eof(): CoParser[Unit] =
        CoParser.Read(mc -> match mc {
            case None    => CoParser.Pure(())
            case Some(_) => CoParser.Fail("end of input")
        })

    pub def letter(): CoParser[Char] =
        satisfy(c -> Char.isAscii(c) and Char.isLetter(c), "letter")

    pub def alphaNum(): CoParser[Char] =
        satisfy(
            c -> (Char.isAscii(c) and Char.isLetter(c)) or Char.isAsciiDigit(c),
            "alphanumeric"
        )

    /// Zero or more. Relies on deep `orElse`: a failing `p` rewinds so the
    /// alternative `pure(Nil)` can succeed (p must fail on its first mismatch
    /// in a rewind-safe way — our `satisfy` does).
    pub def many(p: CoParser[a]): CoParser[List[a]] =
        orElse(
            flatMap(x -> map(xs -> x :: xs, many(p)), p),
            pure(Nil)
        )

    pub def some(p: CoParser[a]): CoParser[List[a]] =
        flatMap(x -> map(xs -> x :: xs, many(p)), p)

    /// Peek at the next character (or EOF) without consuming.
    pub def peek(): CoParser[Option[Char]] =
        CoParser.Peek(c -> CoParser.Pure(c))

    /// Succeed with `()` iff the next char is **not** accepted by `pred` (or EOF).
    /// Does not consume.
    pub def notFollowedByPred(pred: Char -> Bool, label: String): CoParser[Unit] =
        CoParser.Peek(mc -> match mc {
            case None => CoParser.Pure(())
            case Some(c) =>
                if (pred(c)) CoParser.Fail(label) else CoParser.Pure(())
        })

    /// Keyword `kw` not followed by an identifier character.
    pub def keyword(kw: String): CoParser[String] =
        andThenL(
            string(kw),
            notFollowedByPred(
                c -> (Char.isAscii(c) and Char.isLetter(c)) or Char.isAsciiDigit(c),
                "keyword boundary"
            )
        )

    /// Identifier: letter then alphanumerics (may still match keyword text —
    /// prefer trying `keyword` first in an `orElse`).
    pub def ident(): CoParser[String] =
        flatMap(c0 ->
            map(cs -> Char.toString(c0) + List.join("", List.map(Char.toString, cs)),
                many(alphaNum())),
            letter())

    ///////////////////////////////////////////////////////////////////////////
    // Attempt interpreter (immutable buffer ⇒ free rewind)
    ///////////////////////////////////////////////////////////////////////////

    /// Result of trying a branch without committing to the outer stream.
    enum Attempt[a] {
        case Ok(a, String, Position),
        /// Failed; `rem` is unconsumed input, `took` is what this attempt consumed.
        case Err(ParseError, String, String),
        /// Need more input; `took` is what was consumed since the attempt began.
        case Need(CoParser[a], Position, String)
    }

    def mkErr(pos: Position, exp: String): ParseError =
        ParseError.Error(pos, exp :: Nil)

    def appendChar(s: String, c: Char): String =
        s + Char.toString(c)

    /// Interpret `p` against `buf`. `took` accumulates characters this attempt
    /// has already consumed (for choice rewind).
    def attempt(
        p: CoParser[a],
        buf: String,
        pos: Position,
        eof: Bool,
        took: String
    ): Attempt[a] = match p {
        case CoParser.Pure(x) =>
            Attempt.Ok(x, buf, pos)

        case CoParser.Fail(exp) =>
            Attempt.Err(mkErr(pos, exp), buf, took)

        case CoParser.Read(k) =>
            match String.nth(0, buf) {
                case Some(c) => {
                    let rest = String.dropLeft(1, buf);
                    let pos1 = advancePosition(c, pos);
                    attempt(k(Some(c)), rest, pos1, eof, appendChar(took, c))
                }
                case None =>
                    if (eof)
                        attempt(k(None), "", pos, true, took)
                    else
                        Attempt.Need(p, pos, took)
            }

        case CoParser.Choice(p1, p2) =>
            // Deep backtrack: on failure of p1, retry p2 on the *same* buf/pos.
            match attempt(p1, buf, pos, eof, "") {
                case Attempt.Ok(x, rest, pos1) =>
                    Attempt.Ok(x, rest, pos1)
                case Attempt.Err(_, _, _) =>
                    attempt(p2, buf, pos, eof, "")
                case Attempt.Need(p1c, pos1, t1) =>
                    // Suspend left branch; remember p2 + chars already taken from buf.
                    Attempt.Need(
                        CoParser.Branch(p1c, p2, pos, t1),
                        pos1,
                        t1
                    )
            }

        case CoParser.Branch(p1, p2, snapPos, committed) =>
            // Resume left branch; on failure rebuild full input since choice.
            match attempt(p1, buf, pos, eof, "") {
                case Attempt.Ok(x, rest, pos1) =>
                    Attempt.Ok(x, rest, pos1)
                case Attempt.Err(_, _rem, _t1) =>
                    attempt(p2, committed + buf, snapPos, eof, "")
                case Attempt.Need(p1c, pos1, t1) =>
                    Attempt.Need(
                        CoParser.Branch(p1c, p2, snapPos, committed + t1),
                        pos1,
                        committed + t1
                    )
            }

        case CoParser.Peek(k) =>
            match String.nth(0, buf) {
                case Some(c) =>
                    attempt(k(Some(c)), buf, pos, eof, took)
                case None =>
                    if (eof)
                        attempt(k(None), buf, pos, true, took)
                    else
                        Attempt.Need(p, pos, took)
            }
    }

    ///////////////////////////////////////////////////////////////////////////
    // Public driver
    ///////////////////////////////////////////////////////////////////////////

    /// Suspended machine: remaining program + position.
    /// (`took` is only meaningful inside Branch nodes of the program.)
    pub enum Suspended[a] {
        case Suspended(CoParser[a], Position)
    }

    pub def suspendedPos(s: Suspended[a]): Position = match s {
        case Suspended.Suspended(_p, pos) => pos
    }

    pub enum Outcome[a] {
        case Done(a, String),
        case Fail(ParseError),
        case Await(Suspended[a])
    }

    instance ToString[Outcome[a]] with ToString[a] {
        pub def toString(o: Outcome[a]): String = match o {
            case Outcome.Done(x, rest) => "Done(${x}, \"${rest}\")"
            case Outcome.Fail(e)       => "Fail(${e})"
            case Outcome.Await(s)      =>
                match s {
                    case Suspended.Suspended(_, pos) => "Await(at ${pos})"
                }
        }
    }

    pub def isAwait(o: Outcome[a]): Bool = match o {
        case Outcome.Await(_) => true
        case _                => false
    }

    def outcomeOf(a: Attempt[a]): Outcome[a] = match a {
        case Attempt.Ok(x, rest, _) =>
            Outcome.Done(x, rest)
        case Attempt.Err(e, _, _) =>
            Outcome.Fail(e)
        case Attempt.Need(p, pos, _) =>
            Outcome.Await(Suspended.Suspended(p, pos))
    }

    pub def pump(p: CoParser[a], buf: String, pos: Position, eof: Bool): Outcome[a] =
        outcomeOf(attempt(p, buf, pos, eof, ""))

    ///////////////////////////////////////////////////////////////////////////
    // Bridge hooks: CoParser as a pure Parser (full buffer, eof = true)
    ///////////////////////////////////////////////////////////////////////////

    /// Run `p` on the remainder of `s` with EOF asserted (no `Await`).
    ///
    /// Used by `MiniParse.Bridge.toParser` to embed coroutine parsers in the
    /// pure `Parser` stack (Parsec/PEG combinators, `Core.parse`, etc.).
    pub def runCoPartial(p: CoParser[a], s: State): Result[ParseError, (a, State)] =
        match s {
            case State.State(input, pos) => {
                let buf = String.dropLeft(positionOffset(pos), input);
                match attempt(p, buf, pos, true, "") {
                    case Attempt.Ok(x, _rest, pos1) =>
                        Ok((x, State.State(input, pos1)))
                    case Attempt.Err(e, _, _) =>
                        Err(e)
                    case Attempt.Need(_, pos1, _) =>
                        // Should not occur when eof=true; treat as hard EOF.
                        Err(ParseError.Error(pos1, "end of input" :: Nil))
                }
            }
        }

    /// Full parse of `input` via the pure `Parser` embedding.
    pub def runCo(p: CoParser[a], input: String): Result[ParseError, a] =
        match runCoPartial(p, initState(input)) {
            case Ok((x, s1)) =>
                if (stateOffset(s1) >= String.length(stateInput(s1)))
                    Ok(x)
                else
                    Err(ParseError.Error(statePos(s1), "end of input" :: Nil))
            case Err(e) => Err(e)
        }

    /// Compile a `CoParser` into a pure `Parser` (whole remainder available).
    pub def toParser(p: CoParser[a]): Parser[a] =
        mkParser(s -> runCoPartial(p, s))

    pub def start(p: CoParser[a]): Outcome[a] =
        pump(p, "", initialPosition(), false)

    pub def startWith(p: CoParser[a], buf: String): Outcome[a] =
        pump(p, buf, initialPosition(), false)

    pub def feed(chunk: String, s: Suspended[a]): Outcome[a] = match s {
        case Suspended.Suspended(p, pos) =>
            pump(p, chunk, pos, false)
    }

    pub def close(s: Suspended[a]): Outcome[a] = match s {
        case Suspended.Suspended(p, pos) =>
            pump(p, "", pos, true)
    }

    pub def parseChunks(p: CoParser[a], chunks: List[String]): Result[ParseError, a] = {
        def go(cs: List[String], o: Outcome[a]): Result[ParseError, a] = match o {
            case Outcome.Fail(e) =>
                Err(e)
            case Outcome.Done(x, rest) =>
                if (String.isEmpty(rest) and List.isEmpty(cs))
                    Ok(x)
                else
                    Err(ParseError.Error(initialPosition(), "end of input" :: Nil))
            case Outcome.Await(s) =>
                match cs {
                    case Nil =>
                        match close(s) {
                            case Outcome.Done(x, rest) =>
                                if (String.isEmpty(rest)) Ok(x)
                                else Err(ParseError.Error(suspendedPos(s), "end of input" :: Nil))
                            case Outcome.Fail(e) => Err(e)
                            case Outcome.Await(_) =>
                                Err(ParseError.Error(suspendedPos(s), "end of input" :: Nil))
                        }
                    case c :: rest =>
                        go(rest, feed(c, s))
                }
        };
        match chunks {
            case Nil =>
                go(Nil, start(p))
            case c :: rest =>
                go(rest, startWith(p, c))
        }
    }

    pub enum Event with Eq, ToString {
        case Fed(String),
        case SuspendedAt(Int32),
        case Backtracked,  // left branch failed after consume; right branch tried
        case Completed,
        case Failed
    }

    // Note: Backtracked is reserved for future tracing; drive records suspend/fed.

    pub def drive(
        p: CoParser[a],
        chunks: List[String]
    ): (Result[ParseError, a], List[Event]) = {
        def go(
            cs: List[String],
            o: Outcome[a],
            ev: List[Event]
        ): (Result[ParseError, a], List[Event]) = match o {
            case Outcome.Fail(e) =>
                (Err(e), List.reverse(Event.Failed :: ev))
            case Outcome.Done(x, rest) =>
                if (String.isEmpty(rest) and List.isEmpty(cs))
                    (Ok(x), List.reverse(Event.Completed :: ev))
                else
                    (Err(ParseError.Error(initialPosition(), "end of input" :: Nil)),
                     List.reverse(Event.Failed :: ev))
            case Outcome.Await(s) =>
                match cs {
                    case Nil =>
                        match close(s) {
                            case Outcome.Done(x, rest) =>
                                if (String.isEmpty(rest))
                                    (Ok(x), List.reverse(Event.Completed :: ev))
                                else
                                    (Err(ParseError.Error(suspendedPos(s), "end of input" :: Nil)),
                                     List.reverse(Event.Failed :: ev))
                            case Outcome.Fail(e) =>
                                (Err(e), List.reverse(Event.Failed :: ev))
                            case Outcome.Await(_) =>
                                (Err(ParseError.Error(suspendedPos(s), "end of input" :: Nil)),
                                 List.reverse(Event.Failed :: ev))
                        }
                    case c :: rest => {
                        let off = match suspendedPos(s) {
                            case Position.Position(offset, _, _) => offset
                        };
                        go(rest, feed(c, s),
                            Event.Fed(c) :: Event.SuspendedAt(off) :: ev)
                    }
                }
        };
        match chunks {
            case Nil =>
                go(Nil, start(p), Nil)
            case c :: rest =>
                go(rest, startWith(p, c), Event.Fed(c) :: Nil)
        }
    }

    pub def countSuspends(p: CoParser[a], chunks: List[String]): Int32 = {
        let (_r, ev) = drive(p, chunks);
        List.length(List.filter(e -> match e {
            case Event.SuspendedAt(_) => true
            case _                    => false
        }, ev))
    }

}
