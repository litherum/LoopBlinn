//
//  CGPathIterator.h
//  LoopBlinn
//
//  Created by Litherum on 5/30/15.
//  Copyright (c) 2015 Litherum. All rights reserved.
//

#ifndef __LoopBlinn__CGPathIterator__
#define __LoopBlinn__CGPathIterator__

#import <CoreGraphics/CoreGraphics.h>


typedef void (^CGPathIterator)(CGPathElement);
void iterateCGPath(CGPathRef, CGPathIterator);

#endif /* defined(__LoopBlinn__CGPathIterator__) */
