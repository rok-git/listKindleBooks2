#import <Foundation/Foundation.h>
#import <sqlite3.h>

@interface SyncMetadataAttributes : NSObject <NSSecureCoding>
@property (nonatomic, copy) NSDictionary *attributes;
@end

@implementation SyncMetadataAttributes
+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    NSSet *classes = [NSSet setWithArray:@[
        NSDictionary.class,
        NSMutableDictionary.class,
        NSArray.class,
        NSMutableArray.class,
        NSString.class,
        NSNumber.class,
        NSData.class,
    ]];
    _attributes = [coder decodeObjectOfClasses:classes forKey:@"attributes"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.attributes forKey:@"attributes"];
}
@end

static NSString *AuthorStringFromMetadataBlob(NSData *blob) {
    if (blob.length == 0) {
        return nil;
    }

    NSError *error = nil;
    NSSet *classes = [NSSet setWithArray:@[
        SyncMetadataAttributes.class,
        NSDictionary.class,
        NSMutableDictionary.class,
        NSArray.class,
        NSMutableArray.class,
        NSString.class,
        NSNumber.class,
        NSData.class,
    ]];

    id root = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes
                                                  fromData:blob
                                                     error:&error];
    NSDictionary *attributes = nil;
    if ([root isKindOfClass:[SyncMetadataAttributes class]]) {
        attributes = ((SyncMetadataAttributes *)root).attributes;
    } else if ([root isKindOfClass:[NSDictionary class]]) {
        attributes = ((NSDictionary *)root)[@"attributes"];
    }

    if (![attributes isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    id authors = attributes[@"authors"];
    if ([authors isKindOfClass:[NSDictionary class]]) {
        authors = ((NSDictionary *)authors)[@"author"];
    }

    if ([authors isKindOfClass:[NSString class]]) {
        return authors;
    }

    if ([authors isKindOfClass:[NSArray class]]) {
        NSMutableArray<NSString *> *names = [NSMutableArray array];
        for (id item in (NSArray *)authors) {
            if ([item isKindOfClass:[NSString class]]) {
                [names addObject:item];
            }
        }
        return names.count > 0 ? [names componentsJoinedByString:@", "] : nil;
    }

    return nil;
}

static NSString *NullableText(sqlite3_stmt *statement, int columnIndex) {
    const unsigned char *text = sqlite3_column_text(statement, columnIndex);
    if (text == NULL) {
        return nil;
    }
    return [NSString stringWithUTF8String:(const char *)text];
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        [NSKeyedUnarchiver setClass:SyncMetadataAttributes.class forClassName:@"SyncMetadataAttributes"];

        NSString *databasePath = argc > 1
            ? [NSString stringWithUTF8String:argv[1]]
            : @"BookData.sqlite";

        sqlite3 *db = NULL;
        int openResult = sqlite3_open_v2(databasePath.fileSystemRepresentation,
                                         &db,
                                         SQLITE_OPEN_READONLY,
                                         NULL);
        if (openResult != SQLITE_OK) {
            fprintf(stderr, "Failed to open database: %s\n", sqlite3_errmsg(db));
            if (db != NULL) {
                sqlite3_close(db);
            }
            return 1;
        }

        sqlite3_busy_timeout(db, 3000);

        NSString *sql =
            @"SELECT ZDISPLAYTITLE, ZBOOKID, ZCONTENTTAGS, ZSYNCMETADATAATTRIBUTES "
             "FROM ZBOOK "
             "WHERE ZDISPLAYTITLE IS NOT NULL "
             "  AND COALESCE(ZRAWISDICTIONARY, 0) = 0 "
             "  AND ZRAWBOOKTYPE = 10 "
             "ORDER BY Z_PK "
             "LIMIT 20;";

        sqlite3_stmt *statement = NULL;
        int prepareResult = sqlite3_prepare_v2(db, sql.UTF8String, -1, &statement, NULL);
        if (prepareResult != SQLITE_OK) {
            fprintf(stderr, "Failed to prepare query: %s\n", sqlite3_errmsg(db));
            sqlite3_close(db);
            return 1;
        }

        printf("%-4s %-60s %-30s %-16s %s\n", "No.", "Title", "Author", "BookID", "Tags");

        int rowNumber = 0;
        while (sqlite3_step(statement) == SQLITE_ROW) {
            rowNumber += 1;

            NSString *title = NullableText(statement, 0) ?: @"";
            NSString *bookID = NullableText(statement, 1) ?: @"";
            NSString *tags = NullableText(statement, 2) ?: @"";

            const void *blobBytes = sqlite3_column_blob(statement, 3);
            int blobLength = sqlite3_column_bytes(statement, 3);
            NSData *blob = (blobBytes != NULL && blobLength > 0)
                ? [NSData dataWithBytes:blobBytes length:(NSUInteger)blobLength]
                : nil;
            NSString *author = AuthorStringFromMetadataBlob(blob) ?: @"";

            printf("%-4d %-60.60s %-30.30s %-16.16s %s\n",
                   rowNumber,
                   title.UTF8String,
                   author.UTF8String,
                   bookID.UTF8String,
                   tags.UTF8String);
        }

        sqlite3_finalize(statement);
        sqlite3_close(db);
    }

    return 0;
}
