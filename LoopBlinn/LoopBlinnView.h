//
//  LoopBlinnView.h
//  LoopBlinn
//
//  Created by Litherum on 2/4/15.
//  Copyright (c) 2015 Litherum. All rights reserved.
//

#ifndef LoopBlinn_LoopBlinnView_h
#define LoopBlinn_LoopBlinnView_h

@import Cocoa;

@interface LoopBlinnView : NSOpenGLView

- (void)awakeFromNib;
- (void)update;
- (void)prepareOpenGL;
- (void)drawRect:(NSRect)dirtyRect;
- (void)dealloc;

@end

#endif
