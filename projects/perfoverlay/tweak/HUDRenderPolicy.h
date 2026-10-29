#ifndef PERF_HUD_RENDER_POLICY_H
#define PERF_HUD_RENDER_POLICY_H
/* A global counter includes the HUD's own frame; avoid sustaining redraws on static screens. */
static inline int PerfHUDRenderDue(double now,double last,double interval,int global,int valid,double fps,int changed) {
    if(!changed)return 0;
    if(!global||!valid||fps>1.0/interval+0.5||last<=0||now<last)return 1;
    return now-last>=5.0;
}
#endif
