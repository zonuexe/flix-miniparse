/// Demo: postal codes, JSON, arithmetic, keywords, packrat, error formatting.
def main(): Unit \ IO = {
    use Examples.PostalCode.{parsePostalCode, format};
    use Examples.Json.{parseJson};
    use Examples.Expr.{parseExpr, parseEval};
    use Examples.Keyword.{parseNaiveParsec, parseParsec, parsePeg};
    use Examples.Packrat.{parseNaive, parseMemo};
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
