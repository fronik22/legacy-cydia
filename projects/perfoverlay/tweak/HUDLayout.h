#ifndef PERF_HUD_LAYOUT_H
#define PERF_HUD_LAYOUT_H
#include <CoreGraphics/CoreGraphics.h>

// Logical interface coordinates -> the fixed portrait window; no UIKit/device sensor dependency.
static inline CGAffineTransform PerfHUDScreenTransform(CGSize screen, int quarterTurns) {
    switch (quarterTurns) {
        case -1: return CGAffineTransformMake(0, -1, 1, 0, 0, screen.height);
        case 1:  return CGAffineTransformMake(0, 1, -1, 0, screen.width, 0);
        case 2:  return CGAffineTransformMake(-1, 0, 0, -1, screen.width, screen.height);
        default: return CGAffineTransformIdentity;
    }
}
static inline CGPoint PerfHUDPanelCenter(CGSize screen,CGSize panel,int turns,int corner) {
    CGSize logical=(turns==1||turns==-1)?CGSizeMake(screen.height,screen.width):screen;
    CGFloat x=(corner==1||corner==3)?logical.width-10-panel.width/2:10+panel.width/2;
    CGFloat y=(corner==2||corner==3)?logical.height-30-panel.height/2:30+panel.height/2;
    return CGPointApplyAffineTransform(CGPointMake(x,y),PerfHUDScreenTransform(screen,turns));
}
#endif
