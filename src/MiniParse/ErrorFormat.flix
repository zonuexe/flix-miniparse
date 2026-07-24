///
/// Human-readable parse error formatting (line, column, caret).
///
mod MiniParse.ErrorFormat {

    use MiniParse.Core.{ParseError, Position, parseErrorPos, parseErrorExpected, positionLine, positionColumn, positionOffset}

    /// Format `err` against the original `input` for display.
    pub def formatError(input: String, err: ParseError): String = {
        let pos = parseErrorPos(err);
        let line = positionLine(pos);
        let col = positionColumn(pos);
        let expected = parseErrorExpected(err);
        let expText = match expected {
            case Nil => "(unknown)"
            case xs  => List.join(" or ", xs)
        };
        let srcLine = lineAt(input, line);
        let caret = String.repeat(Int32.max(0, col - 1), " ") + "^";
        "parse error at line ${line}, column ${col} (offset ${positionOffset(pos)})\n" +
            "  expected: ${expText}\n" +
            "  | ${srcLine}\n" +
            "  | ${caret}"
    }

    /// Extract the 1-based `lineNo` line from `input` (without trailing newline).
    pub def lineAt(input: String, lineNo: Int32): String = {
        def loop(off: Int32, cur: Int32, start: Int32): String =
            match String.nth(off, input) {
                case None =>
                    String.slice(start = start, end = String.length(input), input)
                case Some('\n') =>
                    if (cur == lineNo)
                        String.slice(start = start, end = off, input)
                    else
                        loop(off + 1, cur + 1, off + 1)
                case Some(_) =>
                    loop(off + 1, cur, start)
            };
        if (lineNo < 1)
            ""
        else
            loop(0, 1, 0)
    }

}
