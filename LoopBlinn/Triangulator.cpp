//
//  Triangulator.cpp
//  LoopBlinn
//
//  Created by Myles C. Maxfield on 2/5/15.
//  Copyright (c) 2015 Litherum. All rights reserved.
//

#include "Triangulator.h"

#include "CFPtr.h"
#include "PathWinder.h"

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

typedef CGAL::Filtered_kernel<CGAL::Simple_cartesian<CGFloat>>    K;
typedef CGAL::Triangulation_vertex_base_2<K>                      Vb;
typedef CGAL::Triangulation_face_base_with_info_2<FaceInfo, K>    Fbb;
typedef CGAL::Constrained_triangulation_face_base_2<K,Fbb>        Fb;
typedef CGAL::Triangulation_data_structure_2<Vb,Fb>               TDS;
typedef CGAL::Exact_predicates_tag                                Itag;
typedef CGAL::Constrained_Delaunay_triangulation_2<K, TDS, Itag>  CDT;
typedef CGAL::Polygon_2<K>                                        Polygon_2;

static inline std::pair<std::array<std::array<CGFloat, 3>, 4>, bool> serpentine(CGFloat d1, CGFloat d2, CGFloat d3) {
    CGFloat ls(3 * d2 - std::sqrt(9 * d2 * d2 - 12 * d1 * d3));
    CGFloat lt(6 * d1);
    CGFloat ms(3 * d2 + std::sqrt(9 * d2 * d2 - 12 * d1 * d3));
    CGFloat mt(6 * d1);
    return std::make_pair(std::array<std::array<CGFloat, 3>, 4>{
        std::array<CGFloat, 3>{ls * ms, ls * ls * ls, ms * ms * ms},
        std::array<CGFloat, 3>{(3 * ls * ms - ls * mt - lt * ms) / 3, ls * ls * (ls - lt), ms * ms * (ms - mt)},
        std::array<CGFloat, 3>{(lt * (mt - 2 * ms) + ls * (3 * ms - 2 * mt)) / 3, (lt - ls) * (lt - ls) * ls, (mt - ms) * (mt - ms) * ms},
        std::array<CGFloat, 3>{(lt - ls) * (mt - ms), -(lt - ls) * (lt - ls) * (lt - ls), -(mt - ms) * (mt - ms) * (mt - ms)}
    }, d1 < 0);
}

static inline std::pair<std::array<std::array<CGFloat, 3>, 4>, bool> loop(CGFloat d1, CGFloat d2, CGFloat d3) {
    CGFloat ls(d2 - std::sqrt(4 * d1 * d3 - 3 * d2 * d2));
    CGFloat lt(2 * d1);
    CGFloat ms(d2 + std::sqrt(4 * d1 * d3 - 3 * d2 * d2));
    CGFloat mt(2 * d1);
    return std::make_pair(std::array<std::array<CGFloat, 3>, 4>{
        std::array<CGFloat, 3>{ls * ms, ls * ls * ms, ls * ms * ms},
        std::array<CGFloat, 3>{(-ls * mt - lt * ms + 3 * ls * ms) / 3, ls * (ls * (mt - 3 * ms) + 2 * lt * ms) / -3, ms * (ls * (2 * mt - 3 * ms) + lt * ms) / -3},
        std::array<CGFloat, 3>{(lt * (mt - 2 * ms) + ls * (3 * ms - 2 * mt)) / 3, (lt - ls) * (ls * (2 * mt - 3 * ms) + lt * ms) / 3, (mt - ms) * (ls * (mt - 3 * ms) + 2 * lt * ms) / 3},
        std::array<CGFloat, 3>{(lt - ls) * (mt - ms), -(lt - ls) * (lt - ls) * (mt - ms), -(lt - ls) * (mt - ms) * (mt - ms)}
    }, false); // FIXME: might need to subdivide and update orientation
}

static inline std::pair<std::array<std::array<CGFloat, 3>, 4>, bool> cusp(CGFloat d1, CGFloat d2, CGFloat d3) {
    CGFloat ls(d3);
    CGFloat lt(3 * d2);
    return std::make_pair(std::array<std::array<CGFloat, 3>, 4>{
        std::array<CGFloat, 3>{ls, ls * ls * ls, 1},
        std::array<CGFloat, 3>{ls - lt / 3, ls * ls * (ls - lt), 1},
        std::array<CGFloat, 3>{ls - 2 * lt / 3, (ls - lt) * (ls - lt) * ls, 1},
        std::array<CGFloat, 3>{ls - lt, (ls - lt) * (ls - lt) * (ls - lt), 1}
    }, false);
}

static inline std::pair<std::array<std::array<CGFloat, 3>, 4>, bool> quadratic(CGFloat d1, CGFloat d2, CGFloat d3) {
    return std::make_pair(std::array<std::array<CGFloat, 3>, 4>{
        std::array<CGFloat, 3>{0, 0, 0},
        std::array<CGFloat, 3>{CGFloat(1) / 3, 0, CGFloat(1) / 3},
        std::array<CGFloat, 3>{CGFloat(2) / 3, CGFloat(1) / 3, CGFloat(2) / 3},
        std::array<CGFloat, 3>{1, 1, 1}
    }, d3 < 0);
}

static inline std::pair<std::array<std::array<CGFloat, 3>, 4>, bool> lineOrPoint(CGFloat d1, CGFloat d2, CGFloat d3) {
    return std::make_pair(std::array<std::array<CGFloat, 3>, 4>{
        std::array<CGFloat, 3>{0, 0, 0},
        std::array<CGFloat, 3>{0, 0, 0},
        std::array<CGFloat, 3>{0, 0, 0},
        std::array<CGFloat, 3>{0, 0, 0}
    }, false);
}

CGFloat roundToZero(CGFloat val)
{
    static const CGFloat epsilon(5.0e-4f);
    if (val < epsilon && val > -epsilon)
        return 0;
    return val;
}

static inline std::array<std::array<CGFloat, 3>, 4> cubic(CGPoint b0i, CGPoint b1i, CGPoint b2i, CGPoint b3i) {
    CGAL::Vector_3<K> b0(b0i.x, b0i.y, 1);
    CGAL::Vector_3<K> b1(b1i.x, b1i.y, 1);
    CGAL::Vector_3<K> b2(b2i.x, b2i.y, 1);
    CGAL::Vector_3<K> b3(b3i.x, b3i.y, 1);
    CGFloat a1(b0 * CGAL::cross_product(b3, b2));
    CGFloat a2(b1 * CGAL::cross_product(b0, b3));
    CGFloat a3(b2 * CGAL::cross_product(b1, b0));
    CGFloat d1(a1 - 2 * a2 + 3 * a3);
    CGFloat d2(-a2 + 3 * a3);
    CGFloat d3(3 * a3);
    CGAL::Vector_3<K> u(d1, d2, d3);
    u = u / std::sqrt(u.squared_length());
    d1 = u.x();
    d2 = u.y();
    d3 = u.z();

    std::pair<std::array<std::array<CGFloat, 3>, 4>, bool> result;
    CGFloat discr(d1 * d1 * (3 * d2 * d2 - 4 * d1 * d3));

    d1 = roundToZero(d1);
    d2 = roundToZero(d2);
    d3 = roundToZero(d3);

    if (b0 == b1 && b0 == b2 && b0 == b3)
        result = lineOrPoint(d1, d2, d3);
    else if (d1 == 0 && d2 == 0 && d3 == 0)
        result = lineOrPoint(d1, d2, d3);
    else if (d1 == 0 && d2 == 0)
        result = quadratic(d1, d2, d3);
    else if (discr > 0)
        result = serpentine(d1, d2, d3);
    else if (discr < 0)
        result = loop(d1, d2, d3);
    else
        result = cusp(d1, d2, d3);

    if (result.second)
        for (auto& i : result.first)
            for (size_t j(0); j < 2; ++j)
                i[j] *= -1;
    return result.first;
}

struct CubicCurve {
    CubicCurve(std::array<CGPoint, 4>&& vertices, std::array<std::array<CGFloat, 3>, 4>&& coordinates)
        : vertices(std::move(vertices))
        , coordinates(std::move(coordinates))
    {
    }
    std::array<CGPoint, 4> vertices;
    std::array<std::array<CGFloat, 3>, 4> coordinates;
};

static bool onWay(CGAL::Vector_2<K> of, CGAL::Vector_2<K> onto) {
    auto ontoUnit(onto / std::sqrt(onto.squared_length()));
    auto proj((of * ontoUnit) * ontoUnit);
    auto error(std::sqrt((of - proj).squared_length()));
    auto scalar((of * onto) / (onto * onto));
    return scalar > 0 && scalar <= 1 && error < 0.005;
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
        CGPoint cp1 = CGPointMake(currentPosition->point().x() + 2 * (control.x - currentPosition->point().x()) / 3, currentPosition->point().y() + 2 * (control.y - currentPosition->point().y()) / 3);
        CGPoint cp2 = CGPointMake(destination.x + 2 * (control.x - destination.x) / 3, destination.y + 2 * (control.y - destination.y) / 3);
        cubicTo(destination, cp1, cp2);
    }

    void cubicTo(CGPoint destination, CGPoint control1, CGPoint control2) {
        std::array<CGPoint, 4> vertices{CGPointMake(currentPosition->point().x(), currentPosition->point().y()), control1, control2, destination};
        CGAL::Vector_2<K> dc1(control1.x - currentPosition->point().x(), control1.y - currentPosition->point().y());
        CGAL::Vector_2<K> dc2(control2.x - currentPosition->point().x(), control2.y - currentPosition->point().y());
        CGAL::Vector_2<K> dd(destination.x - currentPosition->point().x(), destination.y - currentPosition->point().y());
        bool orientation1 = CGAL::orientation(dc1, dd) == CGAL::LEFT_TURN; // dc1 is on the right side of dd
        bool orientation2 = CGAL::orientation(dc2, dd) == CGAL::LEFT_TURN; // dc2 is on the right side of dd
        auto coordinates(cubic(vertices[0], vertices[1], vertices[2], vertices[3]));

        // Enforce clockwise winding for the curve triangles
        std::array<size_t, 4> order;
        if (orientation1 != orientation2) {
            if (orientation1) // First control point is on the right side of destination
                order = {1, 0, 3, 2};
            else
                order = {2, 0, 3, 1};
        } else if (dc1 * dd < dc2 * dd) { // Same side, dc1 is closer to currentPosition than dc2
            if (orientation1) // Control points are on right side of destination
                order = {0, 3, 1, 2};
            else
                order = {1, 2, 0, 3};
        } else { // Same side, dc2 is closer to currentPosition than dc1
            if (orientation1)
                order = {0, 3, 2, 1};
            else
                order = {2, 1, 0, 3};
        }
        std::array<CGPoint, 4> rearrangedVertices{vertices[order[0]], vertices[order[1]], vertices[order[2]], vertices[order[3]]};
        std::array<std::array<CGFloat, 3>, 4> rearrangedCoordinates{coordinates[order[0]], coordinates[order[1]], coordinates[order[2]], coordinates[order[3]]};
        cubicCurves.emplace_back(std::move(rearrangedVertices), std::move(rearrangedCoordinates));

        // "Inside" is on the right, so if the control points are on the right, make lines to the control points instead of directly to the destination
        if (orientation1 && orientation2) {
            if (dc1 * dd < dc2 * dd) { // dc1 is closer to currentPosition than dc2
                lineTo(control1);
                lineTo(control2);
            } else {
                lineTo(control2);
                lineTo(control1);
            }
        } else if (orientation1)
            lineTo(control1);
        else if (orientation2)
            lineTo(control2);
        lineTo(destination);
    }

    void close() {
        lineTo(subpathStart);
    }

    void mark() {
        for (CDT::All_faces_iterator i(cdt.all_faces_begin()); i != cdt.all_faces_end(); ++i){
            i->info().marked = false;
        }

        for (auto& subpath : subpaths) {
            if (subpath.size() < 3)
                continue;

            for (size_t i = 0; i < subpath.size() - 1; ++i) {
                CDT::Vertex_handle vertex1 = subpath[i];
                CDT::Vertex_handle vertex2 = subpath[i + 1];
                auto partial = vertex1;
                do {
                    auto lookup(lookupFace(partial, vertex2));
                    partial = lookup.second;
                    CDT::Face_handle seed(lookup.first);
                    if (seed == CDT::Face_handle() && partial == CDT::Vertex_handle())
                        break;
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
                } while (partial != vertex2);
            }
        }
    }

    void apply(TriangleIterator iterator, void* context) {
        for (auto i = cdt.all_faces_begin(); i != cdt.all_faces_end(); ++i) {
            if (i->vertex(0) == cdt.infinite_vertex() || i->vertex(1) == cdt.infinite_vertex() || i->vertex(2) == cdt.infinite_vertex())
                continue;
            if (i->info().marked)
                iterator(context, CGPointMake(i->vertex(0)->point().x(), i->vertex(0)->point().y()),
                                  CGPointMake(i->vertex(CDT::cw(0))->point().x(), i->vertex(CDT::cw(0))->point().y()),
                                  CGPointMake(i->vertex(CDT::ccw(0))->point().x(), i->vertex(CDT::ccw(0))->point().y()),
                                  {0, 1, 1}, {0, 1, 1}, {0, 1, 1});
        }

        for (auto& cubicCurve : cubicCurves) {
            iterator(context,
                cubicCurve.vertices[0], cubicCurve.vertices[1], cubicCurve.vertices[2],
                {cubicCurve.coordinates[0][0], cubicCurve.coordinates[0][1], cubicCurve.coordinates[0][2]},
                {cubicCurve.coordinates[1][0], cubicCurve.coordinates[1][1], cubicCurve.coordinates[1][2]},
                {cubicCurve.coordinates[2][0], cubicCurve.coordinates[2][1], cubicCurve.coordinates[2][2]});
            iterator(context,
                cubicCurve.vertices[3], cubicCurve.vertices[2], cubicCurve.vertices[1],
                {cubicCurve.coordinates[3][0], cubicCurve.coordinates[3][1], cubicCurve.coordinates[3][2]},
                {cubicCurve.coordinates[2][0], cubicCurve.coordinates[2][1], cubicCurve.coordinates[2][2]},
                {cubicCurve.coordinates[1][0], cubicCurve.coordinates[1][1], cubicCurve.coordinates[1][2]});
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

    std::pair<CDT::Face_handle, CDT::Vertex_handle> lookupFace(CDT::Vertex_handle vertex1, CDT::Vertex_handle vertex2) {
        CDT::Face_circulator initial = cdt.incident_faces(vertex1);
        CDT::Face_circulator i = initial;
        do {
            for (int j = 0; j < 3; ++j) {
                CDT::Vertex_handle candidate(i->vertex(CDT::cw(j)));
                if (i->vertex(j) == vertex1 && cdt.is_constrained(CDT::Edge(i, CDT::ccw(j))) && onWay(candidate->point() - vertex1->point(), vertex2->point() - vertex1->point()))
                    return std::make_pair(i, candidate);
            }
            ++i;
        } while (i != initial);
        return std::make_pair(CDT::Face_handle(), CDT::Vertex_handle()); // This is bad, but probably not ::that:: bad
    }

    CDT cdt;
    CDT::Vertex_handle currentPosition;
    CDT::Vertex_handle subpathStart;
    std::vector<std::vector<CDT::Vertex_handle>> subpaths;
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
    const CGPoint origin;
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
    CGPathRef newPath(createNonIntersectingPath(path));
    CGPathApply(newPath, &context, &pathIterator);
    CFRelease(newPath);
}

void triangulatorTriangulate(Triangulator* triangulator) {
    triangulator->mark();
}

void triangulatorApply(Triangulator* triangulator, TriangleIterator iterator, void* context) {
    triangulator->apply(iterator, context);
}
