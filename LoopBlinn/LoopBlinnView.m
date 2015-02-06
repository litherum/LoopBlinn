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

@interface TriangulationContext : NSObject
@property NSMutableArray *vertices;
@property NSMutableArray *coordinates;
@property NSMutableArray *orientations;
@end

@implementation TriangulationContext
-(instancetype)init {
    self = [super init];
    if (self != nil) {
        _vertices = [NSMutableArray new];
        _coordinates = [NSMutableArray new];
        _orientations = [NSMutableArray new];
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
    TriangulationContext *context = [self triangulate];
    assert(context.vertices.count == context.coordinates.count);
    assert(context.vertices.count == context.orientations.count * 3);
    _pointCount = (GLsizei)context.vertices.count;
    NSMutableData *data = [NSMutableData dataWithLength:_pointCount * 5 * sizeof(GLfloat)];
    GLfloat *p = [data mutableBytes];
    for (NSUInteger i = 0; i < _pointCount; ++i) {
        CGPoint point;
        [[context.vertices objectAtIndex:i] getValue:&point];
        p[i * 5 + 0] = point.x;
        p[i * 5 + 1] = point.y;
        [[context.coordinates objectAtIndex:i] getValue:&point];
        p[i * 5 + 2] = point.x;
        p[i * 5 + 3] = point.y;
        p[i * 5 + 4] = [[context.orientations objectAtIndex:i / 3] boolValue] ? 1 : 0;
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
    GLint orientationAttributeLocation = glGetAttribLocation(_program, "orientation");
    _sizeUniformLocation = glGetUniformLocation(_program, "size");

    glGenVertexArrays(1, &_vertexArray);
    glBindVertexArray(_vertexArray);

    glGenBuffers(1, &_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo);
    glEnableVertexAttribArray(positionAttributeLocation);
    glEnableVertexAttribArray(coordinateAttributeLocation);
    glEnableVertexAttribArray(orientationAttributeLocation);
    glVertexAttribPointer(positionAttributeLocation, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(GLfloat), 0);
    glVertexAttribPointer(coordinateAttributeLocation, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(GLfloat), (void*)(2 * sizeof(GLfloat)));
    glVertexAttribPointer(orientationAttributeLocation, 1, GL_FLOAT, GL_FALSE, 5 * sizeof(GLfloat), (void*)(4 * sizeof(GLfloat)));

    glUniform2f(_sizeUniformLocation, self.bounds.size.width, self.bounds.size.height);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(self.bounds.origin.x, self.bounds.origin.y, self.bounds.size.width, self.bounds.size.height);

    GLenum glError = glGetError();
    assert(glError == GL_NO_ERROR);
}

static void triangleIterator(void* c, CGPoint p1, CGPoint p2, CGPoint p3, CGPoint c1, CGPoint c2, CGPoint c3, bool orientation) {
    TriangulationContext *context = (__bridge TriangulationContext*)c;
    [context.vertices addObject:[NSValue value:&p1 withObjCType:@encode(CGPoint)]];
    [context.vertices addObject:[NSValue value:&p2 withObjCType:@encode(CGPoint)]];
    [context.vertices addObject:[NSValue value:&p3 withObjCType:@encode(CGPoint)]];
    [context.coordinates addObject:[NSValue value:&c1 withObjCType:@encode(CGPoint)]];
    [context.coordinates addObject:[NSValue value:&c2 withObjCType:@encode(CGPoint)]];
    [context.coordinates addObject:[NSValue value:&c3 withObjCType:@encode(CGPoint)]];
    [context.orientations addObject:[NSNumber numberWithBool:orientation]];
}

- (TriangulationContext *)triangulate {
    CTFontRef font = CTFontCreateWithName((__bridge CFStringRef)@"Arial", 300, NULL);
    CFDictionaryRef attributes = CFDictionaryCreate(kCFAllocatorDefault, (const void**)&kCTFontAttributeName, (const void**)&font, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFAttributedStringRef attributedString = CFAttributedStringCreate(kCFAllocatorDefault, CFSTR("efgh"), attributes);
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
                triangulatorAppendPath(triangulator, path, CGPointMake(origin.x + position.x, origin.y + position.y));
                CFRelease(path);
            }
        }
    }
    CFRelease(frame);
    TriangulationContext *context = [TriangulationContext new];
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
