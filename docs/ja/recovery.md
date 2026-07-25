# エラー回復と診断

**miniparse**が、panic-mode recovery中に集める**soft**エラーと、hardな解析失敗をどう分けるか、言語風文法での使い方。

関連コード:

| Piece | Role |
| --- | --- |
| [`MiniParse.Recover`](../../src/MiniParse/Recover.flix) | Pure: `WithErrors`、`resync`、`manySkipping`、`recover` |
| [`MiniParse.RecoverCo`](../../src/MiniParse/RecoverCo.flix) | CoParser: `runProgramSkipping`、Coの`resync` |
| [`MiniParse.ErrorFormat`](../../src/MiniParse/ErrorFormat.flix) | `formatError`、`formatErrors`、`formatWithErrors` |
| [`Examples.RecoverLab`](../../test/Examples/RecoverLab.flix) | 厳格 vs 回復可能なMiniLang（pure） |
| [`Examples.CoRecoverLab`](../../test/Examples/CoRecoverLab.flix) | CoLang / RecoverCoでの同様 |

ラボは`flix run`（**Recover**節）または`flix test`（`TestRecover`）。英語版: [recovery.md](../recovery.md)

---

## なぜrecoveryがあるか

厳格な`parse(program, input)`は**最初の**壊れた文で失敗し、ファイルの残りを捨てる。fail-fastなCIなど多くのツールには正しいが、**対話**や**バッチ**のフィードバックには向かない。利用者は壊れた文をすべて知りたいし、後段のためにASTをできるだけ残したい。

panic-mode recoveryは古典的なコンパイラ技法である。

1. 次の項目（文、宣言、…）を解析する。
2. 失敗したらエラーを**記録**し、同期トークン（しばしば`;`や`}`）まで**飛ばして**続ける。
3. 部分結果とsoft errorのリストを返す。

miniparseはそれを普通のpure`Parser`の**上のレイヤ**として実装する。Parsec/PEGのchoice規則は変えない。

---

## hardとsoft

| Kind | Type / path | Meaning |
| --- | --- | --- |
| **Hard** | `Result.Err(ParseError)` | 使えるトップレベル値を作れない（例: recovery後の残り入力、非回復`parse`） |
| **Soft** | `WithErrors(_, List[ParseError])`の中 | 項目が失敗; 入力は再同期済み; 他項目は残っているかもしれない |

```flix
use MiniParse.Recover.{WithErrors, valueOf, errorsOf, isClean, parseWithErrors}

// Ok(WithErrors(stmts, errs))  — トップレベル成功; errsは空でないかも
// Err(e)                       — hard失敗
```

`parseWithErrors`も**入力全体**の消費を要求する（`Core.parse`と同じ）。回復リストのあとに残ったテキストは、残り位置でのhardな`end of input`である。

---

## 中核API

### `WithErrors`

```flix
enum WithErrors[a] {
    case WithErrors(a, List[ParseError])
}

valueOf : WithErrors[a] -> a
errorsOf : WithErrors[a] -> List[ParseError]
isClean  : WithErrors[a] -> Bool          // errorsOf is Nil
clean    : a -> WithErrors[a]             // soft errorなし
mapValue : (a -> b) -> WithErrors[a] -> WithErrors[b]
```

soft errorはrecoveryが遭遇した順（複雑なsyncのあとはソース順と一致しないこともある）。

### Syncヘルパ

| Function | Behavior |
| --- | --- |
| `skipUntilOneOf(chars)` | 次文字が`chars`に含まれないあいだスキップ; sync文字またはEOFの**手前**で止まる |
| `skipPastOneOf(chars)` | `chars`の**最初の1文字を含む**ところまで、またはEOFまで |
| `skipOne()` | 可能なら1文字進む |
| `resync(chars)` | `skipPastOneOf`だが、進まなければ少なくとも1文字強制 |

実装メモ: syncは入力上の**offset走査**（`many(satisfy…)`ではない）。進捗が明確で、「消費してから失敗」系の文字テストの端を避けやすい。

### 単一項目

```flix
// 成功: clean(value)
// 失敗: attempt開始からsyncし、fallbackを返し、soft errorを1つ記録
recover(p, sync, fallback): Parser[WithErrors[a]]

// 同様だが失敗時はNone（ダミーASTなし）
recoverSkip(p, sync): Parser[WithErrors[Option[a]]]
```

### 列（よく使う入口）

```flix
// 0個以上; 失敗項目はリストから省略（soft errorのみ）
manySkipping(item, sync): Parser[WithErrors[List[a]]]

// ws *> manySkipping(item, sync) <* ws
programSkipping(item, sync): Parser[WithErrors[List[a]]]
```

各attemptの前に`manySkipping`は`ws()`を走らせる。recoveryが改行上に着地しても空白を「失敗した文」とみなして次の実文を飛ばさないためである。

---

## syncトークンの選び方

panic-modeの品質は**同期集合**次第である。

| Grammar shape | Typical sync | Risk if wrong |
| --- | --- | --- |
| 文リスト（`stmt;`） | `";"`または`";}"` | `;`だけだと文字列/コメント内で止まることがある |
| ブロック向き | `"}"` | 次のブレースまで多くの文を飛ばす |
| 行向き | `"\n"` | Windowsの`\r\n` — `\n`を含む走査がよい |

**MiniLangラボ**は`resync(";}")`: 文終端またはブロック終端。文字列リテラルがないのでコード中の`;`は一意。

指針:

1. 正しいプログラムでは項目境界に**必ず**出るトークンを好む。
2. 失敗後の**進捗**を保証する（`resync`はスキップが進まなければ1文字強制）。
3. recoveryが壊れた項目のあと**良いテキストを飛ばす**ことを受け入れる（ASTの偽陰性）— panic-modeのトレードオフである。
4. 壊れた構文を完璧な木に「直す」ことは期待しない。**継続と診断**のためである。

---

## recoveryの開始位置

失敗時、syncは**失敗したattemptの先頭**（`manySkipping`では先頭の`ws`のあと）から走る。「最遠エラー」ラベルだけからではない。

理由: PEG風の`attempt` / `try`は、choiceが次の代替を試せるようエラー位置をattempt先頭へ**書き換える**ことが多い。最遠位置は**メッセージ**には有用だが、スキップ原点にするとラベルと実消費が食い違うとき1文字ずつ進むことがある。

soft失敗時の`ParseError`は項目パーサが返したもの（期待のマージなど）のままなので、`formatError`は情報を保つ。

---

## 動かし方の例（MiniLang）

ソース:

```text
let x = 1;
let = 2;
print x;
```

| Mode | Result |
| --- | --- |
| **Strict**（`Examples.MiniLang.parseProgram`） | `Err` — しばしば残り入力 / 2つ目の`let`付近 |
| **Resilient**（`Examples.RecoverLab.parseResilient`） | `Ok`、stmts`[Let(x,1), Print(x)]`、壊れた`let`に**1** soft error |
| **回復後の実行** | 残した文だけインタプリタ → `1`をprint |

回復付きプログラムパーサのスケッチ:

```flix
use MiniParse.Recover.{programSkipping, resync, parseWithErrors}
use Examples.MiniLang.{stmt}

def programRecovering() =
    programSkipping(stmt(), resync(";}"))

def parseResilient(input: String) =
    parseWithErrors(programRecovering(), input)
```

報告（ラボヘルパ）:

```flix
// 厳格失敗
formatError(input, hardErr)

// 回復後のsoftリスト
formatErrors(input, errorsOf(w))
// または
formatWithErrors(input, w)
```

---

## 診断の整形

| Helper | Use when |
| --- | --- |
| `formatError(input, e)` | hard/softどちらでも単一エラー（行、列、キャレット、期待） |
| `formatErrors(input, es)` | soft errorの番号付きリスト |
| `formatWithErrors(input, w)` | `"ok (clean)"`または`"ok with N soft error(s):"` + リスト |
| `formatNeedInput` / stream / suspend | 不完全なチャンク入力（recoveryではない） |

softとhardは同じ`ParseError`形（`Position` + 期待ラベル）。recoveryは第二のエラー型を導入しない。

---

## CoParser recovery（`MiniParse.RecoverCo`）

pure`Recover`と同じpanic-mode**方針**を、`runCoPartial`（現在の残りに対しeof確定 — Bridgeの`toParser`と同様）で`CoParser`項目に駆動する。

| Piece | Role |
| --- | --- |
| [`MiniParse.RecoverCo`](../../src/MiniParse/RecoverCo.flix) | Co sync + `runProgramSkipping` |
| [`Examples.CoRecoverLab`](../../test/Examples/CoRecoverLab.flix) | CoLang + pure vs Coの報告 |

```flix
use MiniParse.RecoverCo.{resync, runProgramSkipping}
use Examples.CoLang.{stmt}

runProgramSkipping(stmt(), resync(";}"), source)
// RecoverLabと同じサンプル → 同じ残し文 / soft数
```

| API | Notes |
| --- | --- |
| `skipPastOneOf` / `resync` | `CoParser`のsync（コンビネータ。offset走査ではない） |
| `runManySkipping` / `runProgramSkipping` | 全文; 末尾`ws` + EOF必須 |
| `runProgramSkippingChunks` | チャンクを**結合してから**recover（チャンク途中のsoft-failではない） |
| `runRecover` | 全文上の単一項目 + fallback |

**なぜfreeの`manySkipping`ノードではなくdriverか？** soft errorの蓄積はattempt/resync結果のループである。freeコンストラクタに載せることもできるが重い。driverはpure`Recover`の`mkParser`ループに揃え、読みやすい。

**チャンク:** joinなしの真のsoft recovery（`Await`境界をまたぐsync）は将来課題。joinは「ファイルを成す断片のリストがある」場合には正直である。

同じMiniLang形サンプルでのpure vs Co:

```flix
Examples.CoRecoverLab.report(Examples.RecoverLab.sampleBroken())
// pure Recover:  Ok (2 stmt(s), 1 soft)
// Co RecoverCo:  Ok (2 stmt(s), 1 soft)
```

---

## recoveryが**しない**こと

- **Stream restart層**: `MiniParse.Stream`向けpanic-modeアダプタはまだない。
- **joinなしのチャンク途中soft recovery**（RecoverCoは先にjoinする）。
- トークンの**自動挿入/削除**（編集距離修復）。
- **意味論的**recovery（型エラー、未束縛名）— インタプリタ側（`RuntimeError`）。
- ParsecのcommitやPEGの順序付き選択を**変える**こと; 完成した項目パーサを包む。`orElse`を置き換えない。

---

## 実務チェックリスト

1. 良い入力で動く厳格な項目パーサ（`stmt`）を書く。
2. 具象構文で項目を区切るsync文字を選ぶ。
3. リストに`programSkipping(item, resync(syncChars))`または`manySkipping`を使う。
4. softは`formatErrors`で出し、回復不能はhard`Err`のままにする。
5. 安全なときだけ`valueOf(w)`を後段に渡す（部分AST）。
6. **残った隣接文**と**soft error数の両方**をアサートするテストを書く（`TestRecover`参照）。

---

## 学習パス

1. MiniLangプログラムを厳格に失敗させ、`formatError`を読む。
2. 同じ文字列を`RecoverLab.report`に通し、softとhardを比べる。
3. syncを`";}"`から`";"`だけに変え、recoveryの形の変化を見る。
4. `Recover.flix`の`manySkipping`を読む（ws → try item → resync → loop）。

下層のpureエンジンの設計は[design-doc.md](design-doc.md)と[overview.md](overview.md)。
