# チュートリアル: miniparseのパーサーコンビネータ

「パーサーコンビネータとは何か」から、このパッケージにおけるParsecとPEGの違いまでを短く辿る。モジュール一覧や発展的な話題は[overview.md](../overview.md)ほかのガイドを参照。

**前提:** Flix 0.75.1+と`miniparse`への依存（ルートの[README](../../README.md)）、またはこのリポジトリをcloneして`flix test` / `flix run`（[CONTRIBUTING.md](../../CONTRIBUTING.md)）。

英語版: [tutorial.md](../tutorial.md)

---

## 1. 何を書いているか

**パーサー**はテキストを構造化された値（またはエラー）に変える。**パーサーコンビネータ**は小さなパーサーと、それらを組み合わせる演算子（`map`、`andThen`、`many`、choiceなど）である。文法を別ファイルの`.y` / `.peg`ではなく、普通のFlix関数として書く。

miniparseの核は次の形である。

```text
Parser[a]  ≈  State → Result[ParseError, (a, State)]
```

`State`は入力文字列とカーソル（offsetと行・列）を持つ。成功時は値と進んだ状態を返し、失敗時は何が期待されていたかと位置を返す。

```flix
use MiniParse.Core.{parse}
use MiniParse.Combinator.{digit, many, map, charsToString}

def digits(): MiniParse.Core.Parser[String] =
    map(charsToString, many(digit()))

// parse(digits(), "4242")  ==>  Ok("4242")
// parse(digits(), "x")     ==>  Err(... expected digit ...)
```

共通の部品は`MiniParse.Combinator`にある。何かが失敗したときの**choice**の振る舞いがフロントエンドモジュールの役割である。

---

## 2. 共有スタック

```text
  MiniParse.Parsec          MiniParse.PEG
         \                     /
          \                   /
           Combinator + Core
```

- **Core** — `Parser`、位置、`ParseError`、`parse` / `parsePartial`
- **Combinator** — `satisfy`、`string`、`many`、`sepBy`、`chainl1`、…
- **Parsec** / **PEG** — 選択肢と（PEGでは）述語についての**方針**だけ

多くの場合、ある文法には`Core` + `Combinator`に加えてParsecかPEGの**どちらか一方**を使う（意図的に両方を並べて比較してもよい）。

---

## 3. Parsecスタイル: 消費したらコミット

背景: [Parsec (parser)](https://en.wikipedia.org/wiki/Parsec_(parser)) — Haskellの古典的なコンビネータライブラリ。同じ設計は多くの言語に現れる。

miniparseでは:

```flix
use MiniParse.Parsec.{orElse, attempt}
```

**目安:** `orElse`の左枝が入力を**消費したあと**に失敗した場合、右枝は**試されない**。予測的で失敗位置に近いエラーを出しやすい一方、曖昧な接頭辞には`attempt`（Parsecの`try`）を自分で付ける必要がある。

古典的な落とし穴 — キーワードとより長い識別子:

```text
// 素朴: キーワード "if"、だめなら ident
// 入力: ifa
// 左枝が "if" にマッチし、消費をコミットしたあと余り "a" で失敗
// → "ifa" は妥当な名前なのに "ident" へ落ちない
```

Parsec側の直し方: キーワード（または消費する接頭辞）を`attempt`で包み、失敗時に巻き戻してから`ident`を試す。ラボ`Examples.Keyword`がnaive / Parsec / PEGを並べて見せる。

```flix
// スケッチのみ — 完全な文法は test/Examples/Keyword.flix
// orElse(attempt(keyword("if")), ident())
```

---

## 4. PEGスタイル: 順序付き選択が巻き戻す

背景: [Parsing expression grammar](https://en.wikipedia.org/wiki/Parsing_expression_grammar)（PEG）— 順序付き選択`e1 / e2`は`e1`を試し、失敗したら入力を**復元**して`e2`を試す。PEGには構文的述語`&e`（and）と`!e`（not）もある。

miniparseでは:

```flix
use MiniParse.PEG.{choice, andPredicate, notPredicate}
```

- `choice(p1, p2)` ≈ Parsecの`orElse(attempt(p1), p2)`（左への自動try）
- `notPredicate(p)`は`p`が失敗すれば消費せず成功（キーワード境界向き: `string("if")`のあと`!identChar`）

同じ`ifa`の例: PEGの順序付き選択は失敗した`if`キーワードから自然にバックトラックし、キーワード規則に境界（`if`のあとの`!`）があれば`ifa`を識別子として受理できる。

---

## 5. 学習目的での向き（目安）

| 目的 | 寄りどころ |
| --- | --- |
| **commitとtry**、LL(1)寄りの規律を理解する | **Parsec** + 自分で`attempt`を置く |
| 文法らしい順序付き選択と`&` / `!`を好む | **PEG** |
| **メモ化 / 左再帰**を学ぶ | 基礎のあとPackratラボ（`Examples.Packrat`、`LeftRec`） |
| チャンク入力 / サスペンドのコスト | [suspend.md](../suspend.md)、`Stream` / `Suspend` / `CostCompare` |

言語ごとに唯一の「正しい」スタイルはない。miniparseの価値は、**両方**がひとつの`Parser`型の上に載り、choice層だけ差し替えられることである。

---

## 6. 次に進む先

| 次 | Doc / lab |
| --- | --- |
| モジュール一覧とスニペット | [overview.md](../overview.md) |
| アーキテクチャとロードマップ | [design-doc.md](../design-doc.md) |
| キーワード / `if` vs `ifa` | `Examples.Keyword`、`flix run` |
| 小さな言語 | `Examples.MiniLang`（pure）、`Examples.CoLang`（CoParser） |
| 壊れた文のあとのsoft error | [recovery.md](../recovery.md) |
| ストリーミングとコルーチン型 | [suspend.md](../suspend.md) |

このリポジトリでは:

```bash
flix run    # ラボのツアー
flix test
```

よいパースを。
