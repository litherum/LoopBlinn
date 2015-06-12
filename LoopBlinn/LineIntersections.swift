//
//  LineIntersections.swift
//  LoopBlinn
//
//  Created by Litherum on 6/7/15.
//  Copyright (c) 2015 Litherum. All rights reserved.
//

import Foundation

func intersectLineAndLine(line0: Line, line1: Line) -> CGFloat? {
    let delta0 = line0.1 - line0.0
    let delta1 = line1.1 - line1.0
    // a + t * b = c + s * d
    // f + t * g = h + s * j
    let a = line0.0.x
    let b = delta0.width
    let c = line1.0.x
    let d = delta1.width
    let f = line0.0.y
    let g = delta0.height
    let h = line1.0.y
    let j = delta1.height

    let epsilon = CGFloat(0.001)
    if abs(b * j - d * g) < epsilon {
        // FIXME: The lines are parallel. If the lines are colinear, return the bounds of line1 in line0
        return nil
    }
    let t = (-a * j + c * j + d * f - d * h) / (b * j - d * g)
    if t >= 0 && t < 1 {
        return t
    }
    return nil
}

func intersectLineAndQuadratic(line: Line, quad: Quadratic) -> [CGFloat] {
    return intersectLineAndCubic(line, equivalentCubic(quad))
}

func intersectLineAndCubic(line: Line, cubic: Cubic) -> [CGFloat] {
    return generalIntersectCubicAndLine(cubic, line).map({$0.1})
}