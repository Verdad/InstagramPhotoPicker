//
//  TakePhotoViewController.h
//  Pods
//
//  Created by Cameron McCord on 11/28/16.
//
//

#import <UIKit/UIKit.h>
#import "TWPhotoPickerController.h"

@interface TakePhotoViewController : UIViewController

@property (weak, nonatomic)  TWPhotoPickerController *delegate;

@end
