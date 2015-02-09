//
//  PathWinder.cpp
//  LoopBlinn
//
//  Created by Myles C. Maxfield on 2/8/15.
//  Copyright (c) 2015 Litherum. All rights reserved.
//

#include "PathWinder.h"

#include <vector>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconditional-uninitialized"
#pragma clang diagnostic ignored "-Wshorten-64-to-32"
#include <CGAL/Exact_predicates_inexact_constructions_kernel.h>
#include <CGAL/Constrained_Delaunay_triangulation_2.h>
#include <CGAL/Triangulation_face_base_with_info_2.h>
#include <CGAL/Polygon_2.h>
#pragma clang diagnostic pop

typedef CGAL::Simple_cartesian<CGFloat> K;

class PathComponent {
public:
    virtual void emit(CGMutablePathRef) const = 0;
    virtual void emitReverse(CGMutablePathRef) const = 0;
    virtual CGPoint getSource() const = 0;
    virtual CGPoint getDestination() const = 0;
};

class LineComponent : public PathComponent {
public:
    LineComponent(CGPoint source, CGPoint destination)
        : source(source)
        , destination(destination)
    {
    }
    
    virtual void emit(CGMutablePathRef path) const override {
        CGPathAddLineToPoint(path, NULL, destination.x, destination.y);
    }

    virtual void emitReverse(CGMutablePathRef path) const override {
        CGPathAddLineToPoint(path, NULL, source.x, source.y);
    }

    virtual CGPoint getSource() const override {
        return source;
    }

    virtual CGPoint getDestination() const override {
        return destination;
    }

private:
    CGPoint source;
    CGPoint destination;
};

class QuadraticComponent : public PathComponent {
public:
    QuadraticComponent(CGPoint source, CGPoint control, CGPoint destination)
        : source(source)
        , control(control)
        , destination(destination)
    {
    }
    
    virtual void emit(CGMutablePathRef path) const override {
        CGPathAddQuadCurveToPoint(path, NULL, control.x, control.y, destination.x, destination.y);
    }

    virtual void emitReverse(CGMutablePathRef path) const override {
        CGPathAddQuadCurveToPoint(path, NULL, control.x, control.y, source.x, source.y);
    }

    virtual CGPoint getSource() const override {
        return source;
    }

    virtual CGPoint getDestination() const override {
        return destination;
    }

private:
    CGPoint source;
    CGPoint control;
    CGPoint destination;
};

class CubicComponent : public PathComponent {
public:
    CubicComponent(CGPoint source, CGPoint control1, CGPoint control2, CGPoint destination)
        : source(source)
        , control1(control1)
        , control2(control2)
        , destination(destination)
    {
    }
    
    virtual void emit(CGMutablePathRef path) const override {
        CGPathAddCurveToPoint(path, NULL, control1.x, control1.y, control2.x, control2.y, destination.x, destination.y);
    }

    virtual void emitReverse(CGMutablePathRef path) const override {
        CGPathAddCurveToPoint(path, NULL, control2.x, control2.y, control1.x, control1.y, source.x, source.y);
    }

    virtual CGPoint getSource() const override {
        return source;
    }

    virtual CGPoint getDestination() const override {
        return destination;
    }

private:
    CGPoint source;
    CGPoint control1;
    CGPoint control2;
    CGPoint destination;
};

typedef std::vector<std::unique_ptr<PathComponent>> Subpath;

static CGPathRef createForwardSubpath(const Subpath& path) {
    CGMutablePathRef result = CGPathCreateMutable();
    CGPoint source = path[0]->getSource();
    CGPathMoveToPoint(result, NULL, source.x, source.y);
    for (auto& component : path)
        component->emit(result);
    return result;
}

static CGPathRef createReverseSubpath(const Subpath& path) {
    CGMutablePathRef result = CGPathCreateMutable();
    CGPoint source = path[path.size() - 1]->getDestination();
    CGPathMoveToPoint(result, NULL, source.x, source.y);
    for (auto i(path.rbegin()); i != path.rend(); ++i)
        (*i)->emitReverse(result);
    return result;
}

struct PathContext {
    PathContext(CGMutablePathRef path)
        : path(path)
        , total(0)
    {
    }

    ~PathContext() {
        completeSubpath();
    }

    void append(std::unique_ptr<PathComponent>&& component) {
        total += CGAL::cross_product(
            CGAL::Vector_3<K>(component->getSource().x - subpathSource.x, component->getSource().y - subpathSource.y, 0),
            CGAL::Vector_3<K>(component->getDestination().x - subpathSource.x, component->getDestination().y - subpathSource.y, 0)).z();
        subpath.emplace_back(std::move(component));
    }

    void completeSubpath() {
        if (subpath.size() == 0)
            return;

        CGPathRef woundPath;
        if (total < 0)
            woundPath = createForwardSubpath(subpath);
        else
            woundPath = createReverseSubpath(subpath);
        CGPathAddPath(path, NULL, woundPath);
        CGPathCloseSubpath(path);
        CFRelease(woundPath);
        subpath.clear();
        total = 0;
    }

    CGPoint subpathSource;
    CGPoint source;
    CGMutablePathRef path;

private:
    Subpath subpath;
    CGFloat total;
};

static void applierFunction(void *info, const CGPathElement *element) {
    // FIXME: allocating an object for each path component is not effecient
    PathContext& context = *static_cast<PathContext*>(info);
    switch (element->type) {
        case kCGPathElementMoveToPoint: {
            context.completeSubpath();
            CGPoint source = CGPointMake(element->points[0].x, element->points[0].y);
            context.source = source;
            context.subpathSource = source;
            break;
        } case kCGPathElementAddLineToPoint: {
            CGPoint destination = CGPointMake(element->points[0].x, element->points[0].y);
            context.append(std::unique_ptr<PathComponent>(new LineComponent(context.source, destination)));
            context.source = destination;
            break;
        } case kCGPathElementAddQuadCurveToPoint: {
            CGPoint control = CGPointMake(element->points[0].x, element->points[0].y);
            CGPoint destination = CGPointMake(element->points[1].x, element->points[1].y);
            context.append(std::unique_ptr<PathComponent>(new QuadraticComponent(context.source, control, destination)));
            context.source = destination;
            break;
        }
        case kCGPathElementAddCurveToPoint: {
            CGPoint control1 = CGPointMake(element->points[0].x, element->points[0].y);
            CGPoint control2 = CGPointMake(element->points[1].x, element->points[1].y);
            CGPoint destination = CGPointMake(element->points[2].x, element->points[2].y);
            context.append(std::unique_ptr<PathComponent>(new CubicComponent(context.source, control1, control2, destination)));
            context.source = destination;
            break;
        }
        case kCGPathElementCloseSubpath:
            context.append(std::unique_ptr<PathComponent>(new LineComponent(context.source, context.subpathSource)));
            context.source = context.subpathSource;
            break;
        default:
            assert(false);
    }
}

CGPathRef createCorrectlyWoundPath(CGPathRef path) {
    CGMutablePathRef result = CGPathCreateMutable();
    {
        PathContext context(result);
        CGPathApply(path, &context, &applierFunction);
    }
    CFRetain(path);
    return path;
}