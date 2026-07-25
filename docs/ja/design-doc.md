# flix-miniparse設計

[Flix](https://flix.dev/)向けの教育用パーサコンビネータライブラリ。

目的、アーキテクチャ、モジュール配置、実装ロードマップを記録する。

英語版: [design-doc.md](../design-doc.md)

## 1. 目的と位置づけ

| Aspect | Choice |
| --- | --- |
| **Goal** | ゼロから実装してパーサコンビネータの内部を学ぶ。 |
| **Focus** | [**Parsec**](https://ja.wikipedia.org/wiki/Parsec_(パーサー))スタイルの予測的構文解析（`try`による明示バックトラック）と[**PEG**](https://ja.wikipedia.org/wiki/Parsing_expression_grammar)スタイルの自動バックトラック（順序付き選択、述語、任意でpackratメモ化）を対比する。 |
| **Audience** | 教育 / DIY — プロダクションのパーサフレームワークではない。 |
| **Host language** | **Flix** — 代数的データ型、強い型システム、制御された局所可変のためのeffect / `Region`。 |

プロジェクトは実験室である: 共有コア、二つのフロントエンドAPI、検証ターゲットとしての小さな言語。

## 2. アーキテクチャ

**三層**設計: 一つのコアエンジン、共有コンビネータ、バックトラック方針の異なる二つのフロントエンドAPI。

```text
┌────────────────────────────────────────────────────────┐
│              Front-end API / DSL modules               │
│  ┌──────────────────────┐    ┌──────────────────────┐  │
│  │   MiniParse.Parsec   │    │    MiniParse.PEG     │  │
│  │ (predictive / try)   │    │ (auto-backtrack)     │  │
│  └──────────┬───────────┘    └──────────┬───────────┘  │
└─────────────┼───────────────────────────┼──────────────┘
              ▼                           ▼
┌────────────────────────────────────────────────────────┐
│         Core combinators (shared primitives)           │
│   map, flatMap, satisfy, sequence, rollback, …         │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│     Core engine (state, errors, memoization)           │
│   Position / rollback state / furthest-error tracker   │
└────────────────────────────────────────────────────────┘
```

### 2.1 コアエンジン（`MiniParse.Core`）

責務:

1. **位置とrollback** — 入力位置を追跡し、以前の状態を安全に復元（`rollback`）。
2. **最遠エラー追跡** — 失敗時、到達した**最も遠い**位置とそこで期待されたものを記録。PEG風自動バックトラック下の使えるエラーに特に重要。
3. **メモ化（packrat支援）** — PEG実行の結果をキャッシュ。Flixの**`Region`**と内部可変（`MutMap`）を外からpureに見えるインタフェースの裏に置く。

### 2.2 フロントエンドの振る舞いの差

| Module | Backtracking policy | Main combinators / features |
| --- | --- | --- |
| **`MiniParse.Parsec`** | **明示（LL(1)寄り）。** 入力消費後の失敗は自動では次の代替を試さない。 | 予測/決定的; `try(p)`による明示巻き戻し。 |
| **`MiniParse.PEG`** | **自動（暗黙）。** 失敗した代替は状態を戻して次枝を試す。 | 順序付き選択`choice`（`/`）、`andPredicate`（`&`）、`notPredicate`（`!`）、`memoize`。 |

## 3. モジュールとディレクトリ配置

```text
Main.flix             // flix run ツアー (fpkgに載せない)
src/
  MiniParse/
    Core.flix         // Parser型、位置、最遠エラー
    Combinator.flix   // map, flatMap, satisfy ほか共有
    Parsec.flix       // Parsec風API (try必須モデル)
    PEG.flix          // PEG風API (自動backtrackと述語)
test/
  Examples/           // ラボ / デモ (fpkgに載せない)
  ...                 // 単体・結合テスト
docs/
  design-doc.md       // 英語の本ドキュメント
  ja/                 // 日本語ガイド
```

### 3.1 コードスケッチ

説明用; 具体型は実装中に進化する。

```flix
mod MiniParse.Core {
    /// 入力状態上の関数としてのパーサ。
    pub enum Parser[a] // (State) -> Result[(a, State), ParseError]

    /// pが入力を消費したあと失敗したら位置を戻す。
    pub def rollback(p: Parser[a]): Parser[a] = ???
}

mod MiniParse.Parsec {
    /// 自動バックトラックのないchoice: p1が消費後に失敗したらp2へ落ちない。
    pub def orElse(p1: Parser[a], p2: Parser[a]): Parser[a] = ???

    /// 明示バックトラックラッパ。
    pub def try(p: Parser[a]): Parser[a] = MiniParse.Core.rollback(p)
}

mod MiniParse.PEG {
    /// 自動巻き戻しつき順序付き選択（PEG `/`）。
    pub def choice(p1: Parser[a], p2: Parser[a]): Parser[a] =
        MiniParse.Parsec.orElse(MiniParse.Parsec.try(p1), p2)

    /// 負のlookahead（`!p`）: pが失敗すれば消費せず成功。
    pub def notPredicate(p: Parser[a]): Parser[Unit] = ???
}
```

## 4. 実装ロードマップ

段階的に機能を入れ、具体ターゲットで検証する。

### Step 0 — スモーク（郵便番号）

| | |
| --- | --- |
| **Goal** | 基本: `char`、`digit`、`string`、`map`、`flatMap`、`satisfy`。 |
| **Target** | `〒150-0002`や`150-0002`形の文字列。 |
| **Why** | 線形、choice/backtrackなし。ParsecとPEG両方の共有経路。 |

### Step 1 — コンビネータ（JSON）

| | |
| --- | --- |
| **Goal** | 再帰、空白、エスケープ; Flix ADT（`JsonValue`）へ。 |
| **Target** | JSON部分集合/パーサ。 |
| **Why** | 多くはLL(1)寄り; 両モジュールできれいな文法を書ける。 |

### Step 2 — 思想比較（算術またはミニ言語）

| | |
| --- | --- |
| **Goal** | バックトラックとlookaheadを比較。 |
| **Targets** | 優先順位/結合（`1 + 2 * 3`）; 識別子 vs キーワード（`if` vs `ifa`）。 |
| **Checks** | Parsecでの`try`配置 vs PEGでの自動backtrackと`!`のストレス。 |

## 5. 実装状況

| Step | Status | Notes |
| --- | --- | --- |
| **0** | Done | Core + コンビネータ; 郵便番号スモーク |
| **1** | Done | Parsec/PEGフロント; 再帰JSON |
| **2** | Done | 算術優先順位; `if` / `ifa`の思想比較 |
| **3** | Done | Packrat（`MiniParse.Packrat` + `Examples.Packrat`）; `ErrorFormat` |
| **4** | Done | MiniLang: `let` / `print` / `if`–`then`–`else` / ブロック + インタプリタ |
| **5** | Done | 左再帰packrat成長（Warth）; 左右結合 |
| **6** | Done | ストリーミング入力: `StreamState`、`feed`/`close`、`step` → Done/Fail/Await |
| **7** | Done | 標準コンビネータ拡張（下記） |
| **8** | Done | コルーチンsuspend: `CoParser` free monad + `Await`継続 |
| **9** | Done | CoParser上のCoLang断片; Stream vs Suspendスキャンコスト |
| **10** | Done | MiniLang比較/`while`; `MiniParse.Bridge`（Parser ↔ CoParser） |
| **11** | Done | CoLangフルMiniLang文法; 共有AST/runtime; Bridgeデモ |
| **12** | Done | `Examples.LangCompare`: MiniLang vs CoLang parse/run一致表 |
| **13** | Done | `Suspend`コンビネータ拡張（sepBy、manyTill、lexeme/symbol、chainr1、…） |
| **14** | Done | `MiniParse.Recover` panic-mode; `ErrorFormat.formatErrors`; RecoverLab |
| **15** | Done | 学習ガイド（`docs/recovery.md`、`docs/suspend.md`）; パッケージ**0.3.0** |
| **16** | Done | `MiniParse.RecoverCo` + `CoRecoverLab`（CoParser panic-mode） |

任意の続き: joinなしのチャンク途中soft recovery; `CoParser`のalgebraic-handler移植（[suspend.md](suspend.md)）。

### クロスライブラリのマイクロベンチ

ネストしたパッケージ`bench/`（fpkgに載せない）がpure/`CoParser`のminiparseと兄弟`flix-parsec`を共有マイクロタスクで比べる。`bench/scripts/install-local-deps.sh`でローカルfpkgを入れ、`cd bench && flix run`。

### 利用者向けガイド

| Doc | Topic |
| --- | --- |
| [overview.md](overview.md) | モジュール地図とスニペット |
| [recovery.md](recovery.md) | panic-mode recoveryと診断 |
| [suspend.md](suspend.md) | Stream vs Suspend、free monad、Bridge |
| [tutorial.md](tutorial.md) | 初心者向けParsec/PEG |
| [README.md](README.md) | 日本語docs索引 |

## 6. パッケージ配置（利用者視点）

| Path | Role |
| --- | --- |
| `src/MiniParse/**` | **ライブラリ** — これらに依存（fpkgに載る） |
| `Main.flix` | `flix run`ツアー（リポジトリのみ; fpkg外） |
| `test/Examples/**` | ラボ/デモ — パターンはコピー可、API扱いしない（fpkg外） |
| `test/**` | 自動テスト |
| `docs/overview.md` | 短い消費者地図 |
| `docs/recovery.md` | panic-mode recoveryガイド |
| `docs/suspend.md` | CoParser / Streamガイド |
| `docs/design-doc.md` | 英語の設計史 |
| `docs/ja/**` | 日本語ガイド |
| `CHANGELOG.md` | リリースノート |
| `flix.toml` | パッケージ`miniparse` |
| `LICENSE.md` | fpkgに詰めるライセンス文 |

### suspend下の深いバックトラック

`orElse(p1, p2)` = `Choice(p1, p2)`。attemptインタプリタは不変バッファ上で`p1`を走らせ、失敗時は**元の**バッファで`p2`を再試行（深い巻き戻し）。`p1`がsuspendすると`Branch`フレームが`p2`と文字ログを保持し、後の失敗でも`p2`用に入力を再構築する（`committed ++ remaining`）。

### Suspensionメモ（Step 8）

| Layer | 短い入力 | Resume |
| --- | --- | --- |
| `MiniParse.Stream` | `Await` + カーソルからpure`Parser`を**再起動** | パーサ全体を再走 |
| `MiniParse.Suspend` | `Await(Suspended(k, pos))` | `k(Some(c))` — **同じ**スタック |

`CoParser`は`Read: Option[Char] -> CoParser[a]`上のfreeプログラム。driver`pump`がバッファに対し解釈し、バッファが空のとき破棄せず保留中の`Read`継続を格納する。

### 標準コンビネータ（Step 7追加）

| Group | Combinators |
| --- | --- |
| 文字 | `anyChar`、`oneOf`、`noneOf`、`hexDigit`、`endOfLine`、`takeWhile`/`takeWhile1` |
| Lookahead | `lookAhead`、`notFollowedBy` |
| Skip / value | `void`、`replace`、`option`、`skipMany`/`skipSome` |
| リスト | `manyTill`、`endBy`/`endBy1`、`sepEndBy`/`sepEndBy1`、`many1` |
| 畳み込み | `chainr1`（既存`chainl1`と） |
| その他 | `filter` |

### Streamingメモ（Step 6）

- pure`Parser`は不変; streamingはアダプタ層。
- **開いた**バッファ末尾での失敗は`Await`（データ不足）。
- `close`後の同じ状況はhard EOF`Fail`。
- 各`step`は保存カーソルからpureパーサを再起動（呼び出しスタックのsuspendではない）。
