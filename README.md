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
- A readable `Pronunciation of Author` could not be found in the current SQLite database. At the moment this program outputs the `Author` value again in that column.

For more details about the database structure and investigation results, see [README_KINDLE_DB.md](/Users/rok/work/objc/listKindleBooks_Codex/README_KINDLE_DB.md).

## How?

### How to build

Xcode and Xcode command-line tools must be installed.

Build with:

```sh
clang -fobjc-arc -framework Foundation listKindleBooks2.m -lsqlite3 -o listKindleBooks2
```

### How to use

If no database path is supplied, `listKindleBooks2` reads from the default current Kindle database:

`~/Library/Containers/com.amazon.Lassen/Data/Library/Protected/BookData.sqlite`

Example:

```sh
./listKindleBooks2 > ./kindle.csv
```

You can specify a database file as an argument:

```sh
./listKindleBooks2 /path/to/BookData.sqlite
```

Use `-h` to print a header line:

```sh
./listKindleBooks2 -h > ./kindle.csv
```

Use `-f "Separator"` to specify the field separator:

```sh
./listKindleBooks2 -h -f ';' > ./kindle.csv
```

Options can be combined with a custom database path:

```sh
./listKindleBooks2 -h -f ';' /path/to/BookData.sqlite
```

## Output Notes

- Output is UTF-8 text.
- Fields are always double-quoted.
- The separator is `,` by default and can be changed with `-f`.
- The program currently outputs all rows in `ZBOOK` where `ZDISPLAYTITLE` is not `NULL`, including dictionaries and other content types.

## Others

Apple Numbers can read UTF-8 CSV directly in most cases.

If you need Shift_JIS for Excel in a Japanese environment, you can convert the output like this:

```sh
./listKindleBooks2 -h | iconv -c -f UTF-8 -t SJIS > ./kindle.csv
```

Or, if `nkf` is installed:

```sh
./listKindleBooks2 -h | nkf -Ws > ./kindle.csv
```
