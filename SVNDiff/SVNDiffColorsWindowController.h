//
// SVNDiffColorsWindowController.h
// SVNDiff
//
// Created by Akhmad Syaikhul Hadi on 31/03/2015
// Copyright (c) 2015 Akhmad Syaikhul Hadi. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SVNDiffColorsWindowController : NSWindowController
@property (strong, readonly) NSColor *modifiedColor;
@property (strong, readonly) NSColor *addedColor;
@property (strong, readonly) NSColor *deletedColor;
@property (strong, readonly) NSColor *popoverColor;

- (instancetype)initWithPluginBundle:(NSBundle *)bundle;
@end