mod TestDebug {

    use MiniParse.Core.{parse, parsePartial, stateOffset, Position, parseErrorExpected}
    use MiniParse.Combinator.{char, digit, string, many, andThen}
    use MiniParse.Parsec.{attempt}
    use MiniParse.Debug.{
        getPos, label, inContext,
        TraceEvent, span, spanP, lift, pure, flatMap, orElse, choice,
        parseTraced, parsePartialTraced, formatTrace, failedSpans, tlabel
    }

    ///////////////////////////////////////////////////////////////////////////
    // Lightweight Parser helpers
    ///////////////////////////////////////////////////////////////////////////

    @Test
    def testGetPos(): Unit \ Assert = {
        let p = andThen(char('a'), getPos());
        match parsePartial(p, "ab") {
            case Ok((pos, s)) => {
                Assert.assertEq(expected = 1, stateOffset(s));
                Assert.assertEq(expected = Position.Position(1, 1, 2), pos)
            }
            case Err(_) => Assert.fail("expected Ok")
        }
    }

    @Test
    def testLabelRewritesExpected(): Unit \ Assert = {
        let p = label("keyword if", string("if"));
        match parse(p, "id") {
            case Err(e) =>
                Assert.assertEq(expected = "keyword if" :: Nil, parseErrorExpected(e))
            case Ok(_) => Assert.fail("expected Err")
        }
    }

    @Test
    def testInContextPrefixes(): Unit \ Assert = {
        let p = inContext("expr", digit());
        match parse(p, "x") {
            case Err(e) =>
                Assert.assertEq(
                    expected = "expr: digit" :: Nil,
                    parseErrorExpected(e)
                )
            case Ok(_) => Assert.fail("expected Err")
        }
    }

    @Test
    def testLabelWithChoice(): Unit \ Assert = {
        let p = MiniParse.Parsec.orElse(
            attempt(label("add", andThen(digit(), char('+')))),
            label("num", digit())
        );
        match parse(p, "x") {
            case Err(e) => {
                let exp = parseErrorExpected(e);
                Assert.assertTrue(List.memberOf("add", exp) or List.memberOf("num", exp))
            }
            case Ok(_) => Assert.fail("expected Err")
        }
    }

    ///////////////////////////////////////////////////////////////////////////
    // TParser / span
    ///////////////////////////////////////////////////////////////////////////

    @Test
    def testSpanSuccessTrace(): Unit \ Assert = {
        let p = span("digit", lift(digit()));
        match parseTraced(p, "7") {
            case (ev, Ok('7')) => {
                Assert.assertEq(expected = 2, List.length(ev));
                Assert.assertTrue(match List.head(ev) {
                    case Some(TraceEvent.Enter("digit", _)) => true
                    case _ => false
                });
                Assert.assertTrue(match List.nth(List.length(ev) - 1, ev) {
                    case Some(TraceEvent.Ok("digit", _)) => true
                    case _ => false
                })
            }
            case (_, _) => Assert.fail("expected Ok with trace")
        }
    }

    @Test
    def testSpanFailureKeepsTrace(): Unit \ Assert = {
        let p = span("digit", lift(digit()));
        match parseTraced(p, "x") {
            case (ev, Err(_)) => {
                Assert.assertEq(expected = "digit" :: Nil, failedSpans(ev));
                Assert.assertTrue(List.length(ev) >= 2)
            }
            case (_, Ok(_)) => Assert.fail("expected Err")
        }
    }

    @Test
    def testNestedSpanAndFlatMap(): Unit \ Assert = {
        let ab = flatMap(_ ->
            span("b", lift(char('b'))),
            span("a", lift(char('a')))
        );
        let p = span("ab", ab);
        match parseTraced(p, "ab") {
            case (ev, Ok(_)) => {
                Assert.assertEq(expected = 6, List.length(ev));
                Assert.assertEq(expected = Nil, failedSpans(ev))
            }
            case (_, _) => Assert.fail("expected Ok")
        }
    }

    @Test
    def testOrElseKeepsFailedAlternative(): Unit \ Assert = {
        let p = orElse(
            span("plus", lift(char('+'))),
            span("digit", lift(digit()))
        );
        match parseTraced(p, "9") {
            case (ev, Ok('9')) => {
                Assert.assertTrue(List.memberOf("plus", failedSpans(ev)));
                Assert.assertTrue(match List.find(e -> match e {
                    case TraceEvent.Ok("digit", _) => true
                    case _ => false
                }, ev) {
                    case Some(_) => true
                    case None => false
                })
            }
            case (_, _) => Assert.fail("expected Ok")
        }
    }

    @Test
    def testChoiceSecondWins(): Unit \ Assert = {
        let p = choice(
            spanP("A", char('a')) ::
            spanP("B", char('b')) ::
            Nil
        );
        match parseTraced(p, "b") {
            case (ev, Ok('b')) =>
                Assert.assertEq(expected = "A" :: Nil, failedSpans(ev))
            case (_, _) => Assert.fail("expected Ok")
        }
    }

    @Test
    def testTlabel(): Unit \ Assert = {
        let p = tlabel("number", spanP("digit", digit()));
        match parseTraced(p, "z") {
            case (_, Err(e)) =>
                Assert.assertEq(
                    expected = "number" :: Nil,
                    parseErrorExpected(e)
                )
            case (_, Ok(_)) => Assert.fail("expected Err")
        }
    }

    @Test
    def testFormatTraceNonEmpty(): Unit \ Assert = {
        let p = spanP("x", char('x'));
        match parseTraced(p, "x") {
            case (ev, Ok(_)) =>
                Assert.assertTrue(String.length(formatTrace(ev)) > 0)
            case (_, _) => Assert.fail("expected Ok")
        }
    }

    @Test
    def testParsePartialTraced(): Unit \ Assert = {
        let p = spanP("a", char('a'));
        match parsePartialTraced(p, "ab") {
            case (ev, Ok(('a', s))) => {
                Assert.assertEq(expected = 1, stateOffset(s));
                Assert.assertEq(expected = Nil, failedSpans(ev))
            }
            case (_, _) => Assert.fail("expected Ok")
        }
    }

    @Test
    def testDebugLabOk(): Unit \ Assert =
        match Examples.DebugLab.parseSumLabeled("12+3") {
            case Ok(15) => ()
            case other => Assert.fail("expected Ok(15), got ${other}")
        }

    @Test
    def testDebugLabTracedFailHasSpans(): Unit \ Assert = {
        let names = Examples.DebugLab.sampleFailFailedSpans();
        Assert.assertTrue(List.length(names) > 0)
    }

}
