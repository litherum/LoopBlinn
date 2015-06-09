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

class LoopBlinn_Tests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func dumpPath(path: CGPathRef) -> String {
        var result = ""
        iterateCGPath(path, {element in
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
        })
        result = result.substringToIndex(result.endIndex.predecessor())
        return result
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

    func distance(point0: CGPoint, _ point1: CGPoint) -> CGFloat {
        let dx = point1.x - point0.x
        let dy = point1.y - point1.y
        return sqrt(dx * dx + dy * dy)
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

    func testSimplePath() {
        var path = CGPathCreateMutable()
        CGPathMoveToPoint(path, nil, 0, 0)
        CGPathAddLineToPoint(path, nil, 100, 0)
        CGPathAddLineToPoint(path, nil, 50, 50 * sqrt(3))
        CGPathCloseSubpath(path)
        XCTAssertEqual(dumpPath(decomposePath(path)), "m (0.0, 0.0) l (100.0, 0.0) l (50.0, 86.6025403784439) l (0.0, 0.0) z", "Decomposed path")
    }
    
}
