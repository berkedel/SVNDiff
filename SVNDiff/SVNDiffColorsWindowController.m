//
// SVNDiffColorsWindowController.m
// SVNDiff
//
// Created by Akhmad Syaikhul Hadi on 31/03/2015
// Copyright (c) 2015 Akhmad Syaikhul Hadi. All rights reserved.
//

#import "SVNDiffColorsWindowController.h"

NSString *const SVNDiffModifiedColorKey = @"SVNDiffModifiedColorKey";
NSString *const SVNDiffAddedColorKey = @"SVNDiffAddedColorKey";
NSString *const SVNDiffDeletedColorKey = @"SVNDiffDeletedColorKey";
NSString *const SVNDiffPopoverColorKey = @"SVNDiffPopoverColorKey";

@interface SVNDiffColorsWindowController()
{
    NSDictionary *_pluginDefaults;
    NSUserDefaults *_userDefaults;
}

@property (weak) IBOutlet NSColorWell *modifiedColorWell;
@property (weak) IBOutlet NSColorWell *addedColorWell;
@property (weak) IBOutlet NSColorWell *deletedColorWell;
@property (weak) IBOutlet NSColorWell *popoverColorWell;
@end



@implementation SVNDiffColorsWindowController
- (instancetype)initWithPluginBundle:(NSBundle *)bundle
{
    NSString *nibPath = [bundle pathForResource:@"SVNDiff" ofType:@"nib"];
    if (!nibPath) {
        NSLog(@"SVNDiff Plugin: Could not load colors interface.");
    }
    
    self = [super initWithWindowNibPath:nibPath owner:self];
    if (self) {
        NSString *pluginDefaultsPath = [bundle pathForResource:@"Defaults" ofType:@"plist"];
        _pluginDefaults = [NSDictionary dictionaryWithContentsOfFile:pluginDefaultsPath];
        _userDefaults = [NSUserDefaults standardUserDefaults];
    }
    return self;
}

- (void)awakeFromNib
{
    [self loadColors];
}

#pragma mark - Actions
- (IBAction)svnDiffColorWellChanged:(id)sender
{
    [self saveColors];
}

#pragma mark - Acessor
- (NSColor *)modifiedColor
{
    return [self colorForKey:SVNDiffModifiedColorKey];
}

- (NSColor *)addedColor
{
    return [self colorForKey:SVNDiffAddedColorKey];
}

- (NSColor *)deletedColor
{
    return [self colorForKey:SVNDiffDeletedColorKey];
}

- (NSColor *)popoverColor
{
    return [self colorForKey:SVNDiffPopoverColorKey];
}

#pragma mark - Colors
- (void)resetColors
{
    self.modifiedColorWell.color = [self colorFromPlistString:_pluginDefaults[SVNDiffModifiedColorKey]];
    self.addedColorWell.color = [self colorFromPlistString:_pluginDefaults[SVNDiffAddedColorKey]];
    self.deletedColorWell.color = [self colorFromPlistString:_pluginDefaults[SVNDiffDeletedColorKey]];
    self.popoverColorWell.color = [self colorFromPlistString:_pluginDefaults[SVNDiffPopoverColorKey]];
    
    [self saveColors];
}

- (void)loadColors
{
    self.modifiedColorWell.color = [self colorForKey:SVNDiffModifiedColorKey];
    self.addedColorWell.color = [self colorForKey:SVNDiffAddedColorKey];
    self.deletedColorWell.color = [self colorForKey:SVNDiffDeletedColorKey];
    self.popoverColorWell.color = [self colorForKey:SVNDiffPopoverColorKey];
}

- (void)saveColors
{
    [_userDefaults setObject:[self plistStringFromColor:self.modifiedColorWell.color] forKey:SVNDiffModifiedColorKey];
    [_userDefaults setObject:[self plistStringFromColor:self.addedColorWell.color] forKey:SVNDiffAddedColorKey];
    [_userDefaults setObject:[self plistStringFromColor:self.deletedColorWell.color] forKey:SVNDiffDeletedColorKey];
    [_userDefaults setObject:[self plistStringFromColor:self.popoverColorWell.color] forKey:SVNDiffPopoverColorKey];
}

#pragma mark - Helpers
- (NSColor *)colorFromPlistString:(NSString *)colorString
{
    NSArray *colorStringComponents = [colorString componentsSeparatedByString:@" "];
    CGFloat r = 0.f,
            g = 0.f,
            b = 0.f,
            a = 0.f;
    
    if (colorStringComponents.count == 4) {
        r = [colorStringComponents[0] floatValue];
        g = [colorStringComponents[1] floatValue];
        b = [colorStringComponents[2] floatValue];
        a = [colorStringComponents[3] floatValue];
    }
    
    return [NSColor colorWithRed:r green:g blue:b alpha:a];
}

- (NSString *)plistStringFromColor:(NSColor *)color
{
    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    
    return [NSString stringWithFormat:@"%.3f %.3f %.3f %.3f", r, g, b, a];
}

- (NSColor *)colorForKey:(NSString *)key
{
    if ([_userDefaults stringForKey:key]) {
        return [self colorFromPlistString:[_userDefaults stringForKey:key]];
    }
    return [self colorFromPlistString:_pluginDefaults[key]];
}
@end