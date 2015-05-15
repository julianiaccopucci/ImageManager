//
//  DetailViewController.h
//  ImageManagerSample
//
//  Created by Julian Iaccopucci on 15/05/2015.
//  Copyright (c) 2015 JulianIaccopucci. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DetailViewController : UIViewController

@property (strong, nonatomic) id detailItem;
@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;

@end

