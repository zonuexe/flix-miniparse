mod TestParsecPEG {

    use MiniParse.Core.{parse, pure}
    use MiniParse.Combinator.{char, string, andThen, digit}
    use MiniParse.Parsec.{orElse, attempt}
    use MiniParse.PEG.{choice, notPredicate, andPredicate}

    /// Without attempt: after consuming 'a', failure of second char aborts choice.
    @Test
    def testParsecOrElseNoBacktrack(): Unit \ Assert = {
        // p1 = "ab", p2 = "a" — on input "aX", p1 consumes 'a' then fails; p2 not tried.
        let p1 = andThen(char('a'), char('b'));
        let p2 = char('a');
        Assert.assertTrue(Result.isErr(parse(orElse(p1, p2), "aX")))
    }

    /// With attempt: same p1 can backtrack so p2 matches.
    @Test
    def testParsecAttemptBacktrack(): Unit \ Assert = {
        let p1 = andThen(char('a'), char('b'));
        let p2 = char('a');
        // Note: leftover 'X' → full parse fails; use partial-friendly string "a" only for p2 success path.
        Assert.assertEq(expected = Ok('a'), parse(orElse(attempt(p1), p2), "a"))
    }

    /// PEG choice always rewinds the first alternative.
    @Test
    def testPegChoiceBacktrack(): Unit \ Assert = {
        // Both alternatives must share the same result type.
        let p1 = andThen(char('a'), char('b')); // Parser[Char]
        let p2 = char('a');
        Assert.assertEq(expected = Ok('a'), parse(choice(p1, p2), "a"))
    }

    @Test
    def testNotPredicate(): Unit \ Assert = {
        // !'b' then 'a'
        let p = andThen(notPredicate(char('b')), char('a'));
        Assert.assertEq(expected = Ok('a'), parse(p, "a"));
        Assert.assertTrue(Result.isErr(parse(p, "b")))
    }

    @Test
    def testAndPredicate(): Unit \ Assert = {
        // &digit then digit — lookahead does not consume twice incorrectly
        let p = andThen(andPredicate(digit()), digit());
        Assert.assertEq(expected = Ok('5'), parse(p, "5"));
        Assert.assertTrue(Result.isErr(parse(p, "x")))
    }

    @Test
    def testOrElseFirstWins(): Unit \ Assert =
        Assert.assertEq(expected = Ok('x'), parse(orElse(char('x'), char('y')), "x"))

    @Test
    def testOrElseSecond(): Unit \ Assert =
        Assert.assertEq(expected = Ok('y'), parse(orElse(char('x'), char('y')), "y"))

}
