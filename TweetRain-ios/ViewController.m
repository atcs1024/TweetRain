//
//  ViewController.m
//  TweetRain
//
//  Created by b123400 on 25/1/15.
//  Copyright (c) 2015 b123400. All rights reserved.
//

#import "ViewController.h"
#import "AuthViewController.h"
#import <STTwitter/STTwitter.h>
#import "SettingManager.h"
#import "StreamController.h"
#import "Status.h"
#import "RainDropViewController.h"
#import "RainDropDetailViewController.h"

@interface ViewController () <AuthViewControllerDelegate, StreamControllerDelegate, RainDropViewControllerDelegate, RainDropDetailViewControllerDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[StreamController shared] setDelegate:self];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated {
    if (![AuthViewController authed] || ![SettingManager sharedManager].selectedAccount) {
        AuthViewController *controller = [[AuthViewController alloc] init];
        controller.delegate = self;
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:controller];
        navController.modalInPopover = YES;
        navController.modalPresentationStyle = UIModalPresentationFormSheet;
        navController.navigationBarHidden = YES;
        [self presentViewController:navController animated:YES completion:nil];
    } else {
        [self startStreaming];
    }
}

- (void)authViewControllerDidAuthed:(id)sender {
    if ([self presentedViewController]) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    [self startStreaming];
}

- (void)startStreaming {
    [[StreamController shared] startStreaming];
}

#pragma mark setting

- (IBAction)settingButtonPressed:(UIButton*)sender {
    UIViewController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"SettingNavigationViewController"];
    controller.modalPresentationStyle = UIModalPresentationPopover;
    UIPopoverPresentationController *popover = controller.popoverPresentationController;
    popover.delegate = self;
    popover.sourceRect = [sender frame];
    popover.sourceView = [sender superview];
    [self presentViewController:controller animated:YES completion:nil];
}

#pragma mark interface

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller {
    return UIModalPresentationOverFullScreen;
}


- (UIViewController *)presentationController:(UIPresentationController *)controller
  viewControllerForAdaptivePresentationStyle:(UIModalPresentationStyle)style {
    UIViewController *dest = [controller presentedViewController];
    if (![dest isKindOfClass:[UINavigationController class]]) {
        UINavigationController *controller = [[UINavigationController alloc] initWithRootViewController:dest];
        controller.navigationBar.translucent = NO;
        return controller;
    }
    return dest;
}

#pragma mark stream

- (void)streamController:(id)controller didReceivedTweet:(Status*)tweet {
    RainDropViewController *rainDropController = [[RainDropViewController alloc] initWithStatus:tweet];
    rainDropController.delegate = self;
    [self.view addSubview:rainDropController.view];
    
    CGRect frame = rainDropController.view.frame;
    frame.origin.x = self.view.frame.size.width;
    frame.origin.y = [self smallestPossibleYForStatusViewController:rainDropController];
    rainDropController.view.frame = frame;
    
    [self addChildViewController:rainDropController];
    
    [rainDropController startAnimation];
}

-(float)ySuggestionForStatusViewController:(RainDropViewController*)controller atY:(float)thisY{
    float minY=thisY;
    
    for(RainDropViewController *thisController in self.childViewControllers){
        if (![thisController isKindOfClass:[RainDropViewController class]]) continue;
        if (thisController == controller) continue;
        if ((thisController.view.frame.origin.y<=thisY&&
             thisController.view.frame.origin.y+thisController.view.frame.size.height>=thisY)||
            (thisController.view.frame.origin.y<=thisY+controller.view.frame.size.height&&
             thisController.view.frame.origin.y>=thisY)){
               //y position overlap
               if([thisController willCollideWithRainDrop:controller]){
                   minY = CGRectGetMaxY(thisController.view.frame) + 1;
               }
           }
    }
    return minY;
}

-(float)smallestPossibleYForStatusViewController:(RainDropViewController*)controller{
    float possibleY = self.topLayoutGuide.length;
    while(possibleY < self.view.frame.size.height){
        float suggestion = [self ySuggestionForStatusViewController:controller atY:possibleY];
        if(suggestion == possibleY){
            break;
        }
        possibleY=suggestion;
    }
    return possibleY;
}

- (void)rainDropViewControllerDidDisappeared:(RainDropViewController*)sender {
    [sender.view removeFromSuperview];
    [sender removeFromParentViewController];
    sender.delegate = nil;
}

#pragma mark interaction

- (void)rainDropViewControllerDidTapped:(RainDropViewController*)sender {
    RainDropDetailViewController *detailViewController = [[RainDropDetailViewController alloc] initWithStatus:sender.status];
    detailViewController.delegate = self;
    detailViewController.modalPresentationStyle = UIModalPresentationPopover;
    UIPopoverPresentationController *popover = detailViewController.popoverPresentationController;
    popover.sourceRect = [sender.view.layer.presentationLayer frame];
    popover.sourceView = self.view;
    popover.delegate = self;
    [self presentViewController:detailViewController animated:YES completion:nil];
    [sender pauseAnimation];
}

- (void)popoverPresentationControllerDidDismissPopover:(UIPopoverPresentationController *)popoverPresentationController {
    if ([popoverPresentationController.presentedViewController isKindOfClass:[RainDropDetailViewController class]]) {
        [self rainDropDetailViewControllerDidClosed:(RainDropDetailViewController*)popoverPresentationController.presentedViewController];
    }
}

- (void)rainDropDetailViewControllerDidClosed:(RainDropDetailViewController*)sender {
    Status *status = sender.status;
    for (RainDropViewController *raindrop in self.childViewControllers) {
        if (![raindrop isKindOfClass:[RainDropViewController class]]) continue;
        if ([raindrop status] == status) {
            [raindrop startAnimation];
        }
    }
}

@end
