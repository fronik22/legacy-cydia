#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static IMP originalLayout;
static void emptyLayout(id controller, SEL selector) {}
static void layout(UIView *view, SEL selector) {
    UIResponder *next=[view nextResponder];
    BOOL ownController=[next isKindOfClass:[UIViewController class]] &&
        [NSStringFromClass([next class]) hasPrefix:@"YT"];
    if (ownController) [(UIViewController *)next viewWillLayoutSubviews];
    ((void (*)(id,SEL))originalLayout)(view,selector);
    if (ownController) [(UIViewController *)next viewDidLayoutSubviews];
}
__attribute__((constructor)) static void installLayoutCompatibility(void) {
    // UIKit added controller layout callbacks in iOS 5; every app screen uses them.
    if (![UIViewController instancesRespondToSelector:@selector(viewWillLayoutSubviews)]) {
        class_addMethod([UIViewController class],@selector(viewWillLayoutSubviews),(IMP)emptyLayout,"v@:");
        class_addMethod([UIViewController class],@selector(viewDidLayoutSubviews),(IMP)emptyLayout,"v@:");
        Method method=class_getInstanceMethod([UIView class],@selector(layoutSubviews));
        originalLayout=method_setImplementation(method,(IMP)layout);
    }
}
