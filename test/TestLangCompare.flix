mod TestLangCompare {

    use Examples.LangCompare.{
        compareOne, compareAll, allAgree, chunkAgrees, rowOk, rowAst, rowRun,
        Mark, samples
    }
    use Examples.MiniLang.{parseProgram => parseMini, runProgram, runSource => runMini}
    use Examples.CoLang.{parseProgram => parseCo, runSource => runCo}

    @Test
    def testAllSamplesAgree(): Unit \ Assert =
        Assert.assertTrue(allAgree())

    @Test
    def testSuiteNonEmpty(): Unit \ Assert =
        Assert.assertTrue(List.length(samples()) >= 10)

    @Test
    def testWhileSumAstEqual(): Unit \ Assert = {
        let src =
            "let i = 1; let s = 0; while i <= 5 do { let s = s + i; let i = i + 1; } print s;";
        match (parseMini(src), parseCo(src)) {
            case (Ok(a), Ok(b)) =>
                Assert.assertEq(expected = a, b)
            case other =>
                Assert.fail("parse: ${other}")
        }
    }

    @Test
    def testWhileSumRunEqual(): Unit \ Assert = {
        let src =
            "let i = 1; let s = 0; while i <= 5 do { let s = s + i; let i = i + 1; } print s;";
        match (runMini(src), runCo(src)) {
            case (Ok(Ok((_, oa))), Ok(Ok((_, ob)))) =>
                Assert.assertEq(expected = oa, ob);
                Assert.assertEq(expected = 15 :: Nil, oa)
            case other =>
                Assert.fail("${other}")
        }
    }

    @Test
    def testFailBothErr(): Unit \ Assert = {
        let r = compareOne("fail-let", "let = 1;");
        Assert.assertTrue(rowOk(r));
        Assert.assertEq(expected = Mark.Yes, rowAst(r));
        Assert.assertEq(expected = Mark.Skip, rowRun(r))
    }

    @Test
    def testCompareRowMarks(): Unit \ Assert = {
        let r = compareOne("precedence", "print 1 + 2 * 3;");
        Assert.assertTrue(rowOk(r));
        Assert.assertEq(expected = Mark.Yes, rowAst(r));
        Assert.assertEq(expected = Mark.Yes, rowRun(r))
    }

    @Test
    def testChunkedWhileMatchesMini(): Unit \ Assert = {
        let src =
            "let i = 1; let s = 0; while i <= 3 do { let s = s + i; let i = i + 1; } print s;";
        let chunks =
            "let i = 1; let s = 0; wh" ::
            "ile i <= 3 do { let s = s + i; let i = i + 1; } pr" ::
            "int s;" :: Nil;
        Assert.assertTrue(chunkAgrees(src, chunks))
    }

    @Test
    def testEveryRowOk(): Unit \ Assert =
        Assert.assertTrue(List.forAll(rowOk, compareAll()))

}
