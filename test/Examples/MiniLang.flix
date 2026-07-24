///
/// Step 4: a tiny imperative language that ties the library together.
///
/// ```text
/// program ::= stmt*
/// stmt    ::= "let" ident "=" expr ";"
///           | "print" expr ";"
///           | "if" expr "then" stmt "else" stmt
///           | "{" stmt* "}"
/// expr    ::= arithmetic with variables (same precedence as Examples.Expr)
/// ```
///
/// Keywords use PEG-style ordered choice + negative lookahead (`!identChar`)
/// so `ifa` is an identifier, not `if` + `a`.
///
mod Examples.MiniLang {

    use MiniParse.Core.{Parser, pure, parse, fail}
    use MiniParse.Combinator.{
        map, flatMap, andThen, andThenL, char, digit, letter, alphaNum,
        some, many, charsToString, ws, lexeme, symbol, between, chainl1, delay
    }
    use MiniParse.Parsec.{orElse}
    use MiniParse.PEG.{choice, notPredicate}

    ///////////////////////////////////////////////////////////////////////////
    // AST
    ///////////////////////////////////////////////////////////////////////////

    pub enum Expr with Eq, ToString {
        case Lit(Int32),
        case Var(String),
        case Neg(Expr),
        case Add(Expr, Expr),
        case Sub(Expr, Expr),
        case Mul(Expr, Expr),
        case Div(Expr, Expr)
    }

    pub enum Stmt with Eq, ToString {
        case Let(String, Expr),
        case Print(Expr),
        case If(Expr, Stmt, Stmt),
        case Block(List[Stmt])
    }

    pub enum RuntimeError with Eq, ToString {
        case Unbound(String),
        case DivByZero
    }

    pub type alias Env = Map[String, Int32]

    ///////////////////////////////////////////////////////////////////////////
    // Parser entry
    ///////////////////////////////////////////////////////////////////////////

    pub def parseProgram(input: String): Result[MiniParse.Core.ParseError, List[Stmt]] =
        parse(program(), input)

    pub def program(): Parser[List[Stmt]] =
        andThen(ws(), andThenL(many(stmt()), ws()))

    pub def stmt(): Parser[Stmt] =
        choice(letStmt(),
        choice(printStmt(),
        choice(ifStmt(),
               blockStmt())))

    def letStmt(): Parser[Stmt] =
        flatMap(_ ->
            flatMap(name ->
                andThen(symbol("="),
                    flatMap(e ->
                        map(_ -> Stmt.Let(name, e), symbol(";")),
                        expr())),
                ident()),
            keyword("let"))

    def printStmt(): Parser[Stmt] =
        andThen(keyword("print"),
            flatMap(e ->
                map(_ -> Stmt.Print(e), symbol(";")),
                expr()))

    def ifStmt(): Parser[Stmt] =
        andThen(keyword("if"),
            flatMap(cond ->
                andThen(keyword("then"),
                    flatMap(thn ->
                        andThen(keyword("else"),
                            map(els -> Stmt.If(cond, thn, els),
                                delay(_ -> stmt()))),
                        delay(_ -> stmt()))),
                expr()))

    def blockStmt(): Parser[Stmt] =
        map(Stmt.Block,
            between(symbol("{"), symbol("}"),
                many(delay(_ -> stmt()))))

    ///////////////////////////////////////////////////////////////////////////
    // Expressions (with variables)
    ///////////////////////////////////////////////////////////////////////////

    pub def expr(): Parser[Expr] =
        chainl1(term(), addOp())

    def term(): Parser[Expr] =
        chainl1(factor(), mulOp())

    def factor(): Parser[Expr] =
        orElse(negFactor(),
        orElse(parenExpr(),
        orElse(number(),
               varExpr())))

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
            flatMap(ds -> match Int32.fromString(ds) {
                case Some(n) => pure(Expr.Lit(n))
                case None    => fail("number")
            }, map(charsToString, some(digit())))
        )

    def varExpr(): Parser[Expr] =
        map(Expr.Var, ident())

    ///////////////////////////////////////////////////////////////////////////
    // Lexical: keywords with ! boundary (PEG)
    ///////////////////////////////////////////////////////////////////////////

    def keyword(kw: String): Parser[String] =
        lexeme(
            andThenL(
                MiniParse.Combinator.string(kw),
                notPredicate(alphaNum())
            )
        )

    /// Identifier that is not a reserved keyword.
    pub def ident(): Parser[String] =
        rejectKeywords(
            lexeme(
                flatMap(c0 ->
                    map(cs -> Char.toString(c0) + charsToString(cs),
                        many(alphaNum())),
                    letter())
            )
        )

    def rejectKeywords(p: Parser[String]): Parser[String] =
        flatMap(name ->
            if (isKeyword(name))
                fail("identifier")
            else
                pure(name),
            p)

    def isKeyword(s: String): Bool =
        s == "let" or s == "print" or s == "if" or s == "then" or s == "else"

    ///////////////////////////////////////////////////////////////////////////
    // Interpreter
    ///////////////////////////////////////////////////////////////////////////

    pub def runProgram(stmts: List[Stmt]): Result[RuntimeError, (Env, List[Int32])] =
        execStmts(stmts, Map.empty(), Nil)

    pub def runSource(input: String): Result[MiniParse.Core.ParseError, Result[RuntimeError, (Env, List[Int32])]] =
        Result.map(runProgram, parseProgram(input))

    def execStmts(
        stmts: List[Stmt],
        env: Env,
        out: List[Int32]
    ): Result[RuntimeError, (Env, List[Int32])] = match stmts {
        case Nil => Ok((env, List.reverse(out)))
        case s :: rest =>
            match execStmt(s, env, out) {
                case Ok((env1, out1)) => execStmts(rest, env1, out1)
                case Err(e)           => Err(e)
            }
    }

    def execStmt(
        s: Stmt,
        env: Env,
        out: List[Int32]
    ): Result[RuntimeError, (Env, List[Int32])] = match s {
        case Stmt.Let(name, e) =>
            match evalExpr(e, env) {
                case Ok(n)   => Ok((Map.insert(name, n, env), out))
                case Err(er) => Err(er)
            }
        case Stmt.Print(e) =>
            match evalExpr(e, env) {
                case Ok(n)   => Ok((env, n :: out))
                case Err(er) => Err(er)
            }
        case Stmt.If(c, t, f) =>
            match evalExpr(c, env) {
                case Ok(n) =>
                    if (n != 0)
                        execStmt(t, env, out)
                    else
                        execStmt(f, env, out)
                case Err(er) => Err(er)
            }
        case Stmt.Block(ss) =>
            execStmts(ss, env, out)
    }

    pub def evalExpr(e: Expr, env: Env): Result[RuntimeError, Int32] = match e {
        case Expr.Lit(n) => Ok(n)
        case Expr.Var(x) =>
            match Map.get(x, env) {
                case Some(n) => Ok(n)
                case None    => Err(RuntimeError.Unbound(x))
            }
        case Expr.Neg(x) =>
            Result.map(n -> -n, evalExpr(x, env))
        case Expr.Add(l, r) => bin(l, r, env, (a, b) -> Ok(a + b))
        case Expr.Sub(l, r) => bin(l, r, env, (a, b) -> Ok(a - b))
        case Expr.Mul(l, r) => bin(l, r, env, (a, b) -> Ok(a * b))
        case Expr.Div(l, r) => bin(l, r, env, (a, b) ->
            if (b == 0) Err(RuntimeError.DivByZero) else Ok(a / b))
    }

    def bin(
        l: Expr,
        r: Expr,
        env: Env,
        f: (Int32, Int32) -> Result[RuntimeError, Int32]
    ): Result[RuntimeError, Int32] =
        match evalExpr(l, env) {
            case Err(e) => Err(e)
            case Ok(a) =>
                match evalExpr(r, env) {
                    case Err(e) => Err(e)
                    case Ok(b)  => f(a, b)
                }
        }

}
