//
//  IntersectionTypes.swift
//  LoopBlinn
//
//  Created by Litherum on 6/7/15.
//  Copyright (c) 2015 Litherum. All rights reserved.
//

import Foundation

public typealias Line = (CGPoint, CGPoint)
typealias Quadratic = (CGPoint, CGPoint, CGPoint)
typealias Cubic = (CGPoint, CGPoint, CGPoint, CGPoint)
public typealias Vector3 = (CGFloat, CGFloat, CGFloat)

public func extendPoint(v: CGPoint) -> Vector3 {
    return (v.x, v.y, 1)
}

public func + (left: CGPoint, right: CGSize) -> CGPoint {
    return CGPointMake(left.x + right.width, left.y + right.height)
}

func + (left: CGSize, right: CGSize) -> CGSize {
    return CGSizeMake(left.width + right.width, left.height + right.height)
}

public func - (left: CGPoint, right: CGPoint) -> CGSize {
    return CGSizeMake(left.x - right.x, left.y - right.y)
}

public func - (left: CGSize, right: CGSize) -> CGSize {
    return CGSizeMake(left.width - right.width, left.height - right.height)
}

public func * (left: CGFloat, right: CGSize) -> CGSize {
    return CGSizeMake(left * right.width, left * right.height)
}

public func dot(v1: CGSize, v2: CGSize) -> CGFloat {
    return v1.width * v2.width + v1.height * v2.height
}

func dot(v1: Vector3, v2: Vector3) -> CGFloat {
    return v1.0 * v2.0 + v1.1 * v2.1 + v1.2 * v2.2
}

func cross(u: Vector3, v: Vector3) -> Vector3 {
    return (u.1 * v.2 - u.2 * v.1, u.2 * v.0 - u.0 * v.2, u.0 * v.1 - u.1 * v.0)
}

public func magnitude(v: CGSize) -> CGFloat {
    return sqrt(dot(v, v))
}

func equivalentCubic(quad: Quadratic) -> Cubic {
    let controlPoint1 = quad.0 + CGFloat(2) / 3 * (quad.1 - quad.0)
    let controlPoint2 = quad.2 + CGFloat(2) / 3 * (quad.2 - quad.2)
    return (quad.0, controlPoint1, controlPoint2, quad.2)
}

///////////////////////////////////////////////////////////////////////////////

private func sgn(x: CGFloat) -> CGFloat {
    return x > 0 ? 1 : x < 0 ? -1 : 0
}

func findZeroes(a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat) -> [CGFloat] {
    // https://www.particleincell.com/2013/cubic-line-intersection/
    let A = b / a
    let B = c / a
    let C = d / a
    let Q = (3 * B - A * A) / 9
    let R = (9 * A * B - 27 * C - 2 * A * A * A) / 54;
    let D = Q * Q * Q + R * R; // polynomial discriminant
    var t: [CGFloat] = []
    if D >= 0 { // complex or duplicate roots
        let squareRoot = sqrt(D)
        let S = sgn(R + squareRoot) * pow(abs(R + squareRoot), (1.0/3));
        let T = sgn(R - squareRoot) * pow(abs(R - squareRoot), (1.0/3));
        
        t.append(-A / 3 + (S + T)); // real root
        // discard complex roots
        if abs(sqrt(3) * (S - T) / 2) == 0 { // complex part of root pair
            t.append(-A / 3 - (S + T) / 2); // real part of complex root
            t.append(-A / 3 - (S + T) / 2); // real part of complex root
        }
    } else {
        let th = acos(R / sqrt(-Q * Q * Q));
        
        let squareRoot = sqrt(-Q)
        t.append(2 * squareRoot * cos(th / 3) - A / 3)
        t.append(2 * squareRoot * cos((th + 2 * CGFloat(M_PI)) / 3) - A / 3);
        t.append(2 * squareRoot * cos((th + 4 * CGFloat(M_PI)) / 3) - A / 3);
    }
    
    t = filter(t) {candidate -> Bool in
        return candidate >= 0 && candidate <= 1
    }
    
    return t
}

func bezierCoeffs(point0: CGFloat, point1: CGFloat, point2: CGFloat, point3: CGFloat) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
    return (-point0 + 3 * point1 + -3 * point2 + point3, 3 * point0 - 6 * point1 + 3 * point2, -3 * point0 + 3 * point1, point0)
}

func generalIntersectCubicAndLine(cubic: Cubic, line: Line) -> [(CGFloat, CGFloat)] {
    let epsilon = CGFloat(0.0001)
    return generalIntersectCubicAndInfiniteLine(cubic, line).filter({$0.1 >= epsilon && $0.1 < 1 - epsilon})
}

func generalIntersectCubicAndInfiniteLine(cubic: Cubic, line: Line) -> [(CGFloat, CGFloat)] {
    let (a, b, c) = cross(extendPoint(line.0), extendPoint(line.1))
    
    let bx = bezierCoeffs(cubic.0.x, cubic.1.x, cubic.2.x, cubic.3.x)
    let by = bezierCoeffs(cubic.0.y, cubic.1.y, cubic.2.y, cubic.3.y)
    
    var result: [(CGFloat, CGFloat)] = []
    
    for t in findZeroes(a * bx.0 + b * by.0, a * bx.1 + b * by.1, a * bx.2 + b * by.2, a * bx.3 + b * by.3 + c) {
        if t < 0 || t >= 1 {
            continue
        }

        let candidate = CGPointMake(bx.0 * t * t * t + bx.1 * t * t + bx.2 * t + bx.3, by.0 * t * t * t + by.1 * t * t + by.2 * t + by.3)
        
        var s: CGFloat
        if (abs(line.1.x - line.0.x) > abs(line.1.y - line.0.y)) {
            s = (candidate.x - line.0.x) / (line.1.x - line.0.x)
        } else {
            s = (candidate.y - line.0.y) / (line.1.y - line.0.y)
        }
        
        let tuple = (t, s)
        result.append(tuple)
    }
    
    return result
}