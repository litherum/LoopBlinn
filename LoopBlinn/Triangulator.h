//
//  Triangulator.h
//  LoopBlinn
//
//  Created by Myles C. Maxfield on 2/5/15.
//  Copyright (c) 2015 Litherum. All rights reserved.
//

#ifndef LoopBlinn_Triangulator_h
#define LoopBlinn_Triangulator_h

#include <CoreGraphics/CoreGraphics.h>
#include <simd/simd.h>

#ifdef __cplusplus
extern "C" {
#endif

struct Triangulator;
typedef struct Triangulator Triangulator;

Triangulator* createTriangulator();
void destroyTriangulator(Triangulator*);

void triangulatorAppendPath(Triangulator*, CGPathRef, CGPoint origin);

void triangulatorTriangulate(Triangulator*);

typedef void(*TriangleIterator)(void*, CGPoint, CGPoint, CGPoint, CGPoint, vector_double3, vector_double3, vector_double3, vector_double3, bool);
void triangulatorApply(Triangulator*, TriangleIterator, void*);

void triangulatorCubic(Triangulator* triangulator, CGPoint a, CGPoint b, CGPoint c, CGPoint d); // FIXME: Remove this

#ifdef __cplusplus
}
#endif

#endif
