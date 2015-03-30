//
// SVNDiff.mm
// SVN difference highlighter plugin
//
// Created by Akhmad Syaikhul Hadi on 30/03/2015
// Copyright (c) 2015 Akhmad Syaikhul Hadi. All rights reserved.
//

#import "SVNDiff.h"

#import <objc/runtime.h>
#import <map>

static SVNDiff *svnDiffPlugin;
static NSMutableDictionary *fileDiffs;
static NSColor *modifiedColor, *addedColor;



@interface SVNFileDiffs : NSObject {
@public
    std::map<unsigned long, BOOL> deleted, added;
}
@end

@implementation SVNFileDiffs
@end



@interface SVNDiff()
- (SVNFileDiffs *)getDiffsForFile:(NSString *)path;
@end



@interface IDESourceCodeDocument : NSDocument
@end

@implementation IDESourceCodeDocument(SVNDiff)
// source file is being saved
- (BOOL)svn_writeToURL:(NSURL *)url ofType:(NSString *)type error:(NSError **)error
{
    [svnDiffPlugin performSelector:@selector(getDiffsForFile:) withObject:[[self fileURL] path]];
    return [self svn_writeToURL:url ofType:type error:error];
}
@end



@interface DVTTextSidebarView : NSRulerView
- (void)getParagraphRect:(CGRect *)a0 firstLineRect:(CGRect *)a1 forLineNumber:(unsigned long)a2;
@end

@implementation DVTTextSidebarView(SVNDiff)
// the line numbers sidebar is being redrawn
- (void)svn_drawLineNumbersInSidebarRect:(CGRect)rect foldedIndexes:(unsigned long *)indexes count:(unsigned long)indexCount linesToInvert:(id)a3 linesToReplace:(id)a4 getParaRectBlock:rectBlock
{
    IDESourceCodeDocument *doc = [self valueForKeyPath:@"scrollView.delegate.delegate.document"];
    NSString *path = [[doc fileURL] path];
    SVNFileDiffs *deltas = fileDiffs[path];
    
    if (!deltas) {
        deltas = [svnDiffPlugin getDiffsForFile:path];
    }
    
    [self lockFocus];
    
    for (int i=0; i<indexCount; i++) {
        NSColor *highlight = deltas->added.find(indexes[i]) == deltas->added.end() ? nil :
            deltas->deleted.find(indexes[i]) != deltas->deleted.end() ? modifiedColor : addedColor;
        if (highlight) {
            CGRect a0, a1;
            [highlight setFill];
            [self getParagraphRect:&a0 firstLineRect:&a1 forLineNumber:indexes[i]];
            NSRectFill(CGRectInset(a0, 1, 1));
        }
    }
    
    [self unlockFocus];
    [self svn_drawLineNumbersInSidebarRect:rect foldedIndexes:indexes count:indexCount linesToInvert:a3 linesToReplace:a4 getParaRectBlock:rectBlock];
}
@end



@implementation SVNDiff
+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        svnDiffPlugin = [[self alloc] init];
        fileDiffs = [NSMutableDictionary new];
        
        modifiedColor = [NSColor colorWithCalibratedRed:1. green:.9 blue:.6 alpha:1.];
        addedColor = [NSColor colorWithCalibratedRed:.7 green:1. blue:.7 alpha:1.];
        
        Class aClass = NSClassFromString(@"DVTTextSidebarView");
        Method orig_method = class_getInstanceMethod(aClass, @selector(_drawLineNumbersInSidebarRect:foldedIndexes:count:linesToInvert:linesToReplace:getParaRectBlock:));
        Method alt_method = class_getInstanceMethod(aClass, @selector(svn_drawLineNumbersInSidebarRect:foldedIndexes:count:linesToInvert:linesToReplace:getParaRectBlock:));
        method_exchangeImplementations(orig_method, alt_method);
        
        aClass = NSClassFromString(@"IDESourceCodeDocument");
        orig_method = class_getInstanceMethod(aClass, @selector(writeToURL:ofType:error:));
        alt_method = class_getInstanceMethod(aClass, @selector(svn_writeToURL:ofType:error:));
        method_exchangeImplementations(orig_method, alt_method);
    });
}

// parse "svn diff" output
- (SVNFileDiffs *)getDiffsForFile:(NSString *)path
{
    NSString *command = [NSString stringWithFormat:@"cd '%@' && /usr/bin/svn diff '%@'",
                         [path stringByDeletingLastPathComponent], path];
    FILE *diffs = popen([command UTF8String], "r");
    SVNFileDiffs *deltas = [SVNFileDiffs new];
    
    if (diffs) {
        char buffer[10000];
        int line, deline;
        
        for (int i=0; i<4; i++) {
            // delete first 4 lines of Diff output
            fgets(buffer, sizeof buffer, diffs);
        }
        
        while (fgets(buffer, sizeof buffer, diffs)) {
            switch (buffer[0]) {
                case '@':
                    int d1, d2, d3;
                    sscanf(buffer, "@@ -%d,%d +%d,%d @@", &d1, &d2, &line, &d3);
                    break;
                case '-':
                    deltas->deleted[deline++] = YES;
                case '+':
                    deltas->added[line] = YES;
                default:
                    deline = ++line;
            }
        }
        
        pclose(diffs);
    } else {
        NSLog(@"Could not run diff command: %@", command);
    }
    fileDiffs[path] = deltas;
    return deltas;
}
@end