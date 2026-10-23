#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import <sys/utsname.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate, WKScriptMessageHandler, WKNavigationDelegate>
@property (strong) NSWindow *window;
@property (strong) WKWebView *webView;
@property (strong) NSURL *projectRoot;
@property (strong) NSTask *activeHostTask;
@property (assign) IOPMAssertionID powerAssertion;
@end

@implementation AppDelegate

- (NSURL *)findProjectRoot {
    // Start from the directory containing the binary, or bundle
    NSURL *current = [[NSBundle mainBundle] bundleURL];
    if (!current) {
        current = [NSURL fileURLWithPath:[[NSFileManager defaultManager] currentDirectoryPath]];
    }
    
    // Check up to 5 parent directories for assets/bootstrap.bas or Makefile
    for (int i = 0; i < 6; i++) {
        NSURL *checkPath = [current URLByAppendingPathComponent:@"assets/bootstrap.bas"];
        NSURL *makePath = [current URLByAppendingPathComponent:@"Makefile"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:checkPath.path] ||
            [[NSFileManager defaultManager] fileExistsAtPath:makePath.path]) {
            return current;
        }
        NSURL *parent = [current URLByDeletingLastPathComponent];
        if ([parent.path isEqualToString:current.path]) break;
        current = parent;
    }
    return [NSURL fileURLWithPath:[[NSFileManager defaultManager] currentDirectoryPath]];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.projectRoot = [self findProjectRoot];
    
    NSRect screenRect = [[NSScreen mainScreen] visibleFrame];
    CGFloat width = 940;
    CGFloat height = 660;
    CGFloat x = screenRect.origin.x + (screenRect.size.width - width) / 2.0;
    CGFloat y = screenRect.origin.y + (screenRect.size.height - height) / 2.0;
    NSRect frame = NSMakeRect(x, y, width, height);

    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled |
                                                         NSWindowStyleMaskClosable |
                                                         NSWindowStyleMaskMiniaturizable |
                                                         NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [self.window setTitle:@"mac2jb — Nintendo Switch 2 Jailbreak Assistant"];
    self.window.delegate = self;
    [self.window setMinSize:NSMakeSize(820, 580)];

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    [config.userContentController addScriptMessageHandler:self name:@"mac2jb"];

    self.webView = [[WKWebView alloc] initWithFrame:self.window.contentView.bounds configuration:config];
    self.webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.webView.navigationDelegate = self;
    
    // Load index.html from bundle resources or from gui/index.html
    NSURL *htmlURL = [[NSBundle mainBundle] URLForResource:@"index" withExtension:@"html"];
    if (!htmlURL || ![[NSFileManager defaultManager] fileExistsAtPath:htmlURL.path]) {
        htmlURL = [self.projectRoot URLByAppendingPathComponent:@"gui/index.html"];
    }

    if ([[NSFileManager defaultManager] fileExistsAtPath:htmlURL.path]) {
        [self.webView loadFileURL:htmlURL allowingReadAccessToURL:self.projectRoot];
    } else {
        NSLog(@"Error: index.html not found at %@", htmlURL.path);
    }

    [self.window.contentView addSubview:self.webView];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self logToUI:[NSString stringWithFormat:@"mac2jb ready. Project root: %@", self.projectRoot.path]];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self stopHostTask];
}

- (void)stopHostTask {
    if (self.activeHostTask && self.activeHostTask.isRunning) {
        [self.activeHostTask terminate];
        self.activeHostTask = nil;
    }
}

- (void)sendScriptToUI:(NSString *)js {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.webView evaluateJavaScript:js completionHandler:nil];
    });
}

- (void)logToUI:(NSString *)text {
    // Sanitize string for JS call
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[text] options:0 error:nil];
    NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *js = [NSString stringWithFormat:@"window.onNativeLog(%@[0]);", jsonStr];
    [self sendScriptToUI:js];
}

#pragma mark - Script Message Handler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    NSDictionary *body = message.body;
    if (![body isKindOfClass:[NSDictionary class]]) return;
    
    NSString *action = body[@"action"];
    NSDictionary *payload = body[@"payload"];

    if ([action isEqualToString:@"preflight"]) {
        [self handlePreflight];
    } else if ([action isEqualToString:@"build"]) {
        [self handleBuild];
    } else if ([action isEqualToString:@"sendBootstrap"]) {
        NSString *controller = payload[@"controller"] ?: @"auto";
        [self handleSendBootstrapWithController:controller];
    } else if ([action isEqualToString:@"startHost"]) {
        [self handleStartHost];
    } else if ([action isEqualToString:@"sendCommand"]) {
        NSString *cmd = payload[@"command"];
        NSInteger step = [payload[@"step"] integerValue];
        [self handleSendCommand:cmd stepNumber:step];
    } else if ([action isEqualToString:@"sendStartCommand"]) {
        [self handleSendStartCommand];
    }
}

#pragma mark - Process Execution

- (void)runProcessWithCommand:(NSString *)commandString
                  environment:(NSDictionary *)extraEnv
               onOutputLine:(void (^)(NSString *line))onLine
                 completion:(void (^)(int exitCode))onComplete {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSTask *task = [[NSTask alloc] init];
        [task setExecutableURL:[NSURL fileURLWithPath:@"/bin/bash"]];
        [task setArguments:@[@"-c", commandString]];
        [task setCurrentDirectoryURL:self.projectRoot];

        NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
        if (extraEnv) {
            [env addEntriesFromDictionary:extraEnv];
        }
        [task setEnvironment:env];

        NSPipe *outputPipe = [NSPipe pipe];
        [task setStandardOutput:outputPipe];
        [task setStandardError:outputPipe];

        NSFileHandle *readHandle = [outputPipe fileHandleForReading];

        NSError *error = nil;
        if (![task launchAndReturnError:&error]) {
            [self logToUI:[NSString stringWithFormat:@"Process launch error: %@", error.localizedDescription]];
            if (onComplete) onComplete(-1);
            return;
        }

        NSMutableData *lineBuffer = [NSMutableData data];
        const char newline = '\n';

        while (true) {
            NSData *chunk = [readHandle readDataOfLength:512];
            if (chunk.length == 0) break;

            [lineBuffer appendData:chunk];

            // Scan for lines
            while (true) {
                NSRange range = [lineBuffer rangeOfData:[NSData dataWithBytes:&newline length:1] options:0 range:NSMakeRange(0, lineBuffer.length)];
                if (range.location == NSNotFound) break;

                NSData *lineData = [lineBuffer subdataWithRange:NSMakeRange(0, range.location)];
                NSString *line = [[NSString alloc] initWithData:lineData encoding:NSUTF8StringEncoding];
                if (line) {
                    [self logToUI:line];
                    if (onLine) onLine(line);
                }
                [lineBuffer replaceBytesInRange:NSMakeRange(0, range.location + 1) withBytes:NULL length:0];
            }
        }

        // Flush remaining buffer
        if (lineBuffer.length > 0) {
            NSString *line = [[NSString alloc] initWithData:lineBuffer encoding:NSUTF8StringEncoding];
            if (line) {
                [self logToUI:line];
                if (onLine) onLine(line);
            }
        }

        [task waitUntilExit];
        int code = [task terminationStatus];
        if (onComplete) onComplete(code);
    });
}

#pragma mark - Actions

- (void)handlePreflight {
    [self logToUI:[NSString stringWithFormat:@"--- Running preflight checks in %@ ---", self.projectRoot.path]];

    NSString *cmd = @"bash scripts/check.sh";
    __block BOOL isArm = NO;
    __block BOOL hasXcode = NO;
    __block BOOL hasNode = NO;
    __block BOOL hasDeps = NO;
    __block BOOL hasSha = NO;

    // Check arm64
    NSString *arch = [[[NSProcessInfo processInfo] operatingSystemVersionString] lowercaseString];
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *machine = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    if ([machine isEqualToString:@"arm64"]) isArm = YES;

    [self runProcessWithCommand:cmd environment:nil onOutputLine:^(NSString *line) {
        if ([line containsString:@"Darwin"] || [line containsString:@"arm64"]) isArm = YES;
        if ([line containsString:@"Xcode"]) hasXcode = NO;
        if ([line containsString:@"Node"]) hasNode = NO;
        if ([line containsString:@"OK"] || [line containsString:@"OK:"]) hasSha = YES;
    } completion:^(int exitCode) {
        BOOL overall = (exitCode == 0);
        // Direct checks if script passes
        if (overall) {
            isArm = YES;
            hasXcode = YES;
            hasNode = YES;
            hasDeps = YES;
            hasSha = YES;
        }

        NSString *js = [NSString stringWithFormat:@"window.onPreflightResult(%@, { isArm64: %@, hasXcode: %@, hasNode: %@, hasDeps: %@, hasValidSha: %@ });",
                        overall ? @"true" : @"false",
                        isArm ? @"true" : @"false",
                        hasXcode ? @"true" : @"false",
                        hasNode ? @"true" : @"false",
                        hasDeps ? @"true" : @"false",
                        hasSha ? @"true" : @"false"];
        [self sendScriptToUI:js];
    }];
}

- (void)handleBuild {
    [self logToUI:@"--- Compiling tools (make clean && make) ---"];
    NSString *cmd = @"make clean && make";

    [self runProcessWithCommand:cmd environment:nil onOutputLine:nil completion:^(int exitCode) {
        BOOL success = (exitCode == 0);
        [self logToUI:success ? @"Build completed successfully." : @"Error: build failed."];
        NSString *js = [NSString stringWithFormat:@"window.onBuildResult(%@);", success ? @"true" : @"false"];
        [self sendScriptToUI:js];
    }];
}

- (void)handleSendBootstrapWithController:(NSString *)controller {
    [self logToUI:[NSString stringWithFormat:@"--- Sending bootstrap (controller: %@) ---", controller]];

    // Count lines in bootstrap.bas
    NSURL *bootURL = [self.projectRoot URLByAppendingPathComponent:@"assets/bootstrap.bas"];
    NSString *content = [NSString stringWithContentsOfURL:bootURL encoding:NSUTF8StringEncoding error:nil];
    NSArray *lines = [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSInteger totalLines = lines.count > 0 ? lines.count : 480;

    NSDictionary *env = @{ @"MAC2JB_CONTROLLER": controller };
    NSString *cmd = @"./mac2jb-send assets/bootstrap.bas --delay-ms 50";

    [self runProcessWithCommand:cmd environment:env onOutputLine:^(NSString *line) {
        if ([line containsString:@"Sent line "]) {
            NSScanner *scanner = [NSScanner scannerWithString:line];
            [scanner scanString:@"Sent line " intoString:NULL];
            NSInteger num = 0;
            if ([scanner scanInteger:&num]) {
                NSString *js = [NSString stringWithFormat:@"window.onSendProgress(%ld, %ld);", (long)num, (long)totalLines];
                [self sendScriptToUI:js];
            }
        }
    } completion:^(int exitCode) {
        BOOL success = (exitCode == 0);
        NSString *js = [NSString stringWithFormat:@"window.onSendResult(%@);", success ? @"true" : @"false"];
        [self sendScriptToUI:js];
    }];
}

- (void)handleStartHost {
    [self logToUI:@"--- Starting ns2jb host server (bash scripts/host.sh) ---"];
    [self stopHostTask];

    self.activeHostTask = [[NSTask alloc] init];
    [self.activeHostTask setExecutableURL:[NSURL fileURLWithPath:@"/bin/bash"]];
    [self.activeHostTask setArguments:@[@"-c", @"bash scripts/host.sh"]];
    [self.activeHostTask setCurrentDirectoryURL:self.projectRoot];

    NSPipe *pipe = [NSPipe pipe];
    [self.activeHostTask setStandardOutput:pipe];
    [self.activeHostTask setStandardError:pipe];

    NSFileHandle *readHandle = [pipe fileHandleForReading];

    NSError *error = nil;
    if (![self.activeHostTask launchAndReturnError:&error]) {
        [self logToUI:[NSString stringWithFormat:@"Error: host launch failed: %@", error.localizedDescription]];
        [self sendScriptToUI:@"window.onHostStarted(false, null);"];
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Wait slightly for token file
        NSURL *runFile = [self.projectRoot URLByAppendingPathComponent:@"vendor/ns2jb/runs/mac2jb-active-connect.txt"];
        NSString *capturedStart = nil;

        for (int i = 0; i < 15; i++) {
            [NSThread sleepForTimeInterval:0.5];
            if ([[NSFileManager defaultManager] fileExistsAtPath:runFile.path]) {
                NSString *data = [NSString stringWithContentsOfURL:runFile encoding:NSUTF8StringEncoding error:nil];
                NSArray *lines = [data componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                for (NSString *l in lines) {
                    if ([l hasPrefix:@"V=START("]) {
                        capturedStart = [l stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        break;
                    }
                }
                if (capturedStart) break;
            }
        }

        NSData *strData = capturedStart ? [NSJSONSerialization dataWithJSONObject:@[capturedStart] options:0 error:nil] : nil;
        NSString *jsonStr = strData ? [[NSString alloc] initWithData:strData encoding:NSUTF8StringEncoding] : @"[null]";
        NSString *js = [NSString stringWithFormat:@"window.onHostStarted(true, %@[0]);", jsonStr];
        [self sendScriptToUI:js];

        // Continue background read of host logs
        while (self.activeHostTask && self.activeHostTask.isRunning) {
            NSData *chunk = [readHandle readDataOfLength:256];
            if (chunk.length == 0) break;
            NSString *log = [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding];
            if (log) [self logToUI:log];
        }
    });
}

- (void)handleSendCommand:(NSString *)commandString stepNumber:(NSInteger)step {
    [self logToUI:[NSString stringWithFormat:@"--- Sending command %ld: %@ ---", (long)step, commandString]];

    NSString *tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"mac2jb_cmd.bas"];
    NSString *fileContent = [NSString stringWithFormat:@"%@\n", commandString];
    [fileContent writeToFile:tempFile atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NSString *cmd = [NSString stringWithFormat:@"./mac2jb-send \"%@\" --delay-ms 50", tempFile];
    [self runProcessWithCommand:cmd environment:nil onOutputLine:nil completion:^(int exitCode) {
        [[NSFileManager defaultManager] removeItemAtPath:tempFile error:nil];
        BOOL success = (exitCode == 0);
        NSString *js = [NSString stringWithFormat:@"window.onCommandResult(%ld, %@);", (long)step, success ? @"true" : @"false"];
        [self sendScriptToUI:js];
    }];
}

- (void)handleSendStartCommand {
    NSURL *runFile = [self.projectRoot URLByAppendingPathComponent:@"vendor/ns2jb/runs/mac2jb-active-connect.txt"];
    NSString *capturedStart = nil;

    if ([[NSFileManager defaultManager] fileExistsAtPath:runFile.path]) {
        NSString *data = [NSString stringWithContentsOfURL:runFile encoding:NSUTF8StringEncoding error:nil];
        NSArray *lines = [data componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        for (NSString *l in lines) {
            if ([l hasPrefix:@"V=START("]) {
                capturedStart = [l stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                break;
            }
        }
    }

    if (!capturedStart) {
        [self logToUI:@"Error: active V=START session file not found. Ensure the host server is running."];
        [self sendScriptToUI:@"window.onCommandResult(3, false);"];
        return;
    }

    [self handleSendCommand:capturedStart stepNumber:3];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
