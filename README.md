# SVNDiff Xcode Plugin

This plugin was inspired by GitDiff plugin. Thanks to [johnno1962](https://github.com/johnno1962/GitDiff).

SVNDiff displays deltas against a SVN repository in the Xcode source editor once you've saved the file.
Differences should then be highlighted in orange for lines that have been modified and green for new code.
A red line indicates code has been removed. Hover over deleted/modified line number to see original source.

### Install

To use, copy this repo to your machine, build it and restart Xcode. 

### Uninstall

Delete the plugin:

```
rm -rf ~/Library/Application\ Support/Developer/Shared/Xcode/Plug-ins/SVNDiff.xcplugin
```

### MIT License

Copyright (C) 2015 Akhmad Syaikhul Hadi

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated 
documentation files (the "Software"), to deal in the Software without restriction, including without limitation 
the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, 
and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial 
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT 
LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.