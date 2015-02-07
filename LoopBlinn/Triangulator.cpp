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
#include <CGAL/Linear_algebraCd.h>
#pragma clang diagnostic pop

struct FaceInfo {
    bool marked;
};

typedef CGAL::Simple_cartesian<CGFloat>                           IK;
typedef CGAL::Filtered_kernel<IK>                                 K;
typedef CGAL::Triangulation_vertex_base_2<K>                      Vb;
typedef CGAL::Triangulation_face_base_with_info_2<FaceInfo, K>    Fbb;
typedef CGAL::Constrained_triangulation_face_base_2<K,Fbb>        Fb;
typedef CGAL::Triangulation_data_structure_2<Vb,Fb>               TDS;
typedef CGAL::Exact_predicates_tag                                Itag;
typedef CGAL::Constrained_Delaunay_triangulation_2<K, TDS, Itag>  CDT;
typedef CGAL::Polygon_2<K>                                        Polygon_2;


static inline std::array<std::array<CGFloat, 3>, 4> serpentine(CGFloat d1, CGFloat d2, CGFloat d3) {
    CGFloat ls(3 * d2 - std::sqrt(9 * d2 * d2 - 12 * d1 * d3));
    CGFloat lt(6 * d1);
    CGFloat ms(3 * d2 + std::sqrt(9 * d2 * d2 - 12 * d1 * d3));
    CGFloat mt(6 * d1);
    return std::array<std::array<CGFloat, 3>, 4>{{
        std::array<CGFloat, 3>{{ls * ms, ls * ls * ls, ms * ms * ms}},
        std::array<CGFloat, 3>{{(3 * ls * ms - ls * mt - lt * ms) / 3, ls * ls * (ls - lt), ms * ms * (ms - mt)}},
        std::array<CGFloat, 3>{{(lt * (mt - 2 * ms) + ls * (3 * ms - 2 * mt)) / 3, (lt - ls) * (lt - ls) * ls, (mt - ms) * (mt - ms) * ms}},
        std::array<CGFloat, 3>{{(lt - ls) * (mt - ms), -(lt - ls) * (lt - ls) * (lt - ls), -(mt - ms) * (mt - ms) * (mt - ms)}}
    }};
}

static inline std::array<std::array<CGFloat, 3>, 4> loop(CGFloat d1, CGFloat d2, CGFloat d3) {
    CGFloat ls(d2 - std::sqrt(4 * d1 * d3 - 3 * d2 * d2));
    CGFloat lt(2 * d1);
    CGFloat ms(d2 + std::sqrt(4 * d1 * d3 - 3 * d2 * d2));
    CGFloat mt(2 * d1);
    return std::array<std::array<CGFloat, 3>, 4>{{
        std::array<CGFloat, 3>{{ls * ms, ls * ls * ms, ls * ms * ms}},
        std::array<CGFloat, 3>{{(-ls * mt - lt * ms + ls * ms) / 3, ls * (ls * (mt - 3 * ms) + 2 * lt * ms) / -3, ms * (ls * (2 * mt - 3 * ms) + lt * ms) / -3}},
        std::array<CGFloat, 3>{{(lt * (mt - 2 * ms) + ls * (3 * ms - 2 * mt)) / 3, (lt - ls) * (ls * (2 * mt - 3 * ms) + lt * ms) / 3, (mt - ms) * (ls * (mt - 3 * ms) + 2 * lt * ms) / 3}},
        std::array<CGFloat, 3>{{(lt - ls) * (mt - ms), -(lt - ls) * (lt - ls) * (mt - ms), -(lt - ls) * (mt - ms) * (mt - ms)}}
    }};
}

static inline std::array<std::array<CGFloat, 3>, 4> cuspWithCuspAtInfinity(CGFloat d1, CGFloat d2, CGFloat d3) {
    CGFloat ls(d3);
    CGFloat lt(3 * d2);
    return std::array<std::array<CGFloat, 3>, 4>{{
        std::array<CGFloat, 3>{{ls, ls * ls * ls, 1}},
        std::array<CGFloat, 3>{{ls - lt / 3, ls * ls * (ls - lt), 1}},
        std::array<CGFloat, 3>{{ls - 2 * lt / 3, (ls - lt) * (ls - lt) * ls, 1}},
        std::array<CGFloat, 3>{{ls - lt, (ls - lt) * (ls - lt) * (ls - lt), 1}}
    }};
}

static inline std::array<std::array<CGFloat, 3>, 4> quadratic(CGFloat d1, CGFloat d2, CGFloat d3) {
    return std::array<std::array<CGFloat, 3>, 4>{{
        std::array<CGFloat, 3>{{0, 0, 0}},
        std::array<CGFloat, 3>{{CGFloat(1) / 3, 0, CGFloat(1) / 3}},
        std::array<CGFloat, 3>{{CGFloat(2) / 3, CGFloat(1) / 3, CGFloat(2) / 3}},
        std::array<CGFloat, 3>{{1, 1, 1}}
    }};
}

static inline std::array<std::array<CGFloat, 3>, 4> lineOrPoint(CGFloat d1, CGFloat d2, CGFloat d3) {
    return std::array<std::array<CGFloat, 3>, 4>{{
        std::array<CGFloat, 3>{{0, 0, 0}},
        std::array<CGFloat, 3>{{0, 0, 0}},
        std::array<CGFloat, 3>{{0, 0, 0}},
        std::array<CGFloat, 3>{{0, 0, 0}}
    }};
}

static inline std::array<std::array<CGFloat, 3>, 4> cubic(CGPoint b0i, CGPoint b1i, CGPoint b2i, CGPoint b3i) {
    CGAL::Vector_3<IK> b0(b0i.x, b0i.y, 1);
    CGAL::Vector_3<IK> b1(b1i.x, b1i.y, 1);
    CGAL::Vector_3<IK> b2(b2i.x, b2i.y, 1);
    CGAL::Vector_3<IK> b3(b3i.x, b3i.y, 1);
    CGFloat a1(b0 * CGAL::cross_product(b3, b2));
    CGFloat a2(b1 * CGAL::cross_product(b0, b3));
    CGFloat a3(b2 * CGAL::cross_product(b1, b0));
    CGFloat d1(a1 - 2 * a2 + 3 * a3);
    CGFloat d2(-a2 + 3 * a3);
    CGFloat d3(3 * a3);
    CGFloat discr(3 * d2 * d2 - 4 * d1 * d3);
    if (d1 != 0) {
        if (discr > 0)
            return serpentine(d1, d2, d3);
        else if (discr < 0)
            return loop(d1, d2, d3);
        else
            return serpentine(d1, d2, d3);
    } else if (d2 != 0)
        return cuspWithCuspAtInfinity(d1, d2, d3);
    else if (d3 != 0)
        return quadratic(d1, d2, d3);
    else
        return lineOrPoint(d1, d2, d3);
}

struct CubicCurve {
    CubicCurve(std::array<CGPoint, 4>&& vertices, std::array<std::array<CGFloat, 3>, 4>&& coordinates, bool orientation)
        : vertices(std::move(vertices))
        , coordinates(std::move(coordinates))
        , orientation(orientation)
    {
    }
    std::array<CGPoint, 4> vertices;
    std::array<std::array<CGFloat, 3>, 4> coordinates;
    bool orientation;
};

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
        // FIXME: Unify with cubicTo
        lineTo(destination);
        /*
        std::array<CGPoint, 3> quadraticCurve{{CGPointMake(currentPosition->point().x(), currentPosition->point().y()), control, destination}};
        bool orientation = orientTurn(control.x - currentPosition->point().x(), control.y - currentPosition->point().y(), destination.x - currentPosition->point().x(), destination.y - currentPosition->point().y());
        quadraticCurves.emplace_back(std::make_pair(std::move(quadraticCurve), std::move(orientation)));
        if (orientation) {
            lineTo(control);
            lineTo(destination);
        } else
            lineTo(destination);
        */
    }

    void cubicTo(CGPoint destination, CGPoint control1, CGPoint control2) {
        std::array<CGPoint, 4> vertices{{CGPointMake(currentPosition->point().x(), currentPosition->point().y()), control1, control2, destination}};
        bool orientation1 = orientTurn(control1.x - currentPosition->point().x(), control1.y - currentPosition->point().y(), destination.x - currentPosition->point().x(), destination.y - currentPosition->point().y());
        bool orientation2 = orientTurn(control2.x - currentPosition->point().x(), control2.y - currentPosition->point().y(), destination.x - currentPosition->point().x(), destination.y - currentPosition->point().y());
        auto coordinates(cubic(vertices[0], vertices[1], vertices[2], vertices[3]));
        cubicCurves.emplace_back(std::move(vertices), std::move(coordinates), false);
        if (orientation1 && orientation2) {
            lineTo(control1);
            lineTo(control2);
            lineTo(destination);
        } else if (orientation1) {
            lineTo(control1);
            lineTo(destination);
        } else if (orientation2) {
            lineTo(control2);
            lineTo(destination);
        } else
            lineTo(destination);
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
        /*for (auto i = cdt.all_faces_begin(); i != cdt.all_faces_end(); ++i) {
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
        */
        for (auto& cubicCurve : cubicCurves) {
            iterator(context,
                cubicCurve.vertices[0], cubicCurve.vertices[1], cubicCurve.vertices[2], cubicCurve.vertices[3],
                {cubicCurve.coordinates[0][0], cubicCurve.coordinates[0][1], cubicCurve.coordinates[0][2]},
                {cubicCurve.coordinates[1][0], cubicCurve.coordinates[1][1], cubicCurve.coordinates[1][2]},
                {cubicCurve.coordinates[2][0], cubicCurve.coordinates[2][1], cubicCurve.coordinates[2][2]},
                {cubicCurve.coordinates[3][0], cubicCurve.coordinates[3][1], cubicCurve.coordinates[3][2]},
                cubicCurve.orientation);
        }
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
    std::vector<CubicCurve> cubicCurves;
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

void triangulatorCubic(Triangulator* triangulator, CGPoint a, CGPoint b, CGPoint c, CGPoint d) {
    triangulator->moveTo(a);
    triangulator->cubicTo(d, b, c);
}
