//
//  LoopBlinn_Tests.swift
//  LoopBlinn Tests
//
//  Created by Litherum on 5/30/15.
//  Copyright (c) 2015 Litherum. All rights reserved.
//

import Cocoa
import XCTest

class LoopBlinn_Tests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
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
    /*
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
    */
    }
    
}
