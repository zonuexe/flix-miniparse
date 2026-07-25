# パーサのデバッグ

monad transformer スタック（`WriterT` や `StateT` など）を使わずに、miniparse でパースの振る舞いを調べる方法です。

ラボ: [`Examples.DebugLab`](../../test/Examples/DebugLab.flix)。API: [`MiniParse.Debug`](../../src/MiniParse/Debug.flix)。

## なぜ Parsec 上の `WriterT` ではないか

純 `Parser[a]` は次の固定形です。

```text
State → Result[ParseError, (a, State)]
```

この型の内側に Writer や IO を「積む」スロットはありません。Core / Parsec / PEG / Recover を単純で純に保つための選択です。デバッグは、その上に載せる**小さな純ツール**で行います。

## 日常: expected ラベルを良くする

「どこで落ちたか」の多くは、**規則に名前を付けて** `ErrorFormat` を読むだけで足ります。

| ヘルパ | 役割 |
| --- | --- |
| `label(name, p)` | Parsec の `<?>` — 失敗時の expected を `name` に差し替え |
| `inContext(ctx, p)` | 各 expected に `ctx: …` を前置 |
| `getPos()` | 入力を消費せず現在の `Position` |

```flix
use MiniParse.Debug.{label, inContext}
use MiniParse.Combinator.{digit, many1, map}

def number(): Parser[Int32] =
    label("number", map(digitsToInt, many1(digit())))

def sum(): Parser[Int32] =
    inContext("sum", /* number (+ number)* */)
```

`"12+x"` の失敗では、単に `digit` と出るより `number`（または `sum: number`）の方が追いやすいです。

Debug なしでも使えるもの:

- `parsePartial` — カーソルがどこまで進んだか
- `ErrorFormat.formatError` — 行・列とキャレット
- `Recover` の複数 soft エラー — resync 後の失敗点

## 手順トレイル: `TParser` + `span`

**どの規則が走ったか**（失敗した選択肢も含む）が欲しいときは、常にログを返す並行なパーサ型を使います。

```text
TParser[a]  ≈  State → (List[TraceEvent], Result[ParseError, (a, State)])
```

これは `Parser` の下に載せる transformer ではなく、**戻り値としての Writer 風ログ**です。

| API | 役割 |
| --- | --- |
| `lift(p)` | 通常の `Parser` を埋め込み（イベントなし） |
| `span(name, p)` | `p` の前後に enter / ok / fail（子イベントはその間） |
| `spanP(name, p)` | `span(name, lift(p))` |
| `parseTraced` / `parsePartialTraced` | 実行して `(events, result)` |
| `orElse` / `choice` | PEG 風バックトラック。**失敗した左枝もログに残る** |
| `formatTrace` / `formatTraced` | 人間向けダンプ |
| `failedSpans` | `Fail` を記録した span 名 |

本番文法をすべて `TParser` に書き直す必要はありません。疑わしい断片だけ、またはデバッグ中だけ主要非終端に `span` を付けます。

## 使い分け

| 目的 | 向くもの |
| --- | --- |
| 利用者向けの分かりやすいエラー | `label` / `inContext` |
| 「この選択肢は試されたか」 | `TParser` + `span` + `orElse` |
| カーソル / 残り入力 | `parsePartial` + `getPos` |
| soft 複数エラー | `Recover` |
| ストリームの feed 点 | `Stream.drive` のイベント |

## 設計メモ

- `TParser.orElse` は常にバックトラックし、失敗した選択肢をトレースに残します（デバッグ向け。Parsec の commit 意味とは同一ではありません）。
- Core の `Parser` は純で effect なし。ライブラリ型の中に `println` は入れません。
- 将来 CoParser に `Log` コンストラクタを足す余地はありますが、純 `TParser` でよくあるラボ用途は足ります。

## 関連

- [tutorial.md](tutorial.md) — combinator と choice 方針
- [recovery.md](recovery.md) — panic-mode の複数エラー
- [suspend.md](suspend.md) — free な `CoParser`（「effect をデータにする」発想の近縁）
