//
//  LoopBlinnView.m
//  LoopBlinn
//
//  Created by Litherum on 2/4/15.
//  Copyright (c) 2015 Litherum. All rights reserved.
//

#import <OpenGL/gl3.h>

#import "LoopBlinnView.h"
#import "Triangulator.h"

@interface TriangulationItem : NSObject
@property (nonatomic, readonly) CGPoint vertex1;
@property (nonatomic, readonly) CGPoint vertex2;
@property (nonatomic, readonly) CGPoint vertex3;
@property (nonatomic, readonly) vector_double3 coordinate1;
@property (nonatomic, readonly) vector_double3 coordinate2;
@property (nonatomic, readonly) vector_double3 coordinate3;
@end

@implementation TriangulationItem
-(instancetype)initWithVertex1:(CGPoint)vertex1 vertex2:(CGPoint)vertex2 vertex3:(CGPoint)vertex3 coordinate1:(vector_double3)coordinate1 coordinate2:(vector_double3)coordinate2 coordinate3:(vector_double3)coordinate3 {
    self = [super init];
    if (self != nil) {
        _vertex1 = vertex1;
        _vertex2 = vertex2;
        _vertex3 = vertex3;
        _coordinate1 = coordinate1;
        _coordinate2 = coordinate2;
        _coordinate3 = coordinate3;
    }
    return self;
}
@end

@implementation LoopBlinnView {
    GLsizei _pointCount;
    GLint _sizeUniformLocation;
    GLuint _program;
    GLuint _vbo;
    GLuint _vertexArray;
}

- (void)awakeFromNib {
    NSOpenGLPixelFormatAttribute attributes[] = {
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAAllowOfflineRenderers,
        NSOpenGLPFAColorSize, 32,
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFAStencilSize, 8,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
        0};
    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
    assert(pixelFormat);
    NSOpenGLContext *context = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];
    assert(context);
    self.pixelFormat = pixelFormat;
    self.openGLContext = context;
    self.wantsBestResolutionOpenGLSurface = YES;
    _pointCount = 0;
    _sizeUniformLocation = -1;
    _program = 0;
    _vbo = 0;
    _vertexArray = 0;
}

- (void)update {
    [super update];
    glViewport(self.bounds.origin.x, self.bounds.origin.y, self.bounds.size.width, self.bounds.size.height);
    glUniform2f(_sizeUniformLocation, self.bounds.size.width, self.bounds.size.height);

    NSArray *context = [self triangulate];
    _pointCount = (GLsizei)context.count * 3;

    NSMutableData *data = [NSMutableData dataWithLength:_pointCount * 5 * sizeof(GLfloat)];
    GLfloat *p = [data mutableBytes];
    for (NSUInteger i = 0; i < context.count; ++i) {
        TriangulationItem *item = [context objectAtIndex:i];
        p[i * 15 + 0]  = item.vertex1.x;
        p[i * 15 + 1]  = item.vertex1.y;
        p[i * 15 + 2]  = item.coordinate1.x;
        p[i * 15 + 3]  = item.coordinate1.y;
        p[i * 15 + 4]  = item.coordinate1.z;
        p[i * 15 + 5]  = item.vertex2.x;
        p[i * 15 + 6]  = item.vertex2.y;
        p[i * 15 + 7]  = item.coordinate2.x;
        p[i * 15 + 8]  = item.coordinate2.y;
        p[i * 15 + 9]  = item.coordinate2.z;
        p[i * 15 + 10] = item.vertex3.x;
        p[i * 15 + 11] = item.vertex3.y;
        p[i * 15 + 12] = item.coordinate3.x;
        p[i * 15 + 13] = item.coordinate3.y;
        p[i * 15 + 14] = item.coordinate3.z;
    }
    glBufferData(GL_ARRAY_BUFFER, data.length, data.bytes, GL_STATIC_DRAW);
}

- (void)prepareOpenGL {
    [super prepareOpenGL];

    [[self openGLContext] makeCurrentContext];
    GLint swapInt = 1;
    [[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];

    GLint majorVersion, minorVersion;
    glGetIntegerv(GL_MAJOR_VERSION, &majorVersion);
    glGetIntegerv(GL_MINOR_VERSION, &minorVersion);
    //NSLog(@"OpenGL %@.%@", @(majorVersion), @(minorVersion));

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glEnable(GL_BLEND);

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
    GLint logSize = 0;
    glGetShaderiv(vertexShader, GL_INFO_LOG_LENGTH, &logSize);
    NSMutableData *log = [NSMutableData dataWithCapacity:logSize];
    glGetShaderInfoLog(vertexShader, logSize, NULL, [log mutableBytes]);
    NSLog(@"%s", [log bytes]);
    assert(status == GL_TRUE);
    glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, &status);
    glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, &status);
    glGetShaderiv(fragmentShader, GL_INFO_LOG_LENGTH, &logSize);
    log = [NSMutableData dataWithCapacity:logSize];
    glGetShaderInfoLog(fragmentShader, logSize, NULL, [log mutableBytes]);
    NSLog(@"%s", [log bytes]);
    assert(status == GL_TRUE);

    _program = glCreateProgram();
    glAttachShader(_program, vertexShader);
    glAttachShader(_program, fragmentShader);
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);
    glBindFragDataLocation(_program, 0, "outColor");
    glLinkProgram(_program);
    glGetProgramiv(_program, GL_LINK_STATUS, &status);
    glGetProgramiv(_program, GL_INFO_LOG_LENGTH, &logSize);
    log = [NSMutableData dataWithCapacity:logSize];
    glGetProgramInfoLog(_program, logSize, NULL, [log mutableBytes]);
    NSLog(@"%s", [log bytes]);
    assert(status == GL_TRUE);

    glUseProgram(_program);
    GLint positionAttributeLocation = glGetAttribLocation(_program, "position");
    GLint coordinateAttributeLocation = glGetAttribLocation(_program, "coordinate");
    _sizeUniformLocation = glGetUniformLocation(_program, "size");

    glGenVertexArrays(1, &_vertexArray);
    glBindVertexArray(_vertexArray);

    glGenBuffers(1, &_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo);
    glEnableVertexAttribArray(positionAttributeLocation);
    glEnableVertexAttribArray(coordinateAttributeLocation);
    glVertexAttribPointer(positionAttributeLocation, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(GLfloat), 0);
    glVertexAttribPointer(coordinateAttributeLocation, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(GLfloat), (void*)(2 * sizeof(GLfloat)));

    glUniform2f(_sizeUniformLocation, self.bounds.size.width, self.bounds.size.height);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(self.bounds.origin.x, self.bounds.origin.y, self.bounds.size.width, self.bounds.size.height);

    GLenum glError = glGetError();
    assert(glError == GL_NO_ERROR);
}

static void triangleIterator(void* c, CGPoint p1, CGPoint p2, CGPoint p3, vector_double3 c1, vector_double3 c2, vector_double3 c3) {
    NSMutableArray *context = (__bridge NSMutableArray*)c;
    [context addObject:[[TriangulationItem alloc] initWithVertex1:p1 vertex2:p2 vertex3:p3 coordinate1:c1 coordinate2:c2 coordinate3:c3]];
}

- (NSArray *)triangulate {
    CTFontRef font = CTFontCreateWithName(CFSTR("Arial"), 200, NULL);
    CFDictionaryRef attributes = CFDictionaryCreate(kCFAllocatorDefault, (const void**)&kCTFontAttributeName, (const void**)&font, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFAttributedStringRef attributedString = CFAttributedStringCreate(kCFAllocatorDefault, CFSTR("abc def ghi jkl mno pqrs tuv wxyz ABC DEF GHI JKL MNO PQRS TUV WXYZ"), attributes);
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(attributedString);
    CFRelease(attributedString);
    CFRelease(attributes);
    CFRelease(font);
    CGPathRef path = CGPathCreateWithRect(self.bounds, NULL);
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
    CFRelease(path);
    CFRelease(framesetter);
    CFArrayRef lines = CTFrameGetLines(frame);
    CFIndex lineCount = CFArrayGetCount(lines);
    CGPoint lineOrigins[lineCount];
    CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), lineOrigins);
    Triangulator* triangulator = createTriangulator();
    for (CFIndex lineIndex = 0; lineIndex < lineCount; ++lineIndex) {
        CTLineRef line = CFArrayGetValueAtIndex(lines, lineIndex);
        CGPoint origin = lineOrigins[lineIndex];
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
                CGPathRef path = CTFontCreatePathForGlyph(usedFont, glyph, NULL);
                if (path == NULL)
                    continue;
                triangulatorAppendPath(triangulator, path, CGPointMake(origin.x + position.x, origin.y + position.y));
                CFRelease(path);
            }
        }
    }
    CFRelease(frame);
/*
    {
        CGMutablePathRef path = CGPathCreateMutable();
CGPathMoveToPoint(path, NULL, -0.292969, 0.000000);
CGPathAddLineToPoint(path, NULL, 54.687500, 143.164062);
CGPathAddLineToPoint(path, NULL, 75.097656, 143.164062);
CGPathAddLineToPoint(path, NULL, 133.691406, 0.000000);
CGPathAddLineToPoint(path, NULL, 112.109375, 0.000000);
CGPathAddLineToPoint(path, NULL, 95.410156, 43.359375);
CGPathAddLineToPoint(path, NULL, 35.546875, 43.359375);
CGPathAddLineToPoint(path, NULL, 19.824219, 0.000000);
CGPathCloseSubpath(path);
        triangulatorAppendPath(triangulator, path, CGPointMake(100, 100));
        CFRelease(path);
    }
*/
    NSMutableArray *context = [NSMutableArray new];
    triangulatorTriangulate(triangulator);
    triangulatorApply(triangulator, triangleIterator, (__bridge void*)context);
    destroyTriangulator(triangulator);
    return context;
}

- (void)drawRect:(NSRect)dirtyRect {
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glDrawArrays(GL_TRIANGLES, 0, _pointCount);
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
