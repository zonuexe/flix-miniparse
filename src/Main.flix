/// Demo entry: all roadmap examples.
def main(): Unit \ IO = {
    use Examples.PostalCode.{parsePostalCode, format};
    use Examples.Json.{parseJson};
    use Examples.Expr.{parseExpr, parseEval};
    use Examples.Keyword.{parseNaiveParsec, parseParsec, parsePeg};
    use Examples.Packrat.{parseNaive, parseMemo};
    use Examples.MiniLang.{runSource};
    use Examples.LeftRec.{parseLeft, parseRight};
    use Examples.StreamDemo.{parseJsonChunks};
    use MiniParse.ErrorFormat.{formatError};
    use MiniParse.Core.{parse};
    use MiniParse.Combinator.{digit};

    println("== Postal codes ==");
    foreach (s <- "150-0002" :: "〒150-0002" :: Nil) {
        match parsePostalCode(s) {
            case Ok(pc) => println("OK  `${s}` -> ${format(pc)}")
            case Err(e) => println("ERR `${s}` -> ${e}")
        }
    };

    println("");
    println("== JSON ==");
    foreach (s <- "null" :: "[1, 2]" :: "{\"a\": true}" :: Nil) {
        match parseJson(s) {
            case Ok(v)  => println("OK  `${s}` -> ${v}")
            case Err(e) => println("ERR `${s}` -> ${e}")
        }
    };

    println("");
    println("== Arithmetic ==");
    foreach (s <- "1 + 2 * 3" :: "(1 + 2) * 3" :: "10 - 3 - 2" :: Nil) {
        match parseEval(s) {
            case Ok(n) =>
                match parseExpr(s) {
                    case Ok(e)  => println("OK  `${s}` -> ${e} = ${n}")
                    case Err(_) => println("OK  `${s}` = ${n}")
                }
            case Err(e) => println("ERR `${s}` -> ${e}")
        }
    };

    println("");
    println("== Keyword vs identifier ==");
    println("input | naive | Parsec+attempt | PEG");
    foreach (s <- "if" :: "ifa" :: "if1" :: Nil) {
        println("  `${s}` | ${showTok(parseNaiveParsec(s))} | ${showTok(parseParsec(s))} | ${showTok(parsePeg(s))}")
    };

    println("");
    println("== Packrat (S <- a S S / a S / a) ==");
    foreach (s <- "a" :: "aa" :: "aaa" :: "aaaa" :: Nil) {
        let n = showStats(parseNaive(s));
        let m = showStats(parseMemo(s));
        println("  `${s}` naive=${n}  memo=${m}")
    };

    println("");
    println("== Left-recursive packrat (E <- E+n / n) ==");
    foreach (s <- "1+2+3" :: "10+20+30" :: Nil) {
        println("  `${s}`");
        println("    left : ${parseLeft(s)}");
        println("    right: ${parseRight(s)}")
    };

    println("");
    println("== Streaming restart-style (MiniParse.Stream) ==");
    let chunks = "15" :: "0-00" :: "02" :: Nil;
    println("postal chunks: ${chunks}");
    match Examples.StreamDemo.drivePostal(chunks) {
        case (Ok(pc), ev) =>
            println("  result: ${pc}");
            println("  events: ${ev}")
        case (Err(e), ev) =>
            println("  error: ${e}");
            println("  events: ${ev}")
    };
    match parseJsonChunks("{\"x\":" :: " [1,2]}" :: Nil) {
        case Ok(v)  => println("json chunks: ${v}")
        case Err(e) => println("json chunks error: ${e}")
    };

    println("");
    println("== Coroutine suspension (MiniParse.Suspend) ==");
    println("(continuation resumes mid-token; does not restart)");
    let coChunks = "15" :: "0-" :: "0002" :: Nil;
    match Examples.SuspendDemo.drivePostal(coChunks) {
        case (Ok(pc), ev) =>
            println("  chunks: ${coChunks}");
            println("  result: ${pc}");
            println("  events: ${ev}")
        case (Err(e), ev) =>
            println("  error: ${e}");
            println("  events: ${ev}")
    };
    println("  deep orElse if|ifa on \"ifa\": ${Examples.SuspendDemo.parseIfOrIfa("ifa" :: Nil)}");
    println("  deep orElse abc|abx on ab|x: ${Examples.SuspendDemo.parseAbcOrAbx("ab" :: "x" :: Nil)}");

    println("");
    println("== CoLang (CoParser MiniLang fragment) ==");
    println("  word if/ifa: ${Examples.CoLang.parseWord("if")} / ${Examples.CoLang.parseWord("ifa")}");
    println("  program: ${Examples.CoLang.parseProgram("let ifa = 2; print ifa;")}");

    println("");
    println("== Cost: Stream restart vs Suspend continue ==");
    let n = 8;
    let ones = Examples.CostCompare.oneChunks(n);
    match Examples.CostCompare.streamDigitsCost(n, ones) {
        case (Ok(_), cs) =>
            println("  stream  digits(${n}) one-char chunks: ${cs}")
        case (Err(e), cs) =>
            println("  stream  error ${e} cost ${cs}")
    };
    match Examples.CostCompare.suspendDigitsCost(n, ones) {
        case (Ok(_), cc) =>
            println("  suspend digits(${n}) one-char chunks: ${cc}")
        case (Err(e), cc) =>
            println("  suspend error ${e} cost ${cc}")
    };
    println("  (charVisits: stream ~ n(n+1)/2, suspend ~ n)");

    println("");
    println("== MiniLang ==");
    let prog =
        "let ifa = 2;\n" +
        "let y = 3;\n" +
        "if ifa then print ifa * y; else print 0;\n";
    println(prog);
    match runSource(prog) {
        case Ok(Ok((_env, out))) => println("output = ${out}")
        case Ok(Err(e))          => println("runtime error: ${e}")
        case Err(e)              => println("parse error:\n${formatError(prog, e)}")
    };

    println("");
    println("== Error formatting ==");
    match parse(digit(), "xy") {
        case Ok(_)  => println("unexpected success")
        case Err(e) => println(formatError("xy", e))
    }
}

def showTok(r: Result[MiniParse.Core.ParseError, Examples.Keyword.Token]): String =
    match r {
        case Ok(t)  => "${t}"
        case Err(_) => "FAIL"
    }

def showStats(r: Result[MiniParse.Core.ParseError, Examples.Packrat.Stats]): String =
    match r {
        case Ok(Examples.Packrat.Stats.Stats(v, c)) => "value=${v}, bodyEntries=${c}"
        case Err(_)                                 => "FAIL"
    }
