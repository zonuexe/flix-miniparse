# 日本語ドキュメント

## 表記スタイル

- **行をハード折り返ししない**（GitHubのソフトラップに任せる）。
- **和欧文のあいだにスペースを入れない**（例: `Fooとbar`、`` `attempt`で``、`miniparseの`）。

## 文書一覧

| 文書 | 内容 |
| --- | --- |
| [tutorial.md](tutorial.md) | コンビネータ入門、ParsecとPEG（[パーサコンビネータ](https://ja.wikipedia.org/wiki/パーサコンビネータ)、[Parsec](https://ja.wikipedia.org/wiki/Parsec_(パーサー))、[PEG](https://ja.wikipedia.org/wiki/Parsing_expression_grammar)） |
| [overview.md](overview.md) | モジュール地図、スニペット、ラボ表 |
| [recovery.md](recovery.md) | panic-mode recovery、soft error、sync |
| [suspend.md](suspend.md) | CoParser vs Stream、free monad、Bridge |
| [design-doc.md](design-doc.md) | アーキテクチャとロードマップ |

英語の索引・ガイド: [../README.md](../README.md)

## 読み順の提案

1. ルート[README](../../README.md) — 依存とモジュール表
2. **tutorial** — 最初の手を動かす道
3. **overview** — 全体地図
4. **recovery** — `stmt`リストのあと
5. **suspend** — Stream / CoLangのとき
6. **design-doc** — なぜ層が分かれているか
7. [CONTRIBUTING](../../CONTRIBUTING.md) — このリポジトリをhackするときだけ
