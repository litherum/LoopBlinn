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
        assert(false, "Unknown path type")
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
        assert(false, "Unknown path type")
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
        assert(false, "Unknown path type")
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
        assert(false, "Unknown path type")
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
        assert(false, "Unknown path type")
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

private func convenientIterateCGPath(path: CGPathRef, c: (CGPathElement, CGPoint, CGPoint, Int) -> ()) {
    var elementIndex = 0
    var currentPoint = CGPointMake(0, 0)
    var subpathStart = CGPointMake(0, 0)
    iterateCGPath(path, {element in
        switch element.type.value {
        case kCGPathElementMoveToPoint.value:
            subpathStart = element.points[0]
        default:
            break
        }

        c(element, currentPoint, subpathStart, elementIndex)

        currentPoint = destination(element)
        ++elementIndex
    })
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
        assert(false, "Unknown path type")
    }
}

public func decomposePath(path: CGPathRef) -> CGPathRef {
    var result = CGPathCreateMutable()
    convenientIterateCGPath(path, { (element1, currentPoint1, subpathStart1, element1Index) in
        var ts: [CGFloat] = []
        if let (t1, t2) = selfIntersect(currentPoint1, element1) {
            ts.append(t1)
            ts.append(t2)
        }

        convenientIterateCGPath(path, {(element2, currentPoint2, subpathStart2, element2Index) in
            if element2Index > element1Index {
                for t in intersect(currentPoint1, subpathStart1, element1, currentPoint2, subpathStart2, element2) {
                    ts.append(t)
                }
            }
        })

        updatePath(result, processTs(ts), currentPoint1, subpathStart1, element1)
    })
    return result;
}