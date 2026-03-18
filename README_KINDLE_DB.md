# Kindle for macOS DB Notes

このメモは、macOS 版 Kindle アプリが実際に使うメタデータ保存場所を確認し、その内容を調べた結果を残すためのもの。

現行の Kindle for macOS は、少なくとも書籍メタデータについては次の SQLite DB を使っている前提で見るのがよい。

- `~/Library/Containers/com.amazon.Lassen/Data/Library/Protected/BookData.sqlite`

一方、旧 Kindle.app では次の XML キャッシュが使われていた。

- `~/Library/Application Support/Kindle/Cache/KindleSyncMetadataCache.xml`

## 現行アプリの実データソース

旧 XML キャッシュ:

- `~/Library/Application Support/Kindle/Cache/KindleSyncMetadataCache.xml`

については、旧形式のメタデータが残っており、`author pronunciation` のような可読な著者読みも確認できる。
ただし、現在の Kindle アプリはこの XML を使っていないものとして扱う。

必要なら、現行DBのスキーマは次でローカルに書き出せる。

```sh
make schema
```

このとき生成される `kindledb.sql` はローカル生成物であり、配布物には含めない前提にする。

## 主なテーブル

- `ZBOOK`
- `ZBOOKEXT`
- `ZBOOKUPDATE`
- `ZCOLLECTIONV2`
- `ZCOLLECTIONITEM`
- `ZGROUP`
- `ZGROUPITEM`
- `ZSERIESAUTHOR`
- `ZSERIESIMAGE`
- `ZARTICLE`

通常の書籍一覧を取るときは、まず `ZBOOK` を見る。

## `ZBOOK` で実用的だった項目

- `ZDISPLAYTITLE`: 表示用タイトル
- `ZSORTTITLE`: ソート用タイトル。日本語書籍ではカナ化された読み相当が入る
- `ZBOOKID`: Kindle 側の書籍ID。例: `A:B0CG5853SR-0`
- `ZPATH`: ローカル保存パス
- `ZRAWPUBLISHER`: 出版社
- `ZLANGUAGE`: 言語
- `ZMIMETYPE`: コンテンツ形式
- `ZCONTENTTAGS`: タグ。例: `;MANGA`, `;DICT;FREE_DICT`
- `ZRAWFILESIZE`: ファイルサイズ
- `ZRAWLASTACCESSTIME`: 最終アクセス時刻
- `ZRAWCURRENTPOSITION`: 現在位置
- `ZRAWMAXPOSITION`: 最大到達位置
- `ZRAWISUNREAD`: 未読フラグ
- `ZRAWREADSTATE`: 読書状態
- `ZRAWBOOKTYPE`: 書籍種別
- `ZRAWISDICTIONARY`: 辞書判定
- `ZSYNCMETADATAATTRIBUTES`: binary plist 形式のメタデータ
- `ZORIGINS`: binary plist 形式の起源情報

## 書籍種別の見え方

実データ上は次のような傾向だった。

- 通常書籍:
  - `COALESCE(ZRAWISDICTIONARY, 0) = 0`
  - `ZRAWBOOKTYPE = 10`
- 辞書:
  - `ZRAWISDICTIONARY = 1`
  - `ZRAWBOOKTYPE = 16`
  - `ZCONTENTTAGS = ';DICT;FREE_DICT'`

## `ZSYNCMETADATAATTRIBUTES` について

`ZSYNCMETADATAATTRIBUTES` は `bplist00` で始まる Apple の binary plist。
中身は `NSKeyedArchiver` 形式で、root class 名は `SyncMetadataAttributes`。

ローカルの Objective-C から読むには、受け皿クラスを定義して `NSKeyedUnarchiver` にクラス名マッピングを入れると扱える。

実データで確認できた主なキー:

- `ASIN`
- `authors`
- `publishers`
- `publication_date`
- `purchase_date`
- `title`
- `content_size`
- `content_type`
- `cde_contenttype`
- `origins`
- `content_tags`
- `accessibility_description`
- `bisac_subject_description_code`
- `default_dict_for_locales`
- `target_language`
- `short_item_name`
- `textbook_type`

### 実際に取れた旧フォーマット相当の項目

以下の並びで出力可能だった。

`"ASIN","Title","Author","Publisher","Date Published","Date Purchased","Pronunciation of Title","Pronunciation of Author"`

対応関係:

- `ASIN`
  - `ZSYNCMETADATAATTRIBUTES.attributes.ASIN`
- `Title`
  - `ZDISPLAYTITLE`
- `Author`
  - `ZSYNCMETADATAATTRIBUTES.attributes.authors`
- `Publisher`
  - `ZSYNCMETADATAATTRIBUTES.attributes.publishers`
  - なければ `ZRAWPUBLISHER`
- `Date Published`
  - `ZSYNCMETADATAATTRIBUTES.attributes.publication_date`
- `Date Purchased`
  - `ZSYNCMETADATAATTRIBUTES.attributes.purchase_date`
- `Pronunciation of Title`
  - `ZSORTTITLE`
- `Pronunciation of Author`
  - 現行DBでは可読な読みを確認できず、代用として `Author` をそのまま使うのが現実的

## タイトル読み

`ZSORTTITLE` には、日本語書籍でタイトルの読み相当が入っていた。

例:

- `鵼の碑 【電子百鬼夜行】`
  - `ZSORTTITLE = デンシヒャッキヤコウ001ヌエノイシブミ`
- `魔法科高校の劣等生(1) 入学編〈上〉`
  - `ZSORTTITLE = マホウカコウコウノレットウセイ01ニュウガクヘン01ジョウ (デンゲキブンコ)`

旧版DBの `Pronunciation of Title` 相当として使えそう。

## 著者読みについて

### 結論

現行DBでは、可読な著者読み文字列は見つからなかった。

たとえば:

- `京極夏彦 -> キョウゴクナツヒコ`
- `佐島 勤 -> サトウ ツトム`

のような対応は確認できなかった。

### 何が入っていたか

`ZDISPLAYAUTHOR` と `ZSORTAUTHOR` は存在するが、どちらも可読文字列ではなく BLOB。

単著の例:

- `佐島 勤`
  - `ZDISPLAYAUTHOR = EC968EDF06CF3B0DADFCFD83AE4DB2E4` で 16 バイト
  - `ZSORTAUTHOR = 868F929E49BE27B35A7D4FC06A7026B2996ED1E75CD23FB4525207F196F4A0C6` で 32 バイト

- `京極夏彦`
  - `ZDISPLAYAUTHOR = DF73B5158349495F12EB2196E923056B`
  - `ZSORTAUTHOR = 4B29506EF61FA16BE3FC953802EBEA0C374F5218EB863383690898FDC2CB079A`

これらは少なくとも単純な `MD5`, `SHA1`, `SHA256` の一致ではなかった。

### 複数著者本での挙動

複数著者本を調べると、`ZDISPLAYAUTHOR` / `ZSORTAUTHOR` は 16 バイト単位のトークン列のように見えるが、可読な読みの並びではなさそうだった。

例:

- `葬送のフリーレン（１１）`
  - 著者: `山田鐘人`, `アベツカサ`
  - `ZDISPLAYAUTHOR`: 2トークン
  - `ZSORTAUTHOR`: 3トークン

- `魔女と傭兵`
  - 著者: `超法規的かえる`, `叶世べんち`
  - `ZDISPLAYAUTHOR`: 3トークン
  - `ZSORTAUTHOR`: 4トークン

- `Jetson Nano 超入門 改訂第2版`
  - 著者6人
  - `ZDISPLAYAUTHOR`: 6トークン
  - `ZSORTAUTHOR`: 11トークン

観察結果:

- 著者数とトークン数は一致しないことがある
- 複数著者本のトークンを、同じ著者の単著本の `ZDISPLAYAUTHOR` / `ZSORTAUTHOR` と照合しても一致しなかった
- つまり「著者ごとの固定トークンを単純連結している」だけではなさそう

現時点では、`ZSORTAUTHOR` は「可読な著者読み」ではなく、内部ソートキー列と考えるのが安全。

## `strings` での確認

`strings -a ~/Library/Containers/com.amazon.Lassen/Data/Library/Protected/BookData.sqlite` 相当の内容で次を探したが、可読な著者読みは見つからなかった。

- `キョウゴクナツヒコ`
- `サトウ ツトム`

一方で、タイトルや著者名そのものは `ZSYNCMETADATAATTRIBUTES` から復元できる。

参考までに、旧 `KindleSyncMetadataCache.xml` には次のようなデータが入っていた。

- `<title pronunciation="...">`
- `<author pronunciation="サトウ ツトム">佐島 勤</author>`

ただし、この XML は現行 Kindle アプリの実ソースではないため、現行DBの解析結果とは分けて考える。

## 実装メモ

このディレクトリには確認用の Objective-C サンプルがある。

- [ListNonDictionaryBooks.m](examples/ListNonDictionaryBooks.m)
  - 通常書籍 20 件を表示
- [ExportBooksCSV.m](examples/ExportBooksCSV.m)
  - 旧フォーマット互換の CSV を出力

ビルド例:

```sh
clang -fobjc-arc -framework Foundation examples/ListNonDictionaryBooks.m -lsqlite3 -o list_non_dictionary_books
clang -fobjc-arc -framework Foundation examples/ExportBooksCSV.m -lsqlite3 -o export_books_csv
```

実行例:

```sh
./list_non_dictionary_books ~/Library/Containers/com.amazon.Lassen/Data/Library/Protected/BookData.sqlite
./export_books_csv ~/Library/Containers/com.amazon.Lassen/Data/Library/Protected/BookData.sqlite
```

## 現時点の安全な扱い

- `Pronunciation of Title` は `ZSORTTITLE` を使う
- `Pronunciation of Author` は現行DBからは可読な読みを取れない前提にする
- CSV互換が必要なら、`Pronunciation of Author` は空欄か `Author` の代用にする
