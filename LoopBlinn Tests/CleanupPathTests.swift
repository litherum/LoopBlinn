//
//  CleanupPathTests.swift
//  LoopBlinn
//
//  Created by Litherum on 6/20/15.
//  Copyright (c) 2015 Litherum. All rights reserved.
//

import XCTest
import LoopBlinn

class CleanupPathTests: XCTestCase {
    func testPath1() {
        var path = CGPathCreateMutable()
        CGPathMoveToPoint(path, nil, 100, 100)
        CGPathAddLineToPoint(path, nil, 200, 100)
        CGPathAddLineToPoint(path, nil, 150, 200)
        CGPathAddLineToPoint(path, nil, 100, 100)
        CGPathCloseSubpath(path)
        
        var expectedPath = CGPathCreateMutable()
        CGPathMoveToPoint(expectedPath, nil, 100, 100)
        CGPathAddLineToPoint(expectedPath, nil, 200, 100)
        CGPathAddLineToPoint(expectedPath, nil, 150, 200)
        CGPathCloseSubpath(expectedPath)
        
        XCTAssert(equivalentPaths(cleanupPath(path), expectedPath), "Paths should be equal")
    }

    func testPath2() {
        var path = CGPathCreateMutable()
        CGPathMoveToPoint(path, nil, 100, 100)
        CGPathAddLineToPoint(path, nil, 200, 100)
        CGPathAddLineToPoint(path, nil, 150, 200)
        CGPathAddLineToPoint(path, nil, 100, 100)
        CGPathAddLineToPoint(path, nil, 100, 100)
        CGPathCloseSubpath(path)
        
        var expectedPath = CGPathCreateMutable()
        CGPathMoveToPoint(expectedPath, nil, 100, 100)
        CGPathAddLineToPoint(expectedPath, nil, 200, 100)
        CGPathAddLineToPoint(expectedPath, nil, 150, 200)
        CGPathCloseSubpath(expectedPath)
        
        XCTAssert(equivalentPaths(cleanupPath(path), expectedPath), "Paths should be equal")
    }
    
    func testPath3() {
        var path = CGPathCreateMutable()
        CGPathMoveToPoint(path, nil, 100, 100)
        CGPathAddLineToPoint(path, nil, 200, 100)
        CGPathAddLineToPoint(path, nil, 150, 200)
        CGPathAddLineToPoint(path, nil, 150, 200)
        CGPathCloseSubpath(path)
        
        var expectedPath = CGPathCreateMutable()
        CGPathMoveToPoint(expectedPath, nil, 100, 100)
        CGPathAddLineToPoint(expectedPath, nil, 200, 100)
        CGPathAddLineToPoint(expectedPath, nil, 150, 200)
        CGPathCloseSubpath(expectedPath)
        
        XCTAssert(equivalentPaths(cleanupPath(path), expectedPath), "Paths should be equal")
    }
    
    func testPath4() {
        var path = CGPathCreateMutable()
        CGPathMoveToPoint(path, nil, 100, 100)
        CGPathAddLineToPoint(path, nil, 700, 100)
        CGPathAddCurveToPoint(path, nil, 500, 300, 300, 300, 100, 100)
        CGPathCloseSubpath(path)
        
        var expectedPath = CGPathCreateMutable()
        CGPathMoveToPoint(expectedPath, nil, 100, 100)
        CGPathAddLineToPoint(expectedPath, nil, 700, 100)
        CGPathAddQuadCurveToPoint(expectedPath, nil, 400, 400, 100, 100)
        CGPathCloseSubpath(expectedPath)
        
        XCTAssert(equivalentPaths(cleanupPath(path), expectedPath), "Paths should be equal")
    }
    
    func testPath5() {
        var path = CGPathCreateMutable()
        CGPathMoveToPoint(path, nil, 100, 100)
        CGPathAddLineToPoint(path, nil, 200, 100)
        CGPathAddLineToPoint(path, nil, 150, 200)
        CGPathCloseSubpath(path)
        
        var expectedPath = CGPathCreateMutable()
        CGPathMoveToPoint(expectedPath, nil, 100, 100)
        CGPathAddLineToPoint(expectedPath, nil, 200, 100)
        CGPathAddLineToPoint(expectedPath, nil, 150, 200)
        CGPathCloseSubpath(expectedPath)
        
        XCTAssert(equivalentPaths(cleanupPath(path), expectedPath), "Paths should be equal")
    }
    
    func testPath6() {
        var path = CGPathCreateMutable()
        CGPathMoveToPoint(path, nil, 100, 100)
        CGPathAddQuadCurveToPoint(path, nil, 175, 100, 200, 100)
        CGPathAddLineToPoint(path, nil, 150, 200)
        CGPathCloseSubpath(path)
        
        var expectedPath = CGPathCreateMutable()
        CGPathMoveToPoint(expectedPath, nil, 100, 100)
        CGPathAddLineToPoint(expectedPath, nil, 200, 100)
        CGPathAddLineToPoint(expectedPath, nil, 150, 200)
        CGPathCloseSubpath(expectedPath)
        
        XCTAssert(equivalentPaths(cleanupPath(path), expectedPath), "Paths should be equal")
    }
    
    func testPath7() {
        var path = CGPathCreateMutable()
        CGPathMoveToPoint(path, nil, 100, 100)
        CGPathAddCurveToPoint(path, nil, 175, 100, 183, 100, 200, 100)
        CGPathAddLineToPoint(path, nil, 150, 200)
        CGPathCloseSubpath(path)
        
        var expectedPath = CGPathCreateMutable()
        CGPathMoveToPoint(expectedPath, nil, 100, 100)
        CGPathAddLineToPoint(expectedPath, nil, 200, 100)
        CGPathAddLineToPoint(expectedPath, nil, 150, 200)
        CGPathCloseSubpath(expectedPath)
        
        XCTAssert(equivalentPaths(cleanupPath(path), expectedPath), "Paths should be equal")
    }
    
    func testPath8() {
        let trials = 100000
        let upperBound = UInt32(100)
        for trial in 0 ..< trials {
            let p1 = CGPointMake(100, 100)
            let p2 = CGPointMake(200, 100)
            let controlPoint = CGPointMake(CGFloat(arc4random_uniform(upperBound)), CGFloat(arc4random_uniform(upperBound)))
            let controlPoint1 = p1 + CGFloat(2) / 3 * (controlPoint - p1)
            let controlPoint2 = p2 + CGFloat(2) / 3 * (controlPoint - p2)

            var path = CGPathCreateMutable()
            CGPathMoveToPoint(path, nil, p1.x, p1.y)
            CGPathAddCurveToPoint(path, nil, controlPoint1.x, controlPoint1.y, controlPoint2.x, controlPoint2.y, p2.x, p2.y)
            CGPathAddLineToPoint(path, nil, 150, 0)
            CGPathCloseSubpath(path)
        
            var expectedPath = CGPathCreateMutable()
            CGPathMoveToPoint(expectedPath, nil, p1.x, p1.y)
            if pointIsOnLine(controlPoint, Line(p1, p2)) {
                CGPathAddLineToPoint(expectedPath, nil, p2.x, p2.y)
            } else {
                CGPathAddQuadCurveToPoint(expectedPath, nil, controlPoint.x, controlPoint.y, p2.x, p2.y)
            }
            CGPathAddLineToPoint(expectedPath, nil, 150, 0)
            CGPathCloseSubpath(expectedPath)
        
            XCTAssert(equivalentPaths(cleanupPath(path), expectedPath), "Paths should be equal")
        }
    }
}