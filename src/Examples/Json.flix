///
/// Step 1: a recursive JSON parser built on MiniParse combinators.
///
/// The grammar is LL(1)-friendly: alternatives are distinguished by the first
/// non-whitespace character, so Parsec-style `orElse` (no auto-backtrack) works
/// without wrapping every branch in `attempt`.
///
mod Examples.Json {

    use MiniParse.Core.{Parser, pure, parse, fail}
    use MiniParse.Combinator.{
        map, flatMap, andThen, andThenL, char, digit, string, satisfy,
        many, some, optional, charsToString, ws, lexeme, symbol, between, sepBy,
        delay
    }
    use MiniParse.Parsec.{orElse}

    ///////////////////////////////////////////////////////////////////////////
    // AST
    ///////////////////////////////////////////////////////////////////////////

    pub enum JsonValue with Eq, ToString {
        case JNull,
        case JBool(Bool),
        case JNumber(Float64),
        case JString(String),
        case JArray(List[JsonValue]),
        case JObject(List[(String, JsonValue)])
    }

    ///////////////////////////////////////////////////////////////////////////
    // Entry points
    ///////////////////////////////////////////////////////////////////////////

    pub def parseJson(input: String): Result[MiniParse.Core.ParseError, JsonValue] =
        parse(jsonDoc(), input)

    /// Top-level document: optional BOM-free whitespace, one value, trailing ws.
    pub def jsonDoc(): Parser[JsonValue] =
        andThen(ws(), andThenL(jsonValue(), ws()))

    ///////////////////////////////////////////////////////////////////////////
    // Values
    ///////////////////////////////////////////////////////////////////////////

    /// Recursive array/object branches are `delay`ed so the parser graph is
    /// not built eagerly (would otherwise loop forever at construction time).
    pub def jsonValue(): Parser[JsonValue] =
        orElse(jsonNull(),
        orElse(jsonBool(),
        orElse(jsonNumber(),
        orElse(jsonString(),
        orElse(delay(_ -> jsonArray()),
              delay(_ -> jsonObject()))))))

    pub def jsonNull(): Parser[JsonValue] =
        map(_ -> JsonValue.JNull, lexeme(string("null")))

    pub def jsonBool(): Parser[JsonValue] =
        orElse(
            map(_ -> JsonValue.JBool(true), lexeme(string("true"))),
            map(_ -> JsonValue.JBool(false), lexeme(string("false")))
        )

    ///////////////////////////////////////////////////////////////////////////
    // Number: optional sign, digits, optional fraction, optional exponent
    ///////////////////////////////////////////////////////////////////////////

    pub def jsonNumber(): Parser[JsonValue] =
        lexeme(
            flatMap(sign ->
                flatMap(intPart ->
                    flatMap(frac ->
                        flatMap(exp -> {
                            let text = sign + intPart + frac + exp;
                            match Float64.fromString(text) {
                                case Some(n) => pure(JsonValue.JNumber(n))
                                case None    => fail("number")
                            }
                        }, exponent()),
                        fraction()),
                    intPart()),
                optionalSign())
        )

    def optionalSign(): Parser[String] =
        map(o -> match o {
            case Some(c) => Char.toString(c)
            case None    => ""
        }, optional(char('-')))

    def intPart(): Parser[String] =
        orElse(
            map(_ -> "0", char('0')),
            flatMap(d ->
                map(ds -> Char.toString(d) + charsToString(ds),
                    many(digit())),
                nonzero())
        )

    def nonzero(): Parser[Char] =
        satisfy(c -> c >= '1' and c <= '9', "nonzero digit")

    def fraction(): Parser[String] =
        map(o -> match o {
            case None     => ""
            case Some(ds) => "." + charsToString(ds)
        }, optional(andThen(char('.'), some(digit()))))

    def exponent(): Parser[String] =
        map(o -> match o {
            case None => ""
            case Some((e, sign, ds)) =>
                Char.toString(e) + sign + charsToString(ds)
        }, optional(
            flatMap(e ->
                flatMap(sign ->
                    map(ds -> (e, sign, ds), some(digit())),
                    expSign()),
                satisfy(c -> c == 'e' or c == 'E', "exponent"))
        ))

    def expSign(): Parser[String] =
        map(o -> match o {
            case Some(c) => Char.toString(c)
            case None    => ""
        }, optional(satisfy(c -> c == '+' or c == '-', "sign")))

    ///////////////////////////////////////////////////////////////////////////
    // String with JSON escapes
    ///////////////////////////////////////////////////////////////////////////

    pub def jsonString(): Parser[JsonValue] =
        map(JsonValue.JString, lexeme(jsonStringRaw()))

    /// Quoted string without trailing whitespace (for object keys).
    pub def jsonStringRaw(): Parser[String] =
        between(char('"'), char('"'),
            map(charsToString, many(stringChar())))

    def stringChar(): Parser[Char] =
        orElse(escape(),
            satisfy(c -> c != '"' and c != '\\' and c >= ' ', "string char"))

    def escape(): Parser[Char] =
        andThen(char('\\'),
            orElse(char('"'),
            orElse(char('\\'),
            orElse(char('/'),
            orElse(map(_ -> '\u0008', char('b')),
            orElse(map(_ -> '\u000c', char('f')),
            orElse(map(_ -> '\n', char('n')),
            orElse(map(_ -> '\r', char('r')),
            orElse(map(_ -> '\t', char('t')),
                   unicodeEscape())))))))))

    def unicodeEscape(): Parser[Char] =
        andThen(char('u'),
            flatMap(h1 ->
                flatMap(h2 ->
                    flatMap(h3 ->
                        flatMap(h4 -> {
                            let hex = charsToString(h1 :: h2 :: h3 :: h4 :: Nil);
                            match Int32.parse(16, hex) {
                                case Ok(code) => pure(Int32.truncateToChar(code))
                                case Err(_)   => fail("hex")
                            }
                        }, hexDigit()),
                        hexDigit()),
                    hexDigit()),
                hexDigit()))

    def hexDigit(): Parser[Char] =
        satisfy(Char.isHexDigit, "hex digit")

    ///////////////////////////////////////////////////////////////////////////
    // Array & object
    ///////////////////////////////////////////////////////////////////////////

    pub def jsonArray(): Parser[JsonValue] =
        map(JsonValue.JArray,
            between(symbol("["), symbol("]"),
                sepBy(jsonValue(), symbol(","))))

    pub def jsonObject(): Parser[JsonValue] =
        map(JsonValue.JObject,
            between(symbol("{"), symbol("}"),
                sepBy(jsonMember(), symbol(","))))

    def jsonMember(): Parser[(String, JsonValue)] =
        flatMap(k ->
            andThen(symbol(":"),
                map(v -> (k, v), jsonValue())),
            lexeme(jsonStringRaw()))

}
