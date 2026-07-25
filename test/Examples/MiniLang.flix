///
/// MiniLang: a tiny imperative language that ties MiniParse together.
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
/// Booleans are integers: `0` is false, any other value is true.
/// Comparison operators evaluate to `1` or `0`.
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
    use MiniParse.Parsec.{orElse, attempt}
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
        case Div(Expr, Expr),
        case Eq(Expr, Expr),
        case Ne(Expr, Expr),
        case Lt(Expr, Expr),
        case Le(Expr, Expr),
        case Gt(Expr, Expr),
        case Ge(Expr, Expr)
    }

    pub enum Stmt with Eq, ToString {
        case Let(String, Expr),
        case Print(Expr),
        case If(Expr, Stmt, Stmt),
        case While(Expr, Stmt),
        case Block(List[Stmt])
    }

    pub enum RuntimeError with Eq, ToString {
        case Unbound(String),
        case DivByZero,
        case LoopLimit
    }

    pub type alias Env = Map[String, Int32]

    /// Safety cap for `while` (educational interpreter).
    pub def maxLoopIterations(): Int32 = 100_000

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
        choice(whileStmt(),
        choice(ifStmt(),
               blockStmt()))))

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

    def whileStmt(): Parser[Stmt] =
        andThen(keyword("while"),
            flatMap(cond ->
                andThen(keyword("do"),
                    map(body -> Stmt.While(cond, body),
                        delay(_ -> stmt()))),
                expr()))

    def blockStmt(): Parser[Stmt] =
        map(Stmt.Block,
            between(symbol("{"), symbol("}"),
                many(delay(_ -> stmt()))))

    ///////////////////////////////////////////////////////////////////////////
    // Expressions
    ///////////////////////////////////////////////////////////////////////////

    /// Full expression: optional single comparison over arithmetic.
    pub def expr(): Parser[Expr] =
        flatMap(left ->
            map(o -> match o {
                case None    => left
                case Some(f) => f(left)
            }, optionalCmp()),
            arith())

    /// `op arith` producing a function `left -> Cmp(left, right)`.
    def optionalCmp(): Parser[Option[Expr -> Expr]] =
        orElse(
            map(Some, cmpTail()),
            pure(None)
        )

    def cmpTail(): Parser[Expr -> Expr] =
        flatMap(op ->
            map(right -> (left -> op(left, right)), arith()),
            cmpOp())

    def cmpOp(): Parser[(Expr, Expr) -> Expr] =
        // Longer tokens first; `attempt` so `"<"` does not commit before `"<="`.
        orElse(attempt(map(_ -> (l, r) -> Expr.Eq(l, r), symbol("=="))),
        orElse(attempt(map(_ -> (l, r) -> Expr.Ne(l, r), symbol("!="))),
        orElse(attempt(map(_ -> (l, r) -> Expr.Le(l, r), symbol("<="))),
        orElse(attempt(map(_ -> (l, r) -> Expr.Ge(l, r), symbol(">="))),
        orElse(attempt(map(_ -> (l, r) -> Expr.Lt(l, r), symbol("<"))),
               attempt(map(_ -> (l, r) -> Expr.Gt(l, r), symbol(">"))))))))

    def arith(): Parser[Expr] =
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
    // Lexical
    ///////////////////////////////////////////////////////////////////////////

    def keyword(kw: String): Parser[String] =
        lexeme(
            andThenL(
                MiniParse.Combinator.string(kw),
                notPredicate(alphaNum())
            )
        )

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
            or s == "while" or s == "do"

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
        case Stmt.While(c, body) =>
            execWhile(c, body, env, out, maxLoopIterations())
        case Stmt.Block(ss) =>
            execStmts(ss, env, out)
    }

    def execWhile(
        c: Expr,
        body: Stmt,
        env: Env,
        out: List[Int32],
        fuel: Int32
    ): Result[RuntimeError, (Env, List[Int32])] =
        if (fuel <= 0)
            Err(RuntimeError.LoopLimit)
        else
            match evalExpr(c, env) {
                case Err(er) => Err(er)
                case Ok(0)   => Ok((env, out))
                case Ok(_) =>
                    match execStmt(body, env, out) {
                        case Err(er)           => Err(er)
                        case Ok((env1, out1)) =>
                            execWhile(c, body, env1, out1, fuel - 1)
                    }
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
        case Expr.Eq(l, r) => bin(l, r, env, (a, b) -> Ok(if (a == b) 1 else 0))
        case Expr.Ne(l, r) => bin(l, r, env, (a, b) -> Ok(if (a != b) 1 else 0))
        case Expr.Lt(l, r) => bin(l, r, env, (a, b) -> Ok(if (a < b) 1 else 0))
        case Expr.Le(l, r) => bin(l, r, env, (a, b) -> Ok(if (a <= b) 1 else 0))
        case Expr.Gt(l, r) => bin(l, r, env, (a, b) -> Ok(if (a > b) 1 else 0))
        case Expr.Ge(l, r) => bin(l, r, env, (a, b) -> Ok(if (a >= b) 1 else 0))
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
