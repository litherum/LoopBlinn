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

static inline CGPoint lerp(CGPoint a, CGPoint b, CGFloat scalar) {
    return CGPointMake(a.x * (1 - scalar) + b.x * scalar, a.y * (1 - scalar) + b.y * scalar);
}

// De Casteljau's algorithm
static inline std::array<std::array<CGPoint, 4>, 2> subdivideCubic(CGPoint a, CGPoint b, CGPoint c, CGPoint d) {
    const CGFloat scalar(0.5);
    CGPoint ab(lerp(a, b, scalar));
    CGPoint bc(lerp(b, c, scalar));
    CGPoint cd(lerp(c, d, scalar));
    CGPoint abc(lerp(ab, bc, scalar));
    CGPoint bcd(lerp(bc, cd, scalar));
    CGPoint abcd(lerp(abc, bcd, scalar));
    return std::array<std::array<CGPoint, 4>, 2>{std::array<CGPoint, 4>{a, ab, abc, abcd},
                                                 std::array<CGPoint, 4>{abcd, bcd, cd, d}};
}

class PathComponent {
public:
    virtual void emit(CGMutablePathRef) const = 0;
    virtual void emitReverse(CGMutablePathRef) const = 0;
    virtual CGPoint getSource() const = 0;
    virtual CGPoint getDestination() const = 0;
};

class MoveComponent : public PathComponent {
public:
    MoveComponent(CGPoint destination)
        : destination(destination)
    {
    }
    
    virtual void emit(CGMutablePathRef path) const override {
        CGPathMoveToPoint(path, NULL, destination.x, destination.y);
    }

    virtual void emitReverse(CGMutablePathRef path) const override {
        CGPathMoveToPoint(path, NULL, destination.x, destination.y);
    }

    virtual CGPoint getSource() const override {
        return destination;
    }

    virtual CGPoint getDestination() const override {
        return destination;
    }

private:
    CGPoint destination;
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

    struct Triangle {
        Triangle(CGAL::Point_2<K> common, CGAL::Vector_2<K> v1, CGAL::Vector_2<K> v2)
            : common(common)
            , v1(v1)
            , v2(v2)
        {
        }

        CGFloat area() {
            return std::abs(CGAL::cross_product(CGAL::Vector_3<K>(v1.x(), v1.y(), 0), CGAL::Vector_3<K>(v2.x(), v2.y(), 0)).z());
        }

        bool intersect(CGAL::Point_2<K> p) {
            CGAL::Vector_3<K> d(p.x() - common.x(), p.y() - common.y(), 0);
            CGFloat t((d.y() - v1.y() * d.x() / v1.x()) / (-v1.y() * v2.x() / v1.x() + v2.y()));
            CGFloat s((d.x() - v2.x() * t) / v1.x());
            return t > 0 && t < 1 && s > 0 && t < 1 && t + s < 1;
        }

        CGAL::Point_2<K> common;
        CGAL::Vector_2<K> v1;
        CGAL::Vector_2<K> v2;
    };

    struct Decomposition {
        Decomposition(Triangle&& t1, Triangle&& t2)
            : t1(t1)
            , t2(t2)
        {
        }

        Triangle t1;
        Triangle t2;
    };

    Decomposition decompose() const {
        CGAL::Point_2<K> s(source.x, source.y);
        CGAL::Point_2<K> d(destination.x, destination.y);
        CGAL::Vector_2<K> c1(control1.x - source.x, control1.y - source.y);
        CGAL::Vector_2<K> c2(control2.x - source.x, control2.y - source.y);
        CGAL::Vector_2<K> v(d - s);
        if (CGAL::orientation(c1, v) == CGAL::orientation(c2, v)) {
            if (c1 * v < c2 * v)
                return Decomposition(Triangle(s, c1, v), Triangle(d, CGAL::Vector_2<K>(control1.x - destination.x, control1.y - destination.y), CGAL::Vector_2<K>(control2.x - destination.x, control2.y - destination.y)));
            else
                return Decomposition(Triangle(s, c2, v), Triangle(d, CGAL::Vector_2<K>(control2.x - destination.x, control2.y - destination.y), CGAL::Vector_2<K>(control1.x - destination.x, control1.y - destination.y)));
        }
        return Decomposition(Triangle(s, c1, v), Triangle(s, c2, v));
    }

    CGFloat area() const {
        Decomposition d(decompose());
        return d.t1.area() + d.t2.area();
    }

    bool intersect(const CubicComponent& o) {
        Decomposition d(decompose());
        return d.t1.intersect(CGAL::Point_2<K>(o.source.x, o.source.y)) ||
               d.t1.intersect(CGAL::Point_2<K>(o.control1.x, o.control1.y)) ||
               d.t1.intersect(CGAL::Point_2<K>(o.control2.x, o.control2.y)) ||
               d.t1.intersect(CGAL::Point_2<K>(o.destination.x, o.destination.y)) ||
               d.t2.intersect(CGAL::Point_2<K>(o.source.x, o.source.y)) ||
               d.t2.intersect(CGAL::Point_2<K>(o.control1.x, o.control1.y)) ||
               d.t2.intersect(CGAL::Point_2<K>(o.control2.x, o.control2.y)) ||
               d.t2.intersect(CGAL::Point_2<K>(o.destination.x, o.destination.y));
    }

    std::array<CubicComponent, 2> subdivide() {
        auto d(subdivideCubic(source, control1, control2, destination));
        return std::array<CubicComponent, 2>{CubicComponent(d[0][0], d[0][1], d[0][2], d[0][3]),
                                             CubicComponent(d[1][0], d[1][1], d[1][2], d[1][3])};
    }

private:
    CGPoint source;
    CGPoint control1;
    CGPoint control2;
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

    CubicComponent cubicComponent() const {
        CGPoint cp1 = CGPointMake(source.x + 2 * (control.x - source.x) / 3, source.y + 2 * (control.y - source.y) / 3);
        CGPoint cp2 = CGPointMake(destination.x + 2 * (control.x - destination.x) / 3, destination.y + 2 * (control.y - destination.y) / 3);
        return CubicComponent(source, cp1, cp2, destination);
    }

private:
    CGPoint source;
    CGPoint control;
    CGPoint destination;
};

class CloseComponent : public PathComponent {
public:
    CloseComponent(CGPoint source, CGPoint destination)
        : source(source)
        , destination(destination)
    {
    }
    
    virtual void emit(CGMutablePathRef path) const override {
        CGPathCloseSubpath(path);
    }

    virtual void emitReverse(CGMutablePathRef path) const override {
        CGPathCloseSubpath(path);
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

typedef std::list<std::unique_ptr<PathComponent>> PathList;
struct NonIntersectingContext {
    NonIntersectingContext(PathList& pathList)
        : pathList(pathList)
        , currentPoint(CGPointMake(0, 0))
    {
    }
    PathList& pathList;
    CGPoint subpathStart;
    CGPoint currentPoint;
};

static void nonIntersectingPathApplierFunction(void *info, const CGPathElement *element) {
    NonIntersectingContext& context = *static_cast<NonIntersectingContext*>(info);
    switch (element->type) {
        case kCGPathElementMoveToPoint: {
            CGPoint source = CGPointMake(element->points[0].x, element->points[0].y);
            context.pathList.push_back(std::unique_ptr<PathComponent>(new MoveComponent(source)));
            context.currentPoint = source;
            context.subpathStart = source;
            break;
        } case kCGPathElementAddLineToPoint: {
            CGPoint destination = CGPointMake(element->points[0].x, element->points[0].y);
            context.pathList.push_back(std::unique_ptr<PathComponent>(new LineComponent(context.currentPoint, destination)));
            context.currentPoint = destination;
            break;
        } case kCGPathElementAddQuadCurveToPoint: {
            CGPoint control = CGPointMake(element->points[0].x, element->points[0].y);
            CGPoint destination = CGPointMake(element->points[1].x, element->points[1].y);
            context.pathList.push_back(std::unique_ptr<PathComponent>(new CubicComponent(QuadraticComponent(context.currentPoint, control, destination).cubicComponent())));
            context.currentPoint = destination;
            break;
        } case kCGPathElementAddCurveToPoint: {
            CGPoint control1 = CGPointMake(element->points[0].x, element->points[0].y);
            CGPoint control2 = CGPointMake(element->points[1].x, element->points[1].y);
            CGPoint destination = CGPointMake(element->points[2].x, element->points[2].y);
            context.pathList.push_back(std::unique_ptr<PathComponent>(new CubicComponent(context.currentPoint, control1, control2, destination)));
            context.currentPoint = destination;
            break;
        } case kCGPathElementCloseSubpath:
            context.pathList.push_back(std::unique_ptr<PathComponent>(new CloseComponent(context.currentPoint, context.subpathStart)));
            context.currentPoint = context.subpathStart;
            break;
        default:
            assert(false);
    }
}

CGPathRef createNonIntersectingPath(CGPathRef path) {
    PathList pathList;
    NonIntersectingContext context(pathList);
    CGPathApply(path, &context, &nonIntersectingPathApplierFunction);
    /*
    for (auto i(pathList.begin()); i != pathList.end(); ++i) {
        CubicComponent* a(dynamic_cast<CubicComponent*>(i->get()));
        if (a == nullptr)
            continue;
        auto j(i);
        for (++j; j != pathList.end();) {
            bool incJ(true);
            CubicComponent* b(dynamic_cast<CubicComponent*>(j->get()));
            if (b != nullptr) {
                if (a->intersect(*b)) {
                    incJ = false;
                    CGFloat aarea(a->area());
                    CGFloat barea(b->area());
                    if (aarea > barea) {
                        auto subdivision(a->subdivide());
                        pathList.insert(i, std::unique_ptr<PathComponent>(new CubicComponent(subdivision[0])));
                        pathList.insert(i, std::unique_ptr<PathComponent>(new CubicComponent(subdivision[1])));
                        i = pathList.erase(i);
                        --i;
                        --i;
                    } else {
                        auto subdivision(b->subdivide());
                        pathList.insert(j, std::unique_ptr<PathComponent>(new CubicComponent(subdivision[0])));
                        pathList.insert(j, std::unique_ptr<PathComponent>(new CubicComponent(subdivision[1])));
                        j = pathList.erase(j);
                        --j;
                        --j;
                    }
                }
            }
            if (incJ)
                ++j;
        }
    }
*/
    CGMutablePathRef result = CGPathCreateMutable();
    for (auto& i : pathList)
        i->emit(result);
    return result;
}

/*
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
        } case kCGPathElementAddCurveToPoint: {
            CGPoint control1 = CGPointMake(element->points[0].x, element->points[0].y);
            CGPoint control2 = CGPointMake(element->points[1].x, element->points[1].y);
            CGPoint destination = CGPointMake(element->points[2].x, element->points[2].y);
            context.append(std::unique_ptr<PathComponent>(new CubicComponent(context.source, control1, control2, destination)));
            context.source = destination;
            break;
        } case kCGPathElementCloseSubpath:
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
*/