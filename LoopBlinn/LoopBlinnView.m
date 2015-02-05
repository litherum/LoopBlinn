//
//  LoopBlinnView.m
//  LoopBlinn
//
//  Created by Litherum on 2/4/15.
//  Copyright (c) 2015 Litherum. All rights reserved.
//

#import <OpenGL/gl3.h>

#import "LoopBlinnView.h"

@interface PathElementContext : NSObject
@property NSMutableArray *points;
@property CGPoint lineOrigin;
@property CGPoint glyphPosition;
@end

@implementation PathElementContext
@end

@implementation LoopBlinnView {
    NSArray *_points;
    GLint _sizeUniformLocation;
    GLuint _program;
    GLuint _vbo;
    GLuint _vertexArray;
}

- (void)awakeFromNib {
    NSOpenGLPixelFormatAttribute attributes[] = {
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAColorSize, 32,
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFAStencilSize, 8,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
        0};
    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
    assert(pixelFormat);
    NSOpenGLContext *context = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];
    assert(context);
    [self setPixelFormat:pixelFormat];
    [self setOpenGLContext:context];
    [self setWantsBestResolutionOpenGLSurface:YES];
    _points = [NSArray new];
    _sizeUniformLocation = -1;
    _program = 0;
    _vbo = 0;
    _vertexArray = 0;
}

- (void)update {
    [super update];
    glViewport([self bounds].origin.x, [self bounds].origin.y, [self bounds].size.width, [self bounds].size.height);
    glUniform2f(_sizeUniformLocation, [self bounds].size.width, [self bounds].size.height);
    _points = [self generatePoints];
    GLfloat pointsArray[[_points count] * 2];
    unsigned int i = 0;
    for (NSValue *value in _points) {
        CGPoint point;
        [value getValue:&point];
        pointsArray[i * 2 + 0] = point.x;
        pointsArray[i * 2 + 1] = point.y;
        //NSLog(@"Point (%@, %@)", @(pointsArray[i * 2 + 0]), @(pointsArray[i * 2 + 1]));
        ++i;
    }
    glBufferData(GL_ARRAY_BUFFER, sizeof(pointsArray), pointsArray, GL_STATIC_DRAW);
    NSLog(@"Update to (%@, %@) x (%@, %@)", @([self bounds].origin.x), @([self bounds].origin.y), @([self bounds].size.width), @([self bounds].size.height));
}

- (void)prepareOpenGL {
    [super prepareOpenGL];

    [[self openGLContext] makeCurrentContext];
    GLint swapInt = 1;
    [[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];

    GLint majorVersion, minorVersion;
    glGetIntegerv(GL_MAJOR_VERSION, &majorVersion);
    glGetIntegerv(GL_MINOR_VERSION, &minorVersion);
    NSLog(@"OpenGL %@.%@", @(majorVersion), @(minorVersion));

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);

    NSBundle *bundle = [NSBundle mainBundle];
    NSString *vertexPath = [bundle pathForResource:@"Vertex" ofType:@"vs"];
    NSString *fragmentPath = [bundle pathForResource:@"Fragment" ofType:@"fs"];
    NSStringEncoding encoding;
    NSError *error = nil;
    NSString *vertexShaderSource = [NSString stringWithContentsOfFile:vertexPath usedEncoding:&encoding error:&error];
    assert(error == nil);
    NSString *fragmentShaderSource = [NSString stringWithContentsOfFile:fragmentPath usedEncoding:&encoding error:&error];
    assert(error == nil);

    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    const char *vertexShaderSourcePtr = [vertexShaderSource UTF8String];
    const char *fragmentShaderSourcePtr = [fragmentShaderSource UTF8String];
    glShaderSource(vertexShader, 1, &vertexShaderSourcePtr, NULL);
    glShaderSource(fragmentShader, 1, &fragmentShaderSourcePtr, NULL);
    glCompileShader(vertexShader);
    glCompileShader(fragmentShader);
    GLint status;
    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &status);
    assert(status == GL_TRUE);
    glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, &status);
    assert(status == GL_TRUE);

    _program = glCreateProgram();
    glAttachShader(_program, vertexShader);
    glAttachShader(_program, fragmentShader);
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);
    glBindFragDataLocation(_program, 0, "outColor");
    glLinkProgram(_program);
    glGetProgramiv(_program, GL_LINK_STATUS, &status);
    assert(status == GL_TRUE);

    glUseProgram(_program);
    GLint positionAttributeLocation = glGetAttribLocation(_program, "position");
    NSLog(@"Position attribute location: %@", @(positionAttributeLocation));
    _sizeUniformLocation = glGetUniformLocation(_program, "size");
    NSLog(@"Size uniform location: %@", @(_sizeUniformLocation));

    glGenVertexArrays(1, &_vertexArray);
    glBindVertexArray(_vertexArray);

    GLfloat pointsArray[[_points count] * 2];
    unsigned int i = 0;
    for (NSValue *value in _points) {
        CGPoint point;
        [value getValue:&point];
        pointsArray[i * 2 + 0] = point.x;
        pointsArray[i * 2 + 1] = point.y;
        NSLog(@"Point (%@, %@)", @(pointsArray[i * 2 + 0]), @(pointsArray[i * 2 + 1]));
        ++i;
    }
    glGenBuffers(1, &_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(pointsArray), pointsArray, GL_STATIC_DRAW);
    glEnableVertexAttribArray(positionAttributeLocation);
    glVertexAttribPointer(positionAttributeLocation, 2, GL_FLOAT, GL_FALSE, 0, NULL);

    glUniform2f(_sizeUniformLocation, [self bounds].size.width, [self bounds].size.height);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport([self bounds].origin.x, [self bounds].origin.y, [self bounds].size.width, [self bounds].size.height);

    GLenum glError = glGetError();
    assert(glError == GL_NO_ERROR);
}

static void pathIterator(void *info, const CGPathElement *element) {
    PathElementContext *context = (__bridge PathElementContext*)info;
    NSMutableArray *points = context.points;
    switch (element->type) {
        case kCGPathElementMoveToPoint: {
            //NSLog(@"Moving to (%@, %@)", @(element->points[0].x), @(element->points[0].y));
            CGPoint result = element->points[0];
            result.x += context.lineOrigin.x;
            result.y += context.lineOrigin.y;
            result.x += context.glyphPosition.x;
            result.y += context.glyphPosition.y;
            [points addObject:[NSValue value:&result withObjCType:@encode(CGPoint)]];
            break;
        }
        case kCGPathElementAddLineToPoint: {
            //NSLog(@"Line to (%@, %@)", @(element->points[0].x), @(element->points[0].y));
            CGPoint result = element->points[0];
            result.x += context.lineOrigin.x;
            result.y += context.lineOrigin.y;
            result.x += context.glyphPosition.x;
            result.y += context.glyphPosition.y;
            [points addObject:[NSValue value:&result withObjCType:@encode(CGPoint)]];
            break;
        }
        case kCGPathElementAddQuadCurveToPoint: {
            //NSLog(@"Quadratic curve. Control point 1: (%@, %@) Destination: (%@, %@)", @(element->points[0].x), @(element->points[0].y), @(element->points[1].x), @(element->points[1].y));
            CGPoint result = element->points[1];
            result.x += context.lineOrigin.x;
            result.y += context.lineOrigin.y;
            result.x += context.glyphPosition.x;
            result.y += context.glyphPosition.y;
            [points addObject:[NSValue value:&result withObjCType:@encode(CGPoint)]];
            break;
        }
        case kCGPathElementAddCurveToPoint: {
            //NSLog(@"Cubic curve. Control point 1: (%@, %@) Control point 2: (%@, %@) Destination: (%@, %@)", @(element->points[0].x), @(element->points[0].y), @(element->points[1].x), @(element->points[1].y), @(element->points[2].x), @(element->points[2].y));
            CGPoint result = element->points[2];
            result.x += context.lineOrigin.x;
            result.y += context.lineOrigin.y;
            result.x += context.glyphPosition.x;
            result.y += context.glyphPosition.y;
            [points addObject:[NSValue value:&result withObjCType:@encode(CGPoint)]];
            break;
        }
        case kCGPathElementCloseSubpath:
            //NSLog(@"Closing subpath");
            break;
        default:
            assert(false);
    }
}

- (NSArray *)generatePoints {
    NSLog(@"Bounds: (%@, %@) x (%@, %@)", @([self bounds].origin.x), @([self bounds].origin.y), @([self bounds].size.width), @([self bounds].size.height));
    CTFontRef font = CTFontCreateWithName((__bridge CFStringRef)@"American Typewriter", 1000, NULL);
    CFDictionaryRef attributes = CFDictionaryCreate(kCFAllocatorDefault, (const void**)&kCTFontAttributeName, (const void**)&font, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFAttributedStringRef attributedString = CFAttributedStringCreate(kCFAllocatorDefault, CFSTR("efgh"), attributes);
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(attributedString);
    CFRelease(attributedString);
    CFRelease(attributes);
    CFRelease(font);
    CGPathRef path = CGPathCreateWithRect([self bounds], NULL);
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
    CFRelease(path);
    CFRelease(framesetter);
    CFArrayRef lines = CTFrameGetLines(frame);
    CFIndex lineCount = CFArrayGetCount(lines);
    CGPoint lineOrigins[lineCount];
    CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), lineOrigins);
    NSMutableArray *result = [[NSMutableArray alloc] init];
    PathElementContext *context = [PathElementContext new];
    context.points = result;
    for (CFIndex lineIndex = 0; lineIndex < lineCount; ++lineIndex) {
        CTLineRef line = CFArrayGetValueAtIndex(lines, lineIndex);
        CGPoint origin = lineOrigins[lineIndex];
        context.lineOrigin = origin;
        NSLog(@"Line origin: (%@, %@)", @(origin.x), @(origin.y));
        CFArrayRef runs = CTLineGetGlyphRuns(line);
        CFIndex runCount = CFArrayGetCount(runs);
        for (CFIndex runIndex = 0; runIndex < runCount; ++runIndex) {
            CTRunRef run = CFArrayGetValueAtIndex(runs, runIndex);
            CFIndex glyphCount = CTRunGetGlyphCount(run);
            CGGlyph glyphs[glyphCount];
            CTRunGetGlyphs(run, CFRangeMake(0, 0), glyphs);
            CGPoint positions[glyphCount];
            CTRunGetPositions(run, CFRangeMake(0, 0), positions);
            CFDictionaryRef attributes = CTRunGetAttributes(run);
            CTFontRef usedFont = NULL;
            CFDictionaryGetValueIfPresent(attributes, kCTFontAttributeName, (const void**)&usedFont);
            assert(usedFont != NULL);
            for (CFIndex glyphIndex = 0; glyphIndex < glyphCount; ++glyphIndex) {
                CGGlyph glyph = glyphs[glyphIndex];
                CGPoint position = positions[glyphIndex];
                context.glyphPosition = position;
                CGPathRef path = CTFontCreatePathForGlyph(usedFont, glyph, NULL);
                //NSLog(@"Starting path for glyph %@ at position (%@, %@) with a line origin of (%@, %@)", @(glyph), @(position.x), @(position.y), @(origin.x), @(origin.y));
                CGPathApply(path, (__bridge void*)context, &pathIterator);
                //NSLog(@"Path ending");
                CFRelease(path);
            }
        }
    }
    CFRelease(frame);
    return result;
}

- (void)drawRect:(NSRect)dirtyRect {
    NSLog(@"Drawing");
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glDrawArrays(GL_LINE_STRIP, 0, (GLsizei)[_points count]);
    [[self openGLContext] flushBuffer];
    GLenum glError = glGetError();
    assert(glError == GL_NO_ERROR);
}

- (void)dealloc {
    glDeleteBuffers(1, &_vbo);
    glDeleteVertexArrays(1, &_vertexArray);
    glDeleteProgram(_program);
}

@end
