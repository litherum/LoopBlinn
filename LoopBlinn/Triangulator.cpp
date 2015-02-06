//
//  Triangulator.cpp
//  LoopBlinn
//
//  Created by Myles C. Maxfield on 2/5/15.
//  Copyright (c) 2015 Litherum. All rights reserved.
//

#include "Triangulator.h"

#include "CFPtr.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconditional-uninitialized"
#pragma clang diagnostic ignored "-Wshorten-64-to-32"
#include <CGAL/Exact_predicates_inexact_constructions_kernel.h>
#include <CGAL/Constrained_Delaunay_triangulation_2.h>
#include <CGAL/Triangulation_face_base_with_info_2.h>
#include <CGAL/Polygon_2.h>
#pragma clang diagnostic pop

typedef CGAL::Exact_predicates_inexact_constructions_kernel       K;
typedef CGAL::Triangulation_vertex_base_2<K>                      Vb;
typedef CGAL::Triangulation_face_base_2<K>                        Fbb;
typedef CGAL::Constrained_triangulation_face_base_2<K,Fbb>        Fb;
typedef CGAL::Triangulation_data_structure_2<Vb,Fb>               TDS;
typedef CGAL::Exact_predicates_tag                                Itag;
typedef CGAL::Constrained_Delaunay_triangulation_2<K, TDS, Itag>  CDT;
typedef CGAL::Polygon_2<K>                                        Polygon_2;

struct Triangulator {
    void moveTo(CGPoint destination) {
        //assert(cdt.is_valid());
        currentPosition = cdt.insert(CDT::Point(destination.x, destination.y));
        //assert(cdt.is_valid());
        //std::cout << "Inserting  " << destination.x << " " << destination.y << std::endl;
    }

    void lineTo(CGPoint destination) {
        //assert(cdt.is_valid());
        CDT::Vertex_handle nextPosition = cdt.insert(CDT::Point(destination.x, destination.y));
        //std::cout << "Inserting  " << destination.x << " " << destination.y << std::endl;
        if (currentPosition == nextPosition) {
            //assert(cdt.is_valid());
            return;
        }
        cdt.insert_constraint(currentPosition, nextPosition);
        currentPosition = nextPosition;
        //assert(cdt.is_valid());
    }

    void quadraticTo(CGPoint destination, CGPoint control) {
        std::array<CGPoint, 3> quadraticCurve{{CGPointMake(currentPosition->point().x(), currentPosition->point().y()), control, destination}};
        quadraticCurves.emplace_back(std::move(quadraticCurve));
        lineTo(destination);
    }

    void path(CGPathRef path, CGPoint origin) {
        paths.emplace_back(std::make_pair(path, origin));
    }

    void apply(TriangleIterator iterator, void* context) {
        for (auto i = cdt.all_faces_begin(); i != cdt.all_faces_end(); ++i) {
            //std::cout << "Triangle at (" << i->vertex(0)->point().x() << ", " << i->vertex(0)->point().y() << ") (" << i->vertex(1)->point().x() << ", " << i->vertex(1)->point().y() << ") (" << i->vertex(2)->point().x() << ", " << i->vertex(2)->point().y() << ")" << std::endl;
            if (i->vertex(0) == cdt.infinite_vertex() || i->vertex(1) == cdt.infinite_vertex() || i->vertex(2) == cdt.infinite_vertex())
                continue;
            CGPoint middle = CGPointMake((i->vertex(0)->point().x() + i->vertex(1)->point().x() + i->vertex(2)->point().x()) / 3, (i->vertex(0)->point().y() + i->vertex(1)->point().y() + i->vertex(2)->point().y()) / 3);
            for (auto& path : paths) {
                if (CGPathContainsPoint(path.first.get(), NULL, CGPointMake(middle.x - path.second.x, middle.y - path.second.y), true)) { // FIXME: EO rule?
                    iterator(context, CGPointMake(i->vertex(0)->point().x(), i->vertex(0)->point().y()),
                                      CGPointMake(i->vertex(1)->point().x(), i->vertex(1)->point().y()),
                                      CGPointMake(i->vertex(2)->point().x(), i->vertex(2)->point().y()),
                                      CGPointMake(0, 1), CGPointMake(0, 1), CGPointMake(0, 1));
                    break;
                }
            }
        }
        for (auto& quad : quadraticCurves) {
            iterator(context, quad[0], quad[1], quad[2], CGPointMake(0, 0), CGPointMake(0.5, 0), CGPointMake(1, 1));
        }
        //std::cout << "Done with triangles" << std::endl;
    }

private:
    CDT cdt;
    std::vector<std::pair<CFPtr<CGPathRef>, CGPoint>> paths;
    CDT::Vertex_handle currentPosition;
    std::vector<std::array<CGPoint, 3>> quadraticCurves;
};

Triangulator* createTriangulator() {
    return new Triangulator;
}

void destroyTriangulator(Triangulator* triangulator)
{
    delete triangulator;
}

struct PathIteratorContext {
    PathIteratorContext(Triangulator& triangulator, CGPoint origin)
        : triangulator(triangulator)
        , origin(origin)
        , subpathStart(origin)
    {
    }
    Triangulator& triangulator;
    CGPoint origin;
    CGPoint subpathStart;
};

static void pathIterator(void *info, const CGPathElement *element) {
    struct PathIteratorContext& context = *(PathIteratorContext*)info;
    switch (element->type) {
        case kCGPathElementMoveToPoint: {
            //NSLog(@"Moving to (%@, %@)", @(element->points[0].x), @(element->points[0].y));
            CGPoint absolutePoint = CGPointMake(context.origin.x + element->points[0].x, context.origin.y + element->points[0].y);
            context.triangulator.moveTo(absolutePoint);
            context.subpathStart = absolutePoint;
            break;
        }
        case kCGPathElementAddLineToPoint: {
            //NSLog(@"Line to (%@, %@)", @(element->points[0].x), @(element->points[0].y));
            CGPoint absolutePoint = CGPointMake(context.origin.x + element->points[0].x, context.origin.y + element->points[0].y);
            context.triangulator.lineTo(absolutePoint);
            break;
        }
        case kCGPathElementAddQuadCurveToPoint: {
            //NSLog(@"Quadratic curve. Control point 1: (%@, %@) Destination: (%@, %@)", @(element->points[0].x), @(element->points[0].y), @(element->points[1].x), @(element->points[1].y));
            CGPoint absolutePoint1 = CGPointMake(context.origin.x + element->points[0].x, context.origin.y + element->points[0].y);
            CGPoint absolutePoint2 = CGPointMake(context.origin.x + element->points[1].x, context.origin.y + element->points[1].y);
            context.triangulator.quadraticTo(absolutePoint2, absolutePoint1);
            break;
        }
        case kCGPathElementAddCurveToPoint: {
            //NSLog(@"Cubic curve. Control point 1: (%@, %@) Control point 2: (%@, %@) Destination: (%@, %@)", @(element->points[0].x), @(element->points[0].y), @(element->points[1].x), @(element->points[1].y), @(element->points[2].x), @(element->points[2].y));
            CGPoint absolutePoint = CGPointMake(context.origin.x + element->points[2].x, context.origin.y + element->points[2].y);
            context.triangulator.lineTo(absolutePoint);
            break;
        }
        case kCGPathElementCloseSubpath:
            //NSLog(@"Closing subpath");
            context.triangulator.lineTo(context.subpathStart);
            break;
        default:
            assert(false);
    }
}

void triangulatorAppendPath(Triangulator* triangulator, CGPathRef path, CGPoint origin) {
    triangulator->path(path, origin);
    triangulator->moveTo(origin);
    struct PathIteratorContext context(*triangulator, origin);
    CGPathApply(path, &context, &pathIterator);
}

void triangulatorTriangulate(Triangulator*) {
}

void triangulatorApply(Triangulator* triangulator, TriangleIterator iterator, void* context) {
    triangulator->apply(iterator, context);
}