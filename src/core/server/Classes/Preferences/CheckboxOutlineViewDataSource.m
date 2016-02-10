#import "CheckboxOutlineViewDataSource.h"
#import "PreferencesManager.h"
#import "XMLCompiler.h"

@interface FilterCondition : NSObject
@property BOOL isEnabledOnly;
@property NSString* string;

- (BOOL)isEqualToFilterCondition:(FilterCondition*)other;
@end

@implementation FilterCondition

- (instancetype)init:(BOOL)isEnabledOnly string:(NSString*)string {
  self = [super init];

  if (self) {
    self.isEnabledOnly = isEnabledOnly;
    self.string = string;
  }

  return self;
}

- (BOOL)isEqualToFilterCondition:(FilterCondition*)other {
  if (self.isEnabledOnly != other.isEnabledOnly) {
    return NO;
  }

  if (![self compareString:other.string]) {
    return NO;
  }

  return YES;
}

- (BOOL)compareString:(NSString*)otherString {
  if (self.string == nil && otherString == nil) {
    return YES;
  }
  if (self.string != nil && otherString != nil) {
    return [self.string compare:otherString] == NSOrderedSame;
  }
  return NO;
}

@end

@interface CheckboxOutlineViewDataSource ()
@property(weak) IBOutlet PreferencesManager* preferencesManager;
@property(weak) IBOutlet XMLCompiler* xmlCompiler;
@property NSMutableArray* dataSource;
@property FilterCondition* filterCondition;
@end

@implementation CheckboxOutlineViewDataSource

- (void)load:(BOOL)force {
  if (force) {
    if (self.dataSource) {
      self.dataSource = nil;
      self.filterCondition = nil;
    }
  }

  if (!self.dataSource) {
    self.dataSource = [self.xmlCompiler preferencepane_checkbox];
    self.filterCondition = nil;
  }
}

- (NSDictionary*)filterDataSource_core:(NSDictionary*)dictionary isEnabledOnly:(BOOL)isEnabledOnly strings:(NSArray*)strings {
  // check strings
  BOOL stringsMatched = YES;
  if (strings) {
    CheckboxItem* checkboxItem = dictionary[@"checkboxItem"];
    // Remove matched strings from strings for children.
    //
    // For example:
    //   strings == @[@"Emacs", @"Mode", @"Tab"]
    //
    //   * Emacs Mode
    //     * Control+I to Tab
    //
    //   notMatchedStrings == @[@"Tab"] at "Emacs Mode".
    //   Then "Control+I to Tab" will be matched by strings == @[@"Tab"].

    NSMutableArray* notMatchedStrings = nil;
    for (NSString* s in strings) {
      if (![checkboxItem isNameMatched:s]) {
        stringsMatched = NO;
      } else {
        if (!notMatchedStrings) {
          notMatchedStrings = [NSMutableArray arrayWithArray:strings];
        }
        [notMatchedStrings removeObject:s];
      }
    }

    if (notMatchedStrings) {
      strings = notMatchedStrings;
    }
  }

  // ------------------------------------------------------------
  // check children
  NSArray* children = dictionary[@"children"];
  if (children) {
    NSMutableArray* newchildren = [NSMutableArray new];
    for (NSDictionary* dict in children) {
      NSDictionary* d = [self filterDataSource_core:dict isEnabledOnly:isEnabledOnly strings:strings];
      if (d) {
        [newchildren addObject:d];
      }
    }

    if ([newchildren count] > 0) {
      NSMutableDictionary* newdictionary = [NSMutableDictionary dictionaryWithDictionary:dictionary];
      newdictionary[@"children"] = newchildren;
      return newdictionary;
    }
  }

  // ------------------------------------------------------------
  // filter by isEnabledOnly
  if (isEnabledOnly) {
    NSString* identifier = dictionary[@"identifier"];
    if (!identifier) {
      return nil;
    }
    if (![self.preferencesManager value:identifier]) {
      return nil;
    }
  }

  // check strings
  if (!stringsMatched) {
    return nil;
  }

  return dictionary;
}

// return YES if we need to call [NSOutlineView reloadData]
- (BOOL)filterDataSource:(BOOL)isEnabledOnly string:(NSString*)string {
  // Check filter condition is changed from previous filterDataSource.
  FilterCondition* filterCondition = [[FilterCondition alloc] init:isEnabledOnly string:string];
  if ([self.filterCondition isEqualToFilterCondition:filterCondition]) {
    return NO;
  }

  // ----------------------------------------
  [self load:YES];

  if (!self.dataSource) return NO;

  NSMutableArray* strings = [NSMutableArray new];
  if (string) {
    for (NSString* s in [string componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]) {
      if ([s length] == 0) continue;
      [strings addObject:s];
    }
  }

  if (isEnabledOnly || [strings count] > 0) {
    NSMutableArray* newdatasource = [NSMutableArray new];
    for (NSDictionary* dict in self.dataSource) {
      NSDictionary* d = [self filterDataSource_core:dict isEnabledOnly:isEnabledOnly strings:strings];
      if (d) {
        [newdatasource addObject:d];
      }
    }

    self.dataSource = newdatasource;
  }

  self.filterCondition = filterCondition;
  return YES;
}

- (NSInteger)outlineView:(NSOutlineView*)outlineView numberOfChildrenOfItem:(id)item {
  [self load:NO];

  return item ? [item[@"children"] count] : [self.dataSource count];
}

- (void)clearFilterCondition {
  self.filterCondition = nil;
}

- (id)outlineView:(NSOutlineView*)outlineView child:(NSInteger)index ofItem:(id)item {
  [self load:NO];

  // ----------------------------------------
  NSMutableArray* a = nil;

  // root object
  if (!item) {
    a = self.dataSource;
  } else {
    a = item[@"children"];
  }

  if ((NSUInteger)(index) >= [a count]) return nil;
  return a[index];
}

- (BOOL)outlineView:(NSOutlineView*)outlineView isItemExpandable:(id)item {
  return [item[@"children"] count] > 0;
}

+ (BOOL)isCheckbox:(NSString*)identifier {
  if (!identifier ||
      [identifier hasPrefix:@"notsave."]) {
    return NO;
  }
  return YES;
}

@end
