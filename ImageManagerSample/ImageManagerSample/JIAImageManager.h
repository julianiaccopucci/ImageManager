//
//  JIAImageManager.h
//
//  Created by Julian Iaccopucci on 23/09/2013.
//  Copyright (c) 2013 Julian Iaccopucci. All rights reserved. Usage granted to Capgemini PLC only.
//  Any modification to this software is allowed.
//

#import <Foundation/Foundation.h>
@import UIKit;

/** This class downloads an asset and sets the asset to an image view. Only one instance of the URI will be performed at a time */

@interface JIAImageManager : NSObject

- (id)initWithmaxConcurrentOperation:(NSUInteger)count
                   defaultImageOrNil:(NSString *)defaulImage
               downloadingImageOrNil:(NSString *)downloading
               showSpinningIndicator:(BOOL)showSpinning
               virtualMemoryCapacity:(NSInteger)newCacheMemory//bytes
                  diskMemoryCapacity:(NSInteger)newDiskMemory;//bytes


- (void)setImageViewImage:(UIImageView*)imageView
        withThumbnailPath:(NSString *)path;


- (void)cancellAllOperations;


- (void)cancelPath:(NSString *)path;


- (void)cleanCache;

@end

@interface JIABlockOperation : NSBlockOperation

@property (nonatomic, strong) NSString *imagePath;

@end


@interface JIALIFOOperationQueue : NSOperationQueue

@property (nonatomic, strong) NSMutableArray *operationStack;

-(void) prioritiseOperationForPath:(NSString *)path;
-(void) cancelOperationWithPath:(NSString *)path;

@end

//..UIImageView (SpinningIndicator)
@interface UIImageView (SpinningIndicator)

@property (nonatomic, retain) UIActivityIndicatorView *activityView;

- (void)addActivityIndicator;
- (void)removeActivityIndicator;

@end

@interface JIAImageManager (CapgeminiAdditions)

+(JIAImageManager *)sharedImageMaganer;

@end

