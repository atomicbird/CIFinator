//
//  ViewController.h
//  CIFinator
//
//  Created by Tom Harrington on 2/13/13.
//  Copyright (c) 2013 Tom Harrington. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

- (IBAction)enhance:(id)sender;
- (IBAction)faceZoom:(id)sender;
- (IBAction)tile:(id)sender;
- (IBAction)posterize:(id)sender;
- (IBAction)bump:(id)sender;
- (IBAction)dotScreen:(id)sender;
- (IBAction)twirl:(id)sender;
- (IBAction)pixellate:(id)sender;
- (IBAction)hueAdjust:(id)sender;
- (IBAction)tint:(id)sender;
- (IBAction)falseColor:(id)sender;
- (IBAction)sepiaTone:(id)sender;
- (IBAction)checkerboard:(id)sender;


- (IBAction)getPhoto:(id)sender;
- (IBAction)revert:(id)sender;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *pictureButton;
@property (weak, nonatomic) IBOutlet UIImageView *originalImageView;
@property (weak, nonatomic) IBOutlet UIImageView *filteredImageView;
@end
