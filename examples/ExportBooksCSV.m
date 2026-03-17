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

static NSDictionary *AttributesFromMetadataBlob(NSData *blob) {
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
    if ([root isKindOfClass:[SyncMetadataAttributes class]]) {
        return ((SyncMetadataAttributes *)root).attributes;
    }
    if ([root isKindOfClass:[NSDictionary class]]) {
        id attributes = ((NSDictionary *)root)[@"attributes"];
        return [attributes isKindOfClass:[NSDictionary class]] ? attributes : nil;
    }
    return nil;
}

static NSString *FlattenAuthorValue(id authors) {
    if ([authors isKindOfClass:[NSDictionary class]]) {
        return FlattenAuthorValue(((NSDictionary *)authors)[@"author"]);
    }
    if ([authors isKindOfClass:[NSString class]]) {
        return authors;
    }
    if ([authors isKindOfClass:[NSArray class]]) {
        NSMutableArray<NSString *> *names = [NSMutableArray array];
        for (id item in (NSArray *)authors) {
            NSString *name = FlattenAuthorValue(item);
            if (name.length > 0) {
                [names addObject:name];
            }
        }
        return names.count > 0 ? [names componentsJoinedByString:@", "] : nil;
    }
    return nil;
}

static NSString *FlattenPublisherValue(id publishers) {
    if ([publishers isKindOfClass:[NSDictionary class]]) {
        id publisher = ((NSDictionary *)publishers)[@"publisher"];
        if ([publisher isKindOfClass:[NSString class]]) {
            return publisher;
        }
        return FlattenPublisherValue(publisher);
    }
    if ([publishers isKindOfClass:[NSString class]]) {
        return publishers;
    }
    if ([publishers isKindOfClass:[NSArray class]]) {
        NSMutableArray<NSString *> *values = [NSMutableArray array];
        for (id item in (NSArray *)publishers) {
            NSString *value = FlattenPublisherValue(item);
            if (value.length > 0) {
                [values addObject:value];
            }
        }
        return values.count > 0 ? [values componentsJoinedByString:@", "] : nil;
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

static NSString *CSVField(NSString *value) {
    NSString *safe = value ?: @"";
    NSString *escaped = [safe stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""];
    return [NSString stringWithFormat:@"\"%@\"", escaped];
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
            @"SELECT ZDISPLAYTITLE, ZSORTTITLE, ZBOOKID, ZRAWPUBLISHER, ZSYNCMETADATAATTRIBUTES "
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

        puts("\"ASIN\",\"Title\",\"Author\",\"Publisher\",\"Date Published\",\"Date Purchased\",\"Pronunciation of Title\",\"Pronunciation of Author\"");

        while (sqlite3_step(statement) == SQLITE_ROW) {
            NSString *title = NullableText(statement, 0) ?: @"";
            NSString *sortTitle = NullableText(statement, 1) ?: @"";
            NSString *bookID = NullableText(statement, 2) ?: @"";
            NSString *rawPublisher = NullableText(statement, 3) ?: @"";

            const void *blobBytes = sqlite3_column_blob(statement, 4);
            int blobLength = sqlite3_column_bytes(statement, 4);
            NSData *blob = (blobBytes != NULL && blobLength > 0)
                ? [NSData dataWithBytes:blobBytes length:(NSUInteger)blobLength]
                : nil;
            NSDictionary *attributes = AttributesFromMetadataBlob(blob);

            NSString *asin = [attributes[@"ASIN"] isKindOfClass:[NSString class]] ? attributes[@"ASIN"] : nil;
            if (asin.length == 0 && bookID.length > 3 && [bookID hasPrefix:@"A:"] && [bookID hasSuffix:@"-0"]) {
                asin = [bookID substringWithRange:NSMakeRange(2, bookID.length - 4)];
            }

            NSString *author = FlattenAuthorValue(attributes[@"authors"]) ?: @"";
            NSString *publisher = FlattenPublisherValue(attributes[@"publishers"]);
            if (publisher.length == 0) {
                publisher = rawPublisher;
            }

            NSString *publicationDate = [attributes[@"publication_date"] isKindOfClass:[NSString class]]
                ? attributes[@"publication_date"] : @"";
            NSString *purchaseDate = [attributes[@"purchase_date"] isKindOfClass:[NSString class]]
                ? attributes[@"purchase_date"] : @"";
            NSString *pronunciationOfAuthor = author;

            NSArray<NSString *> *fields = @[
                CSVField(asin ?: @""),
                CSVField(title),
                CSVField(author),
                CSVField(publisher ?: @""),
                CSVField(publicationDate),
                CSVField(purchaseDate),
                CSVField(sortTitle),
                CSVField(pronunciationOfAuthor ?: @""),
            ];
            puts([[fields componentsJoinedByString:@","] UTF8String]);
        }

        sqlite3_finalize(statement);
        sqlite3_close(db);
    }

    return 0;
}
