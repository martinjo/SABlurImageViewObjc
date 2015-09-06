//
//  SABlurImageView.m
//  SABlurImageView
//
//  Created by 鈴木大貴 on 2015/04/17.
//  Copyright (c) 2015年 鈴木大貴. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "SABlurImageView.h"
#import "UIImage+BlurEffect.h"

@interface SABlurImageView()

@property (nonatomic, strong) NSMutableArray *cgImages;
@property (nonatomic, strong) CALayer *nextBlurLayer;
@property (nonatomic, assign) NSInteger previousImageIndex;
@property (nonatomic, assign) CGFloat previousPercentage;

@end

@implementation SABlurImageView

static NSString *const kFadeAnimationKey = @"Fade";

static NSString *const kCountKey = @"count";
static NSString *const kDurationKey = @"duration";
static NSString *const kCGImageKey = @"cgImage";

static NSInteger const kMaxImageCount = 10;

#pragma mark - Init Methods
- (id) init {
    self = [super init];
    if (self) {
        [self initialize];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initialize];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self initialize];
    }
    return self;
}

- (id)initWithImage:(UIImage *)image {
    self = [super initWithImage:image];
    if (self) {
        [self initialize];
    }
    return self;
}

- (id)initWithImage:(UIImage *)image highlightedImage:(UIImage *)highlightedImage {
    self = [super initWithImage:image highlightedImage:highlightedImage];
    if (self) {
        [self initialize];
    }
    return self;
}

- (void)dealloc
{
    self.cgImages = nil;
    if (self.nextBlurLayer) {
        [self.nextBlurLayer removeFromSuperlayer];
    }
    self.nextBlurLayer = nil;
    self.previousImageIndex = -1;
    self.previousPercentage = 0.0f;
}

#pragma mark - Private Methods
- (void)initialize {
    self.previousImageIndex = -1;
    self.previousPercentage = 0.0f;
    self.cgImages = [NSMutableArray array];
}

- (void)setLayers:(NSInteger)index percentage:(CGFloat)percentage currentIndex:(NSInteger)currentIndex nextIndex:(NSInteger)nextIndex {
    if (index != self.previousImageIndex) {
        [CATransaction begin];
        [CATransaction setAnimationDuration:0];
        self.layer.contents = self.cgImages[currentIndex];
        [CATransaction commit];
        
        if (self.nextBlurLayer == nil) {
            self.nextBlurLayer = [CALayer layer];
            self.nextBlurLayer.frame = self.bounds;
            [self.layer addSublayer:self.nextBlurLayer];
        }
        
        [CATransaction begin];
        [CATransaction setAnimationDuration:0];
        self.nextBlurLayer.contents = self.cgImages[nextIndex];
        self.nextBlurLayer.opaque = 0.0f;
        [CATransaction commit];
    }
    self.previousImageIndex = index;
    
    CGFloat minPercentage = percentage * 100.0f;
    CGFloat alpha = (minPercentage - (CGFloat)((NSInteger)(minPercentage / 10.0f) * 10)) / 10.0f;
    if (alpha > 1.0f) {
        alpha = 1.0f;
    } else if (alpha < 0.0f) {
        alpha = 0.0f;
    }
    
    [CATransaction begin];
    [CATransaction setAnimationDuration:0];
    self.nextBlurLayer.opacity = alpha;
    [CATransaction commit];
}

- (void)blurAnimation:(NSDictionary *)dictionary {
    NSInteger count = ((NSNumber *)dictionary[kCountKey]).integerValue;
    NSInteger duration = ((NSNumber *)dictionary[kDurationKey]).integerValue;
    id cgImage = dictionary[kCGImageKey];
    
    CATransition *transition = [CATransition animation];
    transition.duration = duration / count;
    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    transition.type = kCATransitionFade;
    transition.fillMode = kCAFillModeForwards;
    transition.repeatCount = 1;
    transition.removedOnCompletion = false;
    transition.delegate = self;
    [self.layer addAnimation:transition forKey:kFadeAnimationKey];
    self.layer.contents = cgImage;
}

#pragma mark - Public Methods
- (void)addBlurEffect:(CGFloat)boxSize times:(NSUInteger)times {
    if (self.image) {
        UIImage *image;
        for (NSInteger i = 0; i < times; i++) {
            image = [self.image blurEffect:boxSize];
        }
        self.image = image;
    }
}

- (void)configrationForBlurAnimation:(CGFloat)boxSize {
    if (self.image) {
        [self.cgImages addObject:(__bridge id)self.image.CGImage];
        
        CGFloat newBoxSize = boxSize;
        if (newBoxSize > 200) {
            newBoxSize = 200;
        } else if (newBoxSize < 0) {
            newBoxSize = 0;
        }
        
        CGFloat number = sqrt((CGFloat)newBoxSize) / (CGFloat)kMaxImageCount;
        
        UIImage *image = self.image;
        for (NSInteger index = 0; index < kMaxImageCount; index++) {
            CGFloat value = (double)index * number;
            CGFloat boxSize = value * value;
            
            image = [image blurEffect:boxSize];
            
            CGImageRef cgImage = image.CGImage;
            [self.cgImages addObject:(__bridge id)cgImage];
        }
    }
}

-(void)setBlur:(float)blur
{
    CGFloat newPercentage = blur;
    if (newPercentage < 0.0f) {
        newPercentage = 0.0f;
    } else if (newPercentage >= 1.0f) {
        newPercentage = 0.99f;
    }
    
    if (self.previousPercentage - newPercentage  > 0) {
        NSInteger index = (NSInteger)floor(newPercentage * 10) + 1;
        if (index > 0) {
            [self setLayers:index percentage:newPercentage currentIndex:index - 1 nextIndex:index];
        }
    } else {
        NSInteger index = (NSInteger)floor(newPercentage * 10);
        if (index < self.cgImages.count - 1) {
            [self setLayers:index percentage:newPercentage currentIndex:index nextIndex:index + 1];
        }
    }
    self.previousPercentage = newPercentage;
}

-(float)blur
{
    return self.previousPercentage;
}

#pragma mark - CAAnimationDelegate
- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    if (flag) {
        if ([anim isMemberOfClass:[CATransition class]]) {
            [self.layer removeAnimationForKey:kFadeAnimationKey];
        }
    }
}

@end