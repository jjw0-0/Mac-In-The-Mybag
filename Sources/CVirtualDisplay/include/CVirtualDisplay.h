#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

// Thin bridge over CGVirtualDisplay (a private CoreGraphics interface) used by the
// macOS agent to obtain a headless capture surface when no physical display is
// attached. The private interface is resolved at runtime; if it is unavailable on
// the host OS, create returns 0 instead of crashing.

// Creates a virtual display. Returns its displayID (nonzero) on success, 0 on failure.
// The display is retained until CVirtualDisplayRelease(displayID) is called.
CGDirectDisplayID CVirtualDisplayCreate(const char *_Nullable name,
                                        NSUInteger width,
                                        NSUInteger height,
                                        double refreshRate);

// Releases the virtual display with the given id. Returns YES if it existed.
BOOL CVirtualDisplayRelease(CGDirectDisplayID displayID);

// Releases every virtual display created through this bridge.
void CVirtualDisplayReleaseAll(void);
