#ifndef VETERIS_VERSION_POLICY_H
#define VETERIS_VERSION_POLICY_H
static int VeterisLayoutSupported(int major) { return major >= 5 && major <= 7; }
static int VeterisNeedsSGXCacheWorkaround(int major) { return major == 6; }
#endif
