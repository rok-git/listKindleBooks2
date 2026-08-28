# listKindleBooks2

**Notice: This program is for recent Kindle for macOS versions that store metadata in SQLite, not for old Kindle.app versions that used `KindleSyncMetadataCache.xml`.**

## What?

`listKindleBooks2` creates CSV-style output containing the following fields for books stored in Kindle for macOS metadata:

- `ASIN`
- `Title`
- `Author`
- `Publisher`
- `Date Published`
- `Date Purchased`
- `Pronunciation of Title`
- `Pronunciation of Author`

The program reads these values from the SQLite database used by the current Kindle for macOS app:

`~/Library/Containers/com.amazon.Lassen/Data/Library/Protected/BookData.sqlite`

Internally, most book metadata comes from the `ZBOOK` table and the `ZSYNCMETADATAATTRIBUTES` binary plist stored in that table.

## Important Notes

- This program targets the current SQLite-based Kindle data format.
- It does **not** read from `~/Library/Application Support/Kindle/Cache/KindleSyncMetadataCache.xml`.
- The old XML cache may still exist on disk, but it is treated as a legacy format and is not used by the current Kindle app.
- `Pronunciation of Title` is taken from `ZSORTTITLE`.
- Without `-y`, `Pronunciation of Author` is empty.
- With `-y`, the program outputs author pronunciations when they can be recovered from the series/group metadata in `ZGROUP`. Books without a reliable pronunciation remain empty.

For more details about the database structure and investigation results, see [README_KINDLE_DB.md](README_KINDLE_DB.md) and [README_yomi.md](README_yomi.md).

## How?

### How to build

Xcode and Xcode command-line tools must be installed.

Build with:

```sh
make
```

Generate a local schema dump, if needed:

```sh
make schema
```

Install with:

```sh
sudo make install
```

This installs `listKindleBooks2` into `/usr/local/bin`.
If `/usr/local/bin` is in your `PATH`, you can run `listKindleBooks2` without `./`.

The `schema` target writes `kindledb.sql` by extracting `.schema` from the current Kindle database at:

`~/Library/Containers/com.amazon.Lassen/Data/Library/Protected/BookData.sqlite`

`kindledb.sql` is treated as a local generated file and is not intended to be part of the distributed repository contents.

### How to use

If no database path is supplied, `listKindleBooks2` reads from the default current Kindle database:

`~/Library/Containers/com.amazon.Lassen/Data/Library/Protected/BookData.sqlite`

Example:

```sh
listKindleBooks2 > ./kindle.csv
```

You can specify a database file as an argument:

```sh
listKindleBooks2 /path/to/BookData.sqlite
```

Use `-h` to print a header line:

```sh
listKindleBooks2 -h > ./kindle.csv
```

Use `-f "Separator"` to specify the field separator:

```sh
listKindleBooks2 -h -f ';' > ./kindle.csv
```

Use `-c` to add a `Collections` column to the output:

```sh
listKindleBooks2 -h -c > ./kindle.csv
```

Use `-y` to output `Pronunciation of Author` when a reliable reading can be recovered from series/group metadata:

```sh
listKindleBooks2 -h -y > ./kindle.csv
```

Without `-y`, the `Pronunciation of Author` field is empty. Even with `-y`, it remains empty for books whose author pronunciation cannot be recovered.

Options can be combined with a custom database path:

```sh
listKindleBooks2 -h -f ';' /path/to/BookData.sqlite
```

It can also be combined with other options:

```sh
listKindleBooks2 -h -f ';' -c -y /path/to/BookData.sqlite
```

## Output Notes

- Output is UTF-8 text.
- Fields are always double-quoted.
- The separator is `,` by default and can be changed with `-f`.
- The program currently outputs all rows in `ZBOOK` where `ZDISPLAYTITLE` is not `NULL`, including dictionaries and other content types.
- If `-c` is specified, the program adds a `Collections` column using `ZCOLLECTIONITEM` and `ZCOLLECTIONV2`.
- If a book belongs to multiple collections, their names are joined with ` | ` inside the field.
- If `-y` is specified, the program first uses the pronunciation directly associated with the book through `ZGROUPITEM`. It then falls back to an unambiguous single-author map built from `ZGROUP`.

## Others

Apple Numbers can read UTF-8 CSV directly in most cases.

If you need Shift_JIS for Excel in a Japanese environment, you can convert the output like this:

```sh
listKindleBooks2 -h | iconv -c -f UTF-8 -t SJIS > ./kindle.csv
```

Or, if `nkf` is installed:

```sh
listKindleBooks2 -h | nkf -Ws > ./kindle.csv
```
