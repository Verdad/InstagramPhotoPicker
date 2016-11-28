//
//  TakePhotoViewController.m
//  Pods
//
//  Created by Cameron McCord on 11/28/16.
//
//

#import "TakePhotoViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface UIImage (PreviewCropping)

- (UIImage *)cropToPreviewLayerBounds:(AVCaptureVideoPreviewLayer *)previewLayer;
- (UIImage *)resizeToHeight:(CGFloat)height;

@end

@implementation UIImage (PreviewCropping)

-(UIImage *)resizeToHeight:(CGFloat)height {
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, ceilf(height / self.size.height * self.size.width), height)];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.image = self;
    UIGraphicsBeginImageContext(imageView.bounds.size);
    [imageView.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

-(UIImage *)cropToPreviewLayerBounds:(AVCaptureVideoPreviewLayer *)previewLayer {
    CGRect previewImageLayerBounds = previewLayer.bounds;
    
    // This calculates the crop area.
    // keeping in mind that this works with on an unrotated image (so a portrait image is actually rotated counterclockwise)
    // thats why we use originalHeight to calculate the width
    CGFloat originalWidth  = self.size.width;
    CGFloat originalHeight = self.size.height;
    
    CGPoint A = previewImageLayerBounds.origin;
    CGPoint B = CGPointMake(previewImageLayerBounds.size.width, previewImageLayerBounds.origin.y);
//    CGPoint C = CGPointMake(self.imageViewTop.bounds.origin.x, self.imageViewTop.bounds.size.height);
    CGPoint D = CGPointMake(previewImageLayerBounds.size.width, previewImageLayerBounds.size.height);
    
    [previewLayer captureDevicePointOfInterestForPoint:A];
    CGPoint a = [previewLayer captureDevicePointOfInterestForPoint:A];
    CGPoint b = [previewLayer captureDevicePointOfInterestForPoint:B];
//    CGPoint c = [previewLayer captureDevicePointOfInterestForPoint:C];
    CGPoint d = [previewLayer captureDevicePointOfInterestForPoint:D];
    
    CGFloat posX = floor(b.x * originalHeight);
    CGFloat posY = floor(b.y * originalWidth);
    
    CGFloat width = d.x * originalHeight - b.x * originalHeight;
    CGFloat height = a.y * originalWidth - b.y * originalWidth;
    CGRect cropRectangle = CGRectMake(posX, posY, width, height);
    
    // This performs the image cropping.
    CGImageRef imageRef = CGImageCreateWithImageInRect(self.CGImage, cropRectangle);
    UIImage *image = [UIImage imageWithCGImage:imageRef scale:self.scale orientation:self.imageOrientation];
    return image;
}

@end

@interface TakePhotoViewController () {
    int flashSettingIndex;
    BOOL useFrontCamera;
}
@property (strong, nonatomic) UIButton *flashButton;
@property (strong, nonatomic) UIButton *cameraTypeButton;
@property (strong, nonatomic) UIView *navigationView;
@property (strong, nonatomic) UIView *previewView;
@property (strong, nonatomic) UIView *controlView;
@property (strong, nonatomic) UIView *bottomNavView;
@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *previewLayer;
@property (strong, nonatomic) AVCaptureStillImageOutput *stillImageOutput;
@property (strong, nonatomic) AVCaptureDevice *camera;
@end

@implementation TakePhotoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    flashSettingIndex = 1;
    useFrontCamera = NO;
    [self updateCameraViewForCameraType];
    
    [self.view setBackgroundColor:[UIColor blackColor]];
    [self.view addSubview:self.navigationView];
    [self.view addSubview:self.previewView];
    [self.view addSubview:self.controlView];
    [self.view addSubview:self.bottomNavView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)toggleFlashSetting {
    if(flashSettingIndex == 0){
        return;
    }
    flashSettingIndex++;
    if(flashSettingIndex > 3) {
        flashSettingIndex = 1;
    }
    [self updateFlashButtonImage];
}

- (void)toggleCameraType {
    useFrontCamera = !useFrontCamera;
    [self updateCameraViewForCameraType];
    [self setupCamera];
}

- (void)updateCameraViewForCameraType {
    AVCaptureDevice *backCamera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *frontCamera = NULL;
    
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if([device position] == AVCaptureDevicePositionFront) {
            frontCamera = device;
            break;
        }
    }
    
    self.camera = backCamera;
    if(useFrontCamera) {
        self.camera = frontCamera;
    }
    
    [self updateFlashButtonImage];
}

- (void)updateFlashButtonImage {
    
    if (self.camera.hasFlash) {
        NSError *error = NULL;
        [self.camera lockForConfiguration:&error];
        [self.camera setFlashMode:[self mode:flashSettingIndex]];
        [self.camera unlockForConfiguration];
    }else{
        flashSettingIndex = 0;
    }
    
    NSString *imageName;
    switch (flashSettingIndex) {
        case 0:
            imageName = @"FlashUnavailable";
            break;
        case 1:
            imageName = @"FlashAuto";
            break;
        case 2:
            imageName = @"FlashOff";
            break;
        case 3:
            imageName = @"FlashOn";
            break;
        default:
            [NSException raise:[NSString stringWithFormat:@"Invalid index for flash mode: %i", flashSettingIndex] format:@"Index must be 0...3"];
            return;
    }
    [self.flashButton setBackgroundImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
}

- (AVCaptureFlashMode)mode:(int)index {
    switch (index) {
        case 0:
            return NULL;
        case 1:
            return AVCaptureFlashModeAuto;
        case 2:
            return AVCaptureFlashModeOff;
        case 3:
            return AVCaptureFlashModeOn;
        default:
            [NSException raise:[NSString stringWithFormat:@"Invalid index for flash mode: %i", index] format:@"Index must be 0...3"];
            break;
    }
}

- (void)disconnectSession {
    [self.captureSession stopRunning];
    [self.captureSession removeInput:self.videoDeviceInput];
    [self.captureSession removeOutput:self.stillImageOutput];
    [self.previewLayer removeFromSuperlayer];
    
    self.captureSession = NULL;
    self.videoDeviceInput = NULL;
    self.stillImageOutput = NULL;
    self.previewLayer = NULL;
}

- (void)cancel {
    [self disconnectSession];
    
    self.navigationView = NULL;
    self.previewView = NULL;
    self.controlView = NULL;
    self.bottomNavView = NULL;
    
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)setupCamera {
    if(self.captureSession != NULL) {
        [self disconnectSession];
    }
    self.captureSession = [[AVCaptureSession alloc] init];
    self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto;
    
    NSError *error = NULL;
    self.videoDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.camera error:&error];
    if(error != NULL) {
        NSLog(@"Error setting up caputre session");
        self.videoDeviceInput = NULL;
    }else{
        if([self.captureSession canAddInput:self.videoDeviceInput]) {
            [self.captureSession addInput:self.videoDeviceInput];
            
            self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
            self.stillImageOutput.outputSettings = @{AVVideoCodecKey: AVVideoCodecJPEG};
            if([self.captureSession canAddOutput:self.stillImageOutput]) {
                [self.captureSession addOutput:self.stillImageOutput];
                
                self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
                self.previewLayer.frame = self.previewView.bounds;
                self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
                self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
                [self.previewView.layer addSublayer:self.previewLayer];
                self.previewLayer.frame = self.previewLayer.bounds;
                
                [self updateFlashButtonImage];
                
                [self.previewView bringSubviewToFront:self.flashButton];
                //                                self.flashButton.userInteractionEnabled = YES;
                [self.previewView bringSubviewToFront:self.cameraTypeButton];
                //                                self.cameraTypeButton.userInteractionEnabled = YES;
                
                [self.captureSession startRunning];
            }
        }else{
            NSLog(@"Can't add input to capture session");
        }
    }
}

- (UIView *)previewView {
    if (_previewView == NULL) {
        CGFloat navHeight = 44.0f;
        CGFloat handleHeight = 20.0f;
        CGFloat padding = 1.0;
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        CGRect rect = CGRectMake(0, navHeight, CGRectGetWidth(self.view.bounds), CGRectGetWidth(self.view.bounds));
        _previewView = [[UIView alloc] initWithFrame:rect];
        [_previewView setBackgroundColor:[UIColor whiteColor]];
        
        CGFloat flashButtonWidth = 32;
        CGFloat flashButtonPad = 15;
        CGRect flashFrame = CGRectMake(CGRectGetWidth(self.view.bounds) - flashButtonWidth - flashButtonPad, CGRectGetWidth(self.view.bounds) - flashButtonWidth - flashButtonPad, flashButtonWidth, flashButtonWidth);
        self.flashButton = [[UIButton alloc] initWithFrame:flashFrame];
        [self.flashButton addTarget:self action:@selector(toggleFlashSetting) forControlEvents:UIControlEventTouchUpInside];
        [self.flashButton setTitle:@"" forState:UIControlStateNormal];
        [self updateFlashButtonImage];
        [self.previewView addSubview:self.flashButton];
        
        CGFloat cameraTypeButtonHeight = 29;
        CGFloat cameraTypeButtonWidth = 34;
        self.cameraTypeButton = [[UIButton alloc] initWithFrame:CGRectMake(flashButtonPad, CGRectGetWidth(self.view.bounds) - cameraTypeButtonHeight - flashButtonPad, cameraTypeButtonWidth, cameraTypeButtonHeight)];
        [self.cameraTypeButton addTarget:self action:@selector(toggleCameraType) forControlEvents:UIControlEventTouchUpInside];
        [self.cameraTypeButton setTitle:@"" forState:UIControlStateNormal];
        [self.cameraTypeButton setBackgroundImage:[UIImage imageNamed:@"SwitchCamera"] forState:UIControlStateNormal];
        [self.previewView addSubview:self.cameraTypeButton];
        
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if(granted) {
                    [self setupCamera];
                }else{
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Update Camera Permissions" message:@"To give permissions tap on 'Change Settings' button" preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                        // do nothing
                    }]];
                    [alert addAction:[UIAlertAction actionWithTitle:@"Change Settings" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
                        });
                    }]];
                    [self presentViewController:alert animated:YES completion:NULL];
                }
            });
        }];
    }
    return _previewView;
}

- (UIView *)controlView {
    if (_controlView == NULL) {
        CGFloat navHeight = 44.0f;
        CGFloat handleHeight = 20.0f;
        CGFloat padding = 1.0;
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        CGRect rect = CGRectMake(0, navHeight + CGRectGetWidth(self.view.bounds), CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds) - navHeight - CGRectGetWidth(self.view.bounds) - navHeight);
        _controlView = [[UIView alloc] initWithFrame:rect];
        [_controlView setBackgroundColor:[UIColor whiteColor]];
        
        CGFloat greyDiameter = CGRectGetWidth(self.view.bounds) * 0.25;
        CGRect greyRect = CGRectMake(CGRectGetWidth(self.view.bounds) / 2.0 - greyDiameter / 2.0, rect.size.height / 2.0 - greyDiameter / 2.0, greyDiameter, greyDiameter);
        UIView *greyView = [[UIView alloc] initWithFrame:greyRect];
        greyView.backgroundColor = [UIColor colorWithRed:204.0/255.0 green:204.0/255.0 blue:204.0/255.0 alpha:255.0/255.0];
        greyView.layer.cornerRadius = greyDiameter / 2.0;
        [_controlView addSubview:greyView];
        
        CGFloat buttonDiameter = greyDiameter * 0.7;
        CGRect buttonRect = CGRectMake(CGRectGetWidth(self.view.bounds) / 2.0 - buttonDiameter / 2.0, rect.size.height / 2.0 - buttonDiameter / 2.0, buttonDiameter, buttonDiameter);
        UIButton *button = [[UIButton alloc] initWithFrame:buttonRect];
        button.backgroundColor = [UIColor whiteColor];
        [button setTitle:@"" forState:UIControlStateNormal];
        [button addTarget:self action:@selector(takePhoto) forControlEvents:UIControlEventTouchUpInside];
        button.layer.cornerRadius = buttonDiameter / 2.0;
        [_controlView addSubview:button];
    }
    return _controlView;
}

- (UIView *)navigationView {
    if (_navigationView == NULL) {
        CGFloat navHeight = 44.0f;
        CGFloat handleHeight = 20.0f;
        CGFloat padding = 1.0;
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        CGRect rect = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), navHeight);
        _navigationView = [[UIView alloc] initWithFrame:rect];
        [_navigationView setBackgroundColor:[UIColor whiteColor]];
        
        UILabel *label = [[UILabel alloc] initWithFrame:rect];
        [label setText:@"Photo"];
        label.backgroundColor = [UIColor clearColor];
        label.textColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1];
        label.font = [UIFont systemFontOfSize:17.0f];
        [label setTextAlignment:NSTextAlignmentCenter];
        [_navigationView addSubview:label];
        
        CGRect cancelRect = CGRectMake(20, 0, CGRectGetWidth(self.view.bounds) / 3, navHeight);
        UIButton *cancelButton = [[UIButton alloc] initWithFrame:cancelRect];
        [cancelButton setTitle:@"Cancel" forState:UIControlStateNormal];
        [cancelButton setBackgroundColor:[UIColor clearColor]];
        [cancelButton setTitleColor:[UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1] forState:UIControlStateNormal];
        [cancelButton.titleLabel setFont:[UIFont systemFontOfSize:17.0f]];
        [cancelButton setContentHorizontalAlignment:UIControlContentHorizontalAlignmentLeft];
        [cancelButton addTarget:self action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside];
        [_navigationView addSubview:cancelButton];
    }
    return _navigationView;
}

- (UIView *)bottomNavView {
    if (_bottomNavView == nil) {
        CGFloat navHeight = 44.0f;
        CGRect rect = CGRectMake(0, CGRectGetHeight(self.view.bounds) - navHeight, CGRectGetWidth(self.view.bounds), navHeight);
        self.bottomNavView = [[UIView alloc] initWithFrame:rect];
        self.bottomNavView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
        self.bottomNavView.backgroundColor = [UIColor whiteColor];
        self.bottomNavView.clipsToBounds = YES;
        
        rect = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds) / 2, navHeight);
        UIButton *libraryBtn = [[UIButton alloc] initWithFrame:rect];
        [libraryBtn setTitle:@"Library" forState:UIControlStateNormal];
        [libraryBtn.titleLabel setFont:[UIFont systemFontOfSize:17.0f]];
        [libraryBtn setTitleColor:[UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1] forState:UIControlStateNormal];
        [libraryBtn addTarget:self action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside];
        [self.bottomNavView addSubview:libraryBtn];
        
        rect = CGRectMake(CGRectGetWidth(self.view.bounds) / 2, 0, CGRectGetWidth(self.view.bounds) / 2, navHeight);
        UIButton *photoBtn = [[UIButton alloc] initWithFrame:rect];
        [photoBtn setTitle:@"Photo" forState:UIControlStateNormal];
        [photoBtn.titleLabel setFont:[UIFont systemFontOfSize:17.0f]];
        [photoBtn setTitleColor:[UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1] forState:UIControlStateNormal];
//        [photoBtn addTarget:self action:@selector(takePhotoAction) forControlEvents:UIControlEventTouchUpInside];
        [self.bottomNavView addSubview:photoBtn];
    }
    return _bottomNavView;
}

- (void)takePhoto {
    self.previewLayer.connection.enabled = NO;
    AVCaptureConnection *connection = [_stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    if(connection != NULL) {
        connection.videoOrientation = AVCaptureVideoOrientationPortrait;
        [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
            if(error == NULL) {
                NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                UIImage *image = [UIImage imageWithData:imageData];
                CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData((CFDataRef)imageData);
                CGImageRef cgImageRef = CGImageCreateWithJPEGDataProvider(dataProvider, NULL, YES, kCGRenderingIntentDefault);
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIImage *image = [UIImage imageWithCGImage:cgImageRef scale:1.0 orientation:UIImageOrientationRight];
                    image = [image cropToPreviewLayerBounds:self.previewLayer];
                    [self.delegate tookImage:image];
                    [self cancel];
                });
            }else{
                NSLog(@"Error getting image: %@", error);
            }
        }];
    }
}

@end
