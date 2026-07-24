mod TestCoLang {

    use Examples.CoLang.{
        Stmt, Word, parseProgram, parseProgramChunks, parseWord, stmt
    }

    @Test
    def testWordIf(): Unit \ Assert =
        Assert.assertEq(expected = Ok(Word.WIf), parseWord("if"))

    @Test
    def testWordIfa(): Unit \ Assert =
        Assert.assertEq(expected = Ok(Word.WIdent("ifa")), parseWord("ifa"))

    @Test
    def testWordLet(): Unit \ Assert =
        Assert.assertEq(expected = Ok(Word.WLet), parseWord("let"))

    @Test
    def testWordPrint(): Unit \ Assert =
        Assert.assertEq(expected = Ok(Word.WPrint), parseWord("print"))

    @Test
    def testLetPrint(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(
                Stmt.Let("ifa", 2) :: Stmt.Print("ifa") :: Nil
            ),
            parseProgram("let ifa = 2; print ifa;")
        )

    @Test
    def testIfThenElse(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(
                Stmt.If("x", Stmt.Print("a"), Stmt.Print("b")) :: Nil
            ),
            parseProgram("if x then print a; else print b;")
        )

    @Test
    def testChunks(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(Stmt.Let("x", 1) :: Nil),
            parseProgramChunks("let x" :: " = 1;" :: Nil)
        )

    @Test
    def testIfaNotKeyword(): Unit \ Assert =
        // Must not parse as `if` + leftover `a = 1;`
        Assert.assertEq(
            expected = Ok(Stmt.Let("ifa", 1) :: Nil),
            parseProgram("let ifa = 1;")
        )

}
