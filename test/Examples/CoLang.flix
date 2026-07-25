///
/// CoLang: full MiniLang grammar on `CoParser` (suspendable + deep orElse).
///
/// Same surface syntax and AST as `Examples.MiniLang`, but parsed with the
/// coroutine stack so chunked input can resume mid-token without restarting.
///
/// ```text
/// program ::= stmt*
/// stmt    ::= "let" ident "=" expr ";"
///           | "print" expr ";"
///           | "if" expr "then" stmt "else" stmt
///           | "while" expr "do" stmt
///           | "{" stmt* "}"
/// expr    ::= arith (("=="|"!="|"<="|">="|"<"|">") arith)?
/// arith   ::= term   (("+"|"-") term)*
/// term    ::= factor (("*"|"/") factor)*
/// factor  ::= "-" factor | "(" expr ")" | number | ident
/// ```
///
/// Keywords use `keyword` + boundary (not followed by alphanum). Statement and
/// operator choice use deep `orElse` (longer comparison tokens first).
/// Interpretation reuses `Examples.MiniLang.runProgram`.
///
mod Examples.CoLang {

    use MiniParse.Core.{ParseError}
    use MiniParse.Suspend.{
        CoParser, pure, fail, map, flatMap, andThen, andThenL, char, digit,
        letter, alphaNum, orElse, many, some, keyword, eof, parseChunks, delay,
        chainl1, ws, lexeme, symbol, between, charsToString
    }
    use Examples.MiniLang.{Expr, Stmt, RuntimeError, Env, runProgram}

    ///////////////////////////////////////////////////////////////////////////
    // Lexer-ish pieces
    ///////////////////////////////////////////////////////////////////////////

    def kw(s: String): CoParser[String] =
        lexeme(keyword(s))

    def numberLit(): CoParser[Int32] =
        flatMap(ds -> match Int32.fromString(ds) {
            case Some(n) => pure(n)
            case None    => fail("number")
        }, map(charsToString, some(digit())))

    def number(): CoParser[Expr] =
        lexeme(map(Expr.Lit, numberLit()))

    /// Identifier token; rejects MiniLang keywords so `let` is not a variable.
    pub def ident(): CoParser[String] =
        rejectKeywords(
            lexeme(
                flatMap(c0 ->
                    map(cs -> Char.toString(c0) + charsToString(cs),
                        many(alphaNum())),
                    letter())
            )
        )

    def rejectKeywords(p: CoParser[String]): CoParser[String] =
        flatMap(name ->
            if (isKeyword(name))
                fail("identifier")
            else
                pure(name),
            p)

    def isKeyword(s: String): Bool =
        s == "let" or s == "print" or s == "if" or s == "then" or s == "else"
            or s == "while" or s == "do"

    ///////////////////////////////////////////////////////////////////////////
    // Statements (same AST as MiniLang)
    ///////////////////////////////////////////////////////////////////////////

    pub def stmt(): CoParser[Stmt] =
        orElse(letStmt(),
        orElse(printStmt(),
        orElse(whileStmt(),
        orElse(ifStmt(),
               blockStmt()))))

    def letStmt(): CoParser[Stmt] =
        andThen(kw("let"),
            flatMap(name ->
                andThen(symbol("="),
                    flatMap(e ->
                        map(_ -> Stmt.Let(name, e), symbol(";")),
                        delay(_ -> expr()))),
                ident()))

    def printStmt(): CoParser[Stmt] =
        andThen(kw("print"),
            flatMap(e ->
                map(_ -> Stmt.Print(e), symbol(";")),
                delay(_ -> expr())))

    def ifStmt(): CoParser[Stmt] =
        andThen(kw("if"),
            flatMap(cond ->
                andThen(kw("then"),
                    flatMap(thn ->
                        andThen(kw("else"),
                            map(els -> Stmt.If(cond, thn, els),
                                delay(_ -> stmt()))),
                        delay(_ -> stmt()))),
                delay(_ -> expr())))

    def whileStmt(): CoParser[Stmt] =
        andThen(kw("while"),
            flatMap(cond ->
                andThen(kw("do"),
                    map(body -> Stmt.While(cond, body),
                        delay(_ -> stmt()))),
                delay(_ -> expr())))

    def blockStmt(): CoParser[Stmt] =
        map(Stmt.Block,
            between(symbol("{"), symbol("}"),
                many(delay(_ -> stmt()))))

    pub def program(): CoParser[List[Stmt]] =
        andThen(ws(), andThenL(many(delay(_ -> stmt())), ws()))

    pub def parseProgram(input: String): Result[ParseError, List[Stmt]] =
        parseChunks(program(), input :: Nil)

    pub def parseProgramChunks(chunks: List[String]): Result[ParseError, List[Stmt]] =
        parseChunks(program(), chunks)

    /// Parse then interpret with the shared MiniLang runtime.
    pub def runSource(input: String): Result[ParseError, Result[RuntimeError, (Env, List[Int32])]] =
        Result.map(runProgram, parseProgram(input))

    pub def runSourceChunks(chunks: List[String]): Result[ParseError, Result[RuntimeError, (Env, List[Int32])]] =
        Result.map(runProgram, parseProgramChunks(chunks))

    ///////////////////////////////////////////////////////////////////////////
    // Expressions
    ///////////////////////////////////////////////////////////////////////////

    /// Full expression: optional single comparison over arithmetic.
    pub def expr(): CoParser[Expr] =
        flatMap(left ->
            map(o -> match o {
                case None    => left
                case Some(f) => f(left)
            }, optionalCmp()),
            arith())

    def optionalCmp(): CoParser[Option[Expr -> Expr]] =
        orElse(
            map(Some, cmpTail()),
            pure(None)
        )

    def cmpTail(): CoParser[Expr -> Expr] =
        flatMap(op ->
            map(right -> (left -> op(left, right)), arith()),
            cmpOp())

    /// Longer tokens first; deep `orElse` rewinds so `"<"` does not steal `"<="`.
    def cmpOp(): CoParser[(Expr, Expr) -> Expr] =
        orElse(map(_ -> (l, r) -> Expr.Eq(l, r), symbol("==")),
        orElse(map(_ -> (l, r) -> Expr.Ne(l, r), symbol("!=")),
        orElse(map(_ -> (l, r) -> Expr.Le(l, r), symbol("<=")),
        orElse(map(_ -> (l, r) -> Expr.Ge(l, r), symbol(">=")),
        orElse(map(_ -> (l, r) -> Expr.Lt(l, r), symbol("<")),
               map(_ -> (l, r) -> Expr.Gt(l, r), symbol(">")))))))

    def arith(): CoParser[Expr] =
        chainl1(term(), addOp())

    def term(): CoParser[Expr] =
        chainl1(factor(), mulOp())

    def factor(): CoParser[Expr] =
        orElse(negFactor(),
        orElse(parenExpr(),
        orElse(number(),
               varExpr())))

    def negFactor(): CoParser[Expr] =
        andThen(lexeme(char('-')), map(Expr.Neg, delay(_ -> factor())))

    def parenExpr(): CoParser[Expr] =
        between(symbol("("), symbol(")"), delay(_ -> expr()))

    def addOp(): CoParser[(Expr, Expr) -> Expr] =
        orElse(
            map(_ -> (l, r) -> Expr.Add(l, r), symbol("+")),
            map(_ -> (l, r) -> Expr.Sub(l, r), symbol("-"))
        )

    def mulOp(): CoParser[(Expr, Expr) -> Expr] =
        orElse(
            map(_ -> (l, r) -> Expr.Mul(l, r), symbol("*")),
            map(_ -> (l, r) -> Expr.Div(l, r), symbol("/"))
        )

    def varExpr(): CoParser[Expr] =
        map(Expr.Var, ident())

    ///////////////////////////////////////////////////////////////////////////
    // Word lab (keyword boundary demo; not the full language)
    ///////////////////////////////////////////////////////////////////////////

    /// Tokenize a single word: keyword or identifier (showcases deep orElse).
    pub enum Word with Eq, ToString {
        case WLet, WIf, WThen, WElse, WPrint, WWhile, WDo, WIdent(String)
    }

    pub def word(): CoParser[Word] =
        orElse(map(_ -> Word.WLet, keyword("let")),
        orElse(map(_ -> Word.WIf, keyword("if")),
        orElse(map(_ -> Word.WThen, keyword("then")),
        orElse(map(_ -> Word.WElse, keyword("else")),
        orElse(map(_ -> Word.WPrint, keyword("print")),
        orElse(map(_ -> Word.WWhile, keyword("while")),
        orElse(map(_ -> Word.WDo, keyword("do")),
               map(Word.WIdent, MiniParse.Suspend.ident()))))))))

    pub def parseWord(input: String): Result[ParseError, Word] =
        parseChunks(andThenL(word(), eof()), input :: Nil)

}
