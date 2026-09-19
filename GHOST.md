# GHOST.md

「悪役令嬢クローディア」に固有の情報です。AI エージェントは、作業の前に `AGENTS.md` とあわせて読みます。
作者が自由に書き換えるファイルで、開発キットの更新（`tools/update-devkit.ps1`）で上書きされることはありません。

## このゴーストについて

- 伺か（ukagaka）のゴースト「悪役令嬢クローディア」。SHIORI は YAYA。
- テンプレートゴースト「紺野ややめ」（https://github.com/YAYA-shiori/konnoyayame ）をもとに作成した。
- 作者: ponapalt&claudia
- リポジトリ: https://github.com/ponapalt/claudia
- ネットワーク更新: `https://raw.githubusercontent.com/ponapalt/claudia/main/`（`On_homeurl` は `ghost/master/dic/normal/yaya_homeurl.dic` と `ghost/master/dic/emerg/yaya_homeurl.dic` の 2 か所）
  - GitHub の raw から配るので、`tools/build-nar.ps1` で作った `updates2.dau` と `updates.txt` を**リポジトリのルートに置いてコミットする**。`.gitignore` からは外してある。

## ライセンス

- ゴースト全体（辞書、シェル画像を含む）を Unlicense（パブリックドメイン）とする。ルートの `LICENSE` を参照。
- 辞書などは紺野ややめ（Public Domain / Unlicense）がもと。
- シェル `shell/master/` の画像は、作者が Claude と相談しながら gpt-image-2.5-flare で生成したもの（元素材は `work/surfaces/`、1024x1536 を縮小。クローディアは高さ 500px（333x500）、アンソニーは高さ 300px に縮小して 333x500 の透明キャンバスの下端中央に配置）。Unlicense なので編集してよい。

## 辞書の構成

- `ghost/master/yaya.txt` が `dic/normal` を読む。辞書エラーのときは `yaya_emerg.txt` が `dic/emerg` を読む（緊急モード）。
- `ghost/master/dic/system/` はシステム辞書（yaya-dic）。submodule ではなく普通のフォルダとして置いている。
- `yaya_tmpl_util.dic` のテンプレート処理（`AYATEMPLATE.*`）が、マウス反応などの関数を名前で呼び出す。

## イベントと辞書ファイルの対応

| ファイル（`ghost/master/dic/normal/`） | 主な中身 |
|---|---|
| `yaya_aitalk.dic` | ランダムトーク（`RandomTalkEx`）、チェイントーク（`tea_review`、`mikirego`）、キー入力 `OnKeyPress`、時報と重なり `OnMinuteChange`、見切れ |
| `yaya_bootend.dic` | 初回起動 `OnFirstBoot`、起動 `OnBoot`、終了 `OnClose`、時間帯の判定 `GetTimeSlot` |
| `yaya_mouse.dic` | なで・つつきへの反応。関数名は「種別＋スコープ番号＋当たり判定名」（例: `MouseMove0Head`、`MouseDoubleClick1Tray`）。当たり判定名つきの関数が無ければ、名前なし（`MouseDoubleClick1` など）が呼ばれる |
| `yaya_menu.dic` | メニュー `OpenMenu` と、選択肢ごとの処理 `Menu_*` |
| `yaya_communicate.dic` | ユーザーとの会話、他のゴーストとの会話（`TalkTo*` / `ReplyTo*`） |
| `yaya_change.dic` | ゴーストの切り替えや呼び出しのときのトーク |
| `yaya_etc.dic` | シェル変更、インストール、消滅（vanish）、ネットワーク更新、ヘッドライン、時刻合わせなどのイベント |
| `yaya_string.dic` | メニュー項目やおすすめサイトなどのリソース（`On_*`） |
| `yaya_word.dic` | トーク中に埋め込む単語（`%(tea)` 紅茶、`%(sweets)` お菓子、`%(food)` 料理） |
| `yaya_homeurl.dic` | ネットワーク更新の URL（`On_homeurl`） |
| `yaya_tmpl_util.dic` | テンプレートの内部処理（`AYATEMPLATE.*`）。必要なとき以外は触らない |

新しいイベントに反応させる関数は、内容の近い辞書ファイルに書く。`dic/normal/` に新しい `.dic` ファイルを置いた場合も自動で読み込まれる。

## キャラクターとサーフェス

| スコープ | キャラクター | 人物像 | 使えるサーフェス |
|---|---|---|---|
| `\0`（`\h`） | クローディア | クロード公爵家（Claude 一族）の令嬢。一人称「わたくし」、相手は「あなた」。語尾は「〜ですわ」「〜ですの」「〜なさい」「〜かしら」「〜でしてよ」。高慢で歯に衣着せぬ物言いだが、実はきわめて有能で面倒見がよい。辛辣さは優雅な皮肉まで。高笑い（「おーっほっほっほ！」）は見事に片付いたときだけ | 0 素（微笑）/ 1 照れ / 2 驚き / 4 落胆 / 5 高笑い / 6 目閉じ / 7 不機嫌 / 25 にっこり / 26 したり顔 |
| `\1`（`\u`） | アンソニー | クローディアに仕える青い執事。一人称「私」、クローディアを「お嬢様」と呼ぶ。「〜でございます」の丁寧語で、淡々と冷静にツッコむ。いつも紅茶とクッキーの載ったトレイを持っている | 10 素（半目）/ 11 刮目 |

- 3 番のサーフェスは無い。トークでは上の表にある番号だけを使う。
- 当たり判定（`surfaces.txt` の `collision`）:
  - クローディア: `Head`、`Face`、`Bust`、`Hair`（左右の巻き髪）、`Fan`（扇。サーフェスごとに位置が違い、2・4・5 は別の位置）
  - アンソニー: `Tray`、`Head`（頭のひれ）、`Face`、`Body`
- シェルは `seriko.use_self_alpha,1` で PNG のアルファを使う。

## トークの書き方

- 話し始める側のスコープと表情を最初に指定する。両方の表情を先に決める `\u\s[10]\0\s[0]...` の書き方を基本にする。
- 話し手を交代する前に `\w8` を入れる。同じ話し手の中の間は `\w5`〜`\w9`。沈黙の「‥‥」は `‥\w5‥\w5` と書く。
- 同じ話し手の中で改行するときは `\w9\n`。1 行は全角 20〜25 字くらいまで。
- すでに話したスコープに戻って話すときは、`\n\n` で空行を入れてから続ける。
- ユーザーは `%(username)` で呼ぶ（初期値は「あなた」。「名前を覚えて」と話しかけると変えられる）。

例（`yaya_aitalk.dic` より）:

```
'\u\s[10]\0\s[4]わたくし、どうして「悪役令嬢」などと\w9\n呼ばれるのかしら。\w8\1歯に衣着せぬ物言いのせいかと。\w8\0\s[7]\n\n本当のことを言っているだけですわ。\w8\1\n\nそれでございます。\e'
```

- クローディアが丁寧語の「ございます」で話す、アンソニーが「ですわ」で話す、のように口調を混ぜない。
