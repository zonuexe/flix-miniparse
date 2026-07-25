///
/// Lab: **MiniLang** (pure `Parser`) vs **CoLang** (`CoParser`) parse parity.
///
/// Same surface language, two stacks. For each sample source we check:
///
/// | Check | Meaning |
/// | --- | --- |
/// | AST | `parseProgram` results are equal (`Ok` trees, or both `Err`) |
/// | run | When both parse, `runProgram` outputs agree |
///
/// Printed as a fixed-width table by `formatTable` / `flix run`.
///
mod Examples.LangCompare {

    use MiniParse.Core.{ParseError}
    use Examples.MiniLang.{
        Stmt, RuntimeError, Env, parseProgram => parseMini, runProgram
    }
    use Examples.CoLang.{parseProgram => parseCo, parseProgramChunks}

    ///////////////////////////////////////////////////////////////////////////
    // Row model
    ///////////////////////////////////////////////////////////////////////////

    /// How one side finished parsing.
    pub enum Side with Eq, ToString {
        case Ok,
        case Err
    }

    /// Agreement flag for a pairwise check.
    pub enum Mark with Eq, ToString {
        case Yes,   // agree
        case No,    // disagree
        case Skip   // not applicable (e.g. run when either side failed to parse)
    }

    pub enum Row with Eq, ToString {
        case Row(
            String, // short label
            Side,   // MiniLang parse
            Side,   // CoLang parse
            Mark,   // AST agree
            Mark    // run agree
        )
    }

    pub def rowLabel(r: Row): String = match r {
        case Row.Row(lab, _, _, _, _) => lab
    }

    pub def rowAst(r: Row): Mark = match r {
        case Row.Row(_, _, _, a, _) => a
    }

    pub def rowRun(r: Row): Mark = match r {
        case Row.Row(_, _, _, _, rmk) => rmk
    }

    pub def rowOk(r: Row): Bool = match r {
        case Row.Row(_, _, _, Mark.Yes, Mark.Yes) => true
        case Row.Row(_, _, _, Mark.Yes, Mark.Skip) => true
        case _ => false
    }

    ///////////////////////////////////////////////////////////////////////////
    // Sample suite
    ///////////////////////////////////////////////////////////////////////////

    /// `(label, source)` pairs exercised by the lab.
    pub def samples(): List[(String, String)] =
        ("empty", "") ::
        ("let-print", "let x = 1 + 2; print x * 3;") ::
        ("precedence", "print 1 + 2 * 3;") ::
        ("compare", "print 1 + 2 == 3; print 2 < 1;") ::
        ("cmp-ops", "print 5 >= 5; print 4 != 4; print 1 <= 2;") ::
        ("ifa", "let ifa = 7; print ifa;") ::
        ("if-then", "if 1 then print 10; else print 20;") ::
        ("if-else", "if 0 then print 10; else print 20;") ::
        ("block", "{ let a = 2; let b = 3; print a + b; }") ::
        ("nested-if", "let x = 1; if x then { if 0 then print 1; else print 2; } else print 3;") ::
        ("while-sum", "let i = 1; let s = 0; while i <= 5 do { let s = s + i; let i = i + 1; } print s;") ::
        ("unary", "print -1 + 2; print -(1 + 2);") ::
        ("parens", "print (1 + 2) * 3;") ::
        ("fail-let", "let = 1;") ::
        ("fail-kw", "let if = 1;") ::
        Nil

    ///////////////////////////////////////////////////////////////////////////
    // Comparison
    ///////////////////////////////////////////////////////////////////////////

    def sideOf(r: Result[ParseError, List[Stmt]]): Side = match r {
        case Ok(_)  => Side.Ok
        case Err(_) => Side.Err
    }

    /// Compare pure MiniLang parse vs CoLang parse (and shared interpreter).
    pub def compareOne(label: String, source: String): Row = {
        let m = parseMini(source);
        let c = parseCo(source);
        let sm = sideOf(m);
        let sc = sideOf(c);
        let ast = match (m, c) {
            case (Ok(a), Ok(b)) =>
                if (a == b) Mark.Yes else Mark.No
            case (Err(_), Err(_)) =>
                Mark.Yes
            case _ =>
                Mark.No
        };
        let rmk = match (m, c) {
            case (Ok(a), Ok(b)) => {
                // Even if ASTs differ, still report interpreter agreement.
                let ra = runProgram(a);
                let rb = runProgram(b);
                if (ra == rb) Mark.Yes else Mark.No
            }
            case _ =>
                Mark.Skip
        };
        Row.Row(label, sm, sc, ast, rmk)
    }

    pub def compareAll(): List[Row] =
        List.map(pair -> match pair {
            case (lab, src) => compareOne(lab, src)
        }, samples())

    /// Every sample has matching AST (and run when both parse).
    pub def allAgree(): Bool =
        List.forAll(rowOk, compareAll())

    /// CoLang chunked parse matches MiniLang whole-string parse (AST).
    pub def chunkAgrees(source: String, chunks: List[String]): Bool =
        match (parseMini(source), parseProgramChunks(chunks)) {
            case (Ok(a), Ok(b)) => a == b
            case (Err(_), Err(_)) => true
            case _ => false
        }

    ///////////////////////////////////////////////////////////////////////////
    // Table formatting
    ///////////////////////////////////////////////////////////////////////////

    def padRight(width: Int32, s: String): String = {
        let n = String.length(s);
        if (n >= width)
            String.slice(start = 0, end = width, s)
        else
            s + String.repeat(width - n, " ")
    }

    def showSide(s: Side): String = match s {
        case Side.Ok  => "OK "
        case Side.Err => "ERR"
    }

    def showMark(m: Mark): String = match m {
        case Mark.Yes  => " = "
        case Mark.No   => " ≠ "
        case Mark.Skip => " - "
    }

    def formatRow(r: Row): String = match r {
        case Row.Row(lab, sm, sc, ast, rmk) =>
            padRight(12, lab) + " | " +
            showSide(sm) + " | " +
            showSide(sc) + " | " +
            showMark(ast) + " | " +
            showMark(rmk)
    }

    /// Multi-line table (header + separator + body).
    pub def formatTable(rows: List[Row]): String = {
        let header =
            padRight(12, "label") + " | min | co  | AST | run";
        let sep =
            String.repeat(12, "-") + "-+-" +
            "---" + "-+-" +
            "---" + "-+-" +
            "---" + "-+-" +
            "---";
        let body = List.map(formatRow, rows);
        List.join("\n", header :: sep :: body)
    }

    pub def formatReport(): String = {
        let rows = compareAll();
        let table = formatTable(rows);
        let ok = List.count(rowOk, rows);
        let n = List.length(rows);
        let summary =
            if (ok == n)
                "summary: ${ok}/${n} agree"
            else
                "summary: ${ok}/${n} agree (see ≠ rows)";
        table + "\n" + summary
    }

}
