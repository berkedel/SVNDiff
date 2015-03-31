//
// SVNDiff.mm
// SVN difference highlighter plugin
//
// Created by Akhmad Syaikhul Hadi on 30/03/2015
// Copyright (c) 2015 Akhmad Syaikhul Hadi. All rights reserved.
//

#import "SVNDiff.h"
#import <objc/runtime.h>
#import <string>
#import <map>
#import "SVNDiffColorsWindowController.h"

#define EXISTS(_map, _entry) (_map.find(_entry) != _map.end())

static SVNDiff *svnDiffPlugin;



@interface SVNDiff()
@property NSMutableDictionary *diffsByFile;
@property NSText *popover;
@property SVNDiffColorsWindowController *colorsWindowController;
@end

@implementation SVNDiff
+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        svnDiffPlugin = [[self alloc] init];
        svnDiffPlugin.diffsByFile = [NSMutableDictionary new];
        svnDiffPlugin.colorsWindowController = [[SVNDiffColorsWindowController alloc] initWithPluginBundle:plugin];
        
        // insert menu
        [svnDiffPlugin insertMenuItems];
        
        svnDiffPlugin.popover = [[NSText alloc] initWithFrame:NSZeroRect];
        
        [self swizzleClass:@"IDESourceCodeDocument"
                  exchange:@selector(writeToURL:ofType:error:)
                      with:@selector(svn_writeToURL:ofType:error:)];
        [self swizzleClass:@"DVTTextSidebarView"
                  exchange:@selector(_drawLineNumbersInSidebarRect:foldedIndexes:count:linesToInvert:linesToReplace:getParaRectBlock:)
                      with:@selector(svn_drawLineNumbersInSidebarRect:foldedIndexes:count:linesToInvert:linesToReplace:getParaRectBlock:)];
        [self swizzleClass:@"DVTTextSidebarView"
                  exchange:@selector(annotationAtSidebarPoint:)
                      with:@selector(svn_annotationAtSidebarPoint:)];
    });
}

+ (void)swizzleClass:(NSString *)className exchange:(SEL)origMethod with:(SEL)altMethod
{
    Class aClass = NSClassFromString(className);
    method_exchangeImplementations(class_getInstanceMethod(aClass, origMethod),
                                   class_getInstanceMethod(aClass, altMethod));
}

- (void)insertMenuItems
{
    NSMenu *editorMenu = [[[NSApp mainMenu] itemWithTitle:@"Edit"] submenu];
    
    if (editorMenu) {
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:@"SVNDiff Config"
                                                          action:@selector(svnDiffColorsMenuItemSelected:)
                                                   keyEquivalent:@""];
        menuItem.target = self;
        
        [editorMenu addItem:[NSMenuItem separatorItem]];
        [editorMenu addItem:menuItem];
    }
}

- (void)svnDiffColorsMenuItemSelected:(id)sender
{
    [svnDiffPlugin.colorsWindowController showWindow:self];
}
@end



@interface SVNFileDiffs : NSObject {
@public
    std::map<unsigned long, std::string> deleted; // text deleted by line
    std::map<unsigned long, unsigned long> modified; // line number mods started by line
    std::map<unsigned long, BOOL> added; // line has been added or modified
    time_t updated;
}
@end

@implementation SVNFileDiffs
// parse "svn diff" output
- (SVNFileDiffs *)initFile:(NSString *)path
{
    if ((self = [super init])) {
        NSString *command = [NSString stringWithFormat:@"cd '%@' && /usr/bin/svn diff '%@'",
                             [path stringByDeletingLastPathComponent], path];
        FILE *diffs = popen([command UTF8String], "r");
        
        if (diffs) {
            char buffer[10000];
            int line, deline, modline, delcnt, addcnt;
            
            for (int i=0; i<4; i++) {
                // delete first 4 lines of Diff output
                fgets(buffer, sizeof buffer, diffs);
            }
            
            while (fgets(buffer, sizeof buffer, diffs)) {
                switch (buffer[0]) {
                    case '@': {
                        int d1, d2, d3;
                        sscanf(buffer, "@@ -%d,%d +%d,%d @@", &d1, &d2, &line, &d3);
                        break;
                    }
                    case '-':
                        deleted[deline] += buffer+1;
                        modified[modline++] = deline;
                        delcnt++;
                        break;
                    case '+':
                        added[line] = YES;
                    {
                        auto modent = modified.find(line);
                        if (++addcnt > delcnt && modent != modified.end()) {
                            modified.erase(modent);
                        }
                    }
                    default:
                        deline = modline = ++line;
                        if (buffer[0] != '+') {
                            delcnt = addcnt = 0;
                        }
                }
            }
            
            pclose(diffs);
        } else {
            NSLog(@"SVNDiff Plugin: Could not run diff command: %@", command);
        }
        
        svnDiffPlugin.diffsByFile[path] = self;
        updated = time(NULL);
    }
    
    return self;
}
@end



@interface IDESourceCodeDocument : NSDocument
@end

@implementation IDESourceCodeDocument(SVNDiff)
// source file is being saved
- (BOOL)svn_writeToURL:(NSURL *)url ofType:(NSString *)type error:(NSError **)error
{
    [[SVNFileDiffs alloc] performSelectorInBackground:@selector(initFile:) withObject:[[self fileURL] path]];
    return [self svn_writeToURL:url ofType:type error:error];
}
@end



@interface DVTTextSidebarView : NSRulerView
- (void)getParagraphRect:(CGRect *)a0 firstLineRect:(CGRect *)a1 forLineNumber:(unsigned long)a2;
- (unsigned long)lineNumberForPoint:(CGPoint)a0;
- (double)sidebarWidth;
@end

@implementation DVTTextSidebarView(SVNDiff)
- (NSTextView *)sourceTextView {
    return (NSTextView *)[(id)[self scrollView] delegate];
}

- (SVNFileDiffs *)svnDiffs
{
    IDESourceCodeDocument *doc = [(id)[[self sourceTextView] delegate] document];
    NSString *path = [[doc fileURL] path];
    
    SVNFileDiffs *diffs = svnDiffPlugin.diffsByFile[path];
    if (!diffs || time(NULL) > diffs->updated+60) {
        diffs = [[SVNFileDiffs alloc] initFile:path];
    }
    
    return diffs;
}

// the line numbers sidebar is being redrawn
- (void)svn_drawLineNumbersInSidebarRect:(CGRect)rect foldedIndexes:(unsigned long *)indexes count:(unsigned long)indexCount linesToInvert:(id)a3 linesToReplace:(id)a4 getParaRectBlock:rectBlock
{
    SVNFileDiffs *diffs = [self svnDiffs];
    
    [self lockFocus];
    
    for (int i=0; i<indexCount; i++) {
        unsigned long line = indexes[i];
        NSColor *highlight = !EXISTS(diffs->added, line) ? nil :
            EXISTS(diffs->modified, line) ? svnDiffPlugin.colorsWindowController.modifiedColor : svnDiffPlugin.colorsWindowController.addedColor;
        CGRect a0, a1;
        
        if (highlight) {
            [highlight setFill];
            [self getParagraphRect:&a0 firstLineRect:&a1 forLineNumber:indexes[i]];
            NSRectFill(CGRectInset(a0, 1., 1.));
        } else if (EXISTS(diffs->deleted, line)) {
            [svnDiffPlugin.colorsWindowController.deletedColor setFill];
            [self getParagraphRect:&a0 firstLineRect:&a1 forLineNumber:line];
            a0.size.height = 1.;
            NSRectFill(a0);
        }
    }
    
    [self unlockFocus];
    [self svn_drawLineNumbersInSidebarRect:rect foldedIndexes:indexes count:indexCount
                             linesToInvert:a3 linesToReplace:a4 getParaRectBlock:rectBlock];
}

- (id)svn_annotationAtSidebarPoint:(CGPoint)p0
{
    NSText *popover = svnDiffPlugin.popover;
    
    svnDiffPlugin.popover.wantsLayer = YES;
    svnDiffPlugin.popover.layer.cornerRadius = 6.0;
    
    svnDiffPlugin.popover.backgroundColor = svnDiffPlugin.colorsWindowController.popoverColor;
    
    id annotation = [self svn_annotationAtSidebarPoint:p0];
    
    if (!annotation && p0.x < self.sidebarWidth) {
        SVNFileDiffs *diffs = [self svnDiffs];
        unsigned long line = [self lineNumberForPoint:p0];
        
        if (EXISTS(diffs->deleted, line) ||
            (EXISTS(diffs->added, line) && EXISTS(diffs->modified, line))) {
            CGRect a0, a1;
            unsigned long start = diffs->modified[line];
            [self getParagraphRect:&a0 firstLineRect:&a1 forLineNumber:start];
            
            std::string deleted = diffs->deleted[start];
            deleted = deleted.substr(0, deleted.length()-1);
            
            popover.font = [self sourceTextView].font;
            popover.string = [NSMutableString stringWithUTF8String:deleted.c_str()];
            popover.frame = NSMakeRect(self.frame.size.width+1, a0.origin.y, 700, 10.);
            [popover sizeToFit];
            
            [self.scrollView addSubview:popover];
            return annotation;
        }
    }
    
    if ([popover superview]) {
        [popover removeFromSuperview];
    }
    
    return annotation;
}
@end