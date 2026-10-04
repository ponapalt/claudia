# GHOST.md

「悪役令嬢クローディア」に固有の情報です。AI エージェントは、作業の前に `AGENTS.md` とあわせて読みます。
作者が自由に書き換えるファイルで、開発キットの更新（`tools/update-devkit.ps1`）で上書きされることはありません。

## このゴーストについて

- 伺か（ukagaka）のゴースト「悪役令嬢クローディア」。SHIORI は YAYA。
- テンプレートゴースト「紺野ややめ」（https://github.com/YAYA-shiori/konnoyayame ）をもとに作成した。
- 作者: ponapalt&claudia
- リポジトリ: https://github.com/ponapalt/claudia
- ネットワーク更新: `https://raw.githubusercontent.com/ponapalt/claudia/main/`（`On_homeurl` は `ghost/master/dic/normal/yaya_homeurl.dic` と `ghost/master/dic/emerg/yaya_homeurl.dic` の 2 か所）
  - GitHub の raw から配るので、`updates2.dau` と `updates.txt` を**コミットする**。`.gitignore` からは外してある。
  - 同梱バルーン `claudia/` と `claudia_vertical/` は、それぞれの `descript.txt` の `homeurl`（`.../main/claudia/`、`.../main/claudia_vertical/`）から別に更新される。ゴーストの更新からは `.updateignore` で外してある。
  - 配布物に入るファイルを変えたら、**コミットの前に毎回** `powershell -NoProfile -ExecutionPolicy Bypass -File tools/claudia-updates.ps1` を実行し、できた更新ファイルを同じコミットに含める。このスクリプトが、ルート（ゴースト）、`claudia/`、`claudia_vertical/` の 3 か所の更新ファイルを一度に作り直す（開発キットのファイルではない、このゴースト専用のスクリプト）。

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
| `yaya_aitalk.dic` | ランダムトーク（`RandomTalkEx`）、季節と記念日のトーク（`SeasonTalk.*`。記念日はその日に一度、季節は 5 回に 1 回ほど）、チェイントーク（`tea_review`、`mikirego`）、キー入力 `OnKeyPress`、時報と重なり `OnMinuteChange`、見切れ |
| `yaya_bootend.dic` | 初回起動 `OnFirstBoot`、起動 `OnBoot`、終了 `OnClose`、時間帯の判定 `GetTimeSlot`、最小化と復帰（`OnWindowStateMinimize` / `OnWindowStateRestore`、`OnFullScreenAppMinimize` / `OnFullScreenAppRestore`） |
| `yaya_mouse.dic` | なで・つつきへの反応。関数名は「種別＋スコープ番号＋当たり判定名」（例: `MouseMove0Head`、`MouseDoubleClick1Tray`）。当たり判定名つきの関数が無ければ、名前なし（`MouseDoubleClick1` など）が呼ばれる |
| `yaya_menu.dic` | メニュー `OpenMenu` と、選択肢ごとの処理 `Menu_*` |
| `yaya_communicate.dic` | ユーザーとの会話（`TalkToUser`。言葉ごとの分岐は上から順に見る）、他のゴーストとの会話（`TalkTo*` / `ReplyTo*`。紺野ややめとは `TalkTo_紺野ややめ` / `ReplyTo_紺野ややめ`） |
| `yaya_change.dic` | ゴーストの切り替えや呼び出しのときのトーク |
| `yaya_etc.dic` | シェル変更、インストール、消滅（vanish）、ネットワーク更新、ヘッドライン、時刻合わせなどのイベント。PC の様子（バッテリー、デバイスの抜き差し、壁紙の変更、音楽の再生） |
| `yaya_string.dic` | メニュー項目やおすすめサイトなどのリソース（`On_*`） |
| `yaya_word.dic` | トーク中に埋め込む単語（`%(tea)` 紅茶、`%(sweets)` お菓子、`%(food)` 料理） |
| `yaya_claudecode.dic` | Claude Code のセッションの見張り（`CC.*`）。`%USERPROFILE%\.claude\sessions\*.json` を `\![execute,filewatch]` で見張り（`OnClaudeCodeDir` / `OnClaudeCodeFile`）、返事待ちのベルと 5 分ごとのリマインダ、長考と完了、新しいセッション、会話の記録（`%USERPROFILE%\.claude\projects\...\<sessionId>.jsonl`）から拾ったセッションの題名（`ai-title`）での呼びかけ、長考が片付いたときの働きぶりの報告（`CC.TurnStats`。依頼を受けてから使ったツールと失敗の数）、休憩のすすめ（続けて 2 時間ごと）、通知領域のアイコンの切り替えを行う。見張りは `OnBoot` の `CC.Start` で立てる。詳しい仕組みは先頭のコメントにある |
| `yaya_ccstats.dic` | Claude Code の功績録（`CCS.*`）。依頼の履歴 `%USERPROFILE%\.claude\history.jsonl`（時刻と作業フォルダだけを読み、本文は使わない）と、`yaya_claudecode.dic` の見張りから `CCS.Count` で数えた回数を合わせて、メニュー「功績録と業務報告」の功績録、終了時のひとこと（`OnClose`）、節目のお祝い（記念日、新しい称号、依頼の千件ごと。`CC.Minute` から）を出す。功績録は上端の見出しで切り替える 6 頁（報告・依頼・領地・見届け・称号・番外）で、メニューから開くと 1 頁目の業務報告（本日）を出す。業務報告（`CCS.PageReport`）は、本日・昨日・今週（月曜から）・先週・今月・先月・今年と、日付の入力欄で指定した期間（`OnCCSPeriod`、`OnInputCCSFrom` / `OnInputCCSTo`。`yaya_menu.dic`）を選べる。日は午前 4 時で区切る。期間の依頼は、そのたびに履歴を読み直して数える（`CCS.Span`。月の頭の位置を `ccshmpos` に覚えて読み飛ばす）。見届けた数は日ごとに `ccsdlog` に残し、`ccsdlogsince` より前の日の分は無い。番外の称号（`CCS.OddTitles`。時刻や日付、領地の名前、なでた・つついた回数など）は功績録の最後の頁に並べる。Claude Code が無い PC（`CCS.NoClaude`）では、功績録は頁の代わりに `CCS.PageNoClaude`（番外の称号があればそれだけ）を出す。履歴は読み終えた位置を覚えて増えた分だけ読む。AI グラフ（`On_getaistate`）も持ち、依頼・登城日・領地・返事待ち・大仕事・稼働時間の 6 軸を出す（本日の分は加算値）。数が何も無ければ空を返し、システム辞書の既定のグラフになる。背景は `ghost/master/ai0.png` と `ai0_dark.png`（`work/aigraph/make-aigraph.ps1` で作る）。詳しい仕組みは先頭のコメントにある |
| `yaya_teatimer.dic` | お茶とタイマー（`TM.*`）。メインメニュー「お茶とタイマー」（`Menu_TIMER`）から、紅茶の砂時計と時間を指定した砂時計（同時に 6 本まで）、執務（ポモドーロ。集中・短い休憩・長い休憩の分数と本数は「執務の時間割」で変える）を立てる。締め切りは `OnSecondChange` の `TM.Check` で確かめ、話せるときに知らせる。集中している間は、自動のランダムトーク（`OnAiTalk`）、時報、功績録の節目のお祝いを出さず、執務の間は Claude Code の休憩のすすめも出さない。選択肢の引数は `OnChoiceSelectEx` で受ける（ID が `TM.` で始まるもの）。知らせの音は `ghost/master/tm_*.wav`（`cc_*.wav` と同じく Python で合成した WAV）。詳しい仕組みは先頭のコメントにある |
| `yaya_homeurl.dic` | ネットワーク更新の URL（`On_homeurl`） |
| `yaya_tmpl_util.dic` | テンプレートの内部処理（`AYATEMPLATE.*`）。必要なとき以外は触らない |

新しいイベントに反応させる関数は、内容の近い辞書ファイルに書く。`dic/normal/` に新しい `.dic` ファイルを置いた場合も自動で読み込まれる。

## キャラクターとサーフェス

| スコープ | キャラクター | 人物像 | 使えるサーフェス |
|---|---|---|---|
| `\0`（`\h`） | クローディア | クロード公爵家（Claude 一族）の令嬢。一人称「わたくし」、相手は「あなた」。語尾は「〜ですわ」「〜ですの」「〜なさい」「〜かしら」「〜でしてよ」。高慢で歯に衣着せぬ物言いだが、実はきわめて有能で面倒見がよい。辛辣さは優雅な皮肉まで。高笑い（「おーっほっほっほ！」）は見事に片付いたときだけ | 0 素（微笑）/ 1 照れ / 2 驚き / 3 不安（困り顔） / 4 落胆 / 5 高笑い / 6 目閉じ / 7 不機嫌 / 8 冷笑（扇で口元を隠す） / 9 照れ怒り / 25 にっこり / 26 したり顔 / 27 考え中（閉じた扇を口元に当てる） / 28 お辞儀（カーテシー。一度だけ動いて 0 番の姿に戻る） |
| `\1`（`\u`） | アンソニー | クローディアに仕える青い執事。一人称「私」、クローディアを「お嬢様」と呼ぶ。「〜でございます」の丁寧語で、淡々と冷静にツッコむ。いつも紅茶とクッキーの載ったトレイを持っている | 10 素（半目）/ 11 刮目 |

- トークでは上の表にある番号だけを使う。
- 似た表情の使い分け:
  - 26 したり顔と 8 冷笑は、どちらも目を細めた余裕の顔で、違いは扇で口元を隠しているかどうか。8 のほうが冷ややかさが強い。26 は自分に向いた得意（手柄、自信、上機嫌な命令、褒めるときの上から目線、軽いからかい）。8 は相手や物事に向けた冷ややかさ（皮肉、あてこすり、見下し、不埒者への威圧、「悪役ですもの」と悪役令嬢を演じる場面、傷ついたのを扇で隠して平気を装う場面）。迷ったら 26 にして、8 はここぞという場面に取っておく
  - 1 照れは素直な照れ。9 照れ怒りは、照れているのに「べ、別に〜」「余計なことを」と強がって言い返す場面
  - 3 不安は困惑、心配、ちょっとした困りごと（失敗の知らせ、入力の誤りなど）。4 落胆は、寂しさや傷心など、はっきり気落ちした場面だけ
  - 7 不機嫌は、拗ねる、叱る、反発する場面。照れ隠しは 9、困っているだけなら 3
  - 27 考え中は、答えを探して考えている場面（思案、思い出そうとする、何にするか選ぶ）。考えあぐねて困っているなら 3、目を閉じて静かに物思いにふけるなら 6、企みなら 26
- 28 お辞儀は、挨拶やお礼、お見送りなど、令嬢らしく礼をする場面で使う。`\s[28]` にすると、`animation100`（`runonce`、`exclusive`）が `base` で 0 → 1010 → 1011（1.2 秒止まる）→ 1010 → 0 と動き、そのあとは 0 番と同じ姿（まばたきもする）になる。1010（膝を曲げ始め）と 1011（いちばん深いお辞儀）はそのためのコマで、トークでは使わない（`__parts`）。元素材は `work/surfaces/surface1010.png`（682x1024）と `surface1011.png`（1024x1536）で、他の立ち絵と同じく 333x500 に縮小し、1011 は靴の下端を 0 番（y=491）にそろえるため 3px 下へずらした。1010 と 1011 には当たり判定を置いていないので、動いている間（約 1.6 秒）はなでもつつきも効かない
- ドラッグ中の浮いた姿として、クローディアの 29 番とアンソニーの 19 番がある（元素材は `work/surfaces/`、他の立ち絵と同じ縮小と配置）。`yaya_mouse.dic` の `OnMouseDragStart` / `OnMouseDragEnd` だけで使い、トークでは使わない。
- 1000（目閉じ）と 1001（半目）は、0 番のまばたき（`animation0`、1001→1000→1001）に使うパーツ。1700（目閉じ）と 1701（半目）は、7 番と 9 番のまばたき（同じ順）に使うパーツ。1910 は 9 番の頬紅。どれもトークでは使わない（`surfacetable.txt` で `__parts` に入れている）。
- クローディアの 1・3・6・7・9・25・26 番は画像を持たず、`surfaces.txt` の `element` で 0 番の上に表情のパーツを重ねて作っている（1 は `claudia_eyes_1.png`、3 は `claudia_eyes_3.png`、6 は 1000、7 と 9 は `claudia_eyes_7.png`、25 は `claudia_eyes_25.png`、26 は `claudia_eyes_26.png`）。9 番は、さらに `animation9999`（`runonce`）で頬紅の 1910 を重ねている。
- クローディアの表情のパーツ（1000、1001、1700、1701、1910、`claudia_eyes_*.png`）は、立ち絵の左上から顔のまわりまでを切り出した大きさで、どれも `0,0` に重ねる。
- アンソニーの 11 番は画像を持たず、`surfaces.txt` の `element` で 10 番の上に目と眉のパーツ `anthony_eyes11.png` を重ねて作っている（体の色味を 10 番とそろえるため）。
- 当たり判定（`surfaces.txt` の `collision`）:
  - クローディア: `Head`、`Face`、`Bust`、`Hair`（左右の巻き髪）、`Fan`（扇。サーフェスごとに位置が違い、2・4・5・8・27 は別の位置。27 は閉じた扇が口元にあり、`Face` を口の上までに縮めている。8 は扇が口元にあるので、`Face` を扇より上の目のまわりまでに縮め、右の `Hair` も扇と重ならないよう狭めている）、`Skirt`（裾）、`Foot`（左右の靴）
  - アンソニー: `Tray`、`Head`（頭のひれ）、`Face`、`Body`、`Foot`
- シェルは `seriko.use_self_alpha,1` で PNG のアルファを使う。
- 生成した画像は体の内側のアルファが 252〜253 で、255 になっていない。元素材やシェルの画像を足したり作り直したりしたら、`powershell -NoProfile -ExecutionPolicy Bypass -File work/surfaces/fix-alpha.ps1` で、アルファ 240〜254 を 255 にそろえる（既定で `work/surfaces/` と `shell/master/` の全部。`-DryRun` で数えるだけ、`-Path` で対象を絞る）。

## 見た目の決まり（デザインシステム）

バルーン、メニュー、アイコン、サムネイルやバナー、HTML のページ、バルーンの中の文字の装飾（`\f[...]`）など、目に見えるものを作ったり直したりする前に、`docs/design-system.md` を読む。色、書体、飾りの部品、媒体ごとの作り方と、仕上げの確かめがある。既存の素材は、頼まれない限りこれに合わせて作り直さない。

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
