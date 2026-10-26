// DepthLock - kerangka efek depth wallpaper Lock Screen (iOS 16, roothide)
//
// Ide: potong subjek (orang) dari wallpaper dengan Vision, lalu taruh
// potongan itu DI ATAS view jam. Jam jadi terlihat "di belakang" subjek.
//
// CATATAN: nama class di bawah (CSCoverSheetView, *DateView, *Wallpaper*)
// adalah tebakan terbaik dan HARUS diverifikasi di perangkatmu
// (FLEX / cycript / class-dump). Semua pencarian view dibuat longgar
// berdasarkan potongan nama supaya mudah disesuaikan.

#import <UIKit/UIKit.h>
#import <Vision/Vision.h>
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>

#define DLLog(fmt, ...) NSLog(@"[DepthLock] " fmt, ##__VA_ARGS__)

static const NSInteger kDLCutoutTag = 0xD3E7;

// ---------- util pencarian view ----------

static BOOL DLNameContains(UIView *v, NSString *needle) {
    return [NSStringFromClass(v.class) rangeOfString:needle
                                             options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static UIView *DLFind(UIView *root, BOOL (^pred)(UIView *)) {
    if (pred(root)) return root;
    for (UIView *s in root.subviews) {
        UIView *r = DLFind(s, pred);
        if (r) return r;
    }
    return nil;
}

// Wallpaper bisa berada di window lain (SpringBoard punya banyak window),
// jadi cari di semua window.
static UIView *DLFindInAllWindows(BOOL (^pred)(UIView *)) {
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        UIView *r = DLFind(w, pred);
        if (r) return r;
    }
    return nil;
}

// ---------- Vision: potong subjek ----------

static UIImage *DLSnapshot(UIView *v) {
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithBounds:v.bounds];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [v.layer renderInContext:ctx.CGContext];
    }];
}

static UIImage *DLCutout(UIImage *img) {
    CGImageRef cg = img.CGImage;
    if (!cg) return nil;

    VNGeneratePersonSegmentationRequest *req = [VNGeneratePersonSegmentationRequest new];
    req.qualityLevel = VNGeneratePersonSegmentationRequestQualityLevelBalanced;
    req.outputPixelFormat = kCVPixelFormatType_OneComponent8;

    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:cg options:@{}];
    NSError *err = nil;
    if (![handler performRequests:@[req] error:&err] || req.results.count == 0) {
        DLLog(@"segmentasi gagal: %@", err);
        return nil;
    }

    CVPixelBufferRef maskBuf = ((VNPixelBufferObservation *)req.results.firstObject).pixelBuffer;
    CIImage *orig = [CIImage imageWithCGImage:cg];
    CIImage *mask = [CIImage imageWithCVPixelBuffer:maskBuf];

    CGFloat sx = orig.extent.size.width  / mask.extent.size.width;
    CGFloat sy = orig.extent.size.height / mask.extent.size.height;
    mask = [mask imageByApplyingTransform:CGAffineTransformMakeScale(sx, sy)];

    CIFilter *blend = [CIFilter filterWithName:@"CIBlendWithMask"];
    [blend setValue:orig forKey:kCIInputImageKey];
    [blend setValue:[CIImage emptyImage] forKey:kCIInputBackgroundImageKey];
    [blend setValue:mask forKey:kCIInputMaskImageKey];

    CIContext *ctx = [CIContext contextWithOptions:nil];
    CGImageRef out = [ctx createCGImage:blend.outputImage fromRect:orig.extent];
    if (!out) return nil;
    UIImage *result = [UIImage imageWithCGImage:out scale:img.scale orientation:UIImageOrientationUp];
    CGImageRelease(out);
    return result;
}

// ---------- hook ----------

%hook CSCoverSheetView

- (void)didMoveToWindow {
    %orig;
    if (self.window) {
        // beri waktu supaya wallpaper & jam selesai dirender
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self dl_applyDepth];
        });
    }
}

%new
- (void)dl_applyDepth {
    UIView *dateView = DLFind(self, ^BOOL(UIView *v) {
        return DLNameContains(v, @"LockScreenDateView") || DLNameContains(v, @"DateView");
    });
    UIView *wallpaper = DLFindInAllWindows(^BOOL(UIView *v) {
        return DLNameContains(v, @"WallpaperView") || DLNameContains(v, @"PosterWallpaper");
    });

    if (!dateView || !wallpaper || !dateView.superview) {
        DLLog(@"view tidak ketemu (date=%@ wallpaper=%@)", dateView, wallpaper);
        return;
    }
    DLLog(@"date=%@ wallpaper=%@", NSStringFromClass(dateView.class), NSStringFromClass(wallpaper.class));

    UIView *host = dateView.superview;
    [[host viewWithTag:kDLCutoutTag] removeFromSuperview];

    UIImage *snap = DLSnapshot(wallpaper);
    CGRect target = [wallpaper convertRect:wallpaper.bounds toView:host];

    // Vision berat -> kerjakan di background
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        UIImage *cut = DLCutout(snap);
        if (!cut) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            UIImageView *iv = [[UIImageView alloc] initWithImage:cut];
            iv.tag = kDLCutoutTag;
            iv.frame = target;
            iv.contentMode = UIViewContentModeScaleAspectFill;
            iv.userInteractionEnabled = NO;
            [host insertSubview:iv aboveSubview:dateView];
        });
    });
}

%end
