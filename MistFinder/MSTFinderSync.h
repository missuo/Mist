//
//  MSTFinderSync.h
//  MistFinder
//
//  Created by Vincent Yang on 7/16/26.
//

#import <FinderSync/FinderSync.h>

NS_ASSUME_NONNULL_BEGIN

/// Finder Sync extension that adds "Upload to Mist" directly to Finder's
/// context menu. Selected files are handed to the main app through the
/// mist:// URL scheme.
@interface MSTFinderSync : FIFinderSync

@end

NS_ASSUME_NONNULL_END
