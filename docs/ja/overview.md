# miniparse概要

**ライブラリ**（`MiniParse.*`）と**ラボ**（`Examples.*`）の短い地図。

リポジトリ: [zonuexe/flix-miniparse](https://github.com/zonuexe/flix-miniparse)
パッケージ名（`flix.toml`）: `miniparse`
ライセンス: Apache-2.0

英語版: [overview.md](../overview.md)

## これは何か

[Flix](https://flix.dev/)向けの、教育用パーサコンビネータ実装である。

- [Parsec](https://ja.wikipedia.org/wiki/Parsec_(パーサー))スタイルの予測的構文解析と、[PEG](https://ja.wikipedia.org/wiki/Parsing_expression_grammar)スタイルの自動バックトラックの**違い**を学ぶ
- **packrat**メモ化、**streaming**、**coroutine suspension**を別レイヤとして見る
- 小さな文法を端から端まで動かす（JSON、算術、小さな言語）

産業用パーサ生成器の置き換えを目指したプロダクション向け製品ではない。

コンビネータが初めてなら[**tutorial.md**](tutorial.md)（ParsecとPEGの例つき）から。

## ライブラリモジュール

```text
MiniParse
├── Core          Parser[a], State, Position, ParseError
├── Combinator    map, flatMap, satisfy, many, sepBy, chainl1, …
├── Parsec        orElse (自動巻き戻しなし), attempt
├── PEG           choice, andPredicate, notPredicate
├── Packrat       Table / Cell / newTable (Region + MutMap)
├── ErrorFormat   formatError / formatErrors (行 + キャレット)
├── Debug         label / inContext; TParser + span（transformerなしトレース）
├── Recover       panic-mode manySkipping (pure Parser)
├── RecoverCo     同方針のCoParser (runProgramSkipping)
├── Stream        feed / close / step → Done | Fail | Await  (restart)
├── Suspend       CoParser free monad, deep orElse, Peek/keyword, 共有コンビネータ
└── Bridge        CoParser ↔ pure Parser の埋め込み
```

`Suspend`は`Combinator`の大半を写す（リスト、畳み込み、語彙ヘルパ、文字クラス）。文字級lookaheadは`Peek` / `notFollowedByPred` / `keyword`。詳細は[suspend.md](suspend.md)。

### Recovery（panic-mode）

```flix
use MiniParse.Recover.{programSkipping, resync, parseWithErrors, valueOf, errorsOf}
use MiniParse.ErrorFormat.{formatErrors}

// programSkipping(stmt(), resync(";}"))
// parseWithErrors(p, src)  ==>  Ok(WithErrors(items, softErrs)) | Err(hard)
```

soft errorは`formatErrors` / `formatWithErrors`で整形する。ガイド: [recovery.md](recovery.md)。ラボ: `Examples.RecoverLab`。

### Debug（ラベルと任意の規則トレイル）

```flix
use MiniParse.Debug.{label, inContext, spanP, parseTraced, formatTrace}

// 日常: pure Parserに規則名（Parsecの<?>に近い）
label("number", many1(digit()))

// 失敗後も残る手順トレイル: TParser + span
let (ev, r) = parseTraced(spanP("digit", digit()), "x");
// formatTrace(ev)
```

ガイド: [debug.md](debug.md)。ラボ: `Examples.DebugLab`。

### Bridge

```flix
use MiniParse.Bridge.{toParser, fromParser, parseCo, pureViaCo}
use MiniParse.Suspend.{string, orElse}
use MiniParse.Core.{parse}
use MiniParse.Combinator.{digit}

// Co → pure (Parsec/PEGコンビネータと合成)
parse(toParser(orElse(string("ab"), string("ac"))), "ac")

// pure → Co (EOFまでバッファしてからpureパーサを実行)
pureViaCo(digit(), "7")
```

### 典型的なpureパイプライン

```flix
use MiniParse.Core.{parse}
use MiniParse.Combinator.{char, many, map}
use MiniParse.Parsec.{orElse}

def digits(): MiniParse.Core.Parser[String] =
    map(MiniParse.Combinator.charsToString, many(MiniParse.Combinator.digit()))

// parse(digits(), "12345")
```

### Streaming（restartスタイル）

```flix
use MiniParse.Stream.{open, feed, close, step, parseChunks}
// parseChunks(parser, "ab" :: "c" :: Nil)
```

### Suspendable（continuationスタイル）

```flix
use MiniParse.Suspend.{string, orElse, parseChunks, keyword, ident}
// orElse(keyword("if"), ident)  — 失敗時の深い巻き戻し
```

## ラボ（`Examples.*`）

| Module | Topic |
| --- | --- |
| `PostalCode` | 線形のCoreスモークテスト |
| `Json` | 再帰、空白、エスケープ |
| `Expr` / `Keyword` | 優先順位; Parsecの`attempt` vs PEGの`!` |
| `Packrat` / `LeftRec` | 指数 vs メモ; Warth成長 |
| `MiniLang` | pureパーサ上の`let` / `print` / `if` |
| `StreamDemo` / `SuspendDemo` | チャンク郵便番号 / JSON; CoParser郵便番号 |
| `CoLang` | `CoParser`上のフルMiniLang（共有AST; チャンク + Bridge） |
| `LangCompare` | MiniLangとCoLangのAST/run一致表 |
| `RecoverLab` | 厳格 vs 回復可能なMiniLang（pure Recover） |
| `CoRecoverLab` | CoLang / RecoverCoでの同様の実験 |
| `DebugLab` | 小さなsum文法での`label` / `TParser` spanトレイル |
| `CostCompare` | charVisits: Stream ~ n²/2 vs Suspend ~ n |

すべては`flix run`で（ルート`Main.flix`; ラボは`test/Examples/`）。

## 設計の深さ

| Doc | Topic |
| --- | --- |
| [design-doc.md](design-doc.md) | アーキテクチャ、ロードマップ、パッケージ配置 |
| [recovery.md](recovery.md) | panic-mode recoveryと複数エラー診断 |
| [suspend.md](suspend.md) | CoParser vs Stream、free monad、Bridge |
| [README.md](README.md) | 日本語docsの索引 |

## 比較ベンチ（任意）

ネストしたプロジェクト[`bench/`](../../bench/)が兄弟の[flix-parsec](https://github.com/stephentetley/flix-parsec)との壁時計マイクロタスクを測る。公開fpkgには含まれない。[bench/README.md](../../bench/README.md)を参照。

## バージョニング

このパッケージは教育用である。`0.y.z`系は長い非推奨サイクルなしにモジュール配置やAPIを変えることがある。依存するときはgitコミットまたはタグをピン留めすること。
