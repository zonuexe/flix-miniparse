///
/// Streaming / chunked input on top of pure `Parser`s.
///
/// Model:
/// - `StreamState` holds a growable buffer, a cursor, and whether the producer
///   has closed the stream (`eof`).
/// - `step(p, s)` runs pure parser `p` on the current buffer.
/// - If `p` fails **at the end of the buffer** and the stream is **not** closed,
///   the result is `Await` (need more bytes) instead of a hard error.
/// - After `close`, end-of-buffer failures become real `Fail`s.
///
/// This is an educational incremental interface: each `step` restarts `p` from
/// the saved cursor (no suspension of the parser's internal call stack). That
/// is enough to feed tokens in chunks and is easy to reason about.
///
/// ```text
///   open → feed → step ⇄ Await
///                ↘ Done / Fail
///           close → step → Done / Fail
/// ```
///
mod MiniParse.Stream {

    use MiniParse.Core.{
        Parser, ParseError, State, Position,
        runParser, stateOffset, statePos, stateInput,
        positionOffset, initialPosition, parseErrorPos
    }

    ///////////////////////////////////////////////////////////////////////////
    // State
    ///////////////////////////////////////////////////////////////////////////

    /// Buffered input with an explicit end-of-stream flag.
    pub enum StreamState with Eq, ToString {
        case StreamState(String, Position, Bool) // buffer, pos, closed
    }

    pub def buffer(s: StreamState): String = match s {
        case StreamState.StreamState(buf, _pos, _c) => buf
    }

    pub def cursor(s: StreamState): Position = match s {
        case StreamState.StreamState(_buf, pos, _c) => pos
    }

    pub def isClosed(s: StreamState): Bool = match s {
        case StreamState.StreamState(_buf, _pos, c) => c
    }

    pub def offset(s: StreamState): Int32 =
        positionOffset(cursor(s))

    /// Empty open stream.
    pub def open(): StreamState =
        StreamState.StreamState("", initialPosition(), false)

    /// Open stream preloaded with `input` (still open — call `close` when done).
    pub def fromString(input: String): StreamState =
        StreamState.StreamState(input, initialPosition(), false)

    /// Append a chunk to the buffer (no-op content if empty). Position is kept.
    pub def feed(chunk: String, s: StreamState): StreamState = match s {
        case StreamState.StreamState(buf, pos, closed) =>
            if (closed)
                s // ignore writes after close (educational simplicity)
            else if (String.isEmpty(chunk))
                s
            else
                StreamState.StreamState(buf + chunk, pos, false)
    }

    /// Mark the stream finished: further end-of-buffer is a hard EOF error.
    pub def close(s: StreamState): StreamState = match s {
        case StreamState.StreamState(buf, pos, _) =>
            StreamState.StreamState(buf, pos, true)
    }

    /// Drop consumed prefix from the buffer and rebase the cursor to 0.
    ///
    /// Useful after `Done` when the remainder should become the new buffer
    /// without retaining forever-growing history.
    pub def compact(s: StreamState): StreamState = match s {
        case StreamState.StreamState(buf, pos, closed) =>
            let off = positionOffset(pos);
            let rest = String.dropLeft(off, buf);
            StreamState.StreamState(rest, initialPosition(), closed)
    }

    def toCore(s: StreamState): State = match s {
        case StreamState.StreamState(buf, pos, _) => State.State(buf, pos)
    }

    def withCore(s: StreamState, cs: State): StreamState = match s {
        case StreamState.StreamState(_buf, _pos, closed) =>
            StreamState.StreamState(stateInput(cs), statePos(cs), closed)
    }

    ///////////////////////////////////////////////////////////////////////////
    // Step results
    ///////////////////////////////////////////////////////////////////////////

    pub enum Step[a] with ToString {
        /// Parser produced a value; state cursor advanced (leftover may remain).
        case Done(a, StreamState),
        /// Hard failure (invalid input, or EOF after `close`).
        case Fail(ParseError),
        /// Not enough input yet — feed more chunks (or `close`) and `step` again.
        case Await(StreamState)
    }

    pub def isAwait(st: Step[a]): Bool = match st {
        case Step.Await(_) => true
        case _             => false
    }

    pub def isDone(st: Step[a]): Bool = match st {
        case Step.Done(_, _) => true
        case _               => false
    }

    ///////////////////////////////////////////////////////////////////////////
    // Running parsers
    ///////////////////////////////////////////////////////////////////////////

    /// True when a failure looks like "ran out of buffer" rather than a mismatch.
    pub def looksLikeNeedInput(err: ParseError, s: StreamState): Bool = {
        let off = positionOffset(parseErrorPos(err));
        let len = String.length(buffer(s));
        (not isClosed(s)) and (off >= len)
    }

    /// Run `p` once on the current buffer (partial: leftover is OK).
    pub def step(p: Parser[a], s: StreamState): Step[a] =
        match runParser(p, toCore(s)) {
            case Ok((x, cs)) =>
                Step.Done(x, withCore(s, cs))
            case Err(e) =>
                if (looksLikeNeedInput(e, s))
                    Step.Await(s)
                else
                    Step.Fail(e)
        }

    /// Like `step`, but after success require that the cursor is at end **only if
    /// the stream is closed**. If open and leftover is empty, still `Done`.
    /// If closed and leftover remains, `Fail` with "end of input".
    pub def stepExhaust(p: Parser[a], s: StreamState): Step[a] =
        match step(p, s) {
            case Step.Done(x, s1) =>
                let off = offset(s1);
                let len = String.length(buffer(s1));
                if (off >= len)
                    Step.Done(x, s1)
                else if (isClosed(s1))
                    Step.Fail(ParseError.Error(cursor(s1), "end of input" :: Nil))
                else
                    // Successful parse with trailing buffered data still Done
                    // (caller may parse next message). For "whole message" use
                    // `drive` which closes before the final step.
                    Step.Done(x, s1)
            case other => other
        }

    /// Feed `chunk`, then `step`.
    pub def push(p: Parser[a], chunk: String, s: StreamState): Step[a] =
        step(p, feed(chunk, s))

    ///////////////////////////////////////////////////////////////////////////
    // Drivers
    ///////////////////////////////////////////////////////////////////////////

    /// Feed all `chunks` in order, then `close`, then parse to completion.
    ///
    /// Returns `Err` if the parser still awaits after close, or hard-fails.
    pub def parseChunks(p: Parser[a], chunks: List[String]): Result[ParseError, a] = {
        def feedAll(cs: List[String], s: StreamState): StreamState = match cs {
            case Nil => s
            case c :: rest => feedAll(rest, feed(c, s))
        };
        let s0 = feedAll(chunks, open());
        let s1 = close(s0);
        match step(p, s1) {
            case Step.Done(x, s2) =>
                if (offset(s2) >= String.length(buffer(s2)))
                    Ok(x)
                else
                    Err(ParseError.Error(cursor(s2), "end of input" :: Nil))
            case Step.Fail(e) => Err(e)
            case Step.Await(_) =>
                // Closed but still need input → treat as EOF error.
                Err(ParseError.Error(cursor(s1), "end of input" :: Nil))
        }
    }

    /// Interactive-style drive: for each chunk, feed and try `step` until `Done`
    /// or `Fail`. After the last chunk the stream is closed automatically.
    ///
    /// Collects a trace of whether each intermediate attempt was `Await` (for demos).
    pub enum DriveEvent with Eq, ToString {
        case Fed(String),
        case GotAwait,
        case GotDone,
        case GotFail
    }

    pub def drive(
        p: Parser[a],
        chunks: List[String]
    ): (Result[ParseError, a], List[DriveEvent]) = {
        def loop(
            cs: List[String],
            s: StreamState,
            ev: List[DriveEvent],
            last: Bool
        ): (Result[ParseError, a], List[DriveEvent]) = match cs {
            case Nil =>
                if (last) {
                    // already closed path
                    match step(p, s) {
                        case Step.Done(x, s2) =>
                            if (offset(s2) >= String.length(buffer(s2)))
                                (Ok(x), List.reverse(DriveEvent.GotDone :: ev))
                            else
                                (Err(ParseError.Error(cursor(s2), "end of input" :: Nil)),
                                 List.reverse(DriveEvent.GotFail :: ev))
                        case Step.Fail(e) =>
                            (Err(e), List.reverse(DriveEvent.GotFail :: ev))
                        case Step.Await(_) =>
                            (Err(ParseError.Error(cursor(s), "end of input" :: Nil)),
                             List.reverse(DriveEvent.GotFail :: ev))
                    }
                } else
                    loop(Nil, close(s), ev, true)
            case c :: rest =>
                let s1 = feed(c, s);
                let ev1 = DriveEvent.Fed(c) :: ev;
                match step(p, s1) {
                    case Step.Await(s2) =>
                        loop(rest, s2, DriveEvent.GotAwait :: ev1, false)
                    case Step.Done(x, s2) =>
                        // If more chunks remain, this early Done may be incomplete
                        // for whole-input parsers — still report Done on first success.
                        // For streaming demos that need all chunks, prefer `parseChunks`.
                        if (List.isEmpty(rest) and offset(s2) >= String.length(buffer(s2)))
                            (Ok(x), List.reverse(DriveEvent.GotDone :: ev1))
                        else if (List.isEmpty(rest)) {
                            // close and re-check exhaustiveness
                            match step(p, close(compact(s2))) {
                                case Step.Done(x2, s3) =>
                                    if (offset(s3) >= String.length(buffer(s3)))
                                        (Ok(x2), List.reverse(DriveEvent.GotDone :: ev1))
                                    else
                                        (Err(ParseError.Error(cursor(s3), "end of input" :: Nil)),
                                         List.reverse(DriveEvent.GotFail :: ev1))
                                case Step.Fail(e) =>
                                    (Err(e), List.reverse(DriveEvent.GotFail :: ev1))
                                case Step.Await(s3) =>
                                    // After close, await → fail
                                    (Err(ParseError.Error(cursor(s3), "end of input" :: Nil)),
                                     List.reverse(DriveEvent.GotFail :: ev1))
                            }
                        } else
                            // Early complete with more chunks: keep going only if
                            // leftover; otherwise success.
                            if (offset(s2) < String.length(buffer(s2)))
                                // Parsed something with leftover — treat as success of
                                // a prefix parser; educational demos use parseChunks.
                                (Ok(x), List.reverse(DriveEvent.GotDone :: ev1))
                            else
                                loop(rest, s2, DriveEvent.GotAwait :: ev1, false)
                    case Step.Fail(e) =>
                        (Err(e), List.reverse(DriveEvent.GotFail :: ev1))
                }
        };
        loop(chunks, open(), Nil, false)
    }

}
