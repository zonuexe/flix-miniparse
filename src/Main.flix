/// Demo: postal codes, JSON, arithmetic, and keyword vs identifier.
def main(): Unit \ IO = {
    use Examples.PostalCode.{parsePostalCode, format};
    use Examples.Json.{parseJson};
    use Examples.Expr.{parseExpr, parseEval};
    use Examples.Keyword.{parseNaiveParsec, parseParsec, parsePeg};

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
    println("== Arithmetic (precedence / assoc) ==");
    foreach (s <- "1 + 2 * 3" :: "(1 + 2) * 3" :: "10 - 3 - 2" :: "-4 + 1" :: Nil) {
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
    println("== Keyword vs identifier (if / ifa) ==");
    println("input | naive Parsec | Parsec+attempt | PEG");
    foreach (s <- "if" :: "ifa" :: "foo" :: "if1" :: Nil) {
        let n = showTok(parseNaiveParsec(s));
        let p = showTok(parseParsec(s));
        let g = showTok(parsePeg(s));
        println("  `${s}` | ${n} | ${p} | ${g}")
    }
}

def showTok(r: Result[MiniParse.Core.ParseError, Examples.Keyword.Token]): String =
    match r {
        case Ok(t)  => "${t}"
        case Err(_) => "FAIL"
    }
