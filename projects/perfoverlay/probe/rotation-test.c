#include "../tweak/HUDLayout.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>

static int near(CGFloat a, CGFloat b) { return fabs(a-b) < 0.001; }
int main(void) {
    const CGSize screens[] = {{320,480},{320,568},{375,667},{414,736},{768,1024},{1024,1366}};
    const int rotations[] = {0,1,2,-1};
    for (unsigned s=0; s<sizeof(screens)/sizeof(*screens); s++) {
        for (unsigned r=0; r<4; r++) {
            CGSize screen=screens[s]; int turn=rotations[r];
            CGAffineTransform t=PerfHUDScreenTransform(screen,turn);
            CGPoint center=CGPointApplyAffineTransform(CGPointMake(81,69),t);
            // Independent physical-screen corner expectations for the existing142x78 HUD.
            CGPoint expected;
            switch(turn) {
                case 1: expected=CGPointMake(screen.width-69,81); break;
                case -1: expected=CGPointMake(69,screen.height-81); break;
                case 2: expected=CGPointMake(screen.width-81,screen.height-69); break;
                default: expected=CGPointMake(81,69);
            }
            assert(near(center.x,expected.x)&&near(center.y,expected.y));
            CGRect rect=CGRectApplyAffineTransform(CGRectMake(10,30,142,78),t);
            assert(rect.origin.x>=0&&rect.origin.y>=0);
            assert(CGRectGetMaxX(rect)<=screen.width&&CGRectGetMaxY(rect)<=screen.height);
            assert(near(rect.size.width,(turn==1||turn==-1)?78:142));
            assert(near(rect.size.height,(turn==1||turn==-1)?142:78));
            CGPoint back=CGPointApplyAffineTransform(center,CGAffineTransformInvert(t));
            assert(near(back.x,81)&&near(back.y,69));
        }
    }
    const CGSize panels[]={{142,78},{185,148}};
    for(unsigned s=0;s<sizeof(screens)/sizeof(*screens);s++)
    for(unsigned r=0;r<4;r++)for(unsigned p=0;p<2;p++)for(int corner=0;corner<4;corner++) {
        CGSize screen=screens[s],panel=panels[p];int turn=rotations[r];
        CGAffineTransform t=PerfHUDScreenTransform(screen,turn);
        CGPoint center=PerfHUDPanelCenter(screen,panel,turn,corner);
        CGPoint logical=CGPointApplyAffineTransform(center,CGAffineTransformInvert(t));
        CGSize size=(turn==1||turn==-1)?CGSizeMake(screen.height,screen.width):screen;
        CGFloat edgeX=(corner==1||corner==3)?size.width-logical.x-panel.width/2:logical.x-panel.width/2;
        CGFloat edgeY=(corner==2||corner==3)?size.height-logical.y-panel.height/2:logical.y-panel.height/2;
        assert(near(edgeX,10)&&near(edgeY,30));
        CGRect rect=CGRectApplyAffineTransform(CGRectMake(logical.x-panel.width/2,logical.y-panel.height/2,panel.width,panel.height),t);
        assert(rect.origin.x>=0&&rect.origin.y>=0&&CGRectGetMaxX(rect)<=screen.width&&CGRectGetMaxY(rect)<=screen.height);
    }
    puts("PASS: HUD position, dimensions and inverse mapping in24 original cases and192 configurable corner/size cases");
}
