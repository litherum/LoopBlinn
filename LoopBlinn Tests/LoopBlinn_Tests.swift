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
        iterateCGPath(path, { element in
            let e = element.memory
            switch e.type.value {
            case kCGPathElementMoveToPoint.value:
                result = result + "m \(e.points[0]) "
            case kCGPathElementAddLineToPoint.value:
                result = result + "l \(e.points[0]) "
            case kCGPathElementAddQuadCurveToPoint.value:
                result = result + "q \(e.points[0]) \(e.points[1])"
            case kCGPathElementAddCurveToPoint.value:
                result = result + "c \(e.points[0]) \(e.points[1]) \(e.points[2]) "
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
    
}
