///
/// Step A: a MiniLang *fragment* on `CoParser` (suspendable + deep orElse).
///
/// ```text
/// stmt  ::= "let" ident "=" number ";"
///         | "print" ident ";"
///         | "if" ident "then" stmt "else" stmt
/// program ::= stmt+
/// ```
///
/// Keywords use `keyword` = `string` + `notFollowedBy(alphaNum)`, so `ifa` is an
/// identifier, not `if` + `a`. Ordered choice among statement forms uses deep
/// backtracking `orElse`.
///
mod Examples.CoLang {

    use MiniParse.Core.{ParseError}
    use MiniParse.Suspend.{
        CoParser, pure, map, flatMap, andThen, andThenL, char, digit,
        orElse, many, some, keyword, ident, eof, parseChunks
    }

    pub enum Stmt with Eq, ToString {
        case Let(String, Int32),
        case Print(String),
        case If(String, Stmt, Stmt)
    }

    ///////////////////////////////////////////////////////////////////////////
    // Lexer-ish pieces
    ///////////////////////////////////////////////////////////////////////////

    def ws(): CoParser[Unit] =
        map(_ -> (), many(orElse(char(' '), orElse(char('\t'), orElse(char('\n'), char('\r'))))))

    def lexeme(p: CoParser[a]): CoParser[a] =
        andThenL(p, ws())

    def number(): CoParser[Int32] =
        lexeme(
            flatMap(ds -> match Int32.fromString(ds) {
                case Some(n) => pure(n)
                case None    => MiniParse.Suspend.fail("number")
            }, map(cs -> List.join("", List.map(Char.toString, cs)), some(digit())))
        )

    def identTok(): CoParser[String] =
        lexeme(ident())

    def kw(s: String): CoParser[String] =
        lexeme(keyword(s))

    def semi(): CoParser[Unit] =
        lexeme(map(_ -> (), char(';')))

    def eq(): CoParser[Unit] =
        lexeme(map(_ -> (), char('=')))

    ///////////////////////////////////////////////////////////////////////////
    // Statements
    ///////////////////////////////////////////////////////////////////////////

    pub def stmt(): CoParser[Stmt] =
        orElse(letStmt(),
        orElse(printStmt(),
               ifStmt()))

    def letStmt(): CoParser[Stmt] =
        andThen(kw("let"),
            flatMap(name ->
                andThen(eq(),
                    flatMap(n ->
                        map(_ -> Stmt.Let(name, n), semi()),
                        number())),
                identTok()))

    def printStmt(): CoParser[Stmt] =
        andThen(kw("print"),
            flatMap(name ->
                map(_ -> Stmt.Print(name), semi()),
                identTok()))

    def ifStmt(): CoParser[Stmt] =
        andThen(kw("if"),
            flatMap(cond ->
                andThen(kw("then"),
                    flatMap(thn ->
                        andThen(kw("else"),
                            map(els -> Stmt.If(cond, thn, els),
                                stmt())),
                        stmt())),
                identTok()))

    pub def program(): CoParser[List[Stmt]] =
        andThen(ws(), andThenL(some(stmt()), ws()))

    pub def parseProgram(input: String): Result[ParseError, List[Stmt]] =
        parseChunks(program(), input :: Nil)

    pub def parseProgramChunks(chunks: List[String]): Result[ParseError, List[Stmt]] =
        parseChunks(program(), chunks)

    /// Tokenize a single word: keyword or identifier (showcases deep orElse).
    pub enum Word with Eq, ToString {
        case WLet, WIf, WThen, WElse, WPrint, WIdent(String)
    }

    pub def word(): CoParser[Word] =
        orElse(map(_ -> Word.WLet, keyword("let")),
        orElse(map(_ -> Word.WIf, keyword("if")),
        orElse(map(_ -> Word.WThen, keyword("then")),
        orElse(map(_ -> Word.WElse, keyword("else")),
        orElse(map(_ -> Word.WPrint, keyword("print")),
               map(Word.WIdent, ident()))))))

    pub def parseWord(input: String): Result[ParseError, Word] =
        parseChunks(andThenL(word(), eof()), input :: Nil)

}
