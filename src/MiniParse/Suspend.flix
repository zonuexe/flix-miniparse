///
/// Coroutine-style *suspendable* parsers.
///
/// Contrast with `MiniParse.Stream`:
/// - **Stream** wraps a pure `Parser` and, on `Await`, **restarts** it from the
///   saved cursor over the whole buffer (no call-stack capture).
/// - **Suspend** reifies the parser as a free/coroutine program (`CoParser`)
///   that **requests one character at a time**. When input runs out mid-parse,
///   the remaining `Read` continuation is stored and resumed on the next chunk
///   — true suspension of the parse "stack" (as a data structure).
///
/// ```text
///   CoParser  --pump-->  Done | Fail | Await(Suspended)
///   Suspended --feed-->  pump again from the same Read
/// ```
///
mod MiniParse.Suspend {

    use MiniParse.Core.{ParseError, Position, initialPosition, advancePosition}

    ///////////////////////////////////////////////////////////////////////////
    // Free / coroutine parser
    ///////////////////////////////////////////////////////////////////////////

    /// A parser as a small free monad over character reads.
    ///
    /// - `Pure` / `Fail` — finished
    /// - `Read(k)` — need the next character (`Some`) or EOF (`None`)
    pub enum CoParser[a] {
        case Pure(a),
        case Fail(String),
        case Read(Option[Char] -> CoParser[a])
    }

    pub def pure(x: a): CoParser[a] =
        CoParser.Pure(x)

    pub def fail(expected: String): CoParser[a] =
        CoParser.Fail(expected)

    pub def map(f: a -> b, p: CoParser[a]): CoParser[b] = match p {
        case CoParser.Pure(x) => CoParser.Pure(f(x))
        case CoParser.Fail(e) => CoParser.Fail(e)
        case CoParser.Read(k) => CoParser.Read(c -> map(f, k(c)))
    }

    pub def flatMap(f: a -> CoParser[b], p: CoParser[a]): CoParser[b] = match p {
        case CoParser.Pure(x) => f(x)
        case CoParser.Fail(e) => CoParser.Fail(e)
        case CoParser.Read(k) => CoParser.Read(c -> flatMap(f, k(c)))
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

    /// End of input: next read must be EOF.
    pub def eof(): CoParser[Unit] =
        CoParser.Read(mc -> match mc {
            case None    => CoParser.Pure(())
            case Some(_) => CoParser.Fail("end of input")
        })

    ///////////////////////////////////////////////////////////////////////////
    // Driver: pump / feed / close
    ///////////////////////////////////////////////////////////////////////////

    /// Suspended continuation waiting for the next character (or EOF).
    pub enum Suspended[a] {
        case Suspended(Option[Char] -> CoParser[a], Position)
    }

    pub def suspendedPos(s: Suspended[a]): Position = match s {
        case Suspended.Suspended(_k, pos) => pos
    }

    /// Outcome of driving a `CoParser` against a buffer.
    ///
    /// Manual `ToString` (not derived): `Suspended` holds a continuation function,
    /// which cannot participate in derived `ToString`.
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

    /// Interpret `p` against `buf`. Empty buffer + `eof` delivers `None` to `Read`.
    pub def pump(p: CoParser[a], buf: String, pos: Position, eof: Bool): Outcome[a] =
        match p {
            case CoParser.Pure(x) =>
                Outcome.Done(x, buf)
            case CoParser.Fail(exp) =>
                Outcome.Fail(ParseError.Error(pos, exp :: Nil))
            case CoParser.Read(k) =>
                match String.nth(0, buf) {
                    case Some(c) => {
                        let rest = String.dropLeft(1, buf);
                        let pos1 = advancePosition(c, pos);
                        pump(k(Some(c)), rest, pos1, eof)
                    }
                    case None =>
                        if (eof)
                            pump(k(None), "", pos, true)
                        else
                            Outcome.Await(Suspended.Suspended(k, pos))
                }
        }

    pub def start(p: CoParser[a]): Outcome[a] =
        pump(p, "", initialPosition(), false)

    pub def startWith(p: CoParser[a], buf: String): Outcome[a] =
        pump(p, buf, initialPosition(), false)

    pub def feed(chunk: String, s: Suspended[a]): Outcome[a] = match s {
        case Suspended.Suspended(k, pos) =>
            pump(CoParser.Read(k), chunk, pos, false)
    }

    pub def close(s: Suspended[a]): Outcome[a] = match s {
        case Suspended.Suspended(k, pos) =>
            pump(CoParser.Read(k), "", pos, true)
    }

    /// Feed all chunks (suspending as needed), then close, require empty remainder.
    pub def parseChunks(p: CoParser[a], chunks: List[String]): Result[ParseError, a] = {
        def go(cs: List[String], o: Outcome[a]): Result[ParseError, a] = match o {
            case Outcome.Fail(e) =>
                Err(e)
            case Outcome.Done(x, rest) =>
                if (String.isEmpty(rest) and List.isEmpty(cs))
                    Ok(x)
                else if (not List.isEmpty(cs))
                    // Parser finished before all chunks were consumed.
                    Err(ParseError.Error(initialPosition(), "end of input" :: Nil))
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
        case Completed,
        case Failed
    }

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
