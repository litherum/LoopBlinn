//
//  Triangulator.h
//  LoopBlinn
//
//  Created by Myles C. Maxfield on 2/5/15.
//  Copyright (c) 2015 Litherum. All rights reserved.
//

#ifndef LoopBlinn_Triangulator_h
#define LoopBlinn_Triangulator_h

#include "CoreGraphics/CoreGraphics.h"

#ifdef __cplusplus
extern "C" {
#endif

struct Triangulator;
typedef struct Triangulator Triangulator;

Triangulator* createTriangulator();
void destroyTriangulator(Triangulator*);

void triangulatorAppendPath(Triangulator*, CGPathRef, CGPoint origin);

void triangulatorTriangulate(Triangulator*);

typedef void(*TriangleIterator)(void*, CGPoint, CGPoint, CGPoint, CGPoint, CGPoint, CGPoint, bool);
void triangulatorApply(Triangulator*, TriangleIterator, void*);

#ifdef __cplusplus
}
#endif

#endif
