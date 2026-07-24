///
/// Step 2: arithmetic expressions with precedence and associativity.
///
/// Grammar (left-associative, `*`/`/` bind tighter than `+`/`-`):
///
/// ```text
/// expr   ::= term   (("+" | "-") term)*
/// term   ::= factor (("*" | "/") factor)*
/// factor ::= "-" factor | "(" expr ")" | number
/// ```
///
/// Both Parsec-style and PEG-style fronts can share this layered grammar:
/// operator choice is single-character lookahead (no `attempt` required).
///
mod Examples.Expr {

    use MiniParse.Core.{Parser, pure, parse}
    use MiniParse.Combinator.{
        map, flatMap, andThen, andThenL, char, digit, some, charsToString,
        ws, lexeme, symbol, between, chainl1, delay
    }
    use MiniParse.Parsec.{orElse}

    ///////////////////////////////////////////////////////////////////////////
    // AST
    ///////////////////////////////////////////////////////////////////////////

    pub enum Expr with Eq, ToString {
        case Lit(Int32),
        case Neg(Expr),
        case Add(Expr, Expr),
        case Sub(Expr, Expr),
        case Mul(Expr, Expr),
        case Div(Expr, Expr)
    }

    /// Evaluate an expression (integer division truncates toward zero via JVM).
    pub def eval(e: Expr): Int32 = match e {
        case Expr.Lit(n)    => n
        case Expr.Neg(x)    => -eval(x)
        case Expr.Add(l, r) => eval(l) + eval(r)
        case Expr.Sub(l, r) => eval(l) - eval(r)
        case Expr.Mul(l, r) => eval(l) * eval(r)
        case Expr.Div(l, r) => eval(l) / eval(r)
    }

    ///////////////////////////////////////////////////////////////////////////
    // Public parsers
    ///////////////////////////////////////////////////////////////////////////

    pub def parseExpr(input: String): Result[MiniParse.Core.ParseError, Expr] =
        parse(exprDoc(), input)

    pub def parseEval(input: String): Result[MiniParse.Core.ParseError, Int32] =
        Result.map(eval, parseExpr(input))

    pub def exprDoc(): Parser[Expr] =
        andThen(ws(), andThenL(expr(), ws()))

    ///////////////////////////////////////////////////////////////////////////
    // Layers
    ///////////////////////////////////////////////////////////////////////////

    pub def expr(): Parser[Expr] =
        chainl1(term(), addOp())

    pub def term(): Parser[Expr] =
        chainl1(factor(), mulOp())

    pub def factor(): Parser[Expr] =
        orElse(negFactor(),
        orElse(parenExpr(),
               number()))

    def negFactor(): Parser[Expr] =
        andThen(lexeme(char('-')), map(Expr.Neg, delay(_ -> factor())))

    def parenExpr(): Parser[Expr] =
        between(symbol("("), symbol(")"), delay(_ -> expr()))

    def addOp(): Parser[(Expr, Expr) -> Expr] =
        orElse(
            map(_ -> (l, r) -> Expr.Add(l, r), symbol("+")),
            map(_ -> (l, r) -> Expr.Sub(l, r), symbol("-"))
        )

    def mulOp(): Parser[(Expr, Expr) -> Expr] =
        orElse(
            map(_ -> (l, r) -> Expr.Mul(l, r), symbol("*")),
            map(_ -> (l, r) -> Expr.Div(l, r), symbol("/"))
        )

    def number(): Parser[Expr] =
        lexeme(
            map(ds -> match Int32.fromString(ds) {
                case Some(n) => Expr.Lit(n)
                case None    => Expr.Lit(0) // digits are non-empty; should not happen
            }, map(charsToString, some(digit())))
        )

}
