// collection_bridge.m — Objective-C collection bridge (macOS / iOS).
//
// Implements the C trampolines declared by src/ui/native/objc_collections.cr's
// `lib LibCollectionBridge`: NSString / NSArray / NSMutableArray / NSDictionary
// helpers, batch view ops, autorelease-pool scoping, and raw retain/release.
//
// Compiled with -fno-objc-arc (manual reference counting, like the other
// bridges). Per the ownership conventions documented in objc_collections.cr:
//   - factory helpers (`*_create`) return AUTORELEASED (+0) objects — the
//     caller does NOT own them; they live until the enclosing autorelease pool
//     drains. Wrap usage in autorelease_pool_push/pop.
//   - accessors (`*_object_at`, `*_get`, `*_all_keys`) return BORROWED (+0)
//     pointers owned by their container — do not release.
//
// This closes the documented `make test-macos` link gap: the native spec lane
// referenced these ~28 symbols but no implementing source existed. See
// docs/initiative-cross-platform-ui/native-compile-matrix.md (macOS row,
// blocker 2: "the implementing C/Obj-C source (collection_bridge.c/.m) is NOT
// in the repo. make test-macos link step fails with ~40 undefined symbols").

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#if TARGET_OS_OSX
  #import <AppKit/AppKit.h>
  typedef NSView BridgeColView;
#else
  #import <UIKit/UIKit.h>
  typedef UIView BridgeColView;
#endif
#include <string.h>

// ------------------------------------------------------------------ NSString
void *nsstring_create(const unsigned char *utf8_str) {
    return [NSString stringWithUTF8String:(const char *)utf8_str];
}

void *nsstring_create_with_bytes(const unsigned char *bytes, unsigned long long byte_len) {
    return [[[NSString alloc] initWithBytes:bytes
                                     length:(NSUInteger)byte_len
                                   encoding:NSUTF8StringEncoding] autorelease];
}

// Returns a pointer to the string's UTF-8 bytes (valid for the current
// autorelease scope — the Crystal side copies immediately). out_len = UTF-8
// byte length (NOT the UTF-16 code-unit length).
const unsigned char *nsstring_to_utf8(void *nsstring, unsigned long long *out_len) {
    const char *utf8 = [(NSString *)nsstring UTF8String];
    if (!utf8) { if (out_len) *out_len = 0; return (const unsigned char *)""; }
    if (out_len) *out_len = (unsigned long long)strlen(utf8);
    return (const unsigned char *)utf8;
}

unsigned long long nsstring_length(void *nsstring) {
    return (unsigned long long)[(NSString *)nsstring length];
}

// --------------------------------------------------------- NSArray (immutable)
void *nsarray_create(void **objects, unsigned long long count) {
    return [NSArray arrayWithObjects:(const id *)objects count:(NSUInteger)count];
}

unsigned long long nsarray_count(void *nsarray) {
    return (unsigned long long)[(NSArray *)nsarray count];
}

void *nsarray_object_at(void *nsarray, unsigned long long index) {
    return [(NSArray *)nsarray objectAtIndex:(NSUInteger)index];
}

void nsarray_get_objects(void *nsarray, void **out_buf, unsigned long long count) {
    [(NSArray *)nsarray getObjects:(id *)out_buf range:NSMakeRange(0, (NSUInteger)count)];
}

// -------------------------------------------------------------- NSMutableArray
void *nsmutablearray_create(unsigned long long capacity) {
    return [NSMutableArray arrayWithCapacity:(NSUInteger)capacity];
}

void *nsmutablearray_create_from(void **objects, unsigned long long count) {
    return [NSMutableArray arrayWithObjects:(const id *)objects count:(NSUInteger)count];
}

void nsmutablearray_add(void *marray, void *object) {
    [(NSMutableArray *)marray addObject:(id)object];
}

void nsmutablearray_insert(void *marray, void *object, unsigned long long index) {
    [(NSMutableArray *)marray insertObject:(id)object atIndex:(NSUInteger)index];
}

void nsmutablearray_remove_at(void *marray, unsigned long long index) {
    [(NSMutableArray *)marray removeObjectAtIndex:(NSUInteger)index];
}

void nsmutablearray_remove_all(void *marray) {
    [(NSMutableArray *)marray removeAllObjects];
}

void nsmutablearray_add_batch(void *marray, void **objects, unsigned long long count) {
    NSMutableArray *m = (NSMutableArray *)marray;
    for (unsigned long long i = 0; i < count; i++) {
        [m addObject:(id)objects[i]];
    }
}

unsigned long long nsmutablearray_count(void *marray) {
    return (unsigned long long)[(NSMutableArray *)marray count];
}

void *nsmutablearray_object_at(void *marray, unsigned long long index) {
    return [(NSMutableArray *)marray objectAtIndex:(NSUInteger)index];
}

// ---------------------------------------------------------------- NSDictionary
void *nsdictionary_create(void **keys, void **values, unsigned long long count) {
    return [NSDictionary dictionaryWithObjects:(const id *)values
                                       forKeys:(const id<NSCopying> *)keys
                                         count:(NSUInteger)count];
}

void *nsmutabledictionary_create(unsigned long long capacity) {
    return [NSMutableDictionary dictionaryWithCapacity:(NSUInteger)capacity];
}

void nsmutabledictionary_set(void *mdict, void *key, void *value) {
    [(NSMutableDictionary *)mdict setObject:(id)value forKey:(id<NSCopying>)key];
}

void *nsdictionary_get(void *dict, void *key) {
    return [(NSDictionary *)dict objectForKey:(id)key];
}

void *nsdictionary_all_keys(void *dict) {
    return [(NSDictionary *)dict allKeys];
}

unsigned long long nsdictionary_count(void *dict) {
    return (unsigned long long)[(NSDictionary *)dict count];
}

// ----------------------------------------------------- Batch view operations
void nsstack_set_views(void *stack_view, void **views, unsigned long long count, long long gravity) {
#if TARGET_OS_OSX
    NSArray *arr = [NSArray arrayWithObjects:(const id *)views count:(NSUInteger)count];
    [(NSStackView *)stack_view setViews:arr inGravity:(NSStackViewGravity)gravity];
#else
    // UIStackView has no gravity concept — append as arranged subviews.
    UIStackView *sv = (UIStackView *)stack_view;
    for (unsigned long long i = 0; i < count; i++) {
        [sv addArrangedSubview:(UIView *)views[i]];
    }
    (void)gravity;
#endif
}

void objc_add_subviews_batch(void *parent, void **children, unsigned long long count) {
    BridgeColView *p = (BridgeColView *)parent;
    for (unsigned long long i = 0; i < count; i++) {
        [p addSubview:(BridgeColView *)children[i]];
    }
}

// -------------------------------------------------------------- Autorelease pool
void *autorelease_pool_push(void) {
    return [[NSAutoreleasePool alloc] init];
}

void autorelease_pool_pop(void *pool) {
    [(NSAutoreleasePool *)pool drain];
}

// ------------------------------------------------------------- Retain/Release
void *objc_retain_object(void *obj) {
    return [(id)obj retain];
}

void objc_release_object(void *obj) {
    [(id)obj release];
}

void *objc_autorelease_object(void *obj) {
    return [(id)obj autorelease];
}
