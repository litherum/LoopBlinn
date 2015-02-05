//
//  CFPtr.h
//  LoopBlinn
//
//  Created by Myles C. Maxfield on 2/5/15.
//  Copyright (c) 2015 Litherum. All rights reserved.
//

#ifndef __LoopBlinn__CFPtr__
#define __LoopBlinn__CFPtr__

#include <CoreFoundation/CoreFoundation.h>
#include <iostream>

template <typename T>
class CFPtr {
public:
    CFPtr(T ptr)
        : ptr(ptr)
    {
        CFRetain(ptr);
    }

    template <typename S>
    CFPtr(const CFPtr<S>& ptr)
        : CFPtr(ptr.get())
    {
    }

    CFPtr(const CFPtr& ptr)
        : CFPtr(ptr.get())
    {
    }

    template <typename S>
    CFPtr(CFPtr<S>&& ptr_in)
        : ptr(ptr_in.get())
    {
        ptr_in.ptr = NULL;
    }

    CFPtr(CFPtr&& ptr_in)
        : ptr(ptr_in.get())
    {
        ptr_in.ptr = NULL;
    }

    CFPtr& operator=(const CFPtr& o) {
        if (ptr != NULL)
            CFRelease(ptr);
        ptr = o.ptr;
        CFRetain(ptr);
        return *this;
    }

    template <typename S>
    CFPtr& operator=(const CFPtr<S>& o) {
        if (ptr != NULL)
            CFRelease(ptr);
        ptr = o.ptr;
        CFRetain(ptr);
        return *this;
    }

    CFPtr& operator=(CFPtr&& o) {
        if (ptr != NULL)
            CFRelease(ptr);
        ptr = o.ptr;
        o.ptr = NULL;
        return *this;
    }

    template <typename S>
    CFPtr& operator=(CFPtr<S>&& o) {
        if (ptr != NULL)
            CFRelease(ptr);
        ptr = o.ptr;
        o.ptr = NULL;
        return *this;
    }

    ~CFPtr() {
        if (ptr != NULL)
            CFRelease(ptr);
    }

    T get() const {
        return ptr;
    }
private:
    T ptr;
};

#endif /* defined(__LoopBlinn__CFPtr__) */
