//
//  PathDecomposer.swift
//  LoopBlinn
//
//  Created by Litherum on 5/30/15.
//  Copyright (c) 2015 Litherum. All rights reserved.
//

import Foundation

// FIXME: Figure out what to do if the same curve appears in the path multiple times

private func destination(element: CGPathElement) -> CGPoint {
    switch element.type.value {
    case kCGPathElementMoveToPoint.value:
        return element.points[0]
    case kCGPathElementAddLineToPoint.value:
        return element.points[0]
    case kCGPathElementAddQuadCurveToPoint.value:
        return element.points[1]
    case kCGPathElementAddCurveToPoint.value:
        return element.points[2]
    case kCGPathElementCloseSubpath.value:
        return element.points[0]
    default:
        assertionFailure("Unknown path type")
        return element.points[0]
    }
}

private func selfIntersect(cubic: Cubic) -> (CGFloat, CGFloat)? {
    let a = 3 * (cubic.1.x - cubic.0.x)
    let b = 3 * (cubic.0.x - 2 * cubic.1.x + cubic.2.x)
    let c = 3 * cubic.1.x - cubic.0.x - 3 * cubic.2.x + cubic.3.x
    let p = 3 * (cubic.1.y - cubic.0.y)
    let q = 3 * (cubic.0.y - 2 * cubic.1.y + cubic.2.y)
    let r = 3 * cubic.1.y - cubic.0.y - 3 * cubic.2.y + cubic.3.y
    let cqbr = c * q - b * r
    let discriminant = -cqbr * cqbr * (3 * a * a * r * r - 4 * a * b * q * r - 6 * a * c * p * r + 4 * a * c * q * q + 4 * b * b * p * r - 4 * b * c * p * q + 3 * c * c * p * p)
    if discriminant <= 0 {
        return nil
    }
    let rest = -a * b * r * r + a * c * q * r + b * c * p * r + c * c * (-p) * q
    let s = 1 / (2 * cqbr * cqbr) * (-sqrt(discriminant) + rest)
    let t = 1 / (2 * cqbr * cqbr) * (sqrt(discriminant) + rest)
    if s < 0 || s >= 1 || t < 0 || t >= 1 {
        return nil
    }
    return (t, s)
}

private func selfIntersect(currentPoint: CGPoint, element: CGPathElement) -> (CGFloat, CGFloat)? {
    switch element.type.value {
    case kCGPathElementMoveToPoint.value,
    kCGPathElementAddLineToPoint.value,
    kCGPathElementAddQuadCurveToPoint.value,
    kCGPathElementCloseSubpath.value:
        return nil
    case kCGPathElementAddCurveToPoint.value:
        return selfIntersect(Cubic(currentPoint, element.points[0], element.points[1], element.points[2]))
    default:
        assertionFailure("Unknown path type")
        return nil
    }
}

private func intersectLine(line: Line, currentPoint: CGPoint, subpathStart: CGPoint, element: CGPathElement) -> [CGFloat] {
    switch element.type.value {
    case kCGPathElementMoveToPoint.value:
        return []
    case kCGPathElementAddLineToPoint.value:
        if let intersectionPoint = intersectLineAndLine(line, Line(currentPoint, element.points[0])) {
            return [intersectionPoint]
        }
        return []
    case kCGPathElementAddQuadCurveToPoint.value:
        return intersectLineAndQuadratic(line, Quadratic(currentPoint, element.points[0], element.points[1]))
    case kCGPathElementAddCurveToPoint.value:
        return intersectLineAndCubic(line, Cubic(currentPoint, element.points[0], element.points[1], element.points[2]))
    case kCGPathElementCloseSubpath.value:
        if let intersectionPoint = intersectLineAndLine(line, Line(currentPoint, subpathStart)) {
            return [intersectionPoint]
        }
        return []
    default:
        assertionFailure("Unknown path type")
        return []
    }
}

private func intersectCubic(cubic: Cubic, currentPoint: CGPoint, subpathStart: CGPoint, element: CGPathElement) -> [CGFloat] {
    switch element.type.value {
    case kCGPathElementMoveToPoint.value:
        return []
    case kCGPathElementAddLineToPoint.value:
        return intersectCubicAndLine(cubic, Line(currentPoint, element.points[0]))
    case kCGPathElementAddQuadCurveToPoint.value:
        return intersectCubicAndQuadratic(cubic, Quadratic(currentPoint, element.points[0], element.points[1]))
    case kCGPathElementAddCurveToPoint.value:
        return intersectCubicAndCubic(cubic, Cubic(currentPoint, element.points[0], element.points[1], element.points[2]))
    case kCGPathElementCloseSubpath.value:
        return intersectCubicAndLine(cubic, Line(currentPoint, subpathStart))
    default:
        assertionFailure("Unknown path type")
        return []
    }
}

private func intersect(currentPoint1: CGPoint, subpathStart1: CGPoint, element1: CGPathElement, currentPoint2: CGPoint, subpathStart2: CGPoint, element2: CGPathElement) -> [CGFloat] {
    switch element1.type.value {
    case kCGPathElementMoveToPoint.value:
        return []
    case kCGPathElementAddLineToPoint.value:
        return intersectLine(Line(currentPoint1, element1.points[0]), currentPoint2, subpathStart2, element2)
    case kCGPathElementAddQuadCurveToPoint.value:
        return intersectCubic(equivalentCubic(Quadratic(currentPoint1, element1.points[0], element1.points[1])), currentPoint2, subpathStart2, element2)
    case kCGPathElementAddCurveToPoint.value:
        return intersectCubic(Cubic(currentPoint1, element1.points[0], element1.points[1], element1.points[2]), currentPoint2, subpathStart2, element2)
    case kCGPathElementCloseSubpath.value:
        return intersectLine(Line(currentPoint1, subpathStart1), currentPoint2, subpathStart2, element2)
    default:
        assertionFailure("Unknown path type")
        return []
    }
}

private func subdivideLineMany(line: Line, ts: [CGFloat]) -> [Line] {
    var result: [Line] = []
    var currentPoint = line.0
    for t in ts + [1] {
        let intermediary = line.0 + t * (line.1 - line.0)
        let newLine = (currentPoint, intermediary)
        result.append(newLine)
        currentPoint = intermediary
    }
    return result
}

private func subdivideCubicMany(cubic: Cubic, ts: [CGFloat]) -> [Cubic] {
    var result: [Cubic] = []
    var currentT = CGFloat(0)
    for t in ts + [1] {
        result.append(subdivideMiddle(cubic, currentT, t))
        currentT = t
    }
    return result
}

private func processTs(ts: [CGFloat]) -> [CGFloat] {
    let s = sorted(ts).filter({$0 > 0 && $0 < 1})
    if s.count < 2 {
        return s
    }
    var previous = s[0]
    var result = [previous]
    for t in s[1 ..< s.count] {
        if previous != t {
            result.append(t)
        }
        previous = t
    }
    return result
}

public func convenientIterateCGPath(path: CGPathRef, c: (CGPathElement, CGPoint, CGPoint, Int) -> ()) {
    var elementIndex = 0
    var currentPoint = CGPointMake(0, 0)
    var subpathStart = CGPointMake(0, 0)
    iterateCGPath(path) {element in
        switch element.type.value {
        case kCGPathElementMoveToPoint.value:
            subpathStart = element.points[0]
        default:
            break
        }

        c(element, currentPoint, subpathStart, elementIndex)

        currentPoint = destination(element)
        ++elementIndex
    }
}

private func updatePath(path: CGMutablePathRef, ts: [CGFloat], currentPoint: CGPoint, subpathStart: CGPoint, element: CGPathElement) {
    switch element.type.value {
    case kCGPathElementMoveToPoint.value:
        CGPathMoveToPoint(path, nil, element.points[0].x, element.points[0].y)
    case kCGPathElementAddLineToPoint.value:
        for line in subdivideLineMany(Line(currentPoint, element.points[0]), ts) {
            CGPathAddLineToPoint(path, nil, line.1.x, line.1.y)
        }
    case kCGPathElementAddQuadCurveToPoint.value:
        for cubic in subdivideCubicMany(equivalentCubic(Quadratic(currentPoint, element.points[0], element.points[1])), ts) {
            CGPathAddCurveToPoint(path, nil, cubic.1.x, cubic.1.y, cubic.2.x, cubic.2.y, cubic.3.x, cubic.3.y)
        }
    case kCGPathElementAddCurveToPoint.value:
        for cubic in subdivideCubicMany(Cubic(currentPoint, element.points[0], element.points[1], element.points[2]), ts) {
            CGPathAddCurveToPoint(path, nil, cubic.1.x, cubic.1.y, cubic.2.x, cubic.2.y, cubic.3.x, cubic.3.y)
        }
    case kCGPathElementCloseSubpath.value:
        for line in subdivideLineMany(Line(currentPoint, subpathStart), ts) {
            CGPathAddLineToPoint(path, nil, line.1.x, line.1.y)
        }
        CGPathCloseSubpath(path)
    default:
        assertionFailure("Unknown path type")
    }
}

public func decomposedPath(path: CGPathRef) -> CGPathRef {
    var result = CGPathCreateMutable()
    convenientIterateCGPath(path) { (element1, currentPoint1, subpathStart1, element1Index) in
        var ts: [CGFloat] = []
        if let (t1, t2) = selfIntersect(currentPoint1, element1) {
            ts.append(t1)
            ts.append(t2)
        }

        convenientIterateCGPath(path) {(element2, currentPoint2, subpathStart2, element2Index) in
            if element2Index != element1Index {
                for t in intersect(currentPoint1, subpathStart1, element1, currentPoint2, subpathStart2, element2) {
                    ts.append(t)
                }
            }
        }

        updatePath(result, processTs(ts), currentPoint1, subpathStart1, element1)
    }
    return result;
}

public func pointsAreCoincident(point0: CGPoint, point1: CGPoint) -> Bool {
    let epsilon = CGFloat(1)
    return magnitude(point0 - point1) < epsilon
}

private func equivalentQuadraticMethod1(cubic: Cubic) -> Quadratic? {
    let cubicXTerm = bezierCoeffs(cubic.0.x, cubic.1.x, cubic.2.x, cubic.3.x).0
    let cubicYTerm = bezierCoeffs(cubic.0.y, cubic.1.y, cubic.2.y, cubic.3.y).0
    let epsilon = CGFloat(0.001)
    if abs(cubicXTerm) < epsilon && abs(cubicYTerm) < epsilon {
        let controlPoint = cubic.0 + CGFloat(3) / 2 * (cubic.1 - cubic.0)
        return Quadratic(cubic.0, controlPoint, cubic.3)
    }
    return nil
}

private func equivalentQuadratic2(cubic: Cubic) -> Quadratic? {
    let controlPoint = cubic.0 + CGFloat(3) / 2 * (cubic.1 - cubic.0)
    let otherControlPoint = cubic.3 + CGFloat(3) / 2 * (cubic.2 - cubic.3)
    let epsilon = CGFloat(0.001)
    if magnitude(controlPoint - otherControlPoint) < epsilon {
        return Quadratic(cubic.0, controlPoint, cubic.3)
    }
    return nil
}

private func equivalentQuadratic(cubic: Cubic) -> Quadratic? {
    if let method1 = equivalentQuadraticMethod1(cubic) {
        if let method2 = equivalentQuadratic2(cubic) {
            let epsilon = CGFloat(1)
            assert(magnitude(method1.1 - method2.1) < epsilon, "Equivalent quadratic methods don't agree with each other")
            return method1
        } else {
            assertionFailure("Equivalent quadratic methods don't agree with each other")
        }
    } else {
        if let method2 = equivalentQuadratic2(cubic) {
            assertionFailure("Equivalent quadratic methods don't agree with each other")
        } else {
            return nil
        }
    }
    assertionFailure("Not all cases handled in equivalentQuadratic")
    return nil
}

private func equivalentLine(cubic: Cubic) -> Line? {
    let line = Line(cubic.0, cubic.3)
    if !pointIsOnLine(cubic.1, line) || !pointIsOnLine(cubic.2, line) {
        return nil
    }
    // We actually don't care about the case where the control point is colinear but outside the bounds
    // of the endpoints, because we only care about filling the inside of the path. Disregarding this
    // overshoot has no effect on winding order.
    return line
}

private func equivalentLine(quad: Quadratic) -> Line? {
    let line = Line(quad.0, quad.2)
    if !pointIsOnLine(quad.1, line) {
        return nil
    }
    // We actually don't care about the case where the control point is colinear but outside the bounds
    // of the endpoints, because we only care about filling the inside of the path. Disregarding this
    // overshoot has no effect on winding order.
    return line
}

public func cleanupPath(path: CGPathRef) -> CGPathRef {
    var result = CGPathCreateMutable()
    var postponedLine: CGPoint?
    convenientIterateCGPath(path) {(pathElement, currentPoint, subpathStart, elementIndex) in
        if let postponedLine = postponedLine {
            switch pathElement.type.value {
            case kCGPathElementAddLineToPoint.value:
                if pointsAreCoincident(pathElement.points[0], currentPoint) {
                    return
                }
                CGPathAddLineToPoint(result, nil, postponedLine.x, postponedLine.y)
            case kCGPathElementCloseSubpath.value:
                if !pointsAreCoincident(subpathStart, postponedLine) {
                    CGPathAddLineToPoint(result, nil, postponedLine.x, postponedLine.y)
                }
            default:
                CGPathAddLineToPoint(result, nil, postponedLine.x, postponedLine.y)
            }
        }
        postponedLine = nil
        
        let handleLine = {(point: CGPoint) in
            postponedLine = point
        }
        
        let handleQuadratic = {(point0: CGPoint, point1: CGPoint) in
            CGPathAddQuadCurveToPoint(result, nil, point0.x, point0.y, point1.x, point1.y)
        }

        switch pathElement.type.value {
        case kCGPathElementMoveToPoint.value:
            CGPathMoveToPoint(result, nil, pathElement.points[0].x, pathElement.points[0].y)
        case kCGPathElementAddLineToPoint.value:
            handleLine(pathElement.points[0])
        case kCGPathElementAddQuadCurveToPoint.value:
            if let line = equivalentLine(Quadratic(currentPoint, pathElement.points[0], pathElement.points[1])) {
                handleLine(line.1)
            } else {
                handleQuadratic(pathElement.points[0], pathElement.points[1])
            }
        case kCGPathElementAddCurveToPoint.value:
            let cubic = Cubic(currentPoint, pathElement.points[0], pathElement.points[1], pathElement.points[2])
            if let line = equivalentLine(cubic) {
                handleLine(line.1)
            } else if let quad = equivalentQuadratic(cubic) {
                handleQuadratic(quad.1, quad.2)
            } else {
                CGPathAddCurveToPoint(result, nil, pathElement.points[0].x, pathElement.points[0].y, pathElement.points[1].x, pathElement.points[1].y, pathElement.points[2].x, pathElement.points[2].y)
            }
        case kCGPathElementCloseSubpath.value:
            CGPathCloseSubpath(result)
        default:
            assertionFailure("Unknown kind of path element")
        }
    }
    return result
}