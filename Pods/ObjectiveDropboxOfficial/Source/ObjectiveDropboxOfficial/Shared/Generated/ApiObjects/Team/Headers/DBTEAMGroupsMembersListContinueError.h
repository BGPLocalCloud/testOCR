///
/// Copyright (c) 2016 Dropbox, Inc. All rights reserved.
///
/// Auto-generated by Stone, do not modify.
///

#import <Foundation/Foundation.h>

#import "DBSerializableProtocol.h"

@class DBTEAMGroupsMembersListContinueError;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - API Object

///
/// The `GroupsMembersListContinueError` union.
///
/// This class implements the `DBSerializable` protocol (serialize and
/// deserialize instance methods), which is required for all Obj-C SDK API route
/// objects.
///
@interface DBTEAMGroupsMembersListContinueError : NSObject <DBSerializable, NSCopying>

#pragma mark - Instance fields

/// The `DBTEAMGroupsMembersListContinueErrorTag` enum type represents the
/// possible tag states with which the `DBTEAMGroupsMembersListContinueError`
/// union can exist.
typedef NS_ENUM(NSInteger, DBTEAMGroupsMembersListContinueErrorTag) {
  /// The cursor is invalid.
  DBTEAMGroupsMembersListContinueErrorInvalidCursor,

  /// (no description).
  DBTEAMGroupsMembersListContinueErrorOther,

};

/// Represents the union's current tag state.
@property (nonatomic, readonly) DBTEAMGroupsMembersListContinueErrorTag tag;

#pragma mark - Constructors

///
/// Initializes union class with tag state of "invalid_cursor".
///
/// Description of the "invalid_cursor" tag state: The cursor is invalid.
///
/// @return An initialized instance.
///
- (instancetype)initWithInvalidCursor;

///
/// Initializes union class with tag state of "other".
///
/// @return An initialized instance.
///
- (instancetype)initWithOther;

- (instancetype)init NS_UNAVAILABLE;

#pragma mark - Tag state methods

///
/// Retrieves whether the union's current tag state has value "invalid_cursor".
///
/// @return Whether the union's current tag state has value "invalid_cursor".
///
- (BOOL)isInvalidCursor;

///
/// Retrieves whether the union's current tag state has value "other".
///
/// @return Whether the union's current tag state has value "other".
///
- (BOOL)isOther;

///
/// Retrieves string value of union's current tag state.
///
/// @return A human-readable string representing the union's current tag state.
///
- (NSString *)tagName;

@end

#pragma mark - Serializer Object

///
/// The serialization class for the `DBTEAMGroupsMembersListContinueError`
/// union.
///
@interface DBTEAMGroupsMembersListContinueErrorSerializer : NSObject

///
/// Serializes `DBTEAMGroupsMembersListContinueError` instances.
///
/// @param instance An instance of the `DBTEAMGroupsMembersListContinueError`
/// API object.
///
/// @return A json-compatible dictionary representation of the
/// `DBTEAMGroupsMembersListContinueError` API object.
///
+ (nullable NSDictionary<NSString *, id> *)serialize:(DBTEAMGroupsMembersListContinueError *)instance;

///
/// Deserializes `DBTEAMGroupsMembersListContinueError` instances.
///
/// @param dict A json-compatible dictionary representation of the
/// `DBTEAMGroupsMembersListContinueError` API object.
///
/// @return An instantiation of the `DBTEAMGroupsMembersListContinueError`
/// object.
///
+ (DBTEAMGroupsMembersListContinueError *)deserialize:(NSDictionary<NSString *, id> *)dict;

@end

NS_ASSUME_NONNULL_END
