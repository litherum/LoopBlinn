//
//  Triangulator.cpp
//  LoopBlinn
//
//  Created by Myles C. Maxfield on 2/5/15.
//  Copyright (c) 2015 Litherum. All rights reserved.
//

#include "Triangulator.h"

#include "CFPtr.h"

#include <queue>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconditional-uninitialized"
#pragma clang diagnostic ignored "-Wshorten-64-to-32"
#include <CGAL/Exact_predicates_inexact_constructions_kernel.h>
#include <CGAL/Constrained_Delaunay_triangulation_2.h>
#include <CGAL/Triangulation_face_base_with_info_2.h>
#include <CGAL/Polygon_2.h>
#pragma clang diagnostic pop

struct FaceInfo {
    bool marked;
};

typedef CGAL::Exact_predicates_inexact_constructions_kernel       K;
typedef CGAL::Triangulation_vertex_base_2<K>                      Vb;
typedef CGAL::Triangulation_face_base_with_info_2<FaceInfo, K>    Fbb;
typedef CGAL::Constrained_triangulation_face_base_2<K,Fbb>        Fb;
typedef CGAL::Triangulation_data_structure_2<Vb,Fb>               TDS;
typedef CGAL::Exact_predicates_tag                                Itag;
typedef CGAL::Constrained_Delaunay_triangulation_2<K, TDS, Itag>  CDT;
typedef CGAL::Polygon_2<K>                                        Polygon_2;

static bool orientTurn(float x1, float y1, float x2, float y2) {
    return CGAL::cross_product(CGAL::Vector_3<K>(x1, y1, 0), CGAL::Vector_3<K>(x2, y2, 0)).z() > 0;
}

struct Triangulator {
    void moveTo(CGPoint destination) {
        currentPosition = cdt.insert(CDT::Point(destination.x, destination.y));
        subpathStart = currentPosition;
        std::vector<CDT::Vertex_handle> subpath;
        subpath.push_back(currentPosition);
        subpaths.emplace_back(std::move(subpath));
    }

    void lineTo(CGPoint destination) {
        CDT::Vertex_handle nextPosition = cdt.insert(CDT::Point(destination.x, destination.y));
        lineTo(nextPosition);
    }

    void quadraticTo(CGPoint destination, CGPoint control) {
        std::array<CGPoint, 3> quadraticCurve{{CGPointMake(currentPosition->point().x(), currentPosition->point().y()), control, destination}};
        bool orientation = orientTurn(control.x - currentPosition->point().x(), control.y - currentPosition->point().y(), destination.x - currentPosition->point().x(), destination.y - currentPosition->point().y());
        quadraticCurves.emplace_back(std::make_pair(std::move(quadraticCurve), std::move(orientation)));
        if (orientation) {
            lineTo(control);
            lineTo(destination);
        } else
            lineTo(destination);
    }

    void cubicTo(CGPoint destination, CGPoint control1, CGPoint control2) {
        lineTo(destination); // FIXME: Implement
    }

    void close() {
        lineTo(subpathStart);
    }

    void mark() {
        for(CDT::All_faces_iterator i = cdt.all_faces_begin(); i != cdt.all_faces_end(); ++i){
            i->info().marked = false;
        }

        for (auto& subpath : subpaths) {
            if (subpath.size() < 3)
                continue;
            for (size_t i = 0; i < subpath.size() - 1; ++i) {
                CDT::Vertex_handle vertex1 = subpath[i];
                CDT::Vertex_handle vertex2 = subpath[i + 1];
                CDT::Face_handle seed = lookupFace(vertex1, vertex2);
                if (seed->info().marked)
                    continue;

                std::queue<CDT::Face_handle> queue;
                queue.push(seed);
                while (queue.size()) {
                    CDT::Face_handle face = queue.front();
                    queue.pop();
                    face->info().marked = true;
                    for (int i = 0; i < 3; ++i) {
                        CDT::Edge e(face, i);
                        if (cdt.is_constrained(e))
                            continue;
                        CDT::Face_handle neighbor = face->neighbor(i);
                        if (!neighbor->info().marked)
                            queue.push(neighbor);
                    }
                }
            }
        }
    }

    void apply(TriangleIterator iterator, void* context) {
        for (auto i = cdt.all_faces_begin(); i != cdt.all_faces_end(); ++i) {
            if (i->vertex(0) == cdt.infinite_vertex() || i->vertex(1) == cdt.infinite_vertex() || i->vertex(2) == cdt.infinite_vertex())
                continue;
            if (i->info().marked)
                iterator(context, CGPointMake(i->vertex(0)->point().x(), i->vertex(0)->point().y()),
                                  CGPointMake(i->vertex(1)->point().x(), i->vertex(1)->point().y()),
                                  CGPointMake(i->vertex(2)->point().x(), i->vertex(2)->point().y()),
                                  CGPointMake(0, 1), CGPointMake(0, 1), CGPointMake(0, 1), false);
        }
        for (auto& quad : quadraticCurves)
            iterator(context, quad.first[0], quad.first[1], quad.first[2], CGPointMake(0, 0), CGPointMake(0.5, 0), CGPointMake(1, 1), quad.second);
    }

private:
    void lineTo(CDT::Vertex_handle nextPosition) {
        if (currentPosition == nextPosition)
            return;
        cdt.insert_constraint(currentPosition, nextPosition);
        currentPosition = nextPosition;
        subpaths[subpaths.size() - 1].push_back(nextPosition);
    }

    CDT::Face_handle lookupFace(CDT::Vertex_handle vertex1, CDT::Vertex_handle vertex2) {
        CDT::Face_circulator initial = cdt.incident_faces(vertex1);
        CDT::Face_circulator i = initial;
        do {
            for (int j = 0; j < 3; ++j) {
                if (i->vertex(j) == vertex1 && i->vertex(CDT::cw(j)) == vertex2)
                    return i;
            }
            ++i;
        } while (i != initial);
        assert(false);
    }

    CDT cdt;
    CDT::Vertex_handle currentPosition;
    CDT::Vertex_handle subpathStart;
    std::vector<std::vector<CDT::Vertex_handle>> subpaths;
    std::vector<std::pair<std::array<CGPoint, 3>, bool>> quadraticCurves;
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
    {
    }
    Triangulator& triangulator;
    CGPoint origin;
};

static void pathIterator(void *info, const CGPathElement *element) {
    struct PathIteratorContext& context = *(PathIteratorContext*)info;
    switch (element->type) {
        case kCGPathElementMoveToPoint: {
            CGPoint absolutePoint = CGPointMake(context.origin.x + element->points[0].x, context.origin.y + element->points[0].y);
            context.triangulator.moveTo(absolutePoint);
            break;
        }
        case kCGPathElementAddLineToPoint: {
            CGPoint absolutePoint = CGPointMake(context.origin.x + element->points[0].x, context.origin.y + element->points[0].y);
            context.triangulator.lineTo(absolutePoint);
            break;
        }
        case kCGPathElementAddQuadCurveToPoint: {
            CGPoint absolutePoint1 = CGPointMake(context.origin.x + element->points[0].x, context.origin.y + element->points[0].y);
            CGPoint absolutePoint2 = CGPointMake(context.origin.x + element->points[1].x, context.origin.y + element->points[1].y);
            context.triangulator.quadraticTo(absolutePoint2, absolutePoint1);
            break;
        }
        case kCGPathElementAddCurveToPoint: {
            CGPoint absolutePoint1 = CGPointMake(context.origin.x + element->points[0].x, context.origin.y + element->points[0].y);
            CGPoint absolutePoint2 = CGPointMake(context.origin.x + element->points[1].x, context.origin.y + element->points[1].y);
            CGPoint absolutePoint3 = CGPointMake(context.origin.x + element->points[2].x, context.origin.y + element->points[2].y);
            context.triangulator.cubicTo(absolutePoint3, absolutePoint1, absolutePoint2);
            break;
        }
        case kCGPathElementCloseSubpath:
            context.triangulator.close();
            break;
        default:
            assert(false);
    }
}

void triangulatorAppendPath(Triangulator* triangulator, CGPathRef path, CGPoint origin) {
    triangulator->moveTo(origin);
    struct PathIteratorContext context(*triangulator, origin);
    CGPathApply(path, &context, &pathIterator);
}

void triangulatorTriangulate(Triangulator* triangulator) {
    triangulator->mark();
}

void triangulatorApply(Triangulator* triangulator, TriangleIterator iterator, void* context) {
    triangulator->apply(iterator, context);
}