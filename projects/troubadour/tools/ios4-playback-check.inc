- (void)codexPlaybackSample {
    static NSInteger phase = 0, samples = 0;
    static double previous = -1;
    UIViewController *screen = [[YTNav controller] topViewController];
    AVPlayer *player = [screen valueForKey:@"player"];
    double time = player ? CMTimeGetSeconds([player currentTime]) : 0;
    NSInteger status = [[player currentItem] status];
    NSLog(@"[Troubadour/Test] phase=%ld sample=%ld status=%ld rate=%.1f time=%.2f",
          (long)phase, (long)++samples, (long)status, [player rate], time);
    if (samples > 36) {
        NSLog(@"[Troubadour/Test] FAIL timeout phase=%ld", (long)phase);
        return;
    }
    BOOL awaiting = [[screen valueForKey:@"awaitingSeek"] boolValue];
    if (!awaiting && [player rate] > 0 && ((phase == 0 && time < 60) ||
                              (phase == 1 && time < 114))) {
        NSLog(@"[Troubadour/Test] FAIL wrong resume position");
        return;
    }
    BOOL advancing = !awaiting && [player rate] > 0 && time > previous + 1 && previous >= 0;
    if (phase == 0 && advancing && time >= 68 && time < 110) {
        NSLog(@"[Troubadour/Test] PASS automatic resume at 66s");
        [(id)screen restartForTrackChangeAt:120];
        phase = 1; samples = 0; previous = -1;
    } else if (phase == 1 && advancing && time >= 122 && time < 165) {
        NSLog(@"[Troubadour/Test] PASS track restart at 120s");
        [[YTNav controller] popToRootViewControllerAnimated:NO];
        [YTNav openVideo:@"DrACJvV8GbI" title:@"iOS 4 playback check" playlist:nil resumeAt:0];
        phase = 2; samples = 0; previous = -1;
    } else if (phase == 2 && advancing && time >= 2 && time < 35) {
        NSLog(@"[Troubadour/Test] PASS automatic start at zero");
        [(id)screen restartForTrackChangeAt:180];
        [(id)screen playPauseTapped];
        phase = 3; samples = 0; previous = -1;
    } else if (phase == 3 && status == AVPlayerItemStatusReadyToPlay &&
               time >= 174 && time < 182 && previous >= 174 && [player rate] == 0) {
        NSLog(@"[Troubadour/Test] PASS pause while opening preserves resume");
        [(id)screen playPauseTapped];
        phase = 4; samples = 0; previous = -1;
    } else if (phase == 4 && advancing && time >= 182 && time < 225) {
        NSLog(@"[Troubadour/Test] PASS resume after pending pause");
        phase = 5; samples = 0; previous = time;
    } else if (phase == 5 && samples >= 12) {
        if (!advancing) {
            NSLog(@"[Troubadour/Test] FAIL continuous playback");
            return;
        }
        NSLog(@"[Troubadour/Test] PASS 60 seconds continuous playback; ALL PASS");
        return;
    } else {
        previous = time;
    }
    [self performSelector:@selector(codexPlaybackSample) withObject:nil afterDelay:5];
}
