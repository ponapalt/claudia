# 悪役令嬢クローディア

伺か（ukagaka）のゴーストです。SHIORI は YAYA。

- クローディア: 由緒正しきクロード公爵家の令嬢。高慢で口は悪いけれど、実はとても有能で面倒見がよい。
- アンソニー: クローディアに仕える青い執事。淡々とツッコむ。

作者: ponapalt&claudia

## ダウンロード

右横の Releases から nar ファイルをダウンロードして、SSP にドラッグ＆ドロップしてください。
このリポジトリを zip で取得しても動きますが、開発用のファイルが含まれています。

## クレジット

- テンプレートゴースト「紺野ややめ」（https://github.com/YAYA-shiori/konnoyayame ）をもとに作成しました。
- AI（Claude Code）の手を借りて作っています。

## 開発

このゴーストには、紺野ややめ由来の AI エージェント向け開発キットが入っています。

- [GHOST.md](GHOST.md) : このゴーストに固有の情報（キャラクター、サーフェス、辞書の構成）
- [AGENTS.md](AGENTS.md) : エージェント向けの指示書
- [DEVKIT-GUIDE.md](DEVKIT-GUIDE.md) : 開発キットの使い方

辞書のチェック:

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools/check.ps1
```
