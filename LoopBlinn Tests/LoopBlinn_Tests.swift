//
//  LoopBlinn_Tests.swift
//  LoopBlinn Tests
//
//  Created by Litherum on 5/30/15.
//  Copyright (c) 2015 Litherum. All rights reserved.
//

import Cocoa
import XCTest
import LoopBlinn

func dumpPath(path: CGPathRef) -> String {
    var result = ""
    iterateCGPath(path) {element in
        switch element.type.value {
        case kCGPathElementMoveToPoint.value:
            result = result + "m \(element.points[0]) "
        case kCGPathElementAddLineToPoint.value:
            result = result + "l \(element.points[0]) "
        case kCGPathElementAddQuadCurveToPoint.value:
            result = result + "q \(element.points[0]) \(element.points[1])"
        case kCGPathElementAddCurveToPoint.value:
            result = result + "c \(element.points[0]) \(element.points[1]) \(element.points[2]) "
        case kCGPathElementCloseSubpath.value:
            result = result + "z "
        default:
            XCTFail("Unknown path element type")
        }
    }
    result = result.substringToIndex(result.endIndex.predecessor())
    return result
}

func distance(point0: CGPoint, point1: CGPoint) -> CGFloat {
    let dx = point1.x - point0.x
    let dy = point1.y - point1.y
    return sqrt(dx * dx + dy * dy)
}

private func lerp(point0: CGPoint, point1: CGPoint, t: CGFloat) -> CGPoint {
    return CGPointMake(point1.x * t + point0.x * (1 - t), point1.y * t + point0.y * (1 - t))
}

private typealias Cubic = (CGPoint, CGPoint, CGPoint, CGPoint)
private func subdivide(cubic: Cubic, t: CGFloat) -> (Cubic, Cubic) {
    var p01 = lerp(cubic.0, cubic.1, t)
    var p12 = lerp(cubic.1, cubic.2, t)
    var p23 = lerp(cubic.2, cubic.3, t)
    var p012 = lerp(p01, p12, t)
    var p123 = lerp(p12, p23, t)
    var p0123 = lerp(p012, p123, t)
    return ((cubic.0, p01, p012, p0123), (p0123, p123, p23, cubic.3))
}

func isPointOnLine(endpoint1: CGPoint, endpoint2: CGPoint, point: CGPoint) -> Bool {
    let u = endpoint2 - endpoint1
    let v = point - endpoint1
    let frac = dot(u, v) / dot(u, u)
    if frac < 0 || frac > 1 {
        return false
    }
    let epsilon = CGFloat(1)
    return magnitude(v - frac * u) < epsilon
}

func parallel(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) -> Bool {
    let delta0 = p1 - p0
    let delta1 = p3 - p2
    let b = delta0.width
    let d = delta1.width
    let g = delta0.height
    let j = delta1.height
    
    let epsilon = CGFloat(0.001)
    return abs(b * j - d * g) < epsilon
}

func parallelQuad(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) -> Bool {
    let edges = [(p0, p1), (p1, p2), (p2, p3), (p3, p0)]
    for i in 0 ..< edges.count {
        for j in i + 0 ..< edges.count {
            if parallel(edges[i].0, edges[i].1, edges[j].0, edges[j].1) {
                return true
            }
        }
    }
    return false
}

class LoopBlinn_Tests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testPath() {
        var path = CGPathCreateMutable()
        CGPathMoveToPoint(path, nil, 100, 100)
        CGPathAddLineToPoint(path, nil, 200, 100)
        CGPathAddLineToPoint(path, nil, 300, 100)
        CGPathAddLineToPoint(path, nil, 200, 200)
        CGPathCloseSubpath(path)
        XCTAssertEqual(dumpPath(path), "m (100.0, 100.0) l (200.0, 100.0) l (300.0, 100.0) l (200.0, 200.0) z")
        
        path = CGPathCreateMutable()
        CGPathMoveToPoint(path, nil, 100, 200)
        CGPathAddLineToPoint(path, nil, 300, 200)
        CGPathAddLineToPoint(path, nil, 200, 300)
        CGPathAddLineToPoint(path, nil, 200, 100)
        CGPathCloseSubpath(path)
        XCTAssertEqual(dumpPath(path), "m (100.0, 200.0) l (300.0, 200.0) l (200.0, 300.0) l (200.0, 100.0) z")
    }

    func testSubdivision() {
        let trials = 10000
        let upperBound = UInt32(100)
        for i in 0 ..< trials {
            let p1 = CGPointMake(CGFloat(arc4random_uniform(upperBound)), CGFloat(arc4random_uniform(upperBound)))
            let p2 = CGPointMake(CGFloat(arc4random_uniform(upperBound)), CGFloat(arc4random_uniform(upperBound)))
            let p3 = CGPointMake(CGFloat(arc4random_uniform(upperBound)), CGFloat(arc4random_uniform(upperBound)))
            let p4 = CGPointMake(CGFloat(arc4random_uniform(upperBound)), CGFloat(arc4random_uniform(upperBound)))
            let t1 = CGFloat(arc4random_uniform(upperBound)) / CGFloat(upperBound)
            let t2 = CGFloat(arc4random_uniform(upperBound)) / CGFloat(upperBound)
            if t1 == t2 {
                continue
            }
            let minT = min(t1, t2)
            let maxT = max(t1, t2)

            let adjustedMinT = minT / maxT
            let adjustedMaxT = (maxT - minT) / (1 - minT)
            let beginning = subdivide((p1, p2, p3, p4), maxT).0
            let end = subdivide((p1, p2, p3, p4), minT).1
            let middle1 = subdivide((beginning.0, beginning.1, beginning.2, beginning.3), adjustedMinT).1
            let middle2 = subdivide((end.0, end.1, end.2, end.3), adjustedMaxT).0
            let epsilon = CGFloat(0.001)
            XCTAssertEqualWithAccuracy(distance(middle1.0, middle2.0), 0, epsilon, "Points need to be the same")
            XCTAssertEqualWithAccuracy(distance(middle1.1, middle2.1), 0, epsilon, "Points need to be the same")
            XCTAssertEqualWithAccuracy(distance(middle1.2, middle2.2), 0, epsilon, "Points need to be the same")
            XCTAssertEqualWithAccuracy(distance(middle1.3, middle2.3), 0, epsilon, "Points need to be the same")
        }
    }

    func testSimpleLineIntersections() {
        var path = CGPathCreateMutable()
        CGPathMoveToPoint(path, nil, 0, 0)
        CGPathAddLineToPoint(path, nil, 100, 0)
        CGPathAddLineToPoint(path, nil, 50, 50)
        CGPathCloseSubpath(path)
        XCTAssertEqual(dumpPath(decomposePath(path)), "m (0.0, 0.0) l (100.0, 0.0) l (50.0, 50.0) l (0.0, 0.0) z", "Decomposed path")

        path = CGPathCreateMutable()
        CGPathMoveToPoint(path, nil, 50, 0)
        CGPathAddLineToPoint(path, nil, 50, 100)
        CGPathAddLineToPoint(path, nil, 125, 50)
        CGPathAddLineToPoint(path, nil, 0, 50)
        CGPathCloseSubpath(path)
        XCTAssertEqual(dumpPath(decomposePath(path)), "m (50.0, 0.0) l (50.0, 50.0) l (50.0, 100.0) l (125.0, 50.0) l (50.0, 50.0) l (0.0, 50.0) l (50.0, 0.0) z", "Decomposed path")
    }
    
    func testNonParallelLineIntersections() {
        let trials = 10000
        let upperBound = UInt32(100)
        for _ in 0 ..< trials {
            let point1 = CGPointMake(CGFloat(arc4random_uniform(upperBound)), CGFloat(arc4random_uniform(upperBound)))
            let point2 = CGPointMake(CGFloat(arc4random_uniform(upperBound)), CGFloat(arc4random_uniform(upperBound)))
            let point3 = CGPointMake(CGFloat(arc4random_uniform(upperBound)), CGFloat(arc4random_uniform(upperBound)))
            let point4 = CGPointMake(CGFloat(arc4random_uniform(upperBound)), CGFloat(arc4random_uniform(upperBound)))
            if parallelQuad(point1, point2, point3, point4) {
                continue
            }
            var path = CGPathCreateMutable()
            CGPathMoveToPoint(path, nil, point1.x, point1.y)
            CGPathAddLineToPoint(path, nil, point2.x, point2.y)
            CGPathAddLineToPoint(path, nil, point3.x, point3.y)
            CGPathAddLineToPoint(path, nil, point4.x, point4.y)
            CGPathCloseSubpath(path)
            var hasIntersection = false
            var numComponents = 0
            convenientIterateCGPath(decomposePath(path)) {(pathElement, currentPoint, subpathStart, elementIndex) in
                switch pathElement.type.value {
                case kCGPathElementAddLineToPoint.value:
                    let intersection = pathElement.points[0]
                    if intersection != point1 && intersection != point2 && intersection != point3 && intersection != point4 {
                        hasIntersection = true
                        XCTAssert(isPointOnLine(point1, point2, intersection) || isPointOnLine(point2, point3, intersection) || isPointOnLine(point3, point4, intersection) || isPointOnLine(point4, point1, intersection), "intersection point does not lie on line")
                    }
                default:
                    break
                }
                ++numComponents
            }
            XCTAssert(hasIntersection || numComponents == 6)
            XCTAssert(!hasIntersection || numComponents == 8)
        }
    }
    
    func testCubicLineIntersections() {
        let trials = 10000
        let upperBound = UInt32(100)
        for _ in 0 ..< trials {
            let point1 = CGPointMake(CGFloat(arc4random_uniform(upperBound)), CGFloat(arc4random_uniform(upperBound)))
            let point2 = CGPointMake(CGFloat(arc4random_uniform(upperBound)), CGFloat(arc4random_uniform(upperBound)))
            let point3 = CGPointMake(CGFloat(arc4random_uniform(upperBound)), CGFloat(arc4random_uniform(upperBound)))
            let point4 = CGPointMake(CGFloat(arc4random_uniform(upperBound)), CGFloat(arc4random_uniform(upperBound)))
            var path = CGPathCreateMutable()
            CGPathMoveToPoint(path, nil, point1.x, point1.y)
            CGPathAddCurveToPoint(path, nil, point2.x, point2.y, point3.x, point3.y, point4.x, point4.y)
            CGPathCloseSubpath(path)
            var hasIntersection = false
            var numComponents = 0
            convenientIterateCGPath(decomposePath(path)) {(pathElement, currentPoint, subpathStart, elementIndex) in
                switch pathElement.type.value {
                case kCGPathElementAddLineToPoint.value:
                    let intersection = pathElement.points[0]
                    if intersection != point1 && intersection != point2 && intersection != point3 && intersection != point4 {
                        hasIntersection = true
                        XCTAssert(isPointOnLine(point1, point4, intersection), "intersection point does not lie on line")
                    }
                default:
                    break
                }
                ++numComponents
            }
            XCTAssert(hasIntersection || numComponents == 4 || numComponents == 6 || numComponents == 5)
            XCTAssert(!hasIntersection || numComponents == 6 || numComponents == 8)
        }
    }

    // FIXME: Test the same element appearing twice in the same curve. Could even be masquerading as a cubic when the original is a quadratic.
    
}
