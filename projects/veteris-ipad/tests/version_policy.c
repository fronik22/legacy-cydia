#include "../src/VersionPolicy.h"
#include <assert.h>
int main(void) {
 for(int i=3;i<=10;i++) { assert(VeterisLayoutSupported(i)==(i>=5&&i<=7)); assert(VeterisNeedsSGXCacheWorkaround(i)==(i==6)); }
}
