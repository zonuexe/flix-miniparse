///
/// Step 0 smoke test: Japanese-style postal codes.
///
/// Accepts:
///   - `150-0002`
///   - `〒150-0002`
///
mod Examples.PostalCode {

    use MiniParse.Core.{Parser, parse}
    use MiniParse.Combinator.{char, digits, optional, andThen, map, flatMap}

    /// area (3 digits), local (4 digits)
    pub enum PostalCode with Eq, ToString {
        case PostalCode(String, String)
    }

    /// `〒? ddd-dddd`
    pub def postalCode(): Parser[PostalCode] =
        andThen(
            optional(char('〒')),
            flatMap(area ->
                andThen(
                    char('-'),
                    map(local -> PostalCode.PostalCode(area, local),
                        digits(4))
                ),
                digits(3)
            )
        )

    /// Parse a full string as a postal code (must consume all input).
    pub def parsePostalCode(input: String): Result[MiniParse.Core.ParseError, PostalCode] =
        parse(postalCode(), input)

    pub def format(pc: PostalCode): String = match pc {
        case PostalCode.PostalCode(area, local) => "${area}-${local}"
    }

}
