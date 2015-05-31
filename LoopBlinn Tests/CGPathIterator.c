//
//  CGPathIterator.c
//  LoopBlinn
//
//  Created by Litherum on 5/30/15.
//  Copyright (c) 2015 Litherum. All rights reserved.
//

#include "CGPathIterator.h"

static void applyCallback(void *info, const CGPathElement *element) {
    CGPathIterator iterator = (CGPathIterator)info;
    iterator(element);
}

void iterateCGPath(CGPathRef path, CGPathIterator iterator) {
    CGPathApply(path, iterator, &applyCallback);
}