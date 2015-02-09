//
//  PathWinder.h
//  LoopBlinn
//
//  Created by Myles C. Maxfield on 2/8/15.
//  Copyright (c) 2015 Litherum. All rights reserved.
//

#ifndef __LoopBlinn__PathWinder__
#define __LoopBlinn__PathWinder__

#include <CoreGraphics/CoreGraphics.h>

CGPathRef createCorrectlyWoundPath(CGPathRef path);
CGPathRef createNonIntersectingPath(CGPathRef path);

#endif /* defined(__LoopBlinn__PathWinder__) */
