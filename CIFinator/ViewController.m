//
//  ViewController.m
//  CIFinator
//
//  Created by Tom Harrington on 2/13/13.
//  Copyright (c) 2013 Tom Harrington. All rights reserved.
//

#import "ViewController.h"

#define RAND_IN_RANGE(low,high) (low + (high - low) * (arc4random_uniform(RAND_MAX) / (double)RAND_MAX))

@interface ViewController () <UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) UIImagePickerController *imagePickerController;
@property (nonatomic, strong) UIPopoverController *imagePickerPopoverController;
@property (nonatomic, strong) UIImage *originalUIImage;
@property (readwrite, strong) CIImage *originalCIImage;
@property (readwrite, strong) CIContext *ciContext;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    CIContext *context = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer : @NO}];
    [self setCiContext:context];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)enhance:(id)sender {
    UIImage *enhancedImage = [self autoEnhancedVersionOfImage:[self originalCIImage]];
    [[self filteredImageView] setImage:enhancedImage];
}

- (UIImage *)autoEnhancedVersionOfImage:(CIImage *)myCIImage
{
    // Analyze the image and get the enhancement filters
    NSArray *autoAdjustmentFilters = [myCIImage autoAdjustmentFiltersWithOptions:@{
                                                       kCIImageAutoAdjustEnhance:@YES,
                                                        kCIImageAutoAdjustRedEye:@YES,
                                      }];
    
    // Chain the enhancement filters together
    CIImage *enhancedCIImage = myCIImage;
    for (CIFilter *filter in autoAdjustmentFilters) {
        [filter setValue:enhancedCIImage forKey:kCIInputImageKey];
        enhancedCIImage = [filter outputImage];
    }
    
    NSLog(@"Auto enhance filters: %@", autoAdjustmentFilters);
    
    CGImageRef enhancedCGImage = [[self ciContext]
                                  createCGImage:enhancedCIImage
                                  fromRect:[enhancedCIImage extent]];
    
    UIImage *enhancedImage = [UIImage imageWithCGImage:enhancedCGImage];
    CFRelease(enhancedCGImage);
    
    return enhancedImage;
}

- (IBAction)faceZoom:(id)sender {
    NSDictionary *detectorOptions = @{CIDetectorAccuracy : CIDetectorAccuracyLow};
    CIDetector *faceDetector = [CIDetector
                                detectorOfType:CIDetectorTypeFace
                                context:nil
                                options:detectorOptions];
    
    NSArray *faces = [faceDetector featuresInImage:[self originalCIImage]
                                           options:nil];
    NSLog(@"Found %d faces", [faces count]);
    
    if ([faces count] > 0) {
        
        CGRect faceZoomRect = CGRectNull;
        
        // Get a rectangle containing all of the faces
        for (CIFaceFeature *face in faces) {
            // Print out info found for each face
            NSLog(@"Found face at %@", NSStringFromCGRect([face bounds]));
            if ([face hasLeftEyePosition]) {
                NSLog(@"Left eye position: %@",
                      NSStringFromCGPoint([face leftEyePosition]));
            }
            if ([face hasRightEyePosition]) {
                NSLog(@"Right eye position: %@",
                      NSStringFromCGPoint([face rightEyePosition]));
            }
            if ([face hasMouthPosition]) {
                NSLog(@"Mouth position: %@",
                      NSStringFromCGPoint([face mouthPosition]));
            }
            
            // Expand the current faceZoomRect to fit the new face
            if (CGRectEqualToRect(faceZoomRect, CGRectNull)) {
                faceZoomRect = [face bounds];
            } else {
                faceZoomRect = CGRectUnion(faceZoomRect, [face bounds]);
            }
        }
        // Pad the face rectangle a little, so faces don't end up on the edge
        faceZoomRect = CGRectIntersection([[self originalCIImage] extent], CGRectInset(faceZoomRect, -50.0, -50.0)) ;
        NSLog(@"Face zoom rect: %@", NSStringFromCGRect(faceZoomRect));
        
        // Crop to the face rectangle
        CIFilter *cropFilter = [CIFilter filterWithName:@"CICrop"];
        [cropFilter setValue:[self originalCIImage] forKey:kCIInputImageKey];
        [cropFilter setValue:[CIVector vectorWithCGRect:faceZoomRect] forKey:@"inputRectangle"];
        
        CIImage *result = [cropFilter valueForKey: @"outputImage"];
        CGImageRef filteredCGImage = [[self ciContext] createCGImage:result fromRect:[result extent]];
        UIImage *filterdImage = [UIImage imageWithCGImage:filteredCGImage];
        [[self filteredImageView] setImage:filterdImage];
        CFRelease(filteredCGImage);
    } else {
        UIAlertView *noFacesAlert = [[UIAlertView alloc]
                                     initWithTitle:@"No Faces"
                                     message:@"Sorry, I couldn't find any faces in this picture."
                                     delegate:nil
                                     cancelButtonTitle:@"OK"
                                     otherButtonTitles:nil];
        [noFacesAlert show];
    }
}

- (IBAction)tile:(id)sender {
    UIImage *tileImage = [self affineTileOfImage:[self originalCIImage]];
    [[self filteredImageView] setImage:tileImage];
}

- (UIImage *)affineTileOfImage:(CIImage *)myCIImage
{
    CIFilter *tileFilter = [CIFilter filterWithName:@"CIAffineTile"];
    NSLog(@"Attributes: %@", [tileFilter attributes]);
    [tileFilter setValue:myCIImage forKey:kCIInputImageKey];
    
    CGAffineTransform transform = CGAffineTransformMakeScale(0.2, 0.2);
    transform = CGAffineTransformRotate(transform, 0.5);
    [tileFilter setValue:[NSValue valueWithBytes:&transform objCType:@encode(CGAffineTransform)] forKey:@"inputTransform"];
    
    CIImage *tileImage = [tileFilter outputImage];
    
	CGImageRef tileCGImage = [[self ciContext] createCGImage:tileImage fromRect:[myCIImage extent]];
	UIImage *tileUIImage = [UIImage imageWithCGImage:tileCGImage];
	CFRelease(tileCGImage);
	
	return tileUIImage;
}

- (IBAction)posterize:(id)sender {
    UIImage *posterImage = [self posterizeImage:[self originalCIImage]];
    [[self filteredImageView] setImage:posterImage];
}

- (UIImage *)posterizeImage:(CIImage *)myCIImage
{
    CIFilter *filter = [CIFilter filterWithName:@"CIColorPosterize"];
    NSLog(@"Attributes: %@", [filter attributes]);
    [filter setValue:myCIImage forKey:kCIInputImageKey];
    [filter setValue:[NSNumber numberWithFloat:6.0] forKey:@"inputLevels"];
    
    CIImage *filteredImage = [filter outputImage];
    
	CGImageRef filteredCGImage = [[self ciContext] createCGImage:filteredImage fromRect:[myCIImage extent]];
	UIImage *filteredUIImage = [UIImage imageWithCGImage:filteredCGImage];
	CFRelease(filteredCGImage);
	
	return filteredUIImage;
}

- (IBAction)bump:(id)sender {
    UIImage *bumpImage = [self bumpDistortImage:[self originalCIImage]];
    [[self filteredImageView] setImage:bumpImage];
}

- (UIImage *)bumpDistortImage:(CIImage *)myCIImage
{
    CIFilter *filter = [CIFilter filterWithName:@"CIBumpDistortion"];
    NSLog(@"Attributes: %@", [filter attributes]);
    [filter setValue:myCIImage forKey:kCIInputImageKey];
    
    CGRect extents = [myCIImage extent];
    CIVector *inputCenter = [CIVector vectorWithX:(extents.size.width/2.0) Y:(extents.size.height)/2.0];
    [filter setValue:inputCenter forKey:@"inputCenter"];
    [filter setValue:[NSNumber numberWithFloat:extents.size.width/2.0] forKey:@"inputRadius"];
    [filter setValue:[NSNumber numberWithFloat:0.5] forKey:@"inputScale"];
    
    CIImage *filteredImage = [filter outputImage];
    
	CGImageRef filteredCGImage = [[self ciContext] createCGImage:filteredImage fromRect:[myCIImage extent]];
	UIImage *filteredUIImage = [UIImage imageWithCGImage:filteredCGImage];
	CFRelease(filteredCGImage);
	
	return filteredUIImage;
}

- (IBAction)dotScreen:(id)sender {
    UIImage *dotScreenImage = [self dotScreenImage:[self originalCIImage]];
    [[self filteredImageView] setImage:dotScreenImage];
}

- (UIImage *)dotScreenImage:(CIImage *)myCIImage
{
    CIFilter *filter = [CIFilter filterWithName:@"CIDotScreen"];
    NSLog(@"Attributes: %@", [filter attributes]);
    [filter setValue:myCIImage forKey:kCIInputImageKey];
    
    CGRect extents = [myCIImage extent];
    CIVector *inputCenter = [CIVector vectorWithX:(extents.size.width/2.0) Y:(extents.size.height)/2.0];
    [filter setValue:inputCenter forKey:@"inputCenter"];
    [filter setValue:[NSNumber numberWithFloat:1.0] forKey:@"inputAngle"];
    [filter setValue:[NSNumber numberWithFloat:60.0] forKey:@"inputWidth"];
    [filter setValue:[NSNumber numberWithFloat:1.7] forKey:@"inputSharpness"];
    
    
    CIImage *filteredImage = [filter outputImage];
    
	CGImageRef filteredCGImage = [[self ciContext] createCGImage:filteredImage fromRect:[myCIImage extent]];
	UIImage *filteredUIImage = [UIImage imageWithCGImage:filteredCGImage];
	CFRelease(filteredCGImage);
	
	return filteredUIImage;
}

- (IBAction)twirl:(id)sender {
    UIImage *twirlImage = [self twirlImage:[self originalCIImage]];
    [[self filteredImageView] setImage:twirlImage];
}

- (UIImage *)twirlImage:(CIImage *)myCIImage
{
    CIFilter *filter = [CIFilter filterWithName:@"CITwirlDistortion"];
    NSLog(@"Attributes: %@", [filter attributes]);
    [filter setValue:myCIImage forKey:kCIInputImageKey];
    
    CGRect extents = [myCIImage extent];
    CIVector *inputCenter = [CIVector vectorWithX:(extents.size.width/2.0) Y:(extents.size.height)/2.0];
    [filter setValue:inputCenter forKey:@"inputCenter"];
    [filter setValue:[NSNumber numberWithFloat:extents.size.width/2.0] forKey:@"inputRadius"];
    [filter setValue:[NSNumber numberWithFloat:M_PI] forKey:@"inputAngle"];
    
    
    CIImage *filteredImage = [filter outputImage];
    
	CGImageRef filteredCGImage = [[self ciContext] createCGImage:filteredImage fromRect:[myCIImage extent]];
	UIImage *filteredUIImage = [UIImage imageWithCGImage:filteredCGImage];
	CFRelease(filteredCGImage);
	
	return filteredUIImage;
}

- (IBAction)pixellate:(id)sender {
    UIImage *pixelImage = [self pixellateImage:[self originalCIImage]];
    [[self filteredImageView] setImage:pixelImage];
}

- (UIImage *)pixellateImage:(CIImage *)myCIImage
{
    CIFilter *filter = [CIFilter filterWithName:@"CIPixellate"];
    NSLog(@"Attributes: %@", [filter attributes]);
    [filter setValue:myCIImage forKey:kCIInputImageKey];
    
    CGRect extents = [myCIImage extent];
    CIVector *inputCenter = [CIVector vectorWithX:(extents.size.width/2.0) Y:(extents.size.height)/2.0];
    [filter setValue:inputCenter forKey:@"inputCenter"];
    [filter setValue:[NSNumber numberWithFloat:20.0] forKey:@"inputScale"];
    
    
    CIImage *filteredImage = [filter outputImage];
    
	CGImageRef filteredCGImage = [[self ciContext] createCGImage:filteredImage fromRect:[myCIImage extent]];
	UIImage *filteredUIImage = [UIImage imageWithCGImage:filteredCGImage];
	CFRelease(filteredCGImage);
	
	return filteredUIImage;
}

- (IBAction)hueAdjust:(id)sender {
    UIImage *hueAdjustImage = [self hueAdjustImage:[self originalCIImage]];
    [[self filteredImageView] setImage:hueAdjustImage];
}

- (UIImage *)hueAdjustImage:(CIImage *)myCIImage
{
    CIFilter *filter = [CIFilter filterWithName:@"CIHueAdjust"];
    [filter setValue:myCIImage forKey:kCIInputImageKey];

	CGFloat inputAngle = RAND_IN_RANGE(-M_PI, M_PI);
    [filter setValue: [NSNumber numberWithFloat: inputAngle] forKey: @"inputAngle"];

    CIImage *filteredImage = [filter outputImage];
    
	CGImageRef filteredCGImage = [[self ciContext] createCGImage:filteredImage fromRect:[myCIImage extent]];
	UIImage *filteredUIImage = [UIImage imageWithCGImage:filteredCGImage];
	CFRelease(filteredCGImage);
	
	return filteredUIImage;
}

- (IBAction)tint:(id)sender {
    UIImage *tintImage = [self tintedImage:[self originalCIImage]];
    [[self filteredImageView] setImage:tintImage];
}

- (UIImage *)tintedImage:(CIImage *)myCIImage
{
    CIFilter *filter = [CIFilter filterWithName:@"CIColorMonochrome"];
	CIColor *tintColor = [self randomCIColor];
	[filter setValue:myCIImage forKey:kCIInputImageKey];
	[filter setValue:tintColor forKey:@"inputColor"];
    
    CIImage *filteredImage = [filter outputImage];
    
	CGImageRef filteredCGImage = [[self ciContext] createCGImage:filteredImage fromRect:[myCIImage extent]];
	UIImage *filteredUIImage = [UIImage imageWithCGImage:filteredCGImage];
	CFRelease(filteredCGImage);
	
	return filteredUIImage;
}

- (IBAction)falseColor:(id)sender {
    UIImage *falseColorImage = [self falseColorImage:[self originalCIImage]];
    [[self filteredImageView] setImage:falseColorImage];
}

- (UIImage *)falseColorImage:(CIImage *)myCIImage
{
	CIFilter *filter = [CIFilter filterWithName:@"CIFalseColor"];
	CIColor *color0 = [self randomCIColor];
	CIColor *color1 = [CIColor colorWithRed:(1.0 - [color0 red])
									  green:(1.0 - [color0 green])
									   blue:(1.0 - [color0 blue])];

	[filter setValue:myCIImage forKey:kCIInputImageKey];
	[filter setValue:color0 forKey:@"inputColor0"];
	[filter setValue:color1 forKey:@"inputColor1"];

    CIImage *filteredImage = [filter outputImage];
    
	CGImageRef filteredCGImage = [[self ciContext] createCGImage:filteredImage fromRect:[myCIImage extent]];
	UIImage *filteredUIImage = [UIImage imageWithCGImage:filteredCGImage];
	CFRelease(filteredCGImage);
	
	return filteredUIImage;
}

- (IBAction)sepiaTone:(id)sender {
	UIImage *sepiaUIImage = [self sepiaImageFromImage:[self originalCIImage]];
	
	[[self filteredImageView] setImage:sepiaUIImage];
}

- (UIImage *)sepiaImageFromImage:(CIImage *)myCIImage
{
    // Set up the sepia filter
    CIFilter *sepiaFilter = [CIFilter filterWithName:@"CISepiaTone"];
    [sepiaFilter setValue:myCIImage forKey:@"inputImage"];
    [sepiaFilter setValue:@0.9 forKey:@"inputIntensity"];
    
    CIImage *sepiaImage = [sepiaFilter outputImage];
    
    // Render the result
    CGImageRef sepiaCGImage = [[self ciContext] createCGImage:sepiaImage
                                            fromRect:[sepiaImage extent]];
    UIImage *sepiaUIImage = [UIImage imageWithCGImage:sepiaCGImage];
    CFRelease(sepiaCGImage);
    
    return sepiaUIImage;
}

- (IBAction)checkerboard:(id)sender {
    CIColor *color0 = [self randomCIColorAlpha];
    CIColor *color1 = [self randomCIColorAlpha];
    CGRect extents = [[self originalCIImage] extent];
    CIVector *inputCenter = [CIVector vectorWithX:(extents.size.width/2.0) Y:(extents.size.height)/2.0];
    int bandCount = RAND_IN_RANGE(1, 20);
	NSLog(@"checkerboard band count: %d", bandCount);
    CGFloat inputWidth = extents.size.width / bandCount;
    CGFloat inputSharpness = RAND_IN_RANGE(0, 1);
    
	// Generate a checkerboard pattern with random paramaters. The resulting image has infinite extent.
    CIFilter *checkerboardGenerator = [CIFilter filterWithName:@"CICheckerboardGenerator"];
    [checkerboardGenerator setValue:color0 forKey:@"inputColor0"];
    [checkerboardGenerator setValue:color1 forKey:@"inputColor1"];
    [checkerboardGenerator setValue:inputCenter forKey:@"inputCenter"];
    [checkerboardGenerator setValue:[NSNumber numberWithFloat:inputWidth] forKey:@"inputWidth"];
    [checkerboardGenerator setValue:[NSNumber numberWithFloat:inputSharpness] forKey:@"inputSharpness"];
	CIImage *checkerboardImage = [checkerboardGenerator outputImage];
	
	// Crop the checkerboard pattern to the size of the image.
	CIFilter *cropToImageSizeFilter = [CIFilter filterWithName:@"CICrop"];
	[cropToImageSizeFilter setValue:checkerboardImage forKey:kCIInputImageKey];
	[cropToImageSizeFilter setValue:[CIVector vectorWithCGRect:[[self originalCIImage] extent]] forKey:@"inputRectangle"];
	CIImage *checkerboardImageCropped = [cropToImageSizeFilter outputImage];
	
	// Overlay the cropped checkerboard on the original image
	CIFilter *overlayFilter = [CIFilter filterWithName:@"CISourceOverCompositing"];
	[overlayFilter setValue:checkerboardImageCropped forKey:kCIInputImageKey];
	[overlayFilter setValue:[self originalCIImage] forKey:kCIInputBackgroundImageKey];
	
    //    [checkerboardGenerator setValue:[self originalCIImage] forKey:kCIInputImageKey];
    
    CIImage *result = [overlayFilter valueForKey: @"outputImage"];
	CGImageRef filteredCGImage = [[self ciContext] createCGImage:result fromRect:[result extent]];
    UIImage *filterdImage = [UIImage imageWithCGImage:filteredCGImage];
	CFRelease(filteredCGImage);

    [[self filteredImageView] setImage:filterdImage];
}

- (IBAction)getPhoto:(id)sender {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
    [actionSheet setDelegate:self];
    [actionSheet addButtonWithTitle:@"Choose from Library"];
    BOOL hasCamera = [UIImagePickerController
                      isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
    if (hasCamera) {
        [actionSheet addButtonWithTitle:@"Take Photo"];
    }
    [actionSheet showFromBarButtonItem:[self pictureButton] animated:YES];
}

- (IBAction)revert:(id)sender {
    [[self filteredImageView] setImage:[self originalUIImage]];
}

#pragma mark - UIActionSheetDelegate
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // Do nothing if the user taps outside the action
    // sheet (thus closing the popover containing the
    // action sheet).
    if (buttonIndex < 0) {
        return;
    }
    
    if (buttonIndex == 0) {
        // Get from library
        [self presentPhotoLibrary];
    } else if (buttonIndex == 1) {
        // Use camera
        [self presentCamera];
    }
}

#pragma mark - Image acquisition helpers
- (void)presentCamera
{
    // Display the camera.
    UIImagePickerController *imagePicker = [self imagePickerController];
    [imagePicker setSourceType:UIImagePickerControllerSourceTypeCamera];
    [self presentViewController:imagePicker animated:YES completion:nil];
}

- (void)presentPhotoLibrary
{
    // Display assets from the photo library only.
    UIImagePickerController *imagePicker = [self imagePickerController];
    [imagePicker setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
    
    UIPopoverController *newPopoverController =
    [[UIPopoverController alloc] initWithContentViewController:imagePicker];
    [newPopoverController presentPopoverFromBarButtonItem:[self pictureButton]
                                 permittedArrowDirections:UIPopoverArrowDirectionAny
                                                 animated:YES];
    [self setImagePickerPopoverController:newPopoverController];
}

- (UIImagePickerController *)imagePickerController
{
    if (_imagePickerController) {
        return _imagePickerController;
    }
    
    UIImagePickerController *imagePickerController =  nil;
    imagePickerController = [[UIImagePickerController alloc] init];
    [imagePickerController setDelegate:self];
    [self setImagePickerController:imagePickerController];
    
    return _imagePickerController;
}

#pragma mark - UIImagePickerControllerDelegate methods
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    // If the popover controller is available,
    // assume the photo is selected from the library
    // and not from the camera.
    BOOL takenWithCamera = ([self imagePickerPopoverController] == nil);
    
    if (takenWithCamera) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [[self imagePickerPopoverController] dismissPopoverAnimated:YES];
        [self setImagePickerPopoverController:nil];
    }
    
    // Retrieve and display the image.
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    [self setOriginalUIImage:image];
    [[self originalImageView] setImage:image];
    [[self filteredImageView] setImage:image];
    
    CIImage *ciImage = [CIImage imageWithCGImage:[image CGImage]];
    [self setOriginalCIImage:ciImage];
}

#pragma mark - Color
- (CIColor *)randomCIColor
{
	CIColor *randomColor = [CIColor colorWithRed:RAND_IN_RANGE(0.0, 1.0)
										   green:RAND_IN_RANGE(0.0, 1.0)
											blue:RAND_IN_RANGE(0.0, 1.0)];
	return randomColor;
}

- (CIColor *)randomCIColorAlpha
{
	CIColor *randomColor = [CIColor colorWithRed:RAND_IN_RANGE(0.0, 1.0)
										   green:RAND_IN_RANGE(0.0, 1.0)
											blue:RAND_IN_RANGE(0.0, 1.0)
                                           alpha:RAND_IN_RANGE(0.0, 1.0)];
	return randomColor;
}

@end
