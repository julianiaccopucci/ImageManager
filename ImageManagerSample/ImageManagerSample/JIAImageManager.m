//
//  JIAImageManager.m
//
//  Created by Julian Iaccopucci on 23/09/2013.
//  Copyright (c) 2013 Julian Iaccopucci. All rights reserved. Usage granted to Capgemini PLC only.
//

#import "JIAImageManager.h"
#import <objc/runtime.h>

#define cacheDiskPath @"/imageManagerCache"

@interface JIAImageManager (){
    
    BOOL showSpinningIndicator;

}

@property (nonatomic, strong) NSMutableDictionary *downloadInProgress;
@property (nonatomic, strong) JIALIFOOperationQueue *downloadImageOperationStack;
@property (nonatomic, strong) NSURL *baseURL;

@property (nonatomic, strong) UIImage *waitingImage;
@property (nonatomic, strong) UIImage *defaultThumbnail;

@end


@implementation JIAImageManager

#pragma mark - Public methods

-(id)initWithmaxConcurrentOperation:(NSUInteger)count
          defaultImageOrNil:(NSString *)defaulImage
      downloadingImageOrNil:(NSString *)downloadingImage
      showSpinningIndicator:(BOOL)showSpinning
      virtualMemoryCapacity:(NSInteger)newCacheMemory
         diskMemoryCapacity:(NSInteger)newDiskMemory
{
    self = [super init];
    
    if(self)
    {
        NSURLCache *URLCache = [[NSURLCache alloc] initWithMemoryCapacity:newCacheMemory
                                                             diskCapacity:newDiskMemory
                                                                 diskPath:cacheDiskPath];
        [NSURLCache setSharedURLCache:URLCache];
        
        self.downloadInProgress = [NSMutableDictionary new];
        self.downloadImageOperationStack = [JIALIFOOperationQueue new];
        [self.downloadImageOperationStack setMaxConcurrentOperationCount:count];
        
        if (nil != downloadingImage)
        {
            self.waitingImage = [UIImage imageNamed:downloadingImage];
            NSParameterAssert(self.waitingImage);
        }
        
        if (nil != defaulImage)
        {
            self.defaultThumbnail = [UIImage imageNamed:defaulImage];
            NSParameterAssert(self.defaultThumbnail);
        }
        
        showSpinningIndicator = showSpinning;
    }
    return self;
}


-(void) setImageViewImage:(UIImageView *)imageView
        withThumbnailPath:(NSString *)_imagePath
{
    // Unregister the imageview so we can re-register it again
    [self unregisterImageView:imageView];

    NSURL *imageURL = [NSURL URLWithString:_imagePath];
    
    if (imageURL == nil)
    {
        imageView.image = self.defaultThumbnail;
    }
    else
    {
        /** Try the cached Image **/
        UIImage *cachedImage = [self cachedImageForURL:imageURL];
        if (nil != cachedImage)
        {
            imageView.image = cachedImage;
        }
        else
        {   
            if (nil == imageView)
            {
                imageView = [UIImageView new];
            }
            
            if (self.waitingImage != nil)
            {
                imageView.image = self.waitingImage;
            }
            
            // Is image is already in download queue, re-register
            if (YES == [self isPathInQueue:imageURL.path])  /** If the path is being downloaded do not register it again */
            {
                [self registerPath:imageURL.path
                      forImageView:imageView];  /** Register the imageview to be notified when finished*/
                
                [self.downloadImageOperationStack prioritiseOperationForPath:imageURL.path];
            }
            else
            {
                 /** Register the download path and the imaga view to be notified when the download is finished*/
                [self registerPath:imageURL.path
                      forImageView:imageView];
                
                /** Download the asset */
                JIABlockOperation *operation = [JIABlockOperation blockOperationWithBlock:^{
                    
                    NSError *error = nil;
                    __block UIImage *image = [self downloadImageForURL:imageURL
                                                                  error:&error];  /** Download the image */
                    
                    [[NSOperationQueue mainQueue] addOperationWithBlock:
                     ^{
                         if (nil == image) /** If it coulnd't be downloaded add the default image */
                         {
                             image = self.defaultThumbnail;
                         }
                         
                         [self setUIImage:image
               toRegisteredObjectsforPath:imageURL.path]; /** Set the image to all the ImageViews registered to the same path */
                         
                         [self unregisterThumbnailPath:imageURL.path];  /** Removing the path indicated that the download fot that path has ended */
                     }];
        
                }];
                
                operation.imagePath = imageURL.path;
                
                [self.downloadImageOperationStack addOperation:operation];
            }
        }
    }
}


-(void) cancellAllOperations
{
    [self.downloadImageOperationStack cancelAllOperations];
    self.downloadInProgress = [NSMutableDictionary new];
}


-(void) cancelPath:(NSString *)path
{
    [self.downloadImageOperationStack cancelOperationWithPath:path];
    [self unregisterThumbnailPath:path];  /** Removing the path indicated that the download fot that path has ended */
}


-(void) cleanCache
{
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}


#pragma mark - Private methods
-(UIImage*) downloadImageForURL:(NSURL *)url
                           error:(NSError **)error
{
    NSURLResponse *response = nil;
    NSURLRequest *request = [self requestForImageUrl:url];
    
    NSData *imageData = [NSURLConnection sendSynchronousRequest:request
                                               returningResponse:&response
                                                           error:error];
    
    UIImage *image = nil;
    
    if (nil == *error)
    {
        image = [UIImage imageWithData:imageData];
        
        if (nil == image)
        {
            *error = [NSError errorWithDomain:@"jia.JIAImageManager.imageError" code:1000 userInfo:@{NSLocalizedDescriptionKey:@"The image data couldn't be loaded into an image"}];
        }
    }
    
    return image;
}


-(UIImage*) cachedImageForURL:(NSURL*)imageUrl
{
    NSURLRequest *request = [self requestForImageUrl:imageUrl];
    
    NSCachedURLResponse *response = [[NSURLCache sharedURLCache] cachedResponseForRequest:request];
    
    if (nil != response &&
        nil != response.data)
    {
        UIImage *image = [UIImage imageWithData:response.data];
        
        if (nil != image)
        {
            return image;
        }
    }
    
    return nil;
}


-(NSURLRequest*) requestForImageUrl:(NSURL*)imageUrl
{
    NSParameterAssert(imageUrl);
    
    if (imageUrl == nil)
    {
        //prevent any crashing;
        return nil;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:imageUrl];
    [request setCachePolicy:NSURLRequestReturnCacheDataElseLoad];

    return request;
}


-(void) registerPath:(NSString*)path
        forImageView:(UIImageView*)imageView
{
    if(nil != imageView)
    {
        NSMutableArray *registeredArrayForPath = [self.downloadInProgress objectForKey:path]; // Fetch the reference
        
        if (nil == registeredArrayForPath)
        {
            registeredArrayForPath = [NSMutableArray new];
            
            [self.downloadInProgress setObject:registeredArrayForPath forKey:path];
        }
        
        if(NO == [registeredArrayForPath containsObject:imageView])
        {
            [registeredArrayForPath addObject:imageView];
        }
        
        if (showSpinningIndicator)
        {
            [imageView addActivityIndicator];
        }
    }
    
}


-(void) unregisterThumbnailPath:(NSString*)path
{
    NSArray *imageViewsForPath = [self.downloadInProgress objectForKey:path];
    
    [imageViewsForPath enumerateObjectsUsingBlock:^(UIImageView *imageView, NSUInteger idx, BOOL *stop)
     {
         [imageView removeActivityIndicator];
     }];
    
    [self.downloadInProgress removeObjectForKey:path];
}


-(void) unregisterImageView:(UIImageView*)imageView
{
    if (nil != imageView)
    {
        for (NSMutableArray *registeredArray in self.downloadInProgress.allValues)
        {
            [registeredArray removeObject:imageView];
        }
    }
}


-(BOOL) isPathInQueue:(NSString *)path
{
    NSSet *keySet = [NSSet setWithArray:self.downloadInProgress.allKeys];
    
    BOOL containsObject = [keySet containsObject:path];
    
    return YES == containsObject;

}


-(void) setUIImage:(UIImage*)image toRegisteredObjectsforPath:(NSString*)path
{
    NSArray *objects = [self.downloadInProgress objectForKey:path];

    for (UIImageView *registeredImageView in objects)
    {
        registeredImageView.image = image;
    }
}


@end



@implementation JIALIFOOperationQueue

-(id) init
{
    self = [super init];
    
    self.operationStack = [NSMutableArray new];
    
    return self;
}


-(void) addOperation:(JIABlockOperation *)operation
{
    [self.operationStack addObject:operation];
    
    [operation addObserver:self
         forKeyPath:@"isFinished"
            options:NSKeyValueObservingOptionNew
            context:NULL];
    
    [self addOperationIfNeeded];
}


-(void) observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    NSBlockOperation *operation = object;
    if ([keyPath isEqual:@"isFinished"] &&
        [operation isKindOfClass:[NSBlockOperation class]])
    {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            
            [self addOperationIfNeeded];

        }];
    }
}


-(BOOL) canAddOperations
{
    return [self freeSlots] > 0;
}


-(NSInteger) freeSlots
{
    return self.maxConcurrentOperationCount - self.operations.count;
}


-(void) addOperationIfNeeded
{
    @synchronized (self) {
        
        BOOL canAddOperation = [self canAddOperations];

        if (YES == canAddOperation)
        {
            NSInteger emptySlots = [self freeSlots];
            
            while (emptySlots > 0)
            {
                    NSBlockOperation *storedOperation = [self.operationStack lastObject];
                    
                    if (NO == storedOperation.isExecuting &&
                        nil != storedOperation &&
                        NO == storedOperation.isFinished &&
                        NO == storedOperation.isCancelled)
                    {
                            [super addOperation:storedOperation];
                    }
                    
                    [self.operationStack removeObject:storedOperation];

                emptySlots--;
            }
        }
    }
}


-(void) prioritiseOperationForPath:(NSString *)path
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"imagePath == %@", path];
    
    NSArray *result = [self.operationStack filteredArrayUsingPredicate:predicate];
    
    if (result.count > 0)
    {
        JIABlockOperation *operation = result[0];
        [self.operationStack removeObject:operation];
        [self.operationStack addObject:operation];
    }
}


-(void) cancelAllOperations
{
    self.operationStack = [NSMutableArray new];
    [super cancelAllOperations];
}


-(void) cancelOperationWithPath:(NSString *)path
{
    [self.operationStack enumerateObjectsUsingBlock:^(JIABlockOperation *operation, NSUInteger idx, BOOL *stop) {
       
        if ([operation.imagePath isEqualToString:path])
        {
            [operation cancel];
        }
    }];
}

@end


@implementation JIABlockOperation


@end

@implementation UIImageView (SpinningIndicator)

static char const *const ActivityViewKey = "activityView";


-(void) setActivityView:(UIActivityIndicatorView *)activityView
{
    objc_setAssociatedObject(self, ActivityViewKey, activityView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


-(void) addActivityIndicator
{
    CGPoint center = CGPointMake(self.frame.size.width/2.f, self.frame.size.height/2.f);
    
    if (self.activityView.superview != self)
    {
        [self addSubview:self.activityView];
        
    }
    [self.activityView startAnimating];
    self.activityView.center = center;
}


-(UIActivityIndicatorView*) activityView
{
    if (nil == objc_getAssociatedObject(self, ActivityViewKey))
    {
        UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        [activityView startAnimating];
        
        [self setActivityView:activityView];
    }
    
    return objc_getAssociatedObject(self, ActivityViewKey);
}


-(void) removeActivityIndicator
{
    [self.activityView stopAnimating];
}
@end

@implementation JIAImageManager (CapgeminiAdditions)

#define MB(float) float*1048576.0

+(JIAImageManager *)sharedImageMaganer
{
    static JIAImageManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        manager = [[JIAImageManager alloc] initWithmaxConcurrentOperation:20 defaultImageOrNil:@"noOrderThumbnail" downloadingImageOrNil:nil showSpinningIndicator:YES virtualMemoryCapacity:MB(2) diskMemoryCapacity:MB(2)];
        
    });
    
    return manager;
}

@end


