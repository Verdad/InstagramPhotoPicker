//
//  TWPhotoPickerController.m
//  InstagramPhotoPicker
//
//  Created by Emar on 12/4/14.
//  Copyright (c) 2014 wenzhaot. All rights reserved.
//

#import "TWPhotoPickerController.h"
#import "TWPhotoCollectionViewCell.h"
#import "TWImageScrollView.h"
#import "TWPhotoLoader.h"

@interface TWPhotoPickerController ()<UICollectionViewDataSource, UICollectionViewDelegate> {
    CGFloat beginOriginY;
}
@property (strong, nonatomic) UIView *topView;
@property (strong, nonatomic) UIView *bottomView;
@property (strong, nonatomic) UIImageView *maskView;
@property (strong, nonatomic) UICollectionView *collectionView;
@property (strong, nonatomic) TWImageScrollView *imageScrollViewLeft;
@property (strong, nonatomic) TWImageScrollView *imageScrollViewRight;

@property (assign) BOOL isLeftSelected;

@property (strong, nonatomic) NSArray *allPhotos;
@end

@implementation TWPhotoPickerController

#pragma mark - life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self.view setBackgroundColor:[UIColor whiteColor]];
    [self.view addSubview:self.topView];
    [self.view insertSubview:self.collectionView belowSubview:self.topView];
    [self.view insertSubview:self.bottomView aboveSubview:self.collectionView];
    
    [self loadPhotos];
    
    [self setIsLeftSelected:YES];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}



#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self.allPhotos count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"TWPhotoCollectionViewCell";
    
    TWPhotoCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CellIdentifier forIndexPath:indexPath];
    TWPhoto *photo = [self.allPhotos objectAtIndex:indexPath.row];
    cell.imageView.image = photo.thumbnailImage;
    
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    TWPhoto *photo = [self.allPhotos objectAtIndex:indexPath.row];
    //TODO Add logic here to select which photo you're editing
    if (self.isLeftSelected) {
        [self.imageScrollViewLeft displayImage:photo.originalImage];
    } else {
        [self.imageScrollViewRight displayImage:photo.originalImage];
    }
    if (self.topView.frame.origin.y != 0) {
        [self tapGestureAction:nil];
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    if (velocity.y >= 2.0 && self.topView.frame.origin.y == 0) {
        [self tapGestureAction:nil];
    }
}



#pragma mark - event response

- (void)backAction {
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)cropAction {
    if (self.cropBlock) {
        self.cropBlock(self.imageScrollViewLeft.capture, self.imageScrollViewRight.capture);
    }
    //[self backAction];
}

- (void)panGestureAction:(UIPanGestureRecognizer *)panGesture {
    switch (panGesture.state)
    {
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
        {
            CGRect topFrame = self.topView.frame;
            CGRect bottomFrame = self.bottomView.frame;
            CGFloat endOriginY = self.topView.frame.origin.y;
            if (endOriginY > beginOriginY) {
                topFrame.origin.y = (endOriginY - beginOriginY) >= 20 ? 0 : -(CGRectGetHeight(self.topView.bounds)-20-44);
            } else if (endOriginY < beginOriginY) {
                topFrame.origin.y = (beginOriginY - endOriginY) >= 20 ? -(CGRectGetHeight(self.topView.bounds)-20-44) : 0;
            }
            
            CGRect collectionFrame = self.collectionView.frame;
            collectionFrame.origin.y = CGRectGetMaxY(topFrame);
            collectionFrame.size.height = CGRectGetHeight(self.view.bounds) - CGRectGetMaxY(topFrame) - CGRectGetHeight(bottomFrame);
            [UIView animateWithDuration:.3f animations:^{
                self.topView.frame = topFrame;
                self.collectionView.frame = collectionFrame;
            }];
            break;
        }
        case UIGestureRecognizerStateBegan:
        {
            beginOriginY = self.topView.frame.origin.y;
            break;
        }
        case UIGestureRecognizerStateChanged:
        {
            CGPoint translation = [panGesture translationInView:self.view];
            CGRect topFrame = self.topView.frame;
            topFrame.origin.y = translation.y + beginOriginY;
            
            CGRect collectionFrame = self.collectionView.frame;
            collectionFrame.origin.y = CGRectGetMaxY(topFrame);
            collectionFrame.size.height = CGRectGetHeight(self.view.bounds) - CGRectGetMaxY(topFrame);
            
            if (topFrame.origin.y <= 0 && (topFrame.origin.y >= -(CGRectGetHeight(self.topView.bounds)-20-44))) {
                self.topView.frame = topFrame;
                self.collectionView.frame = collectionFrame;
            }
            
            break;
        }
        default:
            break;
    }
}

- (void)tapGestureAction:(UITapGestureRecognizer *)tapGesture {
    CGRect topFrame = self.topView.frame;
    topFrame.origin.y = topFrame.origin.y == 0 ? -(CGRectGetHeight(self.topView.bounds)-20-44) : 0;
    
    CGRect collectionFrame = self.collectionView.frame;
    collectionFrame.origin.y = CGRectGetMaxY(topFrame);
    collectionFrame.size.height = CGRectGetHeight(self.view.bounds) - CGRectGetMaxY(topFrame);
    [UIView animateWithDuration:.3f animations:^{
        self.topView.frame = topFrame;
        self.collectionView.frame = collectionFrame;
    }];
}

- (void)tapGestureImageAction:(UITapGestureRecognizer *)tapGesture {
    [self setIsLeftSelected:(tapGesture.view == self.imageScrollViewLeft)];
}

- (void)tapGestureImageHorizontalAction:(UITapGestureRecognizer *)tapGesture {
    CGFloat navHeight = 44.0f;
    CGFloat handleHeight = 20.0f;
    CGFloat padding = 1.0;
    CGRect rect = CGRectMake(0, navHeight, CGRectGetWidth(self.view.bounds), CGRectGetMaxX(self.view.bounds) / 2);
    [self.imageScrollViewLeft setFrame:rect];
    rect.origin.y = CGRectGetMaxY(self.imageScrollViewLeft.bounds) + 44;
    [self.imageScrollViewRight setFrame:rect];
}

- (void)tapGestureImageVerticalAction:(UITapGestureRecognizer *)tapGesture {
    CGFloat navHeight = 44.0f;
    CGFloat handleHeight = 20.0f;
    CGFloat padding = 1.0;
    CGRect rect = CGRectMake(0, 44.0f, (CGRectGetWidth(self.topView.bounds) / 2) - padding, CGRectGetHeight(self.topView.bounds)-navHeight-handleHeight);
    [self.imageScrollViewLeft setFrame:rect];
    CGFloat x = (CGRectGetWidth(self.topView.bounds) / 2) + padding * 2;
    rect = CGRectMake(x, navHeight, CGRectGetWidth(self.topView.bounds) / 2, CGRectGetHeight(self.topView.bounds)-navHeight-handleHeight);
    [self.imageScrollViewRight setFrame:rect];
}



#pragma mark - private methods

- (void)loadPhotos {
    [TWPhotoLoader loadAllPhotos:^(NSArray *photos, NSError *error) {
        if (!error) {
            self.allPhotos = [NSArray arrayWithArray:photos];
            if (self.allPhotos.count) {
                TWPhoto *firstPhoto = [self.allPhotos objectAtIndex:0];
                [self.imageScrollViewLeft displayImage:firstPhoto.originalImage];
                [self.imageScrollViewRight displayImage:firstPhoto.originalImage];
            }
            [self.collectionView reloadData];
        } else {
            NSLog(@"Load Photos Error: %@", error);
        }
    }];
    
}



#pragma mark - getters & setters

- (UIView *)topView {
    if (_topView == nil) {
        CGFloat navHeight = 44.0f;
        CGFloat handleHeight = 20.0f;
        CGFloat padding = 1.0;
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        CGRect rect = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), CGRectGetWidth(self.view.bounds) + navHeight + 20);
        self.topView = [[UIView alloc] initWithFrame:rect];
        self.topView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
        self.topView.backgroundColor = [UIColor clearColor];
        self.topView.clipsToBounds = YES;
        
        rect = CGRectMake(0, 0, CGRectGetWidth(self.topView.bounds), navHeight);
        UIView *navView = [[UIView alloc] initWithFrame:rect];//26 29 33
        navView.backgroundColor = [UIColor colorWithRed:0.97 green:0.97 blue:0.97 alpha:1];
        [self.topView addSubview:navView];
        
        rect = CGRectMake(15, 0, 60, CGRectGetHeight(navView.bounds));
        UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        backBtn.frame = rect;
        [backBtn setTitle:@"Cancel" forState:UIControlStateNormal];
        [backBtn setTitleColor:[UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1] forState:UIControlStateNormal];
        [backBtn.titleLabel setFont:[UIFont systemFontOfSize:17.0f]];
        [backBtn addTarget:self action:@selector(backAction) forControlEvents:UIControlEventTouchUpInside];
        [navView addSubview:backBtn];
        
        rect = CGRectMake((CGRectGetWidth(navView.bounds)-100)/2, 0, 100, CGRectGetHeight(navView.bounds));
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:rect];
        titleLabel.text = @"Camera Roll";
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.textColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1];
        titleLabel.font = [UIFont systemFontOfSize:17.0f];
        [navView addSubview:titleLabel];
        
        rect = CGRectMake(CGRectGetWidth(navView.bounds)-80, 0, 80, CGRectGetHeight(navView.bounds));
        UIButton *cropBtn = [[UIButton alloc] initWithFrame:rect];
        [cropBtn setTitle:@"Next" forState:UIControlStateNormal];
        [cropBtn.titleLabel setFont:[UIFont systemFontOfSize:17.0f]];
        [cropBtn setTitleColor:[UIColor colorWithRed:0.95 green:0.42 blue:0.30 alpha:1] forState:UIControlStateNormal];
        [cropBtn addTarget:self action:@selector(cropAction) forControlEvents:UIControlEventTouchUpInside];
        [navView addSubview:cropBtn];
        
        rect = CGRectMake(0, CGRectGetHeight(self.topView.bounds) - handleHeight, CGRectGetWidth(self.topView.bounds), 20);
        UIView *dragView = [[UIView alloc] initWithFrame:rect];
        dragView.backgroundColor = [UIColor grayColor];
        dragView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
        [self.topView addSubview:dragView];
        
        UIImage *img = [UIImage imageNamed:@"cameraroll-picker-grip.png" inBundle:bundle compatibleWithTraitCollection:nil];
        rect = CGRectMake((CGRectGetWidth(dragView.bounds)-img.size.width)/2, (CGRectGetHeight(dragView.bounds)-img.size.height)/2, img.size.width, img.size.height);
        UIImageView *gripView = [[UIImageView alloc] initWithFrame:rect];
        gripView.image = img;
        [dragView addSubview:gripView];
        
        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureAction:)];
        [dragView addGestureRecognizer:panGesture];
        
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureAction:)];
        [dragView addGestureRecognizer:tapGesture];
        
        [tapGesture requireGestureRecognizerToFail:panGesture];
        
        UITapGestureRecognizer *imageTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureImageAction:)];
        UITapGestureRecognizer *leftImageTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureImageAction:)];
        
        //Left image
        rect = CGRectMake(0, navHeight, (CGRectGetWidth(self.topView.bounds) / 2) - padding, CGRectGetHeight(self.topView.bounds)-navHeight-handleHeight);
        self.imageScrollViewLeft = [[TWImageScrollView alloc] initWithFrame:rect];
        self.imageScrollViewLeft.clipsToBounds = YES;
        [self.imageScrollViewLeft addGestureRecognizer:leftImageTapGesture];
        [self.topView addSubview:self.imageScrollViewLeft];
        [self.topView sendSubviewToBack:self.imageScrollViewLeft];
        
//        self.maskView = [[UIImageView alloc] initWithFrame:rect];
        
//        self.maskView.image = [UIImage imageNamed:@"straighten-grid.png" inBundle:bundle compatibleWithTraitCollection:nil];
//        [self.topView insertSubview:self.maskView aboveSubview:self.imageScrollViewLeft];
//        [self.imageScrollViewLeft addGestureRecognizer:leftImageTapGesture];
        
        //Right image
        CGFloat x = (CGRectGetWidth(self.topView.bounds) / 2) + padding * 2;
        rect = CGRectMake(x, navHeight, CGRectGetWidth(self.topView.bounds) / 2, CGRectGetHeight(self.topView.bounds)-navHeight-handleHeight);
        self.imageScrollViewRight = [[TWImageScrollView alloc] initWithFrame:rect];
        self.imageScrollViewRight.clipsToBounds = YES;
        [self.imageScrollViewRight addGestureRecognizer:imageTapGesture];
        [self.topView addSubview:self.imageScrollViewRight];
        [self.topView sendSubviewToBack:self.imageScrollViewRight];
        
//        self.maskView = [[UIImageView alloc] initWithFrame:rect];
        
//        self.maskView.image = [UIImage imageNamed:@"straighten-grid.png" inBundle:bundle compatibleWithTraitCollection:nil];
//        [self.topView insertSubview:self.maskView aboveSubview:self.imageScrollViewLeft];
//        [self.imageScrollViewRight addGestureRecognizer:imageTapGesture];
        
        //Picture Settings
        CGFloat circleDiameter = 32.0f;
        rect = CGRectMake(CGRectGetMaxX(self.topView.bounds) - circleDiameter * 2, CGRectGetMaxY(self.topView.bounds) - CGRectGetHeight(dragView.bounds) - circleDiameter - 5, circleDiameter, circleDiameter);
        UIButton *horizontalBtn = [[UIButton alloc] initWithFrame:rect];
        [horizontalBtn setImage:[UIImage imageNamed:@"vertical.pdf"] forState: UIControlStateNormal];
        [horizontalBtn addTarget:self action:@selector(tapGestureImageVerticalAction:) forControlEvents:UIControlEventTouchUpInside];
        horizontalBtn.backgroundColor = [UIColor blueColor];
        horizontalBtn.layer.cornerRadius = circleDiameter / 2;
        [self.topView addSubview:horizontalBtn];
        
        rect = CGRectMake(CGRectGetMaxX(self.topView.bounds) - circleDiameter, CGRectGetMaxY(self.topView.bounds) - CGRectGetHeight(dragView.bounds) - circleDiameter - 5, circleDiameter, circleDiameter);
        UIButton *verticalBtn = [[UIButton alloc] initWithFrame:rect];
        [verticalBtn setImage:[UIImage imageNamed:@"vertical.pdf"] forState: UIControlStateNormal];
        [verticalBtn addTarget:self action:@selector(tapGestureImageHorizontalAction:) forControlEvents:UIControlEventTouchUpInside];
        verticalBtn.backgroundColor = [UIColor greenColor];
        verticalBtn.layer.cornerRadius = circleDiameter / 2;
        [self.topView addSubview:verticalBtn];
    }
    return _topView;
}

- (UIView *)bottomView {
    if (_bottomView == nil) {
        CGFloat navHeight = 44.0f;
        CGRect rect = CGRectMake(0, CGRectGetHeight(self.view.bounds) - navHeight, CGRectGetWidth(self.view.bounds), navHeight);
        self.bottomView = [[UIView alloc] initWithFrame:rect];
        self.bottomView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
        self.bottomView.backgroundColor = [UIColor whiteColor];
        self.bottomView.clipsToBounds = YES;
        
        rect = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds) / 2, navHeight);
        UIButton *libraryBtn = [[UIButton alloc] initWithFrame:rect];
        [libraryBtn setTitle:@"Library" forState:UIControlStateNormal];
        [libraryBtn.titleLabel setFont:[UIFont systemFontOfSize:17.0f]];
        [libraryBtn setTitleColor:[UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1] forState:UIControlStateNormal];
        [libraryBtn addTarget:self action:@selector(cropAction) forControlEvents:UIControlEventTouchUpInside];
        [self.bottomView addSubview:libraryBtn];
        
        rect = CGRectMake(CGRectGetWidth(self.view.bounds) / 2, 0, CGRectGetWidth(self.view.bounds) / 2, navHeight);
        UIButton *photoBtn = [[UIButton alloc] initWithFrame:rect];
        [photoBtn setTitle:@"Photo" forState:UIControlStateNormal];
        [photoBtn.titleLabel setFont:[UIFont systemFontOfSize:17.0f]];
        [photoBtn setTitleColor:[UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1] forState:UIControlStateNormal];
        [photoBtn addTarget:self action:@selector(cropAction) forControlEvents:UIControlEventTouchUpInside];
        [self.bottomView addSubview:photoBtn];
    }
    return _bottomView;
}

- (UICollectionView *)collectionView {
    if (_collectionView == nil) {
        CGFloat colum = 4.0, spacing = 2.0;
        CGFloat value = floorf((CGRectGetWidth(self.view.bounds) - (colum - 1) * spacing) / colum);
        
        UICollectionViewFlowLayout *layout  = [[UICollectionViewFlowLayout alloc] init];
        layout.itemSize                     = CGSizeMake(value, value);
        layout.sectionInset                 = UIEdgeInsetsMake(0, 0, 0, 0);
        layout.minimumInteritemSpacing      = spacing;
        layout.minimumLineSpacing           = spacing;
        
        CGRect rect = CGRectMake(0, CGRectGetMaxY(self.topView.frame), CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds)-CGRectGetHeight(self.topView.bounds)-CGRectGetHeight(self.bottomView.bounds));
        _collectionView = [[UICollectionView alloc] initWithFrame:rect collectionViewLayout:layout];
        _collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
        _collectionView.backgroundColor = [UIColor clearColor];
        
        [_collectionView registerClass:[TWPhotoCollectionViewCell class] forCellWithReuseIdentifier:@"TWPhotoCollectionViewCell"];
    }
    return _collectionView;
}

@end
