# サスペンド可能なパーサ（`CoParser`）

**コルーチン風**解析がpure`Parser`の隣でどう位置づくか、いつ何を使うか。

関連コード:

| Piece | Role |
| --- | --- |
| [`MiniParse.Suspend`](../../src/MiniParse/Suspend.flix) | free`CoParser`、深い`orElse`、driver |
| [`MiniParse.Stream`](../../src/MiniParse/Stream.flix) | pureパーサ上のrestart型チャンク |
| [`MiniParse.Bridge`](../../src/MiniParse/Bridge.flix) | 二スタック間の埋め込み |
| [`Examples.CostCompare`](../../test/Examples/CostCompare.flix) | スキャンコストラボ（restart vs continue） |

英語版: [suspend.md](../suspend.md)

---

## 入力を待つ二つのやり方

| Layer | 短い入力のとき | Resume |
| --- | --- | --- |
| **Stream** | `Await` + カーソルからpureパーサを**再開（全体再実行）** | バッファ上で`Parser`全体を再走 |
| **Suspend** | `Await(Suspended(k, pos))` | 保存した**継続**（`Read` / `Peek`）を呼ぶ |

Streamはアダプタ: pureコンビネータはpureのまま。Suspendは文字読み取り上の**freeプログラム**として解析を再化し、driverがトークン途中で止められる。

長さ`n`の1文字チャンクでは、CostCompareはおおよそ次を示す。

- Streamの`charVisits` ≈ \(n(n+1)/2\)（三角再スキャン）
- Suspendの`charVisits` ≈ \(n`（各文字をだいたい1回消費）

---

## freeプログラムの形

```text
CoParser[a]
  Pure / Fail
  Read   (Option[Char] -> CoParser[a])    // 消費またはEOF
  Peek   (Option[Char] -> CoParser[a])    // 非消費
  Choice / Branch                         // 深いorElse + choiceをまたぐsuspend
  (+ 再帰文法用にPeek経由のdelay)
```

解釈は不変バッファスナップショットを使うので、**失敗した代替は巻き戻せる**（suspendのあとも）— それが「深い`orElse`」。

意図的に**ADT free monad**であり、Flixのalgebraic effect / handlerではない。このプロジェクトに合う理由:

1. **移植しやすい教材モデル** — 他言語のfreeパーサと同じ発想; 読むのにeffect行が要らない。
2. **明示的driver** — `pump` / `feed` / `close`が型上でAwaitを見える（`Outcome`）。
3. **深いバックトラック** — choiceフレーム（`Branch`）が消費ログを保持; ユーザーランドhandlerでも書けるが、ラボ用ライブラリには重い。

将来の「handlerスタイル」移植は`Read`/`Fail`/`Choice`を演算に写し、コルーチン風handlerで扱う; コンビネータの**API面**は似せられる。その実験は任意であり、今日Suspendを使う必須条件ではない。

---

## コンビネータ

Suspendはpure`Combinator`の大半を写す: リスト（`many`、`sepBy`、`manyTill`、…）、畳み込み（`chainl1`、`chainr1`）、語彙（`ws`、`lexeme`、`symbol`、`between`）、文字クラス。

文字級lookahead:

| API | Role |
| --- | --- |
| `peek` | 次文字またはEOF、非消費 |
| `notFollowedByPred` | 文字述語の負のlookahead |
| `keyword` / `ident` | 境界付き語トークン（`if` vs `ifa`） |

**パーサ級**の`lookAhead` / `notFollowedBy`（任意の部分`CoParser`）は、pure`Combinator`と同じ形ではSuspendの公開面に**載せない**。free ADTでの一般lookahead bindはexistentialか型消去（`unchecked_cast`）を要し、依存側を`security = "unrestricted"`へ押しやすい。次を好む。

- キーワード/演算子には文字級`Peek` / `notFollowedByPred`
- 入力全体がすでにバッファ済みなら`Bridge.toParser` / `parseCo`とpureの`Combinator.lookAhead`

---

## Bridge

```flix
// CoParserをpure Parserに（残り全文、eof確定）
MiniParse.Bridge.toParser(co)
MiniParse.Bridge.parseCo(co, input)

// pureパーサをCoParser下で全文字バッファしてから実行
MiniParse.Bridge.fromParser(pureParser)
MiniParse.Bridge.pureViaCo(pureParser, input)
```

SuspendをParsec/PEGスタックと合成するとき、またはpure文法をCo形driverで走らせるときにBridgeを使う。

---

## Recovery

- Pureリスト: `MiniParse.Recover`（`manySkipping`）。
- CoParserリスト: `MiniParse.RecoverCo`（全文 / joinしたチャンクでの`runProgramSkipping`）。

[recovery.md](recovery.md)を参照。

---

## 学習パス

1. pure`Combinator`と`Core.parse`で文字列を解析する。
2. 同じ文法を`Stream.parseChunks`に細かいチャンクで渡す — restartを見る。
3. 小さな文法を`CoParser`で組み直す（`SuspendDemo`、`CoLang`）— トークン途中の`Await`を見る。
4. 量的対比に`CostCompare`を走らせる。
5. suspend下の深いバックトラックのため`Suspend.flix`の`attempt` / `Choice` / `Branch`を読む。
