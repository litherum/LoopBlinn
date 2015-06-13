//
//  CubicIntersections.swift
//  LoopBlinn
//
//  Created by Litherum on 6/7/15.
//  Copyright (c) 2015 Litherum. All rights reserved.
//

import Foundation

func intersectCubicAndLine(cubic: Cubic, line: Line) -> [CGFloat] {
    return generalIntersectCubicAndLine(cubic, line).map({$0.0})
}

func intersectCubicAndQuadratic(cubic: Cubic, quad: Quadratic) -> [CGFloat] {
    return intersectCubicAndCubic(cubic, equivalentCubic(quad))
}

func intersectCubicAndCubic(cubic0: Cubic, cubic1: Cubic) -> [CGFloat] {
    return intersect(IntersectingCubic(cubic: cubic0, minT: 0, maxT: 1), IntersectingCubic(cubic: cubic1, minT: 0, maxT: 1), 0).map({$0.0})
}

private func lerp(point0: CGPoint, point1: CGPoint, t: CGFloat) -> CGPoint {
    return CGPointMake(point1.x * t + point0.x * (1 - t), point1.y * t + point0.y * (1 - t))
}

private func subdivide(cubic: Cubic, t: CGFloat) -> (Cubic, Cubic) {
    var p01 = lerp(cubic.0, cubic.1, t)
    var p12 = lerp(cubic.1, cubic.2, t)
    var p23 = lerp(cubic.2, cubic.3, t)
    var p012 = lerp(p01, p12, t)
    var p123 = lerp(p12, p23, t)
    var p0123 = lerp(p012, p123, t)
    return ((cubic.0, p01, p012, p0123), (p0123, p123, p23, cubic.3))
}

func subdivideMiddle(cubic: Cubic, minT: CGFloat, maxT: CGFloat) -> Cubic {
    let adjustedMaxT = (maxT - minT) / (1 - minT)
    return subdivide(subdivide(cubic, minT).1, adjustedMaxT).0
}

private func interpolatePoint(t: CGFloat, cubic: Cubic) -> CGPoint {
    let oneMinusT = 1 - t
    let b0 = oneMinusT * oneMinusT * oneMinusT
    let b1 = 3 * t * oneMinusT * oneMinusT
    let b2 = 3 * t * t * oneMinusT
    let b3 = t * t * t
    let size0 = cubic.0 - CGPointZero
    let size1 = cubic.1 - CGPointZero
    let size2 = cubic.2 - CGPointZero
    let size3 = cubic.3 - CGPointZero
    return CGPointZero + b0 * size0 + b1 * size1 + b2 * size2 + b3 * size3
}

private func tForPointOnCurve(cubic: Cubic, point: CGPoint) -> [CGFloat] {
    var result = [CGFloat]()

    let bx = bezierCoeffs(cubic.0.x, cubic.1.x, cubic.2.x, cubic.3.x)
    let by = bezierCoeffs(cubic.0.y, cubic.1.y, cubic.2.y, cubic.3.y)
    
    for tx in findZeroes(bx.0, bx.1, bx.2, bx.3 - point.x) {
        let xcandidate = interpolatePoint(tx, cubic)
        for ty in findZeroes(by.0, by.1, by.2, by.3 - point.y) {
            let ycandidate = interpolatePoint(ty, cubic)
            let tEpsilon = CGFloat(0.001)
            let dEpsilon = CGFloat(2)
            if abs(tx - ty) < tEpsilon || magnitude(xcandidate - ycandidate) < dEpsilon {
                let average = (tx + ty) / 2
                if average < 0 || average >= 1 {
                    continue
                }
                result.append(average)
            }
        }
    }
    return result
}

private func lineApproximation(cubic0: Cubic, cubic1: Cubic) -> [(CGFloat, CGFloat)]? {
    var approximatingLine = cross(extendPoint(cubic1.0), extendPoint(cubic1.3))
    var distance1 = abs(dot(approximatingLine, extendPoint(cubic1.1)))
    var distance2 = abs(dot(approximatingLine, extendPoint(cubic1.2)))
    let epsilon = CGFloat(1)
    if distance1 < epsilon && distance2 < epsilon {
        var result: [(CGFloat, CGFloat)] = []
        for (s, t) in generalIntersectCubicAndInfiniteLine(cubic0, Line(cubic1.0, cubic1.3)) {
            let intersection = interpolatePoint(s, cubic0)
            result.extend(tForPointOnCurve(cubic1, intersection).map({(s, $0)}))
        }
        return result
    }
    return nil
}

func localToGlobalT(t: CGFloat, minT: CGFloat, maxT: CGFloat) -> CGFloat {
    return t * (maxT - minT) + minT
}

private struct IntersectingCubic {
    var cubic: Cubic
    var minT: CGFloat
    var maxT: CGFloat
}

private func trivialIntersection(cubic0: IntersectingCubic, t: CGFloat, cubic1: IntersectingCubic) -> [(CGFloat, CGFloat)] {
    let intersection = interpolatePoint(t, cubic0.cubic)
    let globalT = localToGlobalT(t, cubic0.minT, cubic0.maxT)
    return tForPointOnCurve(cubic1.cubic, intersection).map({(globalT, localToGlobalT($0, cubic1.minT, cubic1.maxT))})
}

private func intersect(cubic0: IntersectingCubic, cubic1: IntersectingCubic, depth: UInt) -> [(CGFloat, CGFloat)] {
    if depth >= 13 {
        return [(cubic0.minT, cubic1.minT)]
    }
    
    let tEpsilon = CGFloat(0.001)
    if abs(cubic0.maxT - cubic0.minT) < tEpsilon {
        return trivialIntersection(cubic0, 0.5, cubic1)
    }
    if abs(cubic1.maxT - cubic1.minT) < tEpsilon {
        return trivialIntersection(cubic1, 0.5, cubic0).map({($0.1, $0.0)})
    }

    if let result = lineApproximation(cubic0.cubic, cubic1.cubic) {
        return result.map() {(s, t) in
            (localToGlobalT(s, cubic0.minT, cubic0.maxT), localToGlobalT(t, cubic1.minT, cubic1.maxT))
        }
    }
    if let result = lineApproximation(cubic1.cubic, cubic0.cubic) {
        return result.map() {(s, t) in
            (localToGlobalT(t, cubic0.minT, cubic0.maxT), localToGlobalT(s, cubic1.minT, cubic1.maxT))
        }
    }
    
    if let (minT, maxT) = clip(cubic0.cubic, cubic1.cubic) {
        let newStart = localToGlobalT(minT, cubic0.minT, cubic0.maxT)
        let newEnd = localToGlobalT(maxT, cubic0.minT, cubic0.maxT)
        if abs(newEnd - newStart) < tEpsilon {
            return trivialIntersection(cubic0, (minT + maxT) / 2, cubic1)
        }
        let clipped = subdivideMiddle(cubic0.cubic, minT, maxT)
        if 1 - maxT + minT < 0.2 {
            if maxT - minT > cubic1.maxT - cubic1.minT {
                let subdivided = subdivide(clipped, 0.5)
                let part1 = subdivided.0
                let part2 = subdivided.1
                let midT = (newStart + newEnd) / 2
                return intersect(IntersectingCubic(cubic: part1, minT: newStart, maxT: midT), cubic1, depth + 1) + intersect(IntersectingCubic(cubic: part2, minT: midT, maxT: newEnd), cubic1, depth + 1)
            } else {
                let subdivided = subdivide(cubic1.cubic, 0.5)
                let part1 = subdivided.0
                let part2 = subdivided.1
                let midT = (cubic1.minT + cubic1.maxT) / 2
                return intersect(cubic0, IntersectingCubic(cubic: part1, minT: cubic1.minT, maxT: midT), depth + 1) + intersect(cubic0, IntersectingCubic(cubic: part2, minT: midT, maxT: cubic1.maxT), depth + 1)
            }
        } else {
            return intersect(cubic1, IntersectingCubic(cubic: clipped, minT: newStart, maxT: newEnd), depth + 1).map({($0.1, $0.0)})
        }
    }
    return []
}

private func clipOnce(e0: CGFloat, e1: CGFloat, e2: CGFloat, e3: CGFloat) -> CGFloat? {
    if e0 > 0 || e3 < 0 {
        return nil
    }
    var result: CGFloat?
    let l01 = cross((0, e0, 1), (CGFloat(1) / 3, e1, 1))
    let l02 = cross((0, e0, 1), (CGFloat(2) / 3, e2, 1))
    let l03 = cross((0, e0, 1), (             1, e3, 1))
    let v1 = cross(l01, (0, 1, 0))
    let v2 = cross(l02, (0, 1, 0))
    let v3 = cross(l03, (0, 1, 0))
    let v1c = (v1.0 / v1.2, v1.1 / v1.2)
    let v2c = (v2.0 / v2.2, v2.1 / v2.2)
    let v3c = (v3.0 / v3.2, v3.1 / v3.2)
    if v1c.0 > 0 {
        result = v1c.0
    }
    if v2c.0 > 0 && (result == nil || v2c.0 < result!) {
        result = v2c.0
    }
    if v3c.0 > 0 && (result == nil || v3c.0 < result!) {
        result = v3c.0
    }
    return result
}

private func clip(cubic0: Cubic, cubic1: Cubic) -> (CGFloat, CGFloat)? {
    // Bezier Clipping. http://cagd.cs.byu.edu/~557/text/ch7.pdf
    let (l0, l1, l2) = cross(extendPoint(cubic1.0), extendPoint(cubic1.3))
    let c1 = -l0 * cubic1.1.x - l1 * cubic1.1.y
    let c2 = -l0 * cubic1.2.x - l1 * cubic1.2.y
    let lmin = (-l0, -l1, -min(min(l2, c1), c2))
    let lmax = (l0, l1, max(max(l2, c1), c2))
    
    let e0min = dot(lmin, extendPoint(cubic0.0))
    let e1min = dot(lmin, extendPoint(cubic0.1))
    let e2min = dot(lmin, extendPoint(cubic0.2))
    let e3min = dot(lmin, extendPoint(cubic0.3))
    let e0max = dot(lmax, extendPoint(cubic0.0))
    let e1max = dot(lmax, extendPoint(cubic0.1))
    let e2max = dot(lmax, extendPoint(cubic0.2))
    let e3max = dot(lmax, extendPoint(cubic0.3))
    
    if ((e0min < 0 && e1min < 0 && e2min < 0 && e3min < 0) || (e0max < 1 && e1max < 1 && e2max < 1 && e3max < 1)) {
        return nil
    }
    
    var minT: CGFloat? = nil
    if let clipped = clipOnce(e0min, e1min, e2min, e3min) {
        minT = clipped
    }
    if let clipped = clipOnce(e0max, e1max, e2max, e3max) {
        if let t = minT {
            minT = min(t, clipped)
        } else {
            minT = clipped
        }
    }
    
    var clipMinT: CGFloat
    if let minT = minT {
        clipMinT = minT
    } else {
        clipMinT = 0
    }
    
    var maxT: CGFloat? = nil
    if let initialClipped = clipOnce(e3min, e2min, e1min, e0min) {
        maxT = 1 - initialClipped
    }
    if let initialClipped = clipOnce(e3max, e2max, e1max, e0max) {
        let clipped = 1 - initialClipped
        if let t = maxT {
            maxT = max(t, clipped)
        } else {
            maxT = clipped
        }
    }
    
    var clipMaxT: CGFloat
    if let maxT = maxT {
        clipMaxT = maxT
    } else {
        clipMaxT = 1
    }
    
    return (clipMinT, clipMaxT)
}
