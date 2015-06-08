//
//  PathDecomposer.swift
//  LoopBlinn
//
//  Created by Litherum on 5/30/15.
//  Copyright (c) 2015 Litherum. All rights reserved.
//

import Foundation

// FIXME: Figure out what to do if the same curve appears in the path multiple times

func destination(element: CGPathElement) -> CGPoint {
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

func selfIntersect(cubic: Cubic) -> (CGFloat, CGFloat)? {
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

func selfIntersect(currentPoint: CGPoint, element: CGPathElement) -> (CGFloat, CGFloat)? {
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

func intersectLine(line: Line, currentPoint: CGPoint, subpathStart: CGPoint, element: CGPathElement) -> [CGFloat] {
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

func intersectCubic(cubic: Cubic, currentPoint: CGPoint, subpathStart: CGPoint, element: CGPathElement) -> [CGFloat] {
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

func intersect(currentPoint1: CGPoint, subpathStart1: CGPoint, element1: CGPathElement, currentPoint2: CGPoint, subpathStart2: CGPoint, element2: CGPathElement) -> [CGFloat] {
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

func subdivideLineMany(line: Line, ts: [CGFloat]) -> [Line] {
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

func subdivideCubicMany(cubic: Cubic, ts: [CGFloat]) -> [Cubic] {
    var result: [Cubic] = []
    var currentT = CGFloat(0)
    for t in ts + [1] {
        result.append(subdivideMiddle(cubic, currentT, t))
        currentT = t
    }
    return result
}

func decomposePath(path: CGPathRef) -> CGPathRef {
    var result = CGPathCreateMutable()
    var element1Index = 0
    var currentPoint1 = CGPointMake(0, 0)
    var subpathStart1 = CGPointMake(0, 0)
    iterateCGPath(path, {element1 in
        switch element1.type.value {
        case kCGPathElementMoveToPoint.value:
            subpathStart1 = element1.points[0]
        default:
            break
        }

        var ts: [CGFloat] = []
        if let (t1, t2) = selfIntersect(currentPoint1, element1) {
            ts.append(t1)
            ts.append(t2)
        }

        var element2Index = 0
        var currentPoint2 = CGPointMake(0, 0)
        var subpathStart2 = CGPointMake(0, 0)
        iterateCGPath(path, {element2 in
            switch element2.type.value {
            case kCGPathElementMoveToPoint.value:
                subpathStart2 = element2.points[0]
            default:
                break
            }

            if element2Index > element1Index {
                for t in intersect(currentPoint1, subpathStart1, element1, currentPoint2, subpathStart2, element2) {
                    ts.append(t)
                }
            }
            currentPoint2 = destination(element2)
            ++element2Index
        })

        switch element1.type.value {
        case kCGPathElementMoveToPoint.value:
            CGPathMoveToPoint(result, nil, element1.points[0].x, element1.points[0].y)
        case kCGPathElementAddLineToPoint.value:
            for line in subdivideLineMany(Line(currentPoint1, element1.points[0]), ts) {
                CGPathAddLineToPoint(result, nil, line.1.x, line.1.y)
            }
        case kCGPathElementAddQuadCurveToPoint.value:
            for cubic in subdivideCubicMany(equivalentCubic(Quadratic(currentPoint1, element1.points[0], element1.points[1])), ts) {
                CGPathAddCurveToPoint(result, nil, cubic.1.x, cubic.1.y, cubic.2.x, cubic.2.y, cubic.3.x, cubic.3.y)
            }
        case kCGPathElementAddCurveToPoint.value:
            for cubic in subdivideCubicMany(Cubic(currentPoint1, element1.points[0], element1.points[1], element1.points[2]), ts) {
                CGPathAddCurveToPoint(result, nil, cubic.1.x, cubic.1.y, cubic.2.x, cubic.2.y, cubic.3.x, cubic.3.y)
            }
        case kCGPathElementCloseSubpath.value:
            for line in subdivideLineMany(Line(currentPoint1, subpathStart1), ts) {
                CGPathAddLineToPoint(result, nil, line.1.x, line.1.y)
            }
            CGPathCloseSubpath(result)
        default:
            assert(false, "Unknown path type")
        }

        currentPoint1 = destination(element1)
        ++element1Index
    })
    return result;
}