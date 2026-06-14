//
//  SettingsViewController.m
//  Cyanide
//

#import "SettingsViewController.h"
#import "kexploit/kexploit_opa334.h"
#import "tweaks/sbcustomizer.h"
#import "tweaks/powercuff.h"
#import "tweaks/statbar.h"
#import "tweaks/private_compat.h"
#import "tweaks/nsbar.h"
#import "tweaks/nicebarlite.h"
#import "tweaks/axonlite.h"
#import "tweaks/darksword_tweaks.h"
#import "tweaks/darksword_drag.h"
#import "tweaks/darksword_ota.h"
#import "tweaks/darksword_layout.h"
#import "tweaks/nano_registry.h"
#import "tweaks/killallapps.h"
#import "tweaks/themer.h"
#import "tweaks/snowboardlite.h"
#import "tweaks/livewp.h"
#import "tweaks/gravitylite.h"
#import "tweaks/appswitchergrid.h"
#import "tweaks/hide_home_bar.h"
#import <CoreMotion/CoreMotion.h>

#import <objc/runtime.h>
#import <sys/time.h>
#import "DSKeepAlive.h"
#import "TaskRop/RemoteCall.h"
#import "kexploit/kutils.h"
#import "kexploit/persistence.h"
#import "installer/InstallProgressViewController.h"
#import "installer/Package.h"
#import "installer/PackageCatalog.h"
#import "installer/PackageQueue.h"
#import "docs/DocsViewController.h"
#import "PatreonAuth.h"
#import "UpdateChecker.h"
#import "SBLArchiveExtractor.h"
#import "NiceBarSettingsSupport.h"
#import <WebKit/WebKit.h>
#import <MessageUI/MessageUI.h>
#import <PhotosUI/PhotosUI.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <notify.h>
#import <float.h>
#import <math.h>
#import <sys/sysctl.h>
#import <sys/utsname.h>
#import <time.h>
#import <unistd.h>

@interface DSRespringOverlayView : UIView
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, assign) BOOL didLoadPayload;
@end

@implementation DSRespringOverlayView

- (NSString *)respringHTML {
    // Verbatim port of Lara's respring.swift payload (by rooootdev,
    // skidded from jailbreak.party; web approach by @neonmodder123).
    return @"<!DOCTYPE html>\n"
           @"<html>\n"
           @"    <body>\n"
           @"        <!--  big credit to @neonmodder123  -->\n"
           @"        <iframe id=\"frame\" srcdoc=\"\" sandbox=\"allow-forms allow-modals allow-orientation-lock allow-pointer-lock allow-popups allow-presentation allow-scripts\"></iframe>\n"
           @"        <script>\n"
           @"            const frame = document.getElementById('frame');\n"
           @"            const script = `\n"
           @"                <html>\n"
           @"                <body>\n"
           @"                    <script>\n"
           @"                        const container = document.createElement('div');\n"
           @"                        container.style.cssText = 'perspective: 1px; perspective-origin: 9999999% 9999999%;';\n"
           @"                        document.body.appendChild(container);\n"
           @"    \n"
           @"                        for (let i = 0; i < 500; i++) {\n"
           @"                            let d = document.createElement('div');\n"
           @"                            d.style.cssText = 'position: absolute; width: 100vw; height: 100vh; backdrop-filter: blur(100px); -webkit-backdrop-filter: blur(100px); transform: translate3d(100000px, 100000px, ' + i + 'px) rotateY(90deg);';\n"
           @"                            container.appendChild(d);\n"
           @"                        }\n"
           @"    \n"
           @"                        setInterval(() => {\n"
           @"                            navigator.share({ title: 'R', text: 'R'.repeat(100000) }).catch(() => {});\n"
           @"                            let x = new Uint8Array(1024 * 1024 * 10);\n"
           @"                            crypto.getRandomValues(x);\n"
           @"                        }, 0);\n"
           @"                    <\\/script>\n"
           @"                </body>\n"
           @"                </html>\n"
           @"            `;\n"
           @"    \n"
           @"            frame.srcdoc = script;\n"
           @"        </script>\n"
           @"    </body>\n"
           @"</html>";
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.backgroundColor = [UIColor blackColor];
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    return self;
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window) [self loadRespringPayload];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.webView.frame = self.bounds;
}

- (void)loadRespringPayload {
    if (self.didLoadPayload) return;
    self.didLoadPayload = YES;
    printf("[RESPRING] loading Lara-style in-app WebKit overlay\n");

    // Mirrors Lara's respringview verbatim: default-init WKWebView, the
    // throwaway WKWebpagePreferences assignment (a no-op in Lara's Swift
    // source — kept for fidelity), then loadHTMLString.
    WKWebView *webView = [[WKWebView alloc] initWithFrame:self.bounds];
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [WKWebpagePreferences new].allowsContentJavaScript = YES;
    [self addSubview:webView];
    self.webView = webView;
    [webView loadHTMLString:[self respringHTML] baseURL:nil];
}

@end

NSString * const kSettingsAutoRunKexploit    = @"AutoRunKexploit";
NSString * const kSettingsRunSandboxEscape   = @"RunSandboxEscape";
NSString * const kSettingsRunPatchSandboxExt = @"RunPatchSandboxExt";
NSString * const kSettingsKeepAlive          = @"KeepAlive";

NSString * const kSettingsSBCEnabled    = @"SBCEnabled";
NSString * const kSettingsSBCDockIcons  = @"SBCDockIcons";
NSString * const kSettingsSBCCols       = @"SBCCols";
NSString * const kSettingsSBCRows       = @"SBCRows";
NSString * const kSettingsSBCHideLabels = @"SBCHideLabels";

NSString * const kSettingsPowercuffEnabled = @"PowercuffEnabled";
NSString * const kSettingsPowercuffLevel   = @"PowercuffLevel";
static NSString * const kSettingsPowercuffNominalNoticeShown = @"cyanide.powercuff.nominalDefaultNoticeShown.v1";

NSString * const kSettingsDSDisableAppLibrary = @"DSDisableAppLibrary";
NSString * const kSettingsDSDisableIconFlyIn  = @"DSDisableIconFlyIn";
NSString * const kSettingsDSZeroWakeAnimation = @"DSZeroWakeAnimation";
NSString * const kSettingsDSZeroBacklightFade = @"DSZeroBacklightFade";
NSString * const kSettingsDSDoubleTapToLock   = @"DSDoubleTapToLock";

NSString * const kSettingsDSDragCoefficientEnabled = @"DSDragCoefficientEnabled";
NSString * const kSettingsDSDragCoefficientValue   = @"DSDragCoefficientValue";

NSString * const kSettingsLayoutExtrasEnabled  = @"LayoutExtrasEnabled";
NSString * const kSettingsLayoutHomeExtraLeft   = @"LayoutHomeExtraLeft";
NSString * const kSettingsLayoutHomeExtraRight  = @"LayoutHomeExtraRight";
NSString * const kSettingsLayoutHomeExtraTop    = @"LayoutHomeExtraTop";
NSString * const kSettingsLayoutHomeExtraBottom = @"LayoutHomeExtraBottom";
NSString * const kSettingsLayoutDockExtraHorizontal = @"LayoutDockExtraHorizontal";
NSString * const kSettingsLayoutHomeScalePct    = @"LayoutHomeScalePct";
NSString * const kSettingsLayoutDockScalePct    = @"LayoutDockScalePct";

static double settings_number_row_normalized_value(NSDictionary *row, double value)
{
    double minV = row[@"min"] ? [row[@"min"] doubleValue] : -DBL_MAX;
    double maxV = row[@"max"] ? [row[@"max"] doubleValue] : DBL_MAX;
    if (value < minV) value = minV;
    if (value > maxV) value = maxV;

    double step = row[@"step"] ? [row[@"step"] doubleValue] : 0.0;
    if (step > 0.0) {
        value = round(value / step) * step;
        if (value < minV) value = minV;
        if (value > maxV) value = maxV;
    }

    NSInteger precision = row[@"precision"] ? [row[@"precision"] integerValue] : 0;
    if (precision <= 0) value = (double)llround(value);
    return value;
}

static double settings_drag_coefficient_value(NSUserDefaults *d)
{
    id raw = [d objectForKey:kSettingsDSDragCoefficientValue];
    double value = [raw respondsToSelector:@selector(doubleValue)] ? [raw doubleValue] : 0.5;
    if (value <= 0.0) value = 0.5;

    // Older Cyanide builds stored this row as an integer percent (50 = 0.50).
    // New builds store the actual coefficient so typed values can reach 0.01.
    if (value > 2.0) value /= 100.0;

    NSDictionary *bounds = @{ @"min": @0.01, @"max": @2.0, @"step": @0.01, @"precision": @2 };
    return settings_number_row_normalized_value(bounds, value);
}

static double settings_number_row_current_value(NSDictionary *row, NSUserDefaults *d)
{
    NSString *key = row[@"key"];
    if ([key isEqualToString:kSettingsDSDragCoefficientValue]) {
        return settings_drag_coefficient_value(d);
    }

    id raw = key.length > 0 ? [d objectForKey:key] : nil;
    double value = [raw respondsToSelector:@selector(doubleValue)]
        ? [raw doubleValue]
        : [row[@"default"] doubleValue];
    return settings_number_row_normalized_value(row, value);
}

static NSString *settings_number_row_value_string(NSDictionary *row, double value, BOOL includeUnit)
{
    NSInteger precision = row[@"precision"] ? [row[@"precision"] integerValue] : 0;
    NSString *unit = includeUnit ? (row[@"unit"] ?: @"") : @"";
    if (precision <= 0) {
        return [NSString stringWithFormat:@"%ld%@", (long)llround(value), unit];
    }
    return [NSString stringWithFormat:@"%.*f%@", (int)precision, value, unit];
}

NSString * const kSettingsStatBarEnabled = @"StatBarEnabled";
NSString * const kSettingsStatBarCelsius = @"StatBarCelsius";
NSString * const kSettingsStatBarShowNet = @"StatBarShowNet";
NSString * const kSettingsStatBarShowCPU = @"StatBarShowCPU";
NSString * const kSettingsStatBarShowLabels = @"StatBarShowLabels";
NSString * const kSettingsStatBarNetworkOnly = @"StatBarNetworkOnly";
NSString * const kSettingsStatBarRefreshRateSec = @"StatBarRefreshRateSec";

NSString * const kSettingsNSBarEnabled = @"NSBarEnabled";
NSString * const kSettingsNSBarPosition = @"NSBarPosition";

NSString * const kSettingsNiceBarLiteEnabled = @"NiceBarLiteEnabled";
static NSString * const kSettingsNiceBarLiteCelsius = @"NiceBarLiteCelsius";
static NSString * const kSettingsNiceBarLiteSlotKindPrefix = @"NiceBarLiteSlotKind";
static NSString * const kSettingsNiceBarLiteSlotSystemPrefix = @"NiceBarLiteSlotSystem";
static NSString * const kSettingsNiceBarLiteSlotTextPrefix = @"NiceBarLiteSlotText";
static NSString * const kSettingsNiceBarLiteSlotTimePrefix = @"NiceBarLiteSlotTime";
static NSString * const kSettingsNiceBarLiteSlotWeatherPrefix = @"NiceBarLiteSlotWeather";
static NSString * const kSettingsNiceBarLiteSlotWeatherLanguagePrefix = @"NiceBarLiteSlotWeatherLanguage";
static NSString * const kSettingsNiceBarLiteSlotSystemLanguagePrefix = @"NiceBarLiteSlotSystemLanguage";
static NSString * const kSettingsNiceBarLiteWeatherTemp = @"NiceBarLiteWeatherTemp";
static NSString * const kSettingsNiceBarLiteWeatherCode = @"NiceBarLiteWeatherCode";
static NSString * const kSettingsNiceBarLiteWeatherCache = @"NiceBarLiteWeatherCache";
static NSString * const kSettingsNiceBarLiteWeatherLastAttemptAt = @"NiceBarLiteWeatherLastAttemptAt";
static NSString * const kSettingsNiceBarLiteWeatherUpdatedAt = @"NiceBarLiteWeatherUpdatedAt";
static NSString * const kSettingsNiceBarLiteLayoutTopSideInset = @"NiceBarLiteLayoutTopSideInset";
static NSString * const kSettingsNiceBarLiteLayoutBottomSideInset = @"NiceBarLiteLayoutBottomSideInset";
static NSString * const kSettingsNiceBarLiteLayoutTopY = @"NiceBarLiteLayoutTopY";
static NSString * const kSettingsNiceBarLiteLayoutBottomY = @"NiceBarLiteLayoutBottomY";
static NSString * const kSettingsNiceBarLiteLayoutCenterX = @"NiceBarLiteLayoutCenterX";

NSString * const kSettingsRSSIDisplayEnabled = @"RSSIDisplayEnabled";
NSString * const kSettingsRSSIDisplayWifi    = @"RSSIDisplayWifi";
NSString * const kSettingsRSSIDisplayCell    = @"RSSIDisplayCell";

NSString * const kSettingsAxonLiteEnabled = @"AxonLiteEnabled";

NSString * const kSettingsTypeBannerEnabled = @"TypeBannerEnabled";
NSString * const kSettingsNotificationIslandEnabled = @"NotificationIslandEnabled";
NSString * const kSettingsAppSwitcherGridEnabled = @"AppSwitcherGridEnabled";
static NSString * const kSettingsFastLockXLiteEnabled = @"FastLockXLiteEnabled";
static NSString * const kSettingsFastLockXLiteBlockMusic = @"FastLockXLiteBlockMusic";
static NSString * const kSettingsFastLockXLiteBlockFlashlight = @"FastLockXLiteBlockFlashlight";
static NSString * const kSettingsFastLockXLiteBlockLowPower = @"FastLockXLiteBlockLowPower";
static NSString * const kSettingsFastLockXLiteRetryInterval = @"FastLockXLiteRetryInterval";
static NSString * const kSettingsHideHomeBarMaterialKitBootTime = @"HideHomeBarMaterialKitBootTime";

NSString * const kSettingsGravityLiteEnabled = @"GravityLiteEnabled";
NSString * const kSettingsGravityLiteDockEnabled = @"GravityLiteDockEnabled";
NSString * const kSettingsGravityLiteMagnitudePct = @"GravityLiteMagnitudePct";
NSString * const kSettingsGravityLiteBouncePct = @"GravityLiteBouncePct";
NSString * const kSettingsGravityLiteFrictionPct = @"GravityLiteFrictionPct";
NSString * const kSettingsGravityLiteResistancePct = @"GravityLiteResistancePct";
NSString * const kSettingsGravityLiteAngularResistancePct = @"GravityLiteAngularResistancePct";

NSString * const kSettingsStageStripEnabled = @"StageStripEnabled";

NSString * const kSettingsLocationSimEnabled = @"LocationSimEnabled";
NSString * const kSettingsLocationSimLatitude = @"LocationSimLatitude";
NSString * const kSettingsLocationSimLongitude = @"LocationSimLongitude";
NSString * const kSettingsLocationSimAltitude = @"LocationSimAltitude";
NSString * const kSettingsLocationSimHorizontalAccuracy = @"LocationSimHorizontalAccuracy";
NSString * const kSettingsLocationSimHostProcess = @"LocationSimHostProcess";
static NSString * const kSettingsLocationSimStarted = @"LocationSimStarted";

static NSString * const kSettingsIPADecryptorTargetBundleID = @"IPADecryptorTargetBundleID";
static NSString * const kSettingsIPADecryptorAppStoreInput = @"IPADecryptorAppStoreInput";
static NSString * const kSettingsIPADecryptorAppStoreID = @"IPADecryptorAppStoreID";
static NSString * const kSettingsIPADecryptorAppStoreName = @"IPADecryptorAppStoreName";
static NSString * const kSettingsIPADecryptorAppStoreVersion = @"IPADecryptorAppStoreVersion";
static NSString * const kSettingsIPADecryptorAppStoreURL = @"IPADecryptorAppStoreURL";
static NSString * const kSettingsIPADecryptorDownloadedIPAPath = @"IPADecryptorDownloadedIPAPath";
static NSString * const kSettingsIPADecryptorDownloadStatus = @"IPADecryptorDownloadStatus";

NSString * const kSettingsThemerEnabled = @"ThemerEnabled";
NSString * const kSettingsThemerThemeID = @"ThemerThemeID";
NSString * const kSettingsThemerCustomThemePath = @"ThemerCustomThemePath";
NSString * const kSettingsThemerCustomThemeName = @"ThemerCustomThemeName";

NSString * const kSettingsSnowBoardLiteEnabled = @"SnowBoardLiteEnabled";
NSString * const kSettingsSnowBoardLiteSelectedThemeID = @"SnowBoardLiteSelectedThemeID";

NSString * const kSettingsLiveWPEnabled = @"LiveWPEnabled";
NSString * const kSettingsLiveWPVideoPath = @"LiveWPVideoPath";

// Master gate for experimental tweaks. When NO (default), packages that opt
// into the experimental category are hidden from the Installer and the
// Settings bundle list, and any currently-enabled experimental tweak is
// force-disabled when this is flipped off.
NSString * const kSettingsExperimentalTweaksEnabled = @"ExperimentalTweaksEnabled";

static NSString * const kCyanideLastKnownIsPatron = @"CyanideLastKnownIsPatron";

// NanoRegistry pairing-compatibility editor. Numbers are the watchOS pairing
// compatibility versions that NRPairingCompatibilityVersionInfo reads from
// /var/mobile/Library/Preferences/com.apple.NanoRegistry.plist via
// CFPreferencesCopyValue("com.apple.NanoRegistry").
NSString * const kSettingsNanoMaxPairing       = @"NanoRegistryMaxPairing";
NSString * const kSettingsNanoMinPairing       = @"NanoRegistryMinPairing";
NSString * const kSettingsNanoMinPairingChipID = @"NanoRegistryMinPairingChipID";
NSString * const kSettingsNanoMinQuickSwitch   = @"NanoRegistryMinQuickSwitch";

NSString * const kSettingsLogUploadEnabled = @"LogUploadEnabled";

static void cyanide_upload_log_if_enabled(void);
static void cyanide_upload_log_milestone(NSString *event);
static void cyanide_start_session_uploads(void);
static void cyanide_stop_session_uploads(void);
static NSObject *settings_rc_lock(void);
static BOOL settings_cleanup_in_progress(void);
static BOOL settings_screen_awake_cached(void);
static BOOL settings_screen_locked_cached(void);
static void settings_restart_gravity_motion_if_active(const char *reason);

extern int  escape_sbx_demo2(void);
extern int  escape_sbx_demo2_in_session(void);
extern int  escape_sbx_demo3(void);

static BOOL g_kexploit_done = NO;
static volatile int g_settings_actions_running = 0;
static volatile int g_settings_respring_cleanup_running = 0;
static volatile int g_settings_actions_rerun_requested = 0;
static volatile int g_springboard_rc_ready = 0;
static volatile int g_springboard_sandbox_escaped = 0;
static volatile int g_statbar_live_running = 0;
static volatile int g_statbar_live_stop_requested = 0;
static volatile int g_nsbar_live_running = 0;
static volatile int g_nsbar_live_stop_requested = 0;
static volatile int g_nicebarlite_live_running = 0;
static volatile int g_nicebarlite_live_stop_requested = 0;
static volatile int g_rssi_live_running = 0;
static volatile int g_rssi_live_stop_requested = 0;
static volatile int g_axonlite_live_running = 0;
static volatile int g_axonlite_live_stop_requested = 0;
static volatile int g_typebanner_live_running = 0;
static volatile int g_typebanner_live_stop_requested = 0;
static volatile int g_notificationisland_live_running = 0;
static volatile int g_notificationisland_live_stop_requested = 0;
static volatile int g_gravitylite_background_armed = 0;
static volatile int g_gravitylite_start_worker_running = 0;
static volatile int g_gravity_motion_stop_requested = 1;
static volatile uint64_t g_gravity_motion_generation = 0;
static CMMotionManager *g_gravity_motion_manager = nil;
static volatile int g_themer_live_running = 0;
static volatile int g_themer_live_stop_requested = 0;
static volatile int g_themer_repair_running = 0;
static volatile uint64_t g_themer_repair_generation = 0;
static volatile int g_themer_stage_suppression_logged = 0;
static volatile int g_livewp_live_running = 0;
static volatile int g_livewp_live_stop_requested = 0;

static void settings_mark_tweak_applied(NSString *key, BOOL applied);
static void settings_notify_package_queue_changed_async(void);

static BOOL settings_gravity_motion_can_remote_call(uint64_t generation,
                                                    CMMotionManager *manager)
{
    return manager &&
           manager == g_gravity_motion_manager &&
           generation == g_gravity_motion_generation &&
           g_gravity_motion_stop_requested == 0 &&
           g_springboard_rc_ready != 0 &&
           !settings_screen_locked_cached() &&
           settings_screen_awake_cached() &&
           !settings_cleanup_in_progress();
}

static void settings_start_gravity_motion(double magnitude, double explosionForce)
{
    (void)explosionForce;
    if (g_gravity_motion_manager) {
        [g_gravity_motion_manager stopDeviceMotionUpdates];
        [g_gravity_motion_manager stopAccelerometerUpdates];
        g_gravity_motion_manager = nil;
    }
    CMMotionManager *mm = [[CMMotionManager alloc] init];
    g_gravity_motion_manager = mm;
    uint64_t generation = __sync_add_and_fetch(&g_gravity_motion_generation, 1);
    __sync_lock_test_and_set(&g_gravity_motion_stop_requested, 0);
    NSOperationQueue *q = [[NSOperationQueue alloc] init];
    q.maxConcurrentOperationCount = 1;

    if (mm.deviceMotionAvailable) {
        mm.deviceMotionUpdateInterval = 0.05;
        [mm startDeviceMotionUpdatesToQueue:q withHandler:^(CMDeviceMotion *motion, NSError *err) {
            if (!motion || err || !settings_gravity_motion_can_remote_call(generation, mm)) return;
            // gravity.x/y are already isolated from user movement.
            double tilt = hypot(motion.gravity.x, motion.gravity.y);
            double angle = (tilt < 0.14) ? M_PI_2 : atan2(-motion.gravity.y, motion.gravity.x);
            double effectiveMagnitude = magnitude * ((tilt < 0.14)
                                                     ? 0.65
                                                     : (0.90 + fmin(tilt, 1.0) * 0.60));

            @synchronized (settings_rc_lock()) {
                if (!settings_gravity_motion_can_remote_call(generation, mm)) return;
                gravitylite_update_gravity_angle_in_session(angle, effectiveMagnitude);
            }
        }];
    } else {
        mm.accelerometerUpdateInterval = 0.05;
        [mm startAccelerometerUpdatesToQueue:q withHandler:^(CMAccelerometerData *data, NSError *err) {
            if (!data || err || !settings_gravity_motion_can_remote_call(generation, mm)) return;
            double tilt = hypot(data.acceleration.x, data.acceleration.y);
            double angle = (tilt < 0.14) ? M_PI_2 : atan2(-data.acceleration.y, data.acceleration.x);
            double effectiveMagnitude = magnitude * ((tilt < 0.14)
                                                     ? 0.65
                                                     : (0.90 + fmin(tilt, 1.2) * 0.50));
            @synchronized (settings_rc_lock()) {
                if (!settings_gravity_motion_can_remote_call(generation, mm)) return;
                gravitylite_update_gravity_angle_in_session(angle, effectiveMagnitude);
            }
        }];
    }
    printf("[GRAVITY] Accelerometer active — tilt-only icon physics (magnitude=%.1fx)\n",
           magnitude);
}

static void settings_stop_gravity_motion(void)
{
    __sync_lock_test_and_set(&g_gravity_motion_stop_requested, 1);
    __sync_add_and_fetch(&g_gravity_motion_generation, 1);
    CMMotionManager *mm = g_gravity_motion_manager;
    if (!mm) return;
    g_gravity_motion_manager = nil;
    [mm stopDeviceMotionUpdates];
    [mm stopAccelerometerUpdates];
    printf("[GRAVITY] Accelerometer stopped.\n");
}

typedef void (*SettingsTweakRequestStopFunc)(void);
typedef bool (*SettingsTweakStopFunc)(BOOL springboardWillDie);
typedef void (*SettingsTweakForgetFunc)(void);
typedef BOOL (*SettingsTweakRunningFunc)(void);

typedef struct {
    __unsafe_unretained NSString *key;
    const char *name;
    SettingsTweakRequestStopFunc requestStop;
    SettingsTweakStopFunc stop;
    SettingsTweakForgetFunc forget;
    SettingsTweakRunningFunc isRunning;
    BOOL cleanupOnTermination;
    BOOL keepsSpringBoardSession;
} SettingsSpringBoardTweakCleanupEntry;

static void settings_request_statbar_stop(void) { g_statbar_live_stop_requested = 1; }
static void settings_request_nsbar_stop(void) { g_nsbar_live_stop_requested = 1; }
static void settings_request_nicebarlite_stop(void) { g_nicebarlite_live_stop_requested = 1; }
static void settings_request_rssi_stop(void) { g_rssi_live_stop_requested = 1; }
static void settings_request_axonlite_stop(void) { g_axonlite_live_stop_requested = 1; }
static void settings_request_typebanner_stop(void) { g_typebanner_live_stop_requested = 1; }
static void settings_request_notificationisland_stop(void) { g_notificationisland_live_stop_requested = 1; }
static void settings_request_themer_stop(void) { g_themer_live_stop_requested = 1; }
static void settings_request_gravitylite_stop(void)
{
    __sync_lock_test_and_set(&g_gravitylite_background_armed, 0);
    settings_stop_gravity_motion();
}
static void settings_request_stagestrip_stop(void) { stagestrip_stop_control_loop(); }
static void settings_request_livewp_stop(void) { g_livewp_live_stop_requested = 1; }

static BOOL settings_statbar_running(void) { return g_statbar_live_running != 0; }
static BOOL settings_nsbar_running(void) { return g_nsbar_live_running != 0; }
static BOOL settings_nicebarlite_running(void) { return g_nicebarlite_live_running != 0; }
static BOOL settings_rssi_running(void) { return g_rssi_live_running != 0; }
static BOOL settings_axonlite_running(void) { return g_axonlite_live_running != 0; }
static BOOL settings_typebanner_running(void) { return g_typebanner_live_running != 0; }
static BOOL settings_notificationisland_running(void) { return g_notificationisland_live_running != 0; }
static BOOL settings_themer_running(void) { return g_themer_live_running != 0 || g_themer_repair_running != 0; }
static BOOL settings_livewp_running(void) { return g_livewp_live_running != 0; }

static bool settings_stop_statbar_registered(BOOL springboardWillDie)
{
    (void)springboardWillDie;
    return statbar_stop_in_session();
}

static bool settings_stop_nsbar_registered(BOOL springboardWillDie)
{
    (void)springboardWillDie;
    return nsbar_stop_in_session();
}

static bool settings_stop_nicebarlite_registered(BOOL springboardWillDie)
{
    (void)springboardWillDie;
    return nicebarlite_stop_in_session();
}

static bool settings_stop_rssi_registered(BOOL springboardWillDie)
{
    (void)springboardWillDie;
    return rssidisplay_stop_in_session();
}

static bool settings_stop_axonlite_registered(BOOL springboardWillDie)
{
    return springboardWillDie ? axonlite_stop_in_session_fast()
                              : axonlite_stop_in_session();
}

static bool settings_stop_typebanner_registered(BOOL springboardWillDie)
{
    (void)springboardWillDie;
    bool keepAlive = typebanner_release_mobilesms_keepalive_in_springboard_session();
    bool hidden = typebanner_hide_in_springboard_session();
    printf("[TYPEBANNER] cleanup keepAlive=%d hide=%d\n", keepAlive, hidden);
    return keepAlive && hidden;
}

static bool settings_stop_notificationisland_registered(BOOL springboardWillDie)
{
    (void)springboardWillDie;
    return notificationisland_stop_in_session();
}

static bool settings_stop_appswitchergrid_registered(BOOL springboardWillDie)
{
    if (springboardWillDie) {
        appswitchergrid_forget_remote_state();
        return false;
    }
    return appswitchergrid_stop_in_session();
}

static bool settings_stop_gravitylite_registered(BOOL springboardWillDie)
{
    (void)springboardWillDie;
    settings_request_gravitylite_stop();
    return gravitylite_stop_in_session();
}

static bool settings_stop_themer_registered(BOOL springboardWillDie)
{
    (void)springboardWillDie;
    return themer_stop_in_session();
}

static bool settings_stop_stagestrip_registered(BOOL springboardWillDie)
{
    (void)springboardWillDie;
    return stagestrip_stop_in_session();
}

static bool settings_stop_fastlockx_lite_registered(BOOL springboardWillDie)
{
    if (springboardWillDie) {
        fastlockx_lite_forget_remote_state();
        return true;
    }
    return fastlockx_lite_disable_always_on_in_session();
}

static bool settings_stop_livewp_registered(BOOL springboardWillDie)
{
    (void)springboardWillDie;
    return livewp_stop_in_session();
}

static void settings_each_springboard_cleanup_entry(void (^block)(const SettingsSpringBoardTweakCleanupEntry *entry))
{
    if (!block) return;
    // Add new SpringBoard-backed tweaks here so Clean Up, Respring cleanup,
    // termination cleanup, live-loop waits, and applied-state reset stay in sync.
    const SettingsSpringBoardTweakCleanupEntry entries[] = {
        { kSettingsStatBarEnabled, "StatBar", settings_request_statbar_stop, settings_stop_statbar_registered, statbar_forget_remote_state, settings_statbar_running, YES, YES },
        { kSettingsNSBarEnabled, "NSBar", settings_request_nsbar_stop, settings_stop_nsbar_registered, nsbar_forget_remote_state, settings_nsbar_running, YES, YES },
        { kSettingsNiceBarLiteEnabled, "NiceBar Lite", settings_request_nicebarlite_stop, settings_stop_nicebarlite_registered, nicebarlite_forget_remote_state, settings_nicebarlite_running, YES, YES },
        { kSettingsRSSIDisplayEnabled, "RSSI", settings_request_rssi_stop, settings_stop_rssi_registered, rssidisplay_forget_remote_state, settings_rssi_running, YES, YES },
        { kSettingsAxonLiteEnabled, "Axon Lite", settings_request_axonlite_stop, settings_stop_axonlite_registered, axonlite_forget_remote_state, settings_axonlite_running, YES, YES },
        { kSettingsTypeBannerEnabled, "TypeBanner", settings_request_typebanner_stop, settings_stop_typebanner_registered, typebanner_forget_remote_state, settings_typebanner_running, YES, YES },
        { kSettingsNotificationIslandEnabled, "Notification Island", settings_request_notificationisland_stop, settings_stop_notificationisland_registered, notificationisland_forget_remote_state, settings_notificationisland_running, YES, YES },
        { kSettingsAppSwitcherGridEnabled, "App Switcher Grid", NULL, settings_stop_appswitchergrid_registered, appswitchergrid_forget_remote_state, NULL, YES, YES },
        { kSettingsGravityLiteEnabled, "Gravity Lite", settings_request_gravitylite_stop, settings_stop_gravitylite_registered, gravitylite_forget_remote_state, NULL, YES, YES },
        { kSettingsThemerEnabled, "Themer", settings_request_themer_stop, settings_stop_themer_registered, themer_forget_remote_state, settings_themer_running, YES, YES },
        { kSettingsSnowBoardLiteEnabled, "SnowBoard Lite", settings_request_themer_stop, settings_stop_themer_registered, themer_forget_remote_state, settings_themer_running, YES, YES },
        { kSettingsLiveWPEnabled, "LiveWP", settings_request_livewp_stop, settings_stop_livewp_registered, livewp_forget_remote_state, settings_livewp_running, YES, YES },
        { kSettingsStageStripEnabled, "Stage Strip", settings_request_stagestrip_stop, settings_stop_stagestrip_registered, stagestrip_forget_remote_state, NULL, YES, YES },
        { kSettingsFastLockXLiteEnabled, "FastLockX Lite", NULL, settings_stop_fastlockx_lite_registered, fastlockx_lite_forget_remote_state, NULL, YES, YES },
        { nil, "Kill All Apps", NULL, NULL, killallapps_forget_remote_state, NULL, NO, NO },
    };
    size_t count = sizeof(entries) / sizeof(entries[0]);
    for (size_t i = 0; i < count; i++) {
        block(&entries[i]);
    }
}

static BOOL settings_any_registered_live_loop_running(void)
{
    __block BOOL running = NO;
    settings_each_springboard_cleanup_entry(^(const SettingsSpringBoardTweakCleanupEntry *entry) {
        if (!running && entry->isRunning && entry->isRunning()) running = YES;
    });
    return running;
}

static NSString *settings_registered_live_loop_status_string(void)
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    settings_each_springboard_cleanup_entry(^(const SettingsSpringBoardTweakCleanupEntry *entry) {
        if (!entry->isRunning) return;
        [parts addObject:[NSString stringWithFormat:@"%s=%d",
                                                    entry->name ?: "tweak",
                                                    entry->isRunning() ? 1 : 0]];
    });
    return [parts componentsJoinedByString:@" "];
}
static volatile int g_app_in_background = 0;
static volatile int g_screen_awake = 1;
static volatile int g_screen_locked = 0;
static volatile int g_screen_lock_state_logged = 0;
static volatile int g_settings_termination_cleanup_started = 0;
static volatile int g_settings_cleanup_running = 0;
static volatile uint64_t g_sbc_live_apply_generation = 0;
static UIBackgroundTaskIdentifier g_statbar_bg_task = (UIBackgroundTaskIdentifier)-1;
static int g_springboard_blanked_notify_token = NOTIFY_TOKEN_INVALID;
static int g_display_status_notify_token = NOTIFY_TOKEN_INVALID;
static int g_springboard_lockstate_notify_token = NOTIFY_TOKEN_INVALID;
static int g_springboard_finished_startup_notify_token = NOTIFY_TOKEN_INVALID;
static int g_springboard_app_state_notify_token = NOTIFY_TOKEN_INVALID;
static int g_springboard_frontmost_notify_token = NOTIFY_TOKEN_INVALID;
static const NSInteger kSBCDefaultDockIcons = 4;
static const NSInteger kSBCDefaultCols = 4;
static const NSInteger kSBCDefaultRows = 6;
static const BOOL kSBCDefaultHideLabels = NO;
// Conservative seed values for the NanoRegistry editor. These represent the
// current "newer watch" baseline without changing the legacy-watch gates.
static const NSInteger kNanoDefaultMaxPairing       = 25;
static const NSInteger kNanoDefaultMinPairing       = 24;
static const NSInteger kNanoDefaultMinPairingChipID = 10;
static const NSInteger kNanoDefaultMinQuickSwitch   = 6;
// Pairing range used to let setup accept newer watchOS pairing generations
// while still accepting generation-23 setup messages from the existing flow.
static const NSInteger kNanoPresetNewerMaxPairing       = 99;
static const NSInteger kNanoPresetNewerMinPairing       = 23;
static const NSInteger kNanoPresetNewerMinPairingChipID = 10;
static const NSInteger kNanoPresetNewerMinQuickSwitch   = 6;
static const double kLocationSimDefaultLatitude = 40.55162017033417;
static const double kLocationSimDefaultLongitude = -73.93282297058470;
static const NSInteger kLocationSimDefaultAltitude = 0;
static const NSInteger kLocationSimDefaultAccuracy = 5;
static const NSInteger kNanoUIRowMin = 1;
static const NSInteger kNanoUIRowMax = 999;
static const useconds_t kStatBarLiveIntervalUS = 1000000;
static const NSInteger kStatBarDefaultRefreshRateSec = 1;
static const NSUInteger kStatBarLiveMaxTicks = 43200;
static const useconds_t kNSBarLiveIntervalUS = 1000000;
static const useconds_t kNSBarLiveBackgroundIntervalUS = 1500000;
static const NSUInteger kNSBarLiveMaxTicks = 43200;
static const useconds_t kNiceBarLiteLiveIntervalUS = 1000000;
static const useconds_t kNiceBarLiteLiveBackgroundIntervalUS = 1500000;
static const NSUInteger kNiceBarLiteLiveMaxTicks = 43200;
static const NSTimeInterval kNiceBarLiteWeatherRefreshInterval = 15.0 * 60.0;
static const useconds_t kLiveWPLiveIntervalUS = 2000000;
static const useconds_t kLiveWPLiveBackgroundIntervalUS = 3000000;
static const NSUInteger kLiveWPLiveMaxTicks = 43200;
static const int64_t kLiveBackgroundTaskGraceSeconds = 10;
static const useconds_t kRSSILiveIntervalUS = 250000;
static const useconds_t kRSSILiveBackgroundIntervalUS = 1000000;
static const NSUInteger kRSSILiveMaxTicks = 43200;
static const useconds_t kAxonLiteLiveIntervalUS = 500000;
static const useconds_t kAxonLiteLiveBackgroundIntervalUS = 1500000;
static const NSUInteger kAxonLiteLiveMaxTicks = 43200;
static const int kSettingsSpringBoardRCFirstExceptionTimeoutMS = 3000;
// TypeBanner polls imagent for typing indicators with original-thread-only
// RemoteCall probes and opens SpringBoard only when the banner state changes.
static const useconds_t kTypeBannerLiveIntervalUS = 1000000;
static const useconds_t kTypeBannerLiveBackgroundIntervalUS = 1000000;
static const useconds_t kTypeBannerInitialDaemonSettleUS = 250000;
static const NSUInteger kTypeBannerLiveMaxTicks = 28800;
static const useconds_t kNotificationIslandLiveIntervalUS = 750000;
static const useconds_t kNotificationIslandLiveBackgroundIntervalUS = 1500000;
static const NSUInteger kNotificationIslandLiveMaxTicks = 43200;
// Only Clock/Calendar need periodic repair; normal icons persist through the
// model graft and should not be repainted during SpringBoard animations.
static const useconds_t kThemerLiveIntervalUS = 2000000;
static const useconds_t kThemerLiveBackgroundIntervalUS = 10000000;
static const NSUInteger kThemerLiveMaxTicks = 86400;
static const NSUInteger kThemerLegacyLiveMaxTicks = 1;
static const useconds_t kThemerRepairInitialDelayUS = 900000;
static const useconds_t kThemerRepairIntervalUS = 450000;
static NSString * const kSettingsRemoteCallStateDidChangeNotification = @"SettingsRemoteCallStateDidChangeNotification";
NSString * const kSettingsActionsDidCompleteNotification = @"SettingsActionsDidCompleteNotification";
NSString * const kSettingsActionsDidCompleteSuccessKey = @"success";
NSString * const kSettingsActionsDidCompleteMessageKey = @"message";
static NSString * const kSettingsCleanupStateDidChangeNotification = @"SettingsCleanupStateDidChangeNotification";

static void settings_notify_cleanup_state_changed(void)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
            postNotificationName:kSettingsCleanupStateDidChangeNotification
                          object:nil];
    });
}

static void settings_post_actions_complete_async(BOOL success, NSString *message)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *info = @{
            kSettingsActionsDidCompleteSuccessKey: @(success),
            kSettingsActionsDidCompleteMessageKey: message ?: @""
        };
        [[NSNotificationCenter defaultCenter]
            postNotificationName:kSettingsActionsDidCompleteNotification
                          object:nil
                        userInfo:info];
    });
}

static NSArray<NSString *> * const kPowercuffLevels = nil;

// Session-scoped record of which tweaks were actually applied since launch.
// Distinct from the persisted NSUserDefaults enable flag — these are wiped on
// app launch and whenever the SpringBoard RemoteCall session is torn down, so
// the UI can show accurate "Installed" state rather than a stale toggle.
static NSMutableSet<NSString *> *g_applied_tweak_keys = nil;

static NSMutableSet<NSString *> *settings_applied_keys_set(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        g_applied_tweak_keys = [NSMutableSet set];
    });
    return g_applied_tweak_keys;
}

static void settings_mark_tweak_applied(NSString *key, BOOL applied)
{
    if (!key) return;
    NSMutableSet *set = settings_applied_keys_set();
    @synchronized (set) {
        if (applied) [set addObject:key];
        else         [set removeObject:key];
    }
}

BOOL settings_tweak_is_applied(NSString *key)
{
    if (!key) return NO;
    NSMutableSet *set = settings_applied_keys_set();
    @synchronized (set) {
        return [set containsObject:key];
    }
}

static BOOL settings_clear_all_applied_locked(void)
{
    NSMutableSet *set = settings_applied_keys_set();
    BOOL changed = NO;
    @synchronized (set) {
        if (set.count > 0) {
            [set removeAllObjects];
            changed = YES;
        }
    }
    return changed;
}

static NSArray<NSString *> *settings_rc_backed_tweak_keys(void)
{
    static NSArray<NSString *> *keys = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableArray<NSString *> *allKeys = [NSMutableArray arrayWithArray:@[
            kSettingsSBCEnabled,
            kSettingsPowercuffEnabled,
            kSettingsDSDisableAppLibrary,
            kSettingsDSDisableIconFlyIn,
            kSettingsDSZeroWakeAnimation,
            kSettingsDSZeroBacklightFade,
            kSettingsDSDoubleTapToLock,
            kSettingsDSDragCoefficientEnabled,
            kSettingsLayoutExtrasEnabled,
        ]];
        settings_each_springboard_cleanup_entry(^(const SettingsSpringBoardTweakCleanupEntry *entry) {
            if (entry->key && ![allKeys containsObject:entry->key]) {
                [allKeys addObject:entry->key];
            }
        });
        keys = [allKeys copy];
    });
    return keys;
}

static void settings_reconcile_applied_from_defaults(void)
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    for (NSString *key in settings_rc_backed_tweak_keys()) {
        if (![d boolForKey:key]) settings_mark_tweak_applied(key, NO);
    }
}

static void settings_notify_package_queue_changed_async(void)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:PackageQueueDidChangeNotification
                                                            object:[PackageQueue sharedQueue]];
    });
}

static NSObject *settings_rc_lock(void) {
    static NSObject *lock = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lock = [NSObject new];
    });
    return lock;
}

static NSObject *settings_bg_lock(void) {
    static NSObject *lock = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lock = [NSObject new];
    });
    return lock;
}

static uint64_t settings_now_us(void) {
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) return 0;
    return ((uint64_t)ts.tv_sec * 1000000ULL) + ((uint64_t)ts.tv_nsec / 1000ULL);
}

static void settings_apply_statbar_once_async(const char *reason);
static void settings_apply_nsbar_once_async(const char *reason);
static void settings_apply_nicebarlite_once_async(const char *reason);
static void settings_start_livewp_live_loop(void);
static void settings_resume_livewp_after_wake_async(const char *reason);
static void settings_pause_livewp_for_sleep_async(const char *reason);
static void settings_apply_rssi_once_async(const char *reason);
static void settings_start_rssi_live_loop(void);
static void settings_start_typebanner_live_loop(void);
static void settings_start_notificationisland_live_loop(void);
static void settings_start_themer_live_loop(void);
static void settings_schedule_themer_repair_burst(const char *reason);
static void settings_schedule_themer_quiet_repair_burst(const char *reason);
static void settings_notify_remote_call_state_changed(void);
static void settings_notify_remote_call_state_changed_preserving_applied(BOOL preserveApplied);
static void settings_request_all_live_loops_stop(const char *reason);

static BOOL settings_should_log_statbar_tick(NSUInteger tick) {
    // One-shot: log the very first tick so the user can see the loop took
    // off, then go silent forever. The polling continues; we just stop
    // narrating it.
    return tick == 0;
}

static useconds_t settings_live_interval(useconds_t foregroundUS, useconds_t backgroundUS)
{
    return (g_app_in_background != 0) ? backgroundUS : foregroundUS;
}

static useconds_t settings_statbar_refresh_rate_us(void)
{
    NSInteger sec = [[NSUserDefaults standardUserDefaults] integerForKey:kSettingsStatBarRefreshRateSec];
    if (sec <= 0) sec = kStatBarDefaultRefreshRateSec;
    if (sec < 1) sec = 1;
    if (sec > 30) sec = 30;
    return (useconds_t)sec * 1000000;
}

static useconds_t settings_statbar_live_interval_us(void)
{
    return settings_live_interval(kStatBarLiveIntervalUS,
                                  settings_statbar_refresh_rate_us());
}

static const char *settings_live_context(void)
{
    return (g_app_in_background != 0) ? "background" : "foreground";
}

static BOOL settings_app_state_is_foreground(void)
{
    UIApplicationState state = [UIApplication sharedApplication].applicationState;
    return state == UIApplicationStateActive || state == UIApplicationStateInactive;
}

static NSUInteger settings_live_failure_limit(NSUInteger foregroundLimit)
{
    return (g_app_in_background != 0 || g_screen_awake == 0) ? 1 : foregroundLimit;
}

static BOOL settings_experimental_access_allowed(void)
{
    return cyanide_is_patron() || cyanide_is_creator();
}

static BOOL settings_experimental_tweaks_enabled(void)
{
    return settings_experimental_access_allowed() &&
           [[NSUserDefaults standardUserDefaults] boolForKey:kSettingsExperimentalTweaksEnabled];
}

static BOOL settings_rssi_install_allowed(void)
{
    return cyanide_private_tweaks_available() && settings_experimental_tweaks_enabled();
}

static BOOL settings_typebanner_install_allowed(void)
{
    return cyanide_private_tweaks_available() && settings_experimental_tweaks_enabled();
}

static BOOL settings_notificationisland_install_allowed(void)
{
    return cyanide_private_tweaks_available() && settings_experimental_tweaks_enabled();
}

static BOOL settings_stagestrip_install_allowed(void)
{
    return cyanide_private_tweaks_available() && settings_experimental_tweaks_enabled();
}

static BOOL settings_fastlockx_lite_install_allowed(void)
{
    return cyanide_private_tweaks_available() && settings_experimental_tweaks_enabled();
}

static BOOL settings_themer_dynamic_updates_blocked_by_stage(NSUserDefaults *d)
{
    if (!settings_stagestrip_install_allowed()) return NO;
    if (![d boolForKey:kSettingsStageStripEnabled]) return NO;
    return [d boolForKey:kSettingsThemerEnabled] ||
           [d boolForKey:kSettingsSnowBoardLiteEnabled];
}

static void settings_note_themer_stage_conflict(BOOL userVisible)
{
    g_themer_live_stop_requested = 1;
    printf("[SETTINGS] Themer live icon repair paused while Dynamic Stage Lite is enabled\n");
    if (userVisible && __sync_bool_compare_and_swap(&g_themer_stage_suppression_logged, 0, 1)) {
        log_user("[COMPAT] Dynamic Stage Lite is enabled, so icon theme live repair is paused to avoid SpringBoard resprings. The selected theme still applies once; live repair resumes after Dynamic Stage is disabled.\n");
    }
}

static BOOL settings_location_sim_install_allowed(void)
{
    return YES;
}

static BOOL settings_read_screen_awake(void)
{
    BOOL haveState = NO;
    BOOL awake = YES;

    if (g_springboard_blanked_notify_token != NOTIFY_TOKEN_INVALID) {
        uint64_t state = 0;
        if (notify_get_state(g_springboard_blanked_notify_token, &state) == NOTIFY_STATUS_OK) {
            haveState = YES;
            awake = (state == 0);
        }
    }

    if (!haveState && g_display_status_notify_token != NOTIFY_TOKEN_INVALID) {
        uint64_t state = 0;
        if (notify_get_state(g_display_status_notify_token, &state) == NOTIFY_STATUS_OK) {
            awake = (state != 0);
        }
    }

    return awake;
}

static BOOL settings_screen_awake_cached(void)
{
    return g_screen_awake != 0;
}

static BOOL settings_refresh_screen_awake_state(const char *reason)
{
    BOOL awake = settings_read_screen_awake();
    int newValue = awake ? 1 : 0;
    int old = __sync_lock_test_and_set(&g_screen_awake, newValue);
    if (old != newValue) {
        printf("[SETTINGS] screen state=%s%s%s\n",
               awake ? "awake" : "asleep",
               reason ? " via " : "",
               reason ?: "");
    }
    return old == 0 && newValue != 0;
}

static BOOL settings_statbar_screen_awake(void)
{
    (void)settings_refresh_screen_awake_state(NULL);
    return settings_screen_awake_cached();
}

static BOOL settings_read_screen_locked(void)
{
    if (g_springboard_lockstate_notify_token == NOTIFY_TOKEN_INVALID) return NO;

    uint64_t state = 0;
    if (notify_get_state(g_springboard_lockstate_notify_token, &state) != NOTIFY_STATUS_OK) {
        return NO;
    }

    return state != 0;
}

static BOOL settings_screen_locked_cached(void)
{
    return g_screen_locked != 0;
}

static BOOL settings_refresh_screen_lock_state(const char *reason)
{
    BOOL locked = settings_read_screen_locked();
    int newValue = locked ? 1 : 0;
    int old = __sync_lock_test_and_set(&g_screen_locked, newValue);
    (void)__sync_lock_test_and_set(&g_screen_lock_state_logged, 1);
    return old != newValue;
}

static BOOL settings_axonlite_can_poll_springboard(void)
{
    // Locked-but-awake is the lockscreen — that's where Axon must run, so the
    // lock state is intentionally not part of this predicate. Only pause while
    // the screen is fully blanked, since SB tears down the cover-sheet VCs and
    // our cached pointers would PAC-fault if we kept calling through them.
    (void)settings_refresh_screen_awake_state(NULL);
    return settings_screen_awake_cached();
}

static const char *settings_axonlite_pause_reason(void)
{
    if (!settings_screen_awake_cached()) return "screen asleep";
    return "screen unavailable";
}

static BOOL settings_typebanner_can_poll_messages(void)
{
    (void)settings_refresh_screen_awake_state(NULL);
    (void)settings_refresh_screen_lock_state(NULL);
    return settings_screen_awake_cached() && !settings_screen_locked_cached();
}

static const char *settings_typebanner_pause_reason(void)
{
    if (!settings_screen_awake_cached()) return "screen asleep";
    if (settings_screen_locked_cached()) return "device locked";
    return "screen unavailable";
}

static void settings_stop_axonlite_then_forget_locked(const char *reason)
{
    if (g_springboard_rc_ready) {
        bool stopped = axonlite_stop_in_session();
        printf("[SETTINGS] Axon Lite stopped before state drop%s%s result=%d\n",
               reason ? ": " : "", reason ?: "", stopped);
    }
    axonlite_forget_remote_state();
}

static void settings_forget_springboard_tweak_state_locked(void)
{
    settings_each_springboard_cleanup_entry(^(const SettingsSpringBoardTweakCleanupEntry *entry) {
        if (entry->forget) entry->forget();
    });
}

static void settings_stop_springboard_tweaks_locked(const char *reason,
                                                    BOOL springboardWillDie)
{
    if (!g_springboard_rc_ready) {
        settings_forget_springboard_tweak_state_locked();
        return;
    }

    settings_each_springboard_cleanup_entry(^(const SettingsSpringBoardTweakCleanupEntry *entry) {
        if (!entry->stop) return;
        @try {
            bool stopped = entry->stop(springboardWillDie);
            printf("[SETTINGS] %s %s stop%s result=%d\n",
                   reason ?: "SpringBoard cleanup",
                   entry->name ?: "tweak",
                   springboardWillDie ? " (fast)" : "",
                   stopped);
        } @catch (NSException *e) {
            printf("[SETTINGS] %s %s cleanup exception: %s\n",
                   reason ?: "SpringBoard cleanup",
                   entry->name ?: "tweak",
                   e.reason.UTF8String);
        }
    });

    settings_forget_springboard_tweak_state_locked();
}

static BOOL settings_disabled_applied_springboard_cleanup_needed(NSUserDefaults *d)
{
    __block BOOL needed = NO;
    settings_each_springboard_cleanup_entry(^(const SettingsSpringBoardTweakCleanupEntry *entry) {
        if (needed || !entry->key || !entry->stop) return;
        needed = ![d boolForKey:entry->key] && settings_tweak_is_applied(entry->key);
    });
    return needed;
}

static void settings_stop_disabled_applied_springboard_tweaks_locked(NSUserDefaults *d)
{
    settings_each_springboard_cleanup_entry(^(const SettingsSpringBoardTweakCleanupEntry *entry) {
        if (!entry->key || !entry->stop) return;
        if ([d boolForKey:entry->key] || !settings_tweak_is_applied(entry->key)) return;
        if (entry->requestStop) entry->requestStop();
        @try {
            bool stopped = g_springboard_rc_ready ? entry->stop(NO) : false;
            if (entry->forget) entry->forget();
            settings_mark_tweak_applied(entry->key, NO);
            printf("[SETTINGS] disabled %s cleanup result=%d\n",
                   entry->name ?: "tweak",
                   stopped);
        } @catch (NSException *e) {
            printf("[SETTINGS] disabled %s cleanup exception: %s\n",
                   entry->name ?: "tweak",
                   e.reason.UTF8String);
        }
    });
}

static void settings_handle_springboard_restart(void)
{
    // SpringBoard just (re)started. Every pointer we cached from the previous
    // SB incarnation — class addresses, selector slots, retained objects,
    // ivar offsets, the trojan thread, our shmem map — is stale. Calling
    // through any of them under SB-2 hands a wild signed function pointer to
    // BLRAA and PAC-faults us. Drop everything before the next loop tick.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        BOOL hadSession = NO;
        @synchronized (settings_rc_lock()) {
            hadSession = (g_springboard_rc_ready != 0);
            // Tell live loops to bail at their next interval check.
            settings_request_all_live_loops_stop("SpringBoard restart");
            g_springboard_rc_ready = 0;
            g_springboard_sandbox_escaped = 0;

            settings_forget_springboard_tweak_state_locked();
            if (hadSession) {
                abandon_remote_call();
            }
        }
        printf("[SETTINGS] SpringBoard restart observed; dropped RemoteCall state (hadSession=%d)\n",
               (int)hadSession);
        if (hadSession) {
            log_user("[APP] SpringBoard restarted; tweak sessions cleared. Hit Run to rebuild.\n");
        }
        settings_notify_remote_call_state_changed();
    });
}

static void settings_install_screen_awake_observers(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        int status = notify_register_dispatch("com.apple.springboard.hasBlankedScreen",
                                              &g_springboard_blanked_notify_token,
                                              dispatch_get_main_queue(), ^(int token) {
            (void)token;
            if (settings_refresh_screen_awake_state("springboard.hasBlankedScreen")) {
                settings_apply_statbar_once_async("screen awake");
                settings_apply_nsbar_once_async("screen awake");
                settings_apply_nicebarlite_once_async("screen awake");
                settings_resume_livewp_after_wake_async("screen awake");
                settings_schedule_themer_quiet_repair_burst("screen awake");
                settings_restart_gravity_motion_if_active("screen awake");
            }
        });
        if (status != NOTIFY_STATUS_OK) {
            g_springboard_blanked_notify_token = NOTIFY_TOKEN_INVALID;
        }

        status = notify_register_dispatch("com.apple.iokit.hid.displayStatus",
                                          &g_display_status_notify_token,
                                          dispatch_get_main_queue(), ^(int token) {
            (void)token;
            if (settings_refresh_screen_awake_state("iokit.displayStatus")) {
                settings_apply_statbar_once_async("screen awake");
                settings_apply_nsbar_once_async("screen awake");
                settings_apply_nicebarlite_once_async("screen awake");
                settings_resume_livewp_after_wake_async("display awake");
                settings_schedule_themer_quiet_repair_burst("display awake");
                settings_restart_gravity_motion_if_active("display awake");
            }
        });
        if (status != NOTIFY_STATUS_OK) {
            g_display_status_notify_token = NOTIFY_TOKEN_INVALID;
        }

        status = notify_register_dispatch("com.apple.springboard.lockstate",
                                          &g_springboard_lockstate_notify_token,
                                          dispatch_get_main_queue(), ^(int token) {
            (void)token;
            BOOL changed = settings_refresh_screen_lock_state("springboard.lockstate");
            if (changed && g_screen_locked) {
                // Stop the accelerometer before the XPC/shmem stack tears down on lock —
                // otherwise the next callback fires into a stale shmem mapping.
                settings_stop_gravity_motion();
                gravitylite_forget_remote_state();
            }
        });
        if (status != NOTIFY_STATUS_OK) {
            g_springboard_lockstate_notify_token = NOTIFY_TOKEN_INVALID;
        }

        // Darwin notify fires when SpringBoard finishes its boot/respawn.
        // Either we just launched and SB is fine (cleanup is a no-op against
        // already-zero state) or SB crashed under us and we MUST drop every
        // cached pointer before the live loops fire again into SB-2.
        status = notify_register_dispatch("com.apple.springboard.finishedstartup",
                                          &g_springboard_finished_startup_notify_token,
                                          dispatch_get_main_queue(), ^(int token) {
            (void)token;
            settings_handle_springboard_restart();
        });
        if (status != NOTIFY_STATUS_OK) {
            g_springboard_finished_startup_notify_token = NOTIFY_TOKEN_INVALID;
        }

        status = notify_register_dispatch("com.apple.springboard.applicationStateChanged",
                                          &g_springboard_app_state_notify_token,
                                          dispatch_get_main_queue(), ^(int token) {
            uint64_t state = 0;
            (void)notify_get_state(token, &state);
            printf("[SETTINGS] springboard application state notify state=%llu\n",
                   (unsigned long long)state);
            settings_schedule_themer_repair_burst("springboard app state changed");
        });
        if (status != NOTIFY_STATUS_OK) {
            g_springboard_app_state_notify_token = NOTIFY_TOKEN_INVALID;
        }

        status = notify_register_dispatch("com.apple.springboard.frontmostApplicationChanged",
                                          &g_springboard_frontmost_notify_token,
                                          dispatch_get_main_queue(), ^(int token) {
            uint64_t state = 0;
            (void)notify_get_state(token, &state);
            printf("[SETTINGS] springboard frontmost app notify state=%llu\n",
                   (unsigned long long)state);
            settings_schedule_themer_repair_burst("springboard frontmost changed");
        });
        if (status != NOTIFY_STATUS_OK) {
            g_springboard_frontmost_notify_token = NOTIFY_TOKEN_INVALID;
        }

        // If the live loop tripped its 3-failure exit during a background
        // window, the screen-wake darwin notifications won't fire (the screen
        // never blanked) and the loop stays dead. Re-arm on app foreground.
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            (void)note;
            (void)settings_refresh_screen_awake_state("app became active");
            settings_apply_statbar_once_async("app became active");
            settings_schedule_themer_quiet_repair_burst("app became active");
        }];

        (void)settings_refresh_screen_awake_state("startup");
        (void)settings_refresh_screen_lock_state("startup");
    });
}

static void settings_end_statbar_background_task_async(const char *reason)
{
    void (^endTask)(void) = ^{
        @synchronized (settings_bg_lock()) {
            if (g_statbar_bg_task == UIBackgroundTaskInvalid) return;
            UIBackgroundTaskIdentifier task = g_statbar_bg_task;
            g_statbar_bg_task = UIBackgroundTaskInvalid;
            [[UIApplication sharedApplication] endBackgroundTask:task];
            printf("[SETTINGS] StatBar background task ended%s%s\n",
                   reason ? ": " : "", reason ?: "");
        }
    };

    if ([NSThread isMainThread]) {
        endTask();
    } else {
        dispatch_async(dispatch_get_main_queue(), endTask);
    }
}

// Bridge the foreground -> background transition with a short explicit
// UIBackgroundTask. DSKeepAlive's audio background mode carries the ongoing
// live feed; holding a UIBackgroundTask indefinitely trips UIKit's 30s watchdog
// warning and can get the app terminated.
static void settings_begin_statbar_background_task_async(const char *reason)
{
    void (^beginTask)(void) = ^{
        @synchronized (settings_bg_lock()) {
            if (g_statbar_bg_task != UIBackgroundTaskInvalid) return;
            UIApplication *app = [UIApplication sharedApplication];
            __block UIBackgroundTaskIdentifier task = UIBackgroundTaskInvalid;
            task = [app beginBackgroundTaskWithName:@"cyanide.statbar.live"
                                  expirationHandler:^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    @synchronized (settings_bg_lock()) {
                        if (g_statbar_bg_task != task) return;
                        g_statbar_bg_task = UIBackgroundTaskInvalid;
                        [[UIApplication sharedApplication] endBackgroundTask:task];
                        printf("[SETTINGS] StatBar background task expired by iOS; live loop may pause\n");
                    }
                });
            }];
            if (task == UIBackgroundTaskInvalid) {
                printf("[SETTINGS] StatBar background task could not be acquired%s%s\n",
                       reason ? ": " : "", reason ?: "");
                return;
            }
            g_statbar_bg_task = task;
            printf("[SETTINGS] StatBar background task acquired id=%lu%s%s\n",
                   (unsigned long)task,
                   reason ? ": " : "", reason ?: "");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                         kLiveBackgroundTaskGraceSeconds * NSEC_PER_SEC),
                           dispatch_get_main_queue(), ^{
                @synchronized (settings_bg_lock()) {
                    if (g_statbar_bg_task != task) return;
                    g_statbar_bg_task = UIBackgroundTaskInvalid;
                    [[UIApplication sharedApplication] endBackgroundTask:task];
                    printf("[SETTINGS] StatBar background task ended: transition grace elapsed; keepAlive=%d\n",
                           ds_keepalive_is_running());
                }
            });
        }
    };

    if ([NSThread isMainThread]) {
        beginTask();
    } else {
        dispatch_sync(dispatch_get_main_queue(), beginTask);
    }
}

static void settings_notify_remote_call_state_changed(void)
{
    settings_notify_remote_call_state_changed_preserving_applied(NO);
}

static void settings_notify_remote_call_state_changed_preserving_applied(BOOL preserveApplied)
{
    BOOL ready = (g_springboard_rc_ready != 0);
    BOOL cleared = NO;
    if (!ready && !preserveApplied) {
        cleared = settings_clear_all_applied_locked();
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kSettingsRemoteCallStateDidChangeNotification
                                                            object:nil];
        if (cleared) {
            [[NSNotificationCenter defaultCenter] postNotificationName:PackageQueueDidChangeNotification
                                                                object:[PackageQueue sharedQueue]];
            [[NSNotificationCenter defaultCenter] postNotificationName:kSettingsActionsDidCompleteNotification
                                                                object:nil];
        }
    });
}

static BOOL settings_cleanup_in_progress(void)
{
    return g_settings_cleanup_running != 0 ||
           g_settings_respring_cleanup_running != 0;
}

static void settings_request_all_live_loops_stop(const char *reason)
{
    settings_each_springboard_cleanup_entry(^(const SettingsSpringBoardTweakCleanupEntry *entry) {
        if (entry->requestStop) entry->requestStop();
    });
    if (reason) {
        printf("[SETTINGS] requested all live RemoteCall loops stop: %s\n", reason);
    }
}

static BOOL settings_has_active_termination_live_tweak(void)
{
    if (settings_any_registered_live_loop_running()) {
        return YES;
    }

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    __block BOOL active = NO;
    settings_each_springboard_cleanup_entry(^(const SettingsSpringBoardTweakCleanupEntry *entry) {
        if (active || !entry->cleanupOnTermination || !entry->key) return;
        active = [d boolForKey:entry->key] && settings_tweak_is_applied(entry->key);
    });
    return active;
}

static BOOL settings_has_persistent_springboard_remote_call_user(void)
{
    if (settings_has_active_termination_live_tweak()) {
        return YES;
    }

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    __block BOOL active = NO;
    settings_each_springboard_cleanup_entry(^(const SettingsSpringBoardTweakCleanupEntry *entry) {
        if (active || !entry->keepsSpringBoardSession || !entry->key) return;
        active = [d boolForKey:entry->key] && settings_tweak_is_applied(entry->key);
    });
    return active;
}

static void settings_wait_live_loops_stopped_for_switch(const char *reason)
{
    uint64_t startUS = settings_now_us();
    BOOL logged = NO;
    while (settings_any_registered_live_loop_running()) {
        uint64_t nowUS = settings_now_us();
        uint64_t elapsedUS = (startUS != 0 && nowUS >= startUS) ? nowUS - startUS : 0;
        if (!logged) {
            printf("[SETTINGS] waiting for live RemoteCall loops to stop%s%s\n",
                   reason ? ": " : "", reason ?: "");
            logged = YES;
        }
        if (elapsedUS >= 2000000ULL) {
            NSString *status = settings_registered_live_loop_status_string();
            printf("[SETTINGS] live loop stop wait timed out%s%s %s\n",
                   reason ? ": " : "", reason ?: "",
                   status.UTF8String);
            break;
        }
        usleep(50000);
    }
    if (logged && !settings_any_registered_live_loop_running()) {
        printf("[SETTINGS] live RemoteCall loops stopped%s%s\n",
               reason ? ": " : "", reason ?: "");
    }
}

static void settings_live_loop_sleep_interruptible(uint64_t targetUS,
                                                  useconds_t fallbackUS,
                                                  volatile int *stopFlag)
{
    uint64_t sleptFallbackUS = 0;
    while (!settings_cleanup_in_progress() && (!stopFlag || *stopFlag == 0)) {
        uint64_t nowUS = settings_now_us();
        uint64_t remainingUS = 0;
        if (targetUS != 0 && nowUS != 0 && nowUS < targetUS) {
            remainingUS = targetUS - nowUS;
        } else if (targetUS == 0 && sleptFallbackUS < fallbackUS) {
            remainingUS = (uint64_t)fallbackUS - sleptFallbackUS;
        } else {
            break;
        }

        useconds_t chunkUS = (useconds_t)(remainingUS < 100000ULL ? remainingUS : 100000ULL);
        if (chunkUS == 0) break;
        usleep(chunkUS);
        if (targetUS == 0) sleptFallbackUS += chunkUS;
    }
}

static UIViewController *settings_top_view_controller(UIViewController *vc)
{
    while (vc.presentedViewController) vc = vc.presentedViewController;
    if ([vc isKindOfClass:UINavigationController.class]) {
        return settings_top_view_controller(((UINavigationController *)vc).visibleViewController);
    }
    if ([vc isKindOfClass:UITabBarController.class]) {
        return settings_top_view_controller(((UITabBarController *)vc).selectedViewController);
    }
    return vc;
}

static UIViewController *settings_active_presenter(UIViewController *fallback)
{
    if (fallback.view.window) return settings_top_view_controller(fallback);

    UIWindow *candidate = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        if (ws.activationState != UISceneActivationStateForegroundActive &&
            ws.activationState != UISceneActivationStateForegroundInactive) {
            continue;
        }
        for (UIWindow *window in ws.windows) {
            if (window.isKeyWindow) {
                candidate = window;
                break;
            }
            if (!candidate && !window.hidden && window.rootViewController) {
                candidate = window;
            }
        }
        if (candidate) break;
    }

    return settings_top_view_controller(candidate.rootViewController ?: fallback);
}

static UIWindow *settings_active_window(UIViewController *fallback)
{
    if (fallback.view.window) return fallback.view.window;

    UIWindow *candidate = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        if (ws.activationState != UISceneActivationStateForegroundActive &&
            ws.activationState != UISceneActivationStateForegroundInactive) {
            continue;
        }
        for (UIWindow *window in ws.windows) {
            if (window.isKeyWindow) return window;
            if (!candidate && !window.hidden && window.rootViewController) {
                candidate = window;
            }
        }
    }
    return candidate;
}

static void settings_present_controller(UIViewController *controller, UIViewController *fallback)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presenter = settings_active_presenter(fallback);
        if (!presenter) {
            printf("[SETTINGS] presentation skipped: no attached presenter\n");
            return;
        }
        [presenter presentViewController:controller animated:YES completion:nil];
    });
}

static void settings_show_respring_overlay(UIViewController *fallback)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = settings_active_window(fallback);
        if (!window) {
            printf("[RESPRING] overlay skipped: no active window\n");
            return;
        }
        DSRespringOverlayView *overlay = [[DSRespringOverlayView alloc] initWithFrame:window.bounds];
        [window addSubview:overlay];
        [overlay loadRespringPayload];
    });
}

static NSArray<NSString *> *powercuff_levels(void) {
    return @[ @"off", @"nominal", @"light", @"moderate", @"heavy" ];
}

static NSComparisonResult settings_compare_system_version(NSString *target)
{
    NSString *version = UIDevice.currentDevice.systemVersion ?: @"0";
    return [version compare:target options:NSNumericSearch];
}

BOOL settings_device_supported(void)
{
    BOOL ios17to18 =
        settings_compare_system_version(@"17.0") != NSOrderedAscending &&
        settings_compare_system_version(@"18.7.1") != NSOrderedDescending;

    BOOL ios26 =
        settings_compare_system_version(@"26.0") != NSOrderedAscending &&
        settings_compare_system_version(@"26.0.1") != NSOrderedDescending;

    return ios17to18 || ios26;
}

static NSString *settings_unsupported_message(void)
{
    NSString *version = UIDevice.currentDevice.systemVersion ?: @"未知";
    return [NSString stringWithFormat:@"iOS %@ 不支持。支持的版本：iOS/iPadOS 17.0-18.7.1 或 26.0-26.0.1。", version];
}

static void settings_progress(NSUInteger *step, NSUInteger total, const char *message)
{
    if (!step || !message) return;
    (*step)++;
    log_user("[RUN %lu/%lu] %s\n",
             (unsigned long)*step,
             (unsigned long)total,
             message);
}

static BOOL settings_try_claim_actions_lock(const char *owner, const char *busyMessage)
{
    if (__sync_lock_test_and_set(&g_settings_actions_running, 1)) {
        printf("[SETTINGS] %s blocked: actions already running\n",
               owner ?: "action");
        if (busyMessage) log_user("%s\n", busyMessage);
        return NO;
    }
    return YES;
}

static void settings_release_actions_lock(void)
{
    __sync_lock_release(&g_settings_actions_running);
}

static NSString *settings_bundle_string(NSString *key, NSString *fallback)
{
    id value = [NSBundle mainBundle].infoDictionary[key];
    if ([value isKindOfClass:NSString.class] && [(NSString *)value length] > 0) {
        return value;
    }
    return fallback;
}

static NSString *settings_app_version_string(void)
{
    return settings_bundle_string(@"CFBundleShortVersionString", @"未知");
}

static NSString *settings_app_build_string(void)
{
    return settings_bundle_string(@"CFBundleVersion", @"未知");
}

static void settings_log_run_context(void)
{
}

static BOOL settings_ensure_kexploit(void)
{
    if (!settings_device_supported()) {
        printf("[SETTINGS] unsupported device: %s\n", settings_unsupported_message().UTF8String);
        return NO;
    }

    if (g_kexploit_done) {
        if (kexploit_krw_ready()) {
            log_user("[KRW] Reusing the live app KRW session; no exploit rerun needed.\n");
            return YES;
        }
        printf("[SETTINGS] cached KRW is stale; clearing RemoteCall state and recovering\n");
        log_user("[KRW] Cached app KRW failed validation; clearing RemoteCall state and trying recovery.\n");
        g_kexploit_done = NO;
        g_springboard_rc_ready = 0;
        g_springboard_sandbox_escaped = 0;
        kutils_reset_self_cache();
        settings_notify_remote_call_state_changed();
    }

    int res = kexploit_opa334();
    if (res != 0) {
        printf("[SETTINGS] kexploit_opa334 failed: %d\n", res);
        return NO;
    }
    g_kexploit_done = YES;
    settings_notify_remote_call_state_changed();
    return YES;
}

static BOOL settings_nano_load_override_enabled(void)
{
    if (!settings_device_supported()) return NO;
    return krw_persistence_launchd_holds_krw() || krw_persistence_has_saved_recovery();
}

static BOOL settings_ensure_kexploit_recovery_only(void)
{
    if (!settings_device_supported()) {
        printf("[SETTINGS] unsupported device: %s\n", settings_unsupported_message().UTF8String);
        return NO;
    }

    if (g_kexploit_done) {
        if (kexploit_krw_ready() && krw_persistence_launchd_holds_krw()) {
            log_user("[KRW] Reusing parked/recovered KRW for NanoRegistry load.\n");
            return YES;
        }
        log_user("[KRW] NanoRegistry load requires parked KRW recovery; live state is not eligible.\n");
        return NO;
    }

    if (!krw_persistence_has_saved_recovery()) {
        log_user("[KRW] NanoRegistry load disabled: no parked KRW recovery state is saved.\n");
        return NO;
    }

    log_user("[KRW] NanoRegistry load: attempting parked recovery only; fresh spray is disabled for this button.\n");
    if (!krw_persistence_recover()) {
        log_user("[KRW] NanoRegistry load failed: parked KRW recovery was not available.\n");
        return NO;
    }

    g_kexploit_done = YES;
    settings_notify_remote_call_state_changed();
    return YES;
}

static BOOL settings_ensure_springboard_remote_call_locked(void)
{
    if (g_springboard_rc_ready) {
        printf("[SETTINGS] reusing SpringBoard RemoteCall session\n");
        return YES;
    }

    if (init_remote_call_with_first_exception_timeout("SpringBoard",
                                                      false,
                                                      kSettingsSpringBoardRCFirstExceptionTimeoutMS) != 0) {
        printf("[SETTINGS] init_remote_call(SpringBoard) failed\n");
        return NO;
    }

    g_springboard_rc_ready = 1;
    g_springboard_sandbox_escaped = 0;
    settings_notify_remote_call_state_changed();
    return YES;
}

static void settings_destroy_springboard_remote_call_locked_internal_ex(const char *reason, BOOL notifyState, BOOL preserveApplied)
{
    if (!g_springboard_rc_ready) return;

    printf("[SETTINGS] destroying SpringBoard RemoteCall session%s%s\n",
           reason ? ": " : "", reason ?: "");
    destroy_remote_call();
    g_springboard_rc_ready = 0;
    g_springboard_sandbox_escaped = 0;
    if (notifyState) settings_notify_remote_call_state_changed_preserving_applied(preserveApplied);
}

static void settings_destroy_springboard_remote_call_locked_internal(const char *reason, BOOL notifyState)
{
    settings_destroy_springboard_remote_call_locked_internal_ex(reason, notifyState, NO);
}

static void settings_destroy_springboard_remote_call_locked(const char *reason)
{
    settings_destroy_springboard_remote_call_locked_internal(reason, YES);
}

static void settings_prepare_for_respring_sync(void)
{
    log_user("[RESPRING] Stopping live sessions before respring.\n");
    printf("[SETTINGS] preparing for respring cleanup rcReady=%d\n", g_springboard_rc_ready);
    settings_request_all_live_loops_stop("pre-respring cleanup");
    settings_end_statbar_background_task_async("pre-respring cleanup");
    settings_wait_live_loops_stopped_for_switch("pre-respring cleanup");

    @synchronized (settings_rc_lock()) {
        if (g_springboard_rc_ready) {
            // SB is about to be killed by the respring, so cleanup uses the
            // fast variant for tweaks where full remote restoration is wasted.
            settings_stop_springboard_tweaks_locked("pre-respring cleanup", YES);
            settings_destroy_springboard_remote_call_locked("pre-respring cleanup");
        }
    }

    if (g_kexploit_done) {
        bool parked = kexploit_terminal_cleanup();
        printf("[SETTINGS] pre-respring terminal KRW cleanup parked=%d\n", parked);
        g_kexploit_done = NO;
        g_springboard_rc_ready = 0;
        g_springboard_sandbox_escaped = 0;
        kutils_reset_self_cache();
        settings_notify_remote_call_state_changed();
    }

    log_user("[RESPRING] Cleanup complete. Opening respring flow.\n");
    usleep(300000);
}

static void settings_terminal_kexploit_cleanup_sync_internal(const char *reason)
{
    log_user("[CLEANUP] Tearing down live tweaks and releasing KRW state...\n");
    printf("[SETTINGS] terminal KRW cleanup requested%s%s done=%d rcReady=%d\n",
           reason ? ": " : "", reason ?: "",
           g_kexploit_done, g_springboard_rc_ready);
    settings_request_all_live_loops_stop("terminal KRW cleanup");
    settings_end_statbar_background_task_async("terminal KRW cleanup");
    settings_wait_live_loops_stopped_for_switch("terminal KRW cleanup");

    @synchronized (settings_rc_lock()) {
        if (g_springboard_rc_ready) {
            settings_stop_springboard_tweaks_locked("terminal cleanup", NO);
            settings_destroy_springboard_remote_call_locked(reason ?: "terminal KRW cleanup");
        } else {
            settings_forget_springboard_tweak_state_locked();
        }
    }

    if (!g_kexploit_done) {
        printf("[SETTINGS] terminal KRW cleanup skipped: no local KRW session\n");
        log_user("[CLEANUP] Nothing to clean up — no active KRW session.\n");
        g_springboard_rc_ready = 0;
        g_springboard_sandbox_escaped = 0;
        kutils_reset_self_cache();
        settings_notify_remote_call_state_changed();
        return;
    }

    bool parked = kexploit_terminal_cleanup();
    printf("[SETTINGS] terminal KRW cleanup result parked=%d\n", parked);
    log_user("%s Clean Up complete. %s\n",
             parked ? "[OK]" : "[WARN]",
             parked ? "KRW parked — next Run will recover in seconds." : "KRW not parked — next Run will re-exploit.");
    g_kexploit_done = NO;
    g_springboard_rc_ready = 0;
    g_springboard_sandbox_escaped = 0;
    kutils_reset_self_cache();
    settings_notify_remote_call_state_changed();
}

static void settings_terminal_kexploit_cleanup_sync(const char *reason)
{
    settings_terminal_kexploit_cleanup_sync_internal(reason);
}

static BOOL settings_acquire_actions_lock_wait(const char *owner, uint64_t timeoutUS)
{
    uint64_t startUS = settings_now_us();
    BOOL loggedWait = NO;

    while (__sync_lock_test_and_set(&g_settings_actions_running, 1)) {
        if (!loggedWait) {
            printf("[SETTINGS] %s waiting for active action before cleanup\n",
                   owner ?: "cleanup");
            log_user("[CLEANUP] Run in progress — cleanup queued for when it finishes.\n");
            loggedWait = YES;
        }

        if (timeoutUS != 0) {
            uint64_t nowUS = settings_now_us();
            if (startUS != 0 && nowUS >= startUS && nowUS - startUS >= timeoutUS) {
                printf("[SETTINGS] %s timed out waiting for action lock\n",
                       owner ?: "cleanup");
                log_user("[CLEANUP] Timed out waiting for the current run to finish — proceeding anyway.\n");
                return NO;
            }
        }

        usleep(100000);
    }

    if (loggedWait) {
        uint64_t nowUS = settings_now_us();
        uint64_t waitedUS = (startUS != 0 && nowUS >= startUS) ? nowUS - startUS : 0;
        printf("[SETTINGS] %s acquired action lock after %lluus\n",
               owner ?: "cleanup", waitedUS);
    }
    return YES;
}

static void settings_queue_terminal_kexploit_cleanup(const char *reason)
{
    if (__sync_lock_test_and_set(&g_settings_cleanup_running, 1)) {
        printf("[SETTINGS] terminal cleanup already queued/running%s%s\n",
               reason ? ": " : "", reason ?: "");
        log_user("[CLEANUP] Clean Up is already queued.\n");
        return;
    }
    settings_notify_cleanup_state_changed();

    settings_request_all_live_loops_stop("queued terminal cleanup");
    settings_end_statbar_background_task_async("queued terminal cleanup");

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        BOOL locked = settings_acquire_actions_lock_wait("terminal cleanup", 0);
        @try {
            settings_terminal_kexploit_cleanup_sync_internal(reason ?: "manual action");
        } @finally {
            if (locked) __sync_lock_release(&g_settings_actions_running);
            __sync_lock_release(&g_settings_cleanup_running);
            settings_notify_cleanup_state_changed();
        }
    });
}

void settings_best_effort_termination_cleanup(const char *reason)
{
    if (__sync_lock_test_and_set(&g_settings_termination_cleanup_started, 1)) {
        printf("[SETTINGS] termination cleanup already attempted%s%s\n",
               reason ? ": " : "", reason ?: "");
        return;
    }

    const char *why = reason ?: "app termination";
    log_user("[CLEANUP] App exiting (%s) — running last-chance teardown.\n", why);
    printf("[SETTINGS] best-effort termination cleanup requested: %s\n", why);

    if (!settings_has_active_termination_live_tweak()) {
        printf("[SETTINGS] termination cleanup skipped: no live tweaks active\n");
        log_user("[CLEANUP] No live tweaks active — nothing to tear down.\n");
        return;
    }

    settings_request_all_live_loops_stop("termination cleanup");

    BOOL locked = settings_acquire_actions_lock_wait("termination cleanup", 1500000);
    if (!locked) {
        log_user("[CLEANUP] Last-chance cleanup skipped because another operation is still active.\n");
        return;
    }

    @try {
        settings_terminal_kexploit_cleanup_sync_internal(why);
    } @finally {
        __sync_lock_release(&g_settings_actions_running);
    }
}

void settings_destroy_springboard_remote_call_sync(void)
{
    settings_request_all_live_loops_stop("remote call sync cleanup");
    settings_end_statbar_background_task_async("remote call sync cleanup");
    settings_wait_live_loops_stopped_for_switch("remote call sync cleanup");
    @synchronized (settings_rc_lock()) {
        if (g_springboard_rc_ready) {
            settings_stop_springboard_tweaks_locked("remote call sync cleanup", NO);
        }
        settings_destroy_springboard_remote_call_locked("manual/sync cleanup");
    }
}

void settings_destroy_springboard_remote_call(void)
{
    settings_request_all_live_loops_stop("remote call cleanup");
    settings_end_statbar_background_task_async("remote call cleanup");
    log_user("[SESSION] Closing SpringBoard injection session...\n");
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        settings_wait_live_loops_stopped_for_switch("remote call cleanup");
        @synchronized (settings_rc_lock()) {
            BOOL hadSession = g_springboard_rc_ready != 0;
            if (g_springboard_rc_ready) {
                settings_stop_springboard_tweaks_locked("remote call cleanup", NO);
            }
            settings_destroy_springboard_remote_call_locked("manual cleanup");
            log_user(hadSession ? "[OK] SpringBoard channel closed — live tweaks stopped.\n" :
                                  "[SESSION] No active SpringBoard session to close.\n");
        }
    });
}

static bool settings_apply_sbc_from_defaults_locked(NSUserDefaults *d)
{
    if (![d boolForKey:kSettingsSBCEnabled]) return false;

    return sbcustomizer_apply_in_session((int)[d integerForKey:kSettingsSBCDockIcons],
                                         (int)[d integerForKey:kSettingsSBCCols],
                                         (int)[d integerForKey:kSettingsSBCRows],
                                         [d boolForKey:kSettingsSBCHideLabels]);
}

static NSString *settings_nicebar_key(NSString *prefix, NSInteger slot)
{
    return [NSString stringWithFormat:@"%@%ld", prefix, (long)slot];
}

static NSString *settings_nicebar_slot_name(NSInteger slot)
{
    switch ((NiceBarLiteSlot)slot) {
        case NiceBarLiteSlotTopLeft: return @"左上";
        case NiceBarLiteSlotTopRight: return @"右上";
        case NiceBarLiteSlotBottomLeft: return @"左下";
        case NiceBarLiteSlotBottomRight: return @"右下";
        case NiceBarLiteSlotBottomCenter: return @"中间";
        case NiceBarLiteSlotCount: return @"槽位";
    }
    return @"槽位";
}

static NSString *settings_nicebar_kind_name(NSInteger kind)
{
    switch ((NiceBarLiteContentKind)kind) {
        case NiceBarLiteContentOff: return @"关闭";
        case NiceBarLiteContentCustomText: return @"自定义文本";
        case NiceBarLiteContentSystem: return @"系统";
        case NiceBarLiteContentTimeFormat: return @"日期/时间";
        case NiceBarLiteContentWeather: return @"天气";
    }
    return @"关闭";
}

static NSString *settings_nicebar_system_name(NSInteger item)
{
    switch ((NiceBarLiteSystemItem)item) {
        case NiceBarLiteSystemBatteryTemp: return @"电池温度";
        case NiceBarLiteSystemFreeRAM: return @"可用内存";
        case NiceBarLiteSystemBatteryPercent: return @"电池电量";
        case NiceBarLiteSystemNetworkSpeed: return @"网络速度";
        case NiceBarLiteSystemUptime: return @"运行时间";
        case NiceBarLiteSystemDate: return @"日期";
        case NiceBarLiteSystemLunarDate: return @"农历日期";
        case NiceBarLiteSystemTodayTraffic: return @"今日流量";
        case NiceBarLiteSystemCurrentIP: return @"当前 IP";
        case NiceBarLiteSystemFreeDisk: return @"可用存储";
        case NiceBarLiteSystemThermalState: return @"温度状态";
    }
    return @"系统";
}

static BOOL settings_nicebar_has_weather_slots(NSUserDefaults *d)
{
    for (NSInteger i = 0; i < NiceBarLiteSlotCount; i++) {
        NSInteger kind = [d integerForKey:settings_nicebar_key(kSettingsNiceBarLiteSlotKindPrefix, i)];
        if (kind == NiceBarLiteContentWeather) return YES;
    }
    return NO;
}

static NSString *settings_nicebar_weather_text_for_slot(NSUserDefaults *d, NSInteger slot)
{
    NSNumber *tempNumber = [d objectForKey:kSettingsNiceBarLiteWeatherTemp];
    NSNumber *codeNumber = [d objectForKey:kSettingsNiceBarLiteWeatherCode];
    if (![tempNumber isKindOfClass:NSNumber.class] || ![codeNumber isKindOfClass:NSNumber.class]) {
        return [d stringForKey:kSettingsNiceBarLiteWeatherCache] ?:
               [d stringForKey:settings_nicebar_key(kSettingsNiceBarLiteSlotWeatherPrefix, slot)] ?:
               @"天气 --";
    }

    NSString *language = [d stringForKey:settings_nicebar_key(kSettingsNiceBarLiteSlotWeatherLanguagePrefix, slot)] ?: @"en";
    BOOL chinese = [language isEqualToString:@"zh"];
    NSString *summary = CyanideNiceBarWeatherSummary(codeNumber.integerValue, chinese);
    return [NSString stringWithFormat:@"%@ %.0f°", summary, tempNumber.doubleValue];
}

static BOOL settings_nicebar_has_resolved_weather(NSUserDefaults *d)
{
    NSNumber *tempNumber = [d objectForKey:kSettingsNiceBarLiteWeatherTemp];
    NSNumber *codeNumber = [d objectForKey:kSettingsNiceBarLiteWeatherCode];
    return [tempNumber isKindOfClass:NSNumber.class] &&
           [codeNumber isKindOfClass:NSNumber.class];
}

static void settings_nicebar_update_weather_slot_texts(NSUserDefaults *d)
{
    for (NSInteger i = 0; i < NiceBarLiteSlotCount; i++) {
        [d setObject:settings_nicebar_weather_text_for_slot(d, i)
              forKey:settings_nicebar_key(kSettingsNiceBarLiteSlotWeatherPrefix, i)];
    }
}

static void settings_nicebar_store_weather_result(NSUserDefaults *d,
                                                  NSNumber *temp,
                                                  NSNumber *code,
                                                  NSString *fallbackText,
                                                  BOOL fetched)
{
    if ([temp isKindOfClass:NSNumber.class] && [code isKindOfClass:NSNumber.class]) {
        [d setObject:temp forKey:kSettingsNiceBarLiteWeatherTemp];
        [d setObject:code forKey:kSettingsNiceBarLiteWeatherCode];
        NSString *cache = [NSString stringWithFormat:@"%@ %.0f°",
                           CyanideNiceBarWeatherSummary(code.integerValue, NO),
                           temp.doubleValue];
        [d setObject:cache forKey:kSettingsNiceBarLiteWeatherCache];
    } else {
        NSString *resolved = fallbackText.length ? fallbackText : @"天气 --";
        [d setObject:resolved forKey:kSettingsNiceBarLiteWeatherCache];
    }

    [d setObject:[NSDate date] forKey:kSettingsNiceBarLiteWeatherLastAttemptAt];
    if (fetched) {
        [d setObject:[NSDate date] forKey:kSettingsNiceBarLiteWeatherUpdatedAt];
    }
    settings_nicebar_update_weather_slot_texts(d);
    [d synchronize];
}

static NSString *settings_nsbar_position_name(NSInteger position)
{
    switch ((NSBarPosition)position) {
        case NSBarPositionTopLeft: return @"左上";
        case NSBarPositionBottomLeft: return @"左下";
        case NSBarPositionTopRight: return @"右上";
        case NSBarPositionBottomRight: return @"右下";
        case NSBarPositionCenter: return @"中间";
    }
    return @"左上";
}

static NSString *settings_livewp_video_detail(void)
{
    NSString *path = livewp_absolute_path();
    if (path.length == 0) return @"未选择视频";
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    if (attrs) {
        unsigned long long bytes = [attrs fileSize];
        NSByteCountFormatter *fmt = [[NSByteCountFormatter alloc] init];
        fmt.allowedUnits = NSByteCountFormatterUseMB | NSByteCountFormatterUseGB;
        fmt.countStyle = NSByteCountFormatterCountStyleFile;
        return [NSString stringWithFormat:@"%@ (%@)", path.lastPathComponent, [fmt stringFromByteCount:(long long)bytes]];
    }
    return [NSString stringWithFormat:@"%@ (missing)", path.lastPathComponent ?: path];
}

static NiceBarLiteConfig settings_nicebar_config_from_defaults(NSUserDefaults *d)
{
    NiceBarLiteConfig cfg;
    memset(&cfg, 0, sizeof(cfg));
    cfg.celsius = [d boolForKey:kSettingsNiceBarLiteCelsius];
    cfg.topSideInsetOffset = [d integerForKey:kSettingsNiceBarLiteLayoutTopSideInset];
    cfg.bottomSideInsetOffset = [d integerForKey:kSettingsNiceBarLiteLayoutBottomSideInset];
    cfg.topYOffset = [d integerForKey:kSettingsNiceBarLiteLayoutTopY];
    cfg.bottomYOffset = [d integerForKey:kSettingsNiceBarLiteLayoutBottomY];
    cfg.centerXOffset = [d integerForKey:kSettingsNiceBarLiteLayoutCenterX];
    cfg.updateMask = UINT32_MAX;

    for (NSInteger i = 0; i < NiceBarLiteSlotCount; i++) {
        NSString *text = [d stringForKey:settings_nicebar_key(kSettingsNiceBarLiteSlotTextPrefix, i)] ?: @"";
        NSString *time = [d stringForKey:settings_nicebar_key(kSettingsNiceBarLiteSlotTimePrefix, i)] ?: @"HH:mm";
        NSString *weather = settings_nicebar_weather_text_for_slot(d, i);
        NSString *language = [d stringForKey:settings_nicebar_key(kSettingsNiceBarLiteSlotSystemLanguagePrefix, i)] ?: @"en";
        cfg.slots[i].kind = (int)[d integerForKey:settings_nicebar_key(kSettingsNiceBarLiteSlotKindPrefix, i)];
        cfg.slots[i].systemItem = (int)[d integerForKey:settings_nicebar_key(kSettingsNiceBarLiteSlotSystemPrefix, i)];
        cfg.slots[i].customText = text.UTF8String;
        cfg.slots[i].timeFormat = time.UTF8String;
        cfg.slots[i].weatherText = weather.UTF8String;
        cfg.slots[i].systemLanguage = language.UTF8String;
    }
    return cfg;
}

static bool settings_apply_nicebarlite_from_defaults_locked(NSUserDefaults *d)
{
    if (![d boolForKey:kSettingsNiceBarLiteEnabled]) return false;
    return nicebarlite_apply_in_session(settings_nicebar_config_from_defaults(d));
}

static void settings_nicebar_schedule_apply_after_weather_update(void)
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        if (![d boolForKey:kSettingsNiceBarLiteEnabled] || !g_springboard_rc_ready) return;
        @synchronized (settings_rc_lock()) {
            if (settings_cleanup_in_progress() ||
                ![d boolForKey:kSettingsNiceBarLiteEnabled] ||
                !g_springboard_rc_ready) {
                return;
            }
            bool ok = settings_apply_nicebarlite_from_defaults_locked(d);
            settings_mark_tweak_applied(kSettingsNiceBarLiteEnabled, ok);
            printf("[SETTINGS] NiceBar Lite weather refresh apply result=%d\n", ok);
        }
        settings_notify_package_queue_changed_async();
    });
}

static volatile int g_nicebarlite_weather_refresh_requested = 0;

static void settings_nicebar_refresh_weather_if_needed(BOOL force,
                                                       void (^completion)(BOOL ok, NSString *text))
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (!settings_nicebar_has_weather_slots(d)) {
        if (force || completion) {
            log_user("[NICEBAR] Weather refresh skipped: no weather slot configured.\n");
        }
        if (completion) completion(NO, [d stringForKey:kSettingsNiceBarLiteWeatherCache] ?: @"");
        return;
    }

    BOOL hasResolvedWeather = settings_nicebar_has_resolved_weather(d);
    NSTimeInterval retryInterval = hasResolvedWeather ? kNiceBarLiteWeatherRefreshInterval : 60.0;
    if (!force && completion == nil) {
        NSDate *lastAttempt = [d objectForKey:kSettingsNiceBarLiteWeatherLastAttemptAt];
        if ([lastAttempt isKindOfClass:NSDate.class] &&
            [[NSDate date] timeIntervalSinceDate:lastAttempt] < retryInterval) {
            return;
        }
    }
    if (!force && completion == nil &&
        !__sync_bool_compare_and_swap(&g_nicebarlite_weather_refresh_requested, 0, 1)) {
        return;
    }

    [d setObject:[NSDate date] forKey:kSettingsNiceBarLiteWeatherLastAttemptAt];
    [d synchronize];
    log_user("[NICEBAR] Weather refresh requested force=%d cached=%d.\n",
             force ? 1 : 0,
             hasResolvedWeather ? 1 : 0);

    dispatch_async(dispatch_get_main_queue(), ^{
        [[CyanideNiceBarWeatherRefresher sharedRefresher]
            refreshWeatherForce:force
                      useCelsius:[d boolForKey:kSettingsNiceBarLiteCelsius]
                      completion:^(BOOL ok, NSString *text, NSNumber *temp, NSNumber *code, BOOL fetched) {
            __sync_lock_release(&g_nicebarlite_weather_refresh_requested);
            NSUserDefaults *innerDefaults = [NSUserDefaults standardUserDefaults];
            if (fetched || force) {
                settings_nicebar_store_weather_result(innerDefaults, temp, code, text, ok);
            }
            if (fetched || force || completion) {
                log_user("[NICEBAR] Weather refresh finished ok=%d fetched=%d text=%s temp=%s code=%s\n",
                         ok ? 1 : 0,
                         fetched ? 1 : 0,
                         text.UTF8String ?: "(nil)",
                         temp ? temp.stringValue.UTF8String : "(nil)",
                         code ? code.stringValue.UTF8String : "(nil)");
            }
            if ((fetched || force) &&
                [innerDefaults boolForKey:kSettingsNiceBarLiteEnabled] &&
                g_springboard_rc_ready) {
                settings_nicebar_schedule_apply_after_weather_update();
            }
            if (completion) completion(ok, text);
        }];
    });
}

static BOOL settings_dark_tweaks_any_enabled(NSUserDefaults *d)
{
    return [d boolForKey:kSettingsDSDisableAppLibrary] ||
           [d boolForKey:kSettingsDSDisableIconFlyIn] ||
           [d boolForKey:kSettingsDSZeroWakeAnimation] ||
           [d boolForKey:kSettingsDSZeroBacklightFade] ||
           [d boolForKey:kSettingsDSDoubleTapToLock];
}

static BOOL settings_enabled_tweak_should_run(NSUserDefaults *d, NSString *key, BOOL pendingOnly)
{
    if (![d boolForKey:key]) return NO;
    return !pendingOnly || !settings_tweak_is_applied(key);
}

static NSTimeInterval settings_current_boot_epoch_seconds(void)
{
    struct timeval boottime;
    size_t len = sizeof(boottime);
    memset(&boottime, 0, sizeof(boottime));
    if (sysctlbyname("kern.boottime", &boottime, &len, NULL, 0) == 0 &&
        boottime.tv_sec > 0) {
        return (NSTimeInterval)boottime.tv_sec;
    }

    return [[NSDate date] timeIntervalSince1970] -
           [[NSProcessInfo processInfo] systemUptime];
}

static BOOL settings_hide_home_bar_materialkit_zero_active(NSUserDefaults *d)
{
    NSTimeInterval storedBoot = [d doubleForKey:kSettingsHideHomeBarMaterialKitBootTime];
    if (storedBoot <= 0.0) return NO;

    NSTimeInterval currentBoot = settings_current_boot_epoch_seconds();
    if (currentBoot <= 0.0) return YES;
    if (fabs(currentBoot - storedBoot) > 120.0) {
        // The MaterialKit page zero is memory-backed/transient; a reboot
        // restores the asset catalog, so stale conflict state can be dropped.
        [d removeObjectForKey:kSettingsHideHomeBarMaterialKitBootTime];
        [d synchronize];
        return NO;
    }
    return YES;
}

static void settings_note_hide_home_bar_materialkit_zero_active(NSUserDefaults *d)
{
    [d setDouble:settings_current_boot_epoch_seconds()
          forKey:kSettingsHideHomeBarMaterialKitBootTime];
    [d synchronize];
}

BOOL settings_hide_home_bar_respring_pending(void)
{
    return settings_hide_home_bar_materialkit_zero_active(NSUserDefaults.standardUserDefaults);
}

void settings_present_hide_home_bar_respring_prompt(UIViewController *host)
{
    UIAlertController *ac = [UIAlertController
        alertControllerWithTitle:@"注销以隐藏主屏幕横条？"
                         message:@"隐藏主屏幕横条已应用，但主屏幕（SpringBoard）需要重启，主屏幕横条才会消失。"
                  preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"稍后"
                                           style:UIAlertActionStyleCancel
                                         handler:nil]];
    __weak UIViewController *weakHost = host;
    [ac addAction:[UIAlertAction actionWithTitle:@"注销"
                                           style:UIAlertActionStyleDestructive
                                         handler:^(UIAlertAction *_) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            if (__sync_lock_test_and_set(&g_settings_actions_running, 1)) {
                printf("[SETTINGS] hide home bar respring blocked: actions already running\n");
                log_user("[RESPRING] Another action is still running. Try Respring again in a moment.\n");
                return;
            }

            __sync_lock_test_and_set(&g_settings_respring_cleanup_running, 1);
            settings_notify_cleanup_state_changed();
            @try {
                settings_prepare_for_respring_sync();
            } @finally {
                __sync_lock_release(&g_settings_actions_running);
                __sync_lock_release(&g_settings_respring_cleanup_running);
                settings_notify_cleanup_state_changed();
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                settings_show_respring_overlay(weakHost);
            });
        });
    }]];
    settings_present_controller(ac, host);
}

static BOOL settings_dark_tweaks_should_run(NSUserDefaults *d, BOOL pendingOnly)
{
    NSArray<NSString *> *keys = @[
        kSettingsDSDisableAppLibrary,
        kSettingsDSDisableIconFlyIn,
        kSettingsDSZeroWakeAnimation,
        kSettingsDSZeroBacklightFade,
        kSettingsDSDoubleTapToLock,
        kSettingsDSDragCoefficientEnabled,
    ];
    for (NSString *key in keys) {
        if (settings_enabled_tweak_should_run(d, key, pendingOnly)) return YES;
    }
    return NO;
}

typedef struct {
    bool any;
    bool disableAppLibrary;
    bool disableIconFlyIn;
    bool zeroWakeAnimation;
    bool zeroBacklightFade;
    bool doubleTapToLock;
    bool dragCoefficient;
} SettingsDarkTweaksResult;

static bool settings_dark_tweaks_result_all_ok(SettingsDarkTweaksResult result)
{
    return result.any &&
           result.disableAppLibrary &&
           result.disableIconFlyIn &&
           result.zeroWakeAnimation &&
           result.zeroBacklightFade &&
           result.doubleTapToLock &&
           result.dragCoefficient;
}

static SettingsDarkTweaksResult settings_apply_dark_tweaks_from_defaults_locked(NSUserDefaults *d)
{
    BOOL disableAppLibrary = [d boolForKey:kSettingsDSDisableAppLibrary];
    BOOL disableIconFlyIn = [d boolForKey:kSettingsDSDisableIconFlyIn];
    BOOL zeroWakeAnimation = [d boolForKey:kSettingsDSZeroWakeAnimation];
    BOOL zeroBacklightFade = [d boolForKey:kSettingsDSZeroBacklightFade];
    BOOL doubleTapToLock = [d boolForKey:kSettingsDSDoubleTapToLock];
    BOOL dragCoefficientEnabled = [d boolForKey:kSettingsDSDragCoefficientEnabled];
    SettingsDarkTweaksResult result = {
        .disableAppLibrary = true,
        .disableIconFlyIn = true,
        .zeroWakeAnimation = true,
        .zeroBacklightFade = true,
        .doubleTapToLock = true,
        .dragCoefficient = true,
    };

    printf("[DST] apply appLib=%d flyIn=%d wake=%d backlight=%d dblTap=%d drag=%d\n",
           disableAppLibrary,
           disableIconFlyIn,
           zeroWakeAnimation,
           zeroBacklightFade,
           doubleTapToLock,
           dragCoefficientEnabled);

    if (disableAppLibrary) {
        result.any = true;
        result.disableAppLibrary = darksword_tweak_disable_app_library_in_session();
    }
    if (disableIconFlyIn) {
        result.any = true;
        result.disableIconFlyIn = darksword_tweak_disable_icon_fly_in_in_session();
    }
    if (zeroWakeAnimation) {
        result.any = true;
        result.zeroWakeAnimation = darksword_tweak_zero_wake_animation_in_session();
    }
    if (zeroBacklightFade) {
        result.any = true;
        result.zeroBacklightFade = darksword_tweak_zero_backlight_fade_in_session();
    }
    if (doubleTapToLock) {
        result.any = true;
        result.doubleTapToLock = darksword_tweak_double_tap_to_lock_in_session();
    }
    if (dragCoefficientEnabled) {
        result.any = true;
        result.dragCoefficient = darksword_drag_coefficient_apply(settings_drag_coefficient_value(d));
    }
    return result;
}

static bool settings_apply_layout_extras_from_defaults_locked(NSUserDefaults *d)
{
    if (![d boolForKey:kSettingsLayoutExtrasEnabled]) return false;
    double exL  = (double)[d integerForKey:kSettingsLayoutHomeExtraLeft];
    double exR  = (double)[d integerForKey:kSettingsLayoutHomeExtraRight];
    double exT  = (double)[d integerForKey:kSettingsLayoutHomeExtraTop];
    double exB  = (double)[d integerForKey:kSettingsLayoutHomeExtraBottom];
    double dockExH = (double)[d integerForKey:kSettingsLayoutDockExtraHorizontal];
    NSInteger hsPct = [d integerForKey:kSettingsLayoutHomeScalePct];
    NSInteger dkPct = [d integerForKey:kSettingsLayoutDockScalePct];
    double homeScale = (hsPct > 0) ? (double)hsPct / 100.0 : 1.0;
    double dockScale = (dkPct > 0) ? (double)dkPct / 100.0 : 1.0;
    return darksword_layout_apply_in_session(exL, exR, exT, exB, dockExH, homeScale, dockScale);
}

static GravityLiteConfig settings_gravitylite_config_from_defaults(NSUserDefaults *d)
{
    NSInteger magnitudePct = [d integerForKey:kSettingsGravityLiteMagnitudePct];
    NSInteger bouncePct = [d integerForKey:kSettingsGravityLiteBouncePct];
    NSInteger frictionPct = [d integerForKey:kSettingsGravityLiteFrictionPct];
    NSInteger resistancePct = [d integerForKey:kSettingsGravityLiteResistancePct];
    NSInteger angularResistancePct = [d integerForKey:kSettingsGravityLiteAngularResistancePct];
    if (magnitudePct <= 0) magnitudePct = 100;
    if (resistancePct < 0) resistancePct = 0;
    if (angularResistancePct < 0) angularResistancePct = 0;

    GravityLiteConfig config = {
        .includeDock = [d boolForKey:kSettingsGravityLiteDockEnabled],
        .allowsRotation = true,
        .magnitude = (double)magnitudePct / 45.0,
        .bounce = (double)bouncePct / 100.0,
        .friction = (double)frictionPct / 100.0,
        .resistance = (double)resistancePct / 100.0,
        .angularResistance = (double)angularResistancePct / 100.0,
        .explosionForce = 7.0,
    };
    return config;
}

static bool settings_apply_gravitylite_from_defaults_locked(NSUserDefaults *d)
{
    if (![d boolForKey:kSettingsGravityLiteEnabled]) return false;
    return gravitylite_apply_in_session(settings_gravitylite_config_from_defaults(d));
}

static double settings_fastlockx_lite_retry_interval(NSUserDefaults *d)
{
    id raw = [d objectForKey:kSettingsFastLockXLiteRetryInterval];
    double value = [raw respondsToSelector:@selector(doubleValue)] ? [raw doubleValue] : 0.5;
    if (!isfinite(value) || value <= 0.0) value = 0.5;
    if (value < 0.1) value = 0.1;
    if (value > 2.0) value = 2.0;
    return value;
}

static FastLockXLiteConfig settings_fastlockx_lite_config_from_defaults(NSUserDefaults *d,
                                                                        BOOL pulse,
                                                                        BOOL unlock)
{
    FastLockXLiteConfig config = {
        .pulseBiometricRetry = pulse,
        .attemptUnlock = unlock,
        // Blockers are UI-disabled for now; keep the backend behavior aligned
        // so stale saved defaults don't silently change unlock behavior.
        .blockOnMusic = false,
        .blockOnFlashlight = false,
        .blockOnLowPowerMode = false,
        .diagnosticLogging = YES,
        .retryIntervalSeconds = settings_fastlockx_lite_retry_interval(d),
    };
    return config;
}

static void settings_restart_gravity_motion_if_active(const char *reason)
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (![d boolForKey:kSettingsGravityLiteEnabled]) return;
    if (!settings_tweak_is_applied(kSettingsGravityLiteEnabled)) return;
    if (!g_springboard_rc_ready || settings_cleanup_in_progress()) return;
    if (!settings_screen_awake_cached() || settings_screen_locked_cached()) return;
    if (g_gravity_motion_stop_requested == 0 && g_gravity_motion_manager) return;

    GravityLiteConfig config = settings_gravitylite_config_from_defaults(d);
    settings_start_gravity_motion(config.magnitude, config.explosionForce);
    printf("[GRAVITY] accelerometer loop restarted%s%s\n",
           reason ? ": " : "", reason ?: "");
}

static bool settings_arm_gravitylite_for_background_start_locked(NSUserDefaults *d,
                                                                 const char *reason)
{
    if (![d boolForKey:kSettingsGravityLiteEnabled]) return false;
    bool stopped = gravitylite_stop_in_session();
    __sync_lock_test_and_set(&g_gravitylite_background_armed, 1);
    settings_mark_tweak_applied(kSettingsGravityLiteEnabled, YES);
    printf("[SETTINGS] Gravity Lite armed for background start%s%s stop=%d\n",
           reason ? ": " : "", reason ?: "", stopped);
    return true;
}

static BOOL settings_gravitylite_start_window_ready(const char *reason)
{
    (void)settings_refresh_screen_awake_state(reason ?: "gravity start");
    (void)settings_refresh_screen_lock_state(reason ?: "gravity start");
    return settings_screen_awake_cached() && !settings_screen_locked_cached();
}

static void settings_apply_armed_gravitylite_once_async(const char *reason)
{
    if (g_gravitylite_start_worker_running != 0) {
        printf("[SETTINGS] Gravity async dispatch already running\n");
        return;
    }
    if (g_gravitylite_background_armed == 0) {
        printf("[SETTINGS] Gravity armed check failed: wasArmed=0\n");
        return;
    }
    if (settings_cleanup_in_progress()) {
        printf("[SETTINGS] Gravity skipped: cleanup in progress\n");
        return;
    }
    if (__sync_lock_test_and_set(&g_gravitylite_start_worker_running, 1)) {
        printf("[SETTINGS] Gravity async dispatch already running\n");
        return;
    }
    printf("[SETTINGS] Gravity async dispatch starting%s%s\n",
           reason ? ": " : "", reason ?: "");

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @try {
            printf("[SETTINGS] Gravity async worker entered state=%ld armed=%d rcReady=%d\n",
                   (long)[UIApplication sharedApplication].applicationState,
                   g_gravitylite_background_armed,
                   g_springboard_rc_ready);
            uint64_t waitDeadline = settings_now_us() + 30000000ULL;
            while (!settings_cleanup_in_progress() &&
                   g_gravitylite_background_armed != 0 &&
                   [d boolForKey:kSettingsGravityLiteEnabled] &&
                   g_springboard_rc_ready &&
                   !settings_gravitylite_start_window_ready(reason ?: "gravity start")) {
                if (settings_now_us() >= waitDeadline) {
                    printf("[SETTINGS] Gravity async dispatch waiting for app exit timed out\n");
                    return;
                }
                usleep(50000);
            }

            if (settings_cleanup_in_progress()) return;
            if (![d boolForKey:kSettingsGravityLiteEnabled] || !g_springboard_rc_ready) return;
            if (!settings_gravitylite_start_window_ready(reason ?: "gravity start")) return;

            bool ok = false;
            GravityLiteConfig appliedConfig = {0};
            uint64_t applyDeadline = settings_now_us() + 2000000ULL;
            int attempt = 0;
            do {
                usleep(80000);
                printf("[SETTINGS] Gravity async apply waiting for RemoteCall lock attempt=%d armed=%d state=%ld\n",
                       attempt + 1,
                       g_gravitylite_background_armed,
                       (long)[UIApplication sharedApplication].applicationState);
                @synchronized (settings_rc_lock()) {
                    if (settings_cleanup_in_progress() ||
                        !g_springboard_rc_ready ||
                        ![d boolForKey:kSettingsGravityLiteEnabled] ||
                        !settings_gravitylite_start_window_ready(reason ?: "gravity start")) {
                        return;
                    }
                    if (!__sync_bool_compare_and_swap(&g_gravitylite_background_armed, 1, 0) && attempt == 0) {
                        printf("[SETTINGS] Gravity armed check failed inside worker: wasArmed=%d\n",
                               g_gravitylite_background_armed);
                        return;
                    }
                    appliedConfig = settings_gravitylite_config_from_defaults(d);
                    printf("[SETTINGS] Gravity async apply attempt=%d begin\n", attempt + 1);
                    ok = gravitylite_apply_in_session(appliedConfig);
                    printf("[SETTINGS] Gravity async apply attempt=%d result=%d\n", attempt + 1, ok);
                    settings_mark_tweak_applied(kSettingsGravityLiteEnabled,
                                                ok && [d boolForKey:kSettingsGravityLiteEnabled]);
                }
                if (ok) break;
                attempt++;
                usleep(120000);
            } while (settings_now_us() < applyDeadline);

            if (ok) {
                settings_start_gravity_motion(appliedConfig.magnitude,
                                              appliedConfig.explosionForce);
                log_user("[OK] Gravity Lite active.\n");
                cyanide_upload_log_milestone(@"gravity-lite-applied");
            } else {
                log_user("[WARN] Gravity Lite did not start cleanly.\n");
                cyanide_upload_log_milestone(@"gravity-lite-warning");
            }

            printf("[SETTINGS] Gravity Lite start%s%s result=%d\n",
                   reason ? ": " : "", reason ?: "", ok);
            settings_notify_package_queue_changed_async();
        } @finally {
            __sync_lock_release(&g_gravitylite_start_worker_running);
        }
    });
}

static NSString * const kThemerThemeNone = @"";
static NSString * const kThemerThemeBuiltinIOS6 = @"builtin-ios6";
static NSString * const kThemerThemeCustom = @"custom";

static NSString *settings_themer_builtin_ios6_path(void)
{
    return [[NSBundle mainBundle].bundlePath
        stringByAppendingPathComponent:@"Themes-iOS6.plist"];
}

static NSString *settings_themer_documents_theme_root(void)
{
    NSArray<NSString *> *docs = NSSearchPathForDirectoriesInDomains(
        NSDocumentDirectory, NSUserDomainMask, YES);
    if (docs.count == 0) return nil;
    return [docs.firstObject stringByAppendingPathComponent:@"Themes"];
}

static NSString *settings_themer_imported_theme_dir(void)
{
    NSString *root = settings_themer_documents_theme_root();
    return root ? [root stringByAppendingPathComponent:@"Imported"] : nil;
}

static NSString *settings_themer_imported_plist_path(void)
{
    NSString *root = settings_themer_documents_theme_root();
    return root ? [root stringByAppendingPathComponent:@"Imported.plist"] : nil;
}

static NSString *settings_themer_selected_theme_id(void)
{
    return [[NSUserDefaults standardUserDefaults] stringForKey:kSettingsThemerThemeID] ?: kThemerThemeNone;
}

BOOL settings_themer_has_selected_theme(void)
{
    NSString *theme = settings_themer_selected_theme_id();
    if ([theme isEqualToString:kThemerThemeBuiltinIOS6]) {
        return [[NSFileManager defaultManager] fileExistsAtPath:settings_themer_builtin_ios6_path()];
    }
    if ([theme isEqualToString:kThemerThemeCustom]) {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        NSString *path = [d stringForKey:kSettingsThemerCustomThemePath];
        BOOL isDir = NO;
        return path.length > 0 &&
               [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
    }
    return NO;
}

NSString *settings_themer_selected_theme_display_name(void)
{
    NSString *theme = settings_themer_selected_theme_id();
    if ([theme isEqualToString:kThemerThemeBuiltinIOS6]) return @"iOS 6 主题";
    if ([theme isEqualToString:kThemerThemeCustom]) {
        NSString *name = [[NSUserDefaults standardUserDefaults]
            stringForKey:kSettingsThemerCustomThemeName];
        return name.length > 0 ? name : @"导入的主题";
    }
    return @"无";
}

static NSDictionary<NSString *, NSData *> *settings_themer_load_plist_theme(NSString *plistPath)
{
    NSError *err = nil;
    NSData *raw = [NSData dataWithContentsOfFile:plistPath options:0 error:&err];
    if (!raw) {
        printf("[THEMER] resolve: failed to read plist err=%s\n",
               err.localizedDescription.UTF8String ?: "?");
        return nil;
    }
    id parsed = [NSPropertyListSerialization
        propertyListWithData:raw
                     options:NSPropertyListImmutable
                      format:NULL
                       error:&err];
    if (![parsed isKindOfClass:[NSDictionary class]]) {
        printf("[THEMER] resolve: plist parse failed err=%s\n",
               err.localizedDescription.UTF8String ?: "?");
        return nil;
    }
    NSDictionary *dict = (NSDictionary *)parsed;
    NSMutableDictionary<NSString *, NSData *> *out = [NSMutableDictionary dictionary];
    for (id key in dict) {
        id value = dict[key];
        if (![key isKindOfClass:NSString.class] ||
            ![value isKindOfClass:NSData.class] ||
            [(NSData *)value length] == 0) {
            continue;
        }
        out[key] = value;
    }
    printf("[THEMER] resolve: loaded plist theme entries=%lu size=%lu path=%s\n",
           (unsigned long)out.count,
           (unsigned long)raw.length,
           plistPath.UTF8String);
    return out;
}

// Per-bundle icon swap. A theme must be selected explicitly: either the bundled
// iOS 6 plist, or an imported folder/plist in Documents/Themes/.
static bool settings_apply_themer_from_defaults_locked(NSUserDefaults *d)
{
    if (![d boolForKey:kSettingsThemerEnabled]) {
        printf("[THEMER] resolve: toggle off, skipping\n");
        return false;
    }

    NSString *theme = settings_themer_selected_theme_id();
    if (![theme isEqualToString:kThemerThemeBuiltinIOS6] &&
        ![theme isEqualToString:kThemerThemeCustom]) {
        printf("[THEMER] resolve: no selected theme; install/apply blocked\n");
        log_user("[THEMER] Pick a theme in SnowBoard Lite settings before running.\n");
        return false;
    }

    if ([theme isEqualToString:kThemerThemeBuiltinIOS6]) {
        NSString *plistPath = settings_themer_builtin_ios6_path();
        if (![[NSFileManager defaultManager] fileExistsAtPath:plistPath]) {
            printf("[THEMER] resolve: bundled plist missing at %s\n",
                   plistPath.UTF8String);
            return false;
        }
        NSDictionary *dict = settings_themer_load_plist_theme(plistPath);
        return dict.count > 0 ? themer_apply_data_in_session(dict) : false;
    }

    NSString *path = [d stringForKey:kSettingsThemerCustomThemePath];
    BOOL isDir = NO;
    if (path.length == 0 ||
        ![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir]) {
        printf("[THEMER] resolve: selected custom theme missing path=%s\n",
               path.UTF8String ?: "");
        return false;
    }
    if (isDir) {
        printf("[THEMER] resolve: using imported folder %s\n", path.UTF8String);
        return themer_apply_in_session(path.fileSystemRepresentation);
    }
    NSDictionary *dict = settings_themer_load_plist_theme(path);
    return dict.count > 0 ? themer_apply_data_in_session(dict) : false;
}

static void settings_reset_sbc_defaults(void)
{
    if (!settings_device_supported()) {
        printf("[SETTINGS] SBC reset blocked: %s\n", settings_unsupported_message().UTF8String);
        return;
    }

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setBool:YES forKey:kSettingsSBCEnabled];
    [d setInteger:kSBCDefaultDockIcons forKey:kSettingsSBCDockIcons];
    [d setInteger:kSBCDefaultCols forKey:kSettingsSBCCols];
    [d setInteger:kSBCDefaultRows forKey:kSettingsSBCRows];
    [d setBool:kSBCDefaultHideLabels forKey:kSettingsSBCHideLabels];
    [d synchronize];

    printf("[SETTINGS] SBC reset defaults dock=%ld hs=%ldx%ld hideLabels=%d rcReady=%d\n",
           (long)kSBCDefaultDockIcons,
           (long)kSBCDefaultCols,
           (long)kSBCDefaultRows,
           kSBCDefaultHideLabels,
           g_springboard_rc_ready);

    if (!g_springboard_rc_ready) return;

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        @synchronized (settings_rc_lock()) {
            if (!g_springboard_rc_ready) return;
            bool ok = settings_apply_sbc_from_defaults_locked(d);
            settings_mark_tweak_applied(kSettingsSBCEnabled,
                                        ok && [d boolForKey:kSettingsSBCEnabled]);
            printf("[SETTINGS] SBC reset apply result=%d\n", ok);
        }
        settings_notify_package_queue_changed_async();
    });
}

static bool settings_apply_ota_disabled_body(BOOL disable)
{
    if (!settings_ensure_kexploit()) {
        printf("[OTA] kernel primitives were not acquired\n");
        log_user("[OTA] Failed: kernel primitives were not acquired. Please try running chain again.\n");
        return false;
    }

    bool ok = darksword_ota_set_disabled(disable);

    settings_notify_package_queue_changed_async();
    return ok;
}

BOOL settings_apply_ota_disabled(BOOL disable)
{
    if (__sync_lock_test_and_set(&g_settings_actions_running, 1)) {
        printf("[SETTINGS] actions already running; ignoring OTA request\n");
        log_user("[OTA] Another action is already running.\n");
        return NO;
    }
    @try {
        return settings_apply_ota_disabled_body(disable);
    } @finally {
        __sync_lock_release(&g_settings_actions_running);
    }
}

static void settings_run_ota_action(BOOL disable)
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        log_user("[OTA] %s OTA updates.\n", disable ? "Disabling" : "Enabling");
        bool ok = settings_apply_ota_disabled(disable);
        printf("[SETTINGS] OTA %s result=%d\n", disable ? "disable" : "enable", ok);
        if (ok) {
            log_user("[OK] OTA updates %s. Respring or reboot required for changes to take effect.\n",
                     disable ? "disabled" : "enabled");
        } else {
            log_user("[FAIL] OTA %s failed — see log for [OTA] lines (likely sandbox patch or disabled.plist write).\n",
                     disable ? "disable" : "enable");
        }
    });
}

static void settings_nano_set_defaults_values(NSInteger maxV, NSInteger minV, NSInteger minChipV, NSInteger minQuickV)
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setInteger:maxV     forKey:kSettingsNanoMaxPairing];
    [d setInteger:minV     forKey:kSettingsNanoMinPairing];
    [d setInteger:minChipV forKey:kSettingsNanoMinPairingChipID];
    [d setInteger:minQuickV forKey:kSettingsNanoMinQuickSwitch];
}

static void settings_nano_load_from_plist_into_defaults(BOOL logResult)
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    nano_registry_values values = {
        .max_pairing         = (int)[d integerForKey:kSettingsNanoMaxPairing],
        .min_pairing         = (int)[d integerForKey:kSettingsNanoMinPairing],
        .min_pairing_chip_id = (int)[d integerForKey:kSettingsNanoMinPairingChipID],
        .min_quick_switch    = (int)[d integerForKey:kSettingsNanoMinQuickSwitch],
    };
    bool present = false;
    bool ok = nano_registry_load(&values, &present);
    if (!ok) {
        if (logResult) log_user("[NANO] Could not read existing override plist (parse failure).\n");
        return;
    }
    [d setInteger:values.max_pairing         forKey:kSettingsNanoMaxPairing];
    [d setInteger:values.min_pairing         forKey:kSettingsNanoMinPairing];
    [d setInteger:values.min_pairing_chip_id forKey:kSettingsNanoMinPairingChipID];
    [d setInteger:values.min_quick_switch    forKey:kSettingsNanoMinQuickSwitch];
    if (logResult) {
        log_user(present
                 ? "[NANO] Loaded existing override: max=%d min=%d minChip=%d minQuick=%d.\n"
                 : "[NANO] No override present on device. Editor populated with current/seed values.\n",
                 values.max_pairing, values.min_pairing,
                 values.min_pairing_chip_id, values.min_quick_switch);
    }
}

// Synchronous entry point used by both the Settings UI buttons and the
// Installer's PackageQueue commit path. Logs progress to the in-app log so
// the InstallProgressViewController shows real lines during the apply.
BOOL settings_apply_nano_registry_now(BOOL apply)
{
    if (!settings_try_claim_actions_lock("NanoRegistry apply",
                                         "[NANO] Another action is already running.")) {
        return NO;
    }

    @try {
        if (!settings_ensure_kexploit()) {
            log_user("[NANO] Failed: kernel primitives were not acquired. Please try running chain again.\n");
            return NO;
        }

        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        bool ok;
        nano_registry_values values = {
            .max_pairing         = (int)[d integerForKey:kSettingsNanoMaxPairing],
            .min_pairing         = (int)[d integerForKey:kSettingsNanoMinPairing],
            .min_pairing_chip_id = (int)[d integerForKey:kSettingsNanoMinPairingChipID],
            .min_quick_switch    = (int)[d integerForKey:kSettingsNanoMinQuickSwitch],
        };
        if (apply) {
            log_user("[NANO] Applying pairing override max=%d min=%d minChip=%d minQuick=%d.\n",
                     values.max_pairing, values.min_pairing,
                     values.min_pairing_chip_id, values.min_quick_switch);
            ok = nano_registry_apply(&values);
            if (!ok) {
                log_user("[FAIL] NanoRegistry override write failed — see log for [NANO] lines.\n");
            }
        } else {
            log_user("[NANO] Removing pairing override keys.\n");
            ok = nano_registry_clear();
            if (!ok) {
                log_user("[FAIL] NanoRegistry override clear failed — see log for [NANO] lines.\n");
            }
        }

        // The file write above is necessary but not sufficient — cfprefsd owns
        // the in-memory cache that every CFPreferencesCopyValue call serves
        // from, and it will overwrite our plist with its stale cache the next
        // time any process writes to com.apple.NanoRegistry via the API. Push
        // the same values into cfprefsd's cache so the cache *has* our
        // override and future serializations preserve it.
        if (ok) {
            bool pushed = nano_registry_push_to_cfprefsd(&values, apply ? true : false);
            if (!pushed) {
                log_user("[NANO] cfprefsd push failed; on-disk override may be overwritten by cfprefsd's stale cache.\n");
            }
        }

        return ok ? YES : NO;
    } @finally {
        settings_release_actions_lock();
    }
}

BOOL settings_apply_call_recording_sound_disabled(BOOL disabled)
{
    if (!settings_try_claim_actions_lock("CallRec sound apply",
                                         "[CALLREC] Another action is already running.")) {
        return NO;
    }

    @try {
        if (!settings_ensure_kexploit()) {
            log_user("[CALLREC] Failed: kernel primitives were not acquired. Please try running chain again.\n");
            return NO;
        }
        return call_recording_sound_set_disabled(disabled) ? YES : NO;
    } @finally {
        settings_release_actions_lock();
    }
}

BOOL settings_apply_hide_home_bar_hidden(BOOL hidden)
{
    if (!settings_try_claim_actions_lock("Hide Home Bar apply",
                                         "[HOME BAR] Another action is already running.")) {
        return NO;
    }

    @try {
        if (!hidden) {
            return hide_home_bar_restore() ? YES : NO;
        }
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        if (!settings_ensure_kexploit()) {
            log_user("[HOME BAR] Failed: kernel primitives were not acquired. Please try running chain again.\n");
            return NO;
        }
        BOOL ok = hide_home_bar_apply() ? YES : NO;
        if (ok) settings_note_hide_home_bar_materialkit_zero_active(d);
        return ok;
    } @finally {
        settings_release_actions_lock();
    }
}

static void settings_run_nano_apply_action(void)
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        (void)settings_apply_nano_registry_now(YES);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:kSettingsActionsDidCompleteNotification
                              object:nil];
        });
    });
}

static void settings_run_nano_clear_action(void)
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        (void)settings_apply_nano_registry_now(NO);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:kSettingsActionsDidCompleteNotification
                              object:nil];
        });
    });
}

static void settings_run_nano_probe_action(void)
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if (!settings_try_claim_actions_lock("NanoRegistry probe",
                                             "[NANO-PROBE] Another action is already running.")) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:kSettingsActionsDidCompleteNotification
                                  object:nil];
            });
            return;
        }
        @try {
            if (!settings_ensure_kexploit()) {
                log_user("[NANO-PROBE] Failed: kernel primitives were not acquired. Please try running chain again.\n");
            } else {
                (void)nano_registry_probe_pairing_assets();
            }
        } @finally {
            settings_release_actions_lock();
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:kSettingsActionsDidCompleteNotification
                              object:nil];
        });
    });
}

static void settings_run_nano_steer_action(void)
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if (!settings_try_claim_actions_lock("NanoRegistry steer",
                                             "[NANO-STEER] Another action is already running.")) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:kSettingsActionsDidCompleteNotification
                                  object:nil];
            });
            return;
        }
        @try {
            if (!settings_ensure_kexploit()) {
                log_user("[NANO-STEER] Failed: kernel primitives were not acquired. Please try running chain again.\n");
            } else {
                (void)nano_registry_steer_new_watch_product_alias();
            }
        } @finally {
            settings_release_actions_lock();
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:kSettingsActionsDidCompleteNotification
                              object:nil];
        });
    });
}

static void settings_run_nano_seed_action(void)
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if (!settings_try_claim_actions_lock("NanoRegistry seed",
                                             "[NANO-SEED] Another action is already running.")) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:kSettingsActionsDidCompleteNotification
                                  object:nil];
            });
            return;
        }
        @try {
            if (!settings_ensure_kexploit()) {
                log_user("[NANO-SEED] Failed: kernel primitives were not acquired. Please try running chain again.\n");
            } else {
                NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
                nano_registry_values values = {
                    .max_pairing         = (int)[d integerForKey:kSettingsNanoMaxPairing],
                    .min_pairing         = (int)[d integerForKey:kSettingsNanoMinPairing],
                    .min_pairing_chip_id = (int)[d integerForKey:kSettingsNanoMinPairingChipID],
                    .min_quick_switch    = (int)[d integerForKey:kSettingsNanoMinQuickSwitch],
                };
                bool ok = nano_registry_seed_current_phone_compatibility_index(values.max_pairing);
                if (ok) {
                    (void)nano_registry_push_to_cfprefsd(&values, true);
                }
            }
        } @finally {
            settings_release_actions_lock();
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:kSettingsActionsDidCompleteNotification
                              object:nil];
        });
    });
}

static void settings_start_statbar_live_loop(void)
{
    if (!settings_device_supported()) return;
    if (settings_cleanup_in_progress()) return;

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (![d boolForKey:kSettingsStatBarEnabled]) return;

    if (__sync_lock_test_and_set(&g_statbar_live_running, 1)) {
        // Log-once for the process lifetime; further "already running" hits
        // during foreground/background lifecycle churn are pure noise.
        static volatile int loggedAlready = 0;
        if (__sync_bool_compare_and_swap(&loggedAlready, 0, 1)) {
            printf("[SETTINGS] StatBar live loop already running\n");
        }
        return;
    }

    if (settings_cleanup_in_progress()) {
        __sync_lock_release(&g_statbar_live_running);
        return;
    }

    g_statbar_live_stop_requested = 0;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSUInteger tick = 0;
        NSUInteger failures = 0;
        uint64_t nextTickUS = settings_now_us();
        BOOL pausedForSleep = NO;

        printf("[SETTINGS] StatBar live loop started interval=%uus background=%uus max=%lu\n",
               kStatBarLiveIntervalUS,
               settings_statbar_refresh_rate_us(),
               (unsigned long)kStatBarLiveMaxTicks);
        cyanide_upload_log_milestone(@"statbar-live-started");

        @try {
            while ([d boolForKey:kSettingsStatBarEnabled] &&
                   !settings_cleanup_in_progress() &&
                   !g_statbar_live_stop_requested &&
                   tick < kStatBarLiveMaxTicks) {
                useconds_t intervalUS = settings_statbar_live_interval_us();
                if (!settings_statbar_screen_awake()) {
                    if (!pausedForSleep) {
                        pausedForSleep = YES;
                        printf("[SETTINGS] StatBar paused while screen is asleep\n");
                    }
                    settings_live_loop_sleep_interruptible(0,
                                                           intervalUS,
                                                           &g_statbar_live_stop_requested);
                    nextTickUS = settings_now_us();
                    continue;
                }
                if (pausedForSleep) {
                    pausedForSleep = NO;
                    printf("[SETTINGS] StatBar resumed after screen wake\n");
                }

                uint64_t tickStartUS = settings_now_us();
                bool ok = false;

                @synchronized (settings_rc_lock()) {
                    if (g_statbar_live_stop_requested) break;
                    if (!g_springboard_rc_ready) {
                        printf("[SETTINGS] StatBar loop has no SpringBoard RemoteCall session\n");
                        failures++;
                        break;
                    }
                    ok = statbar_apply_in_session([d boolForKey:kSettingsStatBarCelsius],
                                                  [d boolForKey:kSettingsStatBarShowNet],
                                                  [d boolForKey:kSettingsStatBarShowCPU],
                                                  [d boolForKey:kSettingsStatBarShowLabels],
                                                  [d boolForKey:kSettingsStatBarNetworkOnly]);
                }

                if (tick == 0) {
                    printf("[SETTINGS] StatBar result=%d\n", ok);
                    cyanide_upload_log_milestone(ok ? @"statbar-live-first-ok" : @"statbar-live-first-failed");
                }
                if (ok) {
                    failures = 0;
                } else {
                    failures++;
                    printf("[SETTINGS] StatBar tick failed tick=%lu failures=%lu\n",
                           (unsigned long)tick, (unsigned long)failures);
                    if (failures >= settings_live_failure_limit(3)) break;
                }

                tick++;
                if (![d boolForKey:kSettingsStatBarEnabled] ||
                    g_statbar_live_stop_requested ||
                    tick >= kStatBarLiveMaxTicks) break;

                uint64_t nowUS = settings_now_us();
                uint64_t elapsedUS = (tickStartUS != 0 && nowUS >= tickStartUS) ? (nowUS - tickStartUS) : 0;
                if (nextTickUS != 0) {
                    intervalUS = settings_statbar_live_interval_us();
                    nextTickUS += intervalUS;
                    if (nowUS < nextTickUS) {
                        uint64_t sleepUS = nextTickUS - nowUS;
                        if (settings_should_log_statbar_tick(tick - 1)) {
                            printf("[SETTINGS] StatBar tick=%lu elapsed=%lluus sleep=%lluus mode=%s\n",
                                   (unsigned long)(tick - 1),
                                   elapsedUS,
                                   sleepUS,
                                   settings_live_context());
                        }
                        settings_live_loop_sleep_interruptible(nextTickUS,
                                                               (useconds_t)sleepUS,
                                                               &g_statbar_live_stop_requested);
                    } else {
                        uint64_t overrunUS = nowUS - nextTickUS;
                        if (settings_should_log_statbar_tick(tick - 1)) {
                            printf("[SETTINGS] StatBar tick=%lu elapsed=%lluus overrun=%lluus mode=%s\n",
                                   (unsigned long)(tick - 1),
                                   elapsedUS,
                                   overrunUS,
                                   settings_live_context());
                        }
                        nextTickUS = nowUS;
                    }
                } else {
                    settings_live_loop_sleep_interruptible(0,
                                                           settings_statbar_live_interval_us(),
                                                           &g_statbar_live_stop_requested);
                }
            }
        } @finally {
            printf("[SETTINGS] StatBar live loop exited ticks=%lu enabled=%d failures=%lu stop=%d\n",
                   (unsigned long)tick,
                   [d boolForKey:kSettingsStatBarEnabled],
                   (unsigned long)failures,
                   g_statbar_live_stop_requested);
            if (![d boolForKey:kSettingsStatBarEnabled] || g_statbar_live_stop_requested || failures > 0) {
                settings_end_statbar_background_task_async("live loop exited");
            }
            if (failures > 0)
                cyanide_upload_log_milestone(@"statbar-live-exited-failed");
            __sync_lock_release(&g_statbar_live_running);
        }
    });
}

static void settings_apply_statbar_once_async(const char *reason)
{
    if (!settings_device_supported()) return;
    if (settings_cleanup_in_progress()) return;

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (![d boolForKey:kSettingsStatBarEnabled] || !g_springboard_rc_ready) return;
    if (g_statbar_live_running) return;

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if (settings_cleanup_in_progress()) return;
        bool ok = false;
        (void)settings_refresh_screen_awake_state(reason ?: "statbar apply");
        if (!settings_screen_awake_cached()) {
            printf("[SETTINGS] StatBar lifecycle apply%s%s skipped: screen asleep\n",
                   reason ? ": " : "", reason ?: "");
            settings_start_statbar_live_loop();
            return;
        }
        @synchronized (settings_rc_lock()) {
            if (settings_cleanup_in_progress() ||
                ![d boolForKey:kSettingsStatBarEnabled] ||
                !g_springboard_rc_ready) return;
            ok = statbar_apply_in_session([d boolForKey:kSettingsStatBarCelsius],
                                          [d boolForKey:kSettingsStatBarShowNet],
                                          [d boolForKey:kSettingsStatBarShowCPU],
                                          [d boolForKey:kSettingsStatBarShowLabels],
                                          [d boolForKey:kSettingsStatBarNetworkOnly]);
        }
        // Only log lifecycle applies that change result; a clean success on
        // every foreground/background flip is noise.
        static volatile int lastResult = -1;
        int now = ok ? 1 : 0;
        if (now != lastResult) {
            lastResult = now;
            printf("[SETTINGS] StatBar lifecycle apply%s%s result=%d\n",
                   reason ? ": " : "", reason ?: "", ok);
        }
        settings_start_statbar_live_loop();
    });
}

static void settings_start_nsbar_live_loop(void)
{
    if (!settings_device_supported() || settings_cleanup_in_progress()) return;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (![d boolForKey:kSettingsNSBarEnabled] || !g_springboard_rc_ready) return;

    if (__sync_lock_test_and_set(&g_nsbar_live_running, 1)) return;
    g_nsbar_live_stop_requested = 0;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSUInteger tick = 0;
        NSUInteger failures = 0;
        BOOL pausedForSleep = NO;
        @try {
            while ([d boolForKey:kSettingsNSBarEnabled] &&
                   !settings_cleanup_in_progress() &&
                   !g_nsbar_live_stop_requested &&
                   tick < kNSBarLiveMaxTicks) {
                useconds_t intervalUS = settings_live_interval(kNSBarLiveIntervalUS,
                                                               kNSBarLiveBackgroundIntervalUS);
                if (!settings_statbar_screen_awake()) {
                    if (!pausedForSleep) {
                        pausedForSleep = YES;
                        printf("[SETTINGS] NSBar paused while screen is asleep\n");
                    }
                    settings_live_loop_sleep_interruptible(0,
                                                           intervalUS,
                                                           &g_nsbar_live_stop_requested);
                    continue;
                }
                if (pausedForSleep) {
                    pausedForSleep = NO;
                    printf("[SETTINGS] NSBar resumed after screen wake\n");
                }

                bool ok = false;
                @synchronized (settings_rc_lock()) {
                    if (settings_cleanup_in_progress() ||
                        ![d boolForKey:kSettingsNSBarEnabled] ||
                        !g_springboard_rc_ready) break;
                    ok = nsbar_apply_in_session((NSBarPosition)[d integerForKey:kSettingsNSBarPosition]);
                    settings_mark_tweak_applied(kSettingsNSBarEnabled,
                                                ok && [d boolForKey:kSettingsNSBarEnabled]);
                }
                if (tick == 0 || !ok) {
                    printf("[SETTINGS] NSBar live tick=%lu result=%d\n",
                           (unsigned long)tick, ok);
                }
                failures = ok ? 0 : failures + 1;
                if (failures >= settings_live_failure_limit(3)) break;
                tick++;
                settings_live_loop_sleep_interruptible(0,
                    intervalUS,
                    &g_nsbar_live_stop_requested);
            }
        } @finally {
            printf("[SETTINGS] NSBar live loop exited ticks=%lu enabled=%d failures=%lu stop=%d\n",
                   (unsigned long)tick,
                   [d boolForKey:kSettingsNSBarEnabled],
                   (unsigned long)failures,
                   g_nsbar_live_stop_requested);
            __sync_lock_release(&g_nsbar_live_running);
        }
    });
}

static void settings_apply_nsbar_once_async(const char *reason)
{
    if (!settings_device_supported() || settings_cleanup_in_progress()) return;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (![d boolForKey:kSettingsNSBarEnabled] || !g_springboard_rc_ready) return;
    if (g_nsbar_live_running) return;

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        bool ok = false;
        (void)settings_refresh_screen_awake_state(reason ?: "nsbar apply");
        if (!settings_screen_awake_cached()) {
            printf("[SETTINGS] NSBar lifecycle apply%s%s skipped: screen asleep\n",
                   reason ? ": " : "", reason ?: "");
            settings_start_nsbar_live_loop();
            return;
        }
        @synchronized (settings_rc_lock()) {
            if (settings_cleanup_in_progress() ||
                ![d boolForKey:kSettingsNSBarEnabled] ||
                !g_springboard_rc_ready) return;
            ok = nsbar_apply_in_session((NSBarPosition)[d integerForKey:kSettingsNSBarPosition]);
            settings_mark_tweak_applied(kSettingsNSBarEnabled,
                                        ok && [d boolForKey:kSettingsNSBarEnabled]);
        }
        printf("[SETTINGS] NSBar lifecycle apply%s%s result=%d\n",
               reason ? ": " : "", reason ?: "", ok);
        settings_start_nsbar_live_loop();
        settings_notify_package_queue_changed_async();
    });
}

static void settings_start_nicebarlite_live_loop(void)
{
    if (!settings_device_supported() || settings_cleanup_in_progress()) return;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (![d boolForKey:kSettingsNiceBarLiteEnabled] || !g_springboard_rc_ready) return;

    if (__sync_lock_test_and_set(&g_nicebarlite_live_running, 1)) return;
    g_nicebarlite_live_stop_requested = 0;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSUInteger tick = 0;
        NSUInteger failures = 0;
        BOOL pausedForSleep = NO;
        @try {
            while ([d boolForKey:kSettingsNiceBarLiteEnabled] &&
                   !settings_cleanup_in_progress() &&
                   !g_nicebarlite_live_stop_requested &&
                   tick < kNiceBarLiteLiveMaxTicks) {
                useconds_t intervalUS = settings_live_interval(kNiceBarLiteLiveIntervalUS,
                                                               kNiceBarLiteLiveBackgroundIntervalUS);
                if (!settings_statbar_screen_awake()) {
                    if (!pausedForSleep) {
                        pausedForSleep = YES;
                        printf("[SETTINGS] NiceBar Lite paused while screen is asleep\n");
                    }
                    settings_live_loop_sleep_interruptible(0,
                                                           intervalUS,
                                                           &g_nicebarlite_live_stop_requested);
                    continue;
                }
                if (pausedForSleep) {
                    pausedForSleep = NO;
                    printf("[SETTINGS] NiceBar Lite resumed after screen wake\n");
                }

                bool ok = false;
                settings_nicebar_refresh_weather_if_needed(NO, nil);
                @synchronized (settings_rc_lock()) {
                    if (settings_cleanup_in_progress() ||
                        ![d boolForKey:kSettingsNiceBarLiteEnabled] ||
                        !g_springboard_rc_ready) break;
                    ok = settings_apply_nicebarlite_from_defaults_locked(d);
                    settings_mark_tweak_applied(kSettingsNiceBarLiteEnabled,
                                                ok && [d boolForKey:kSettingsNiceBarLiteEnabled]);
                }
                if (tick == 0 || !ok) {
                    printf("[SETTINGS] NiceBar Lite live tick=%lu result=%d\n",
                           (unsigned long)tick, ok);
                }
                failures = ok ? 0 : failures + 1;
                if (failures >= settings_live_failure_limit(3)) break;
                tick++;
                settings_live_loop_sleep_interruptible(0,
                    intervalUS,
                    &g_nicebarlite_live_stop_requested);
            }
        } @finally {
            printf("[SETTINGS] NiceBar Lite live loop exited ticks=%lu enabled=%d failures=%lu stop=%d\n",
                   (unsigned long)tick,
                   [d boolForKey:kSettingsNiceBarLiteEnabled],
                   (unsigned long)failures,
                   g_nicebarlite_live_stop_requested);
            __sync_lock_release(&g_nicebarlite_live_running);
        }
    });
}

static void settings_apply_nicebarlite_once_async(const char *reason)
{
    if (!settings_device_supported() || settings_cleanup_in_progress()) return;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (![d boolForKey:kSettingsNiceBarLiteEnabled] || !g_springboard_rc_ready) return;
    if (g_nicebarlite_live_running) return;

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        bool ok = false;
        settings_nicebar_refresh_weather_if_needed(!settings_nicebar_has_resolved_weather(d), nil);
        (void)settings_refresh_screen_awake_state(reason ?: "nicebarlite apply");
        if (!settings_screen_awake_cached()) {
            printf("[SETTINGS] NiceBar Lite lifecycle apply%s%s skipped: screen asleep\n",
                   reason ? ": " : "", reason ?: "");
            settings_start_nicebarlite_live_loop();
            return;
        }
        @synchronized (settings_rc_lock()) {
            if (settings_cleanup_in_progress() ||
                ![d boolForKey:kSettingsNiceBarLiteEnabled] ||
                !g_springboard_rc_ready) return;
            ok = settings_apply_nicebarlite_from_defaults_locked(d);
            settings_mark_tweak_applied(kSettingsNiceBarLiteEnabled,
                                        ok && [d boolForKey:kSettingsNiceBarLiteEnabled]);
        }
        printf("[SETTINGS] NiceBar Lite lifecycle apply%s%s result=%d\n",
               reason ? ": " : "", reason ?: "", ok);
        settings_start_nicebarlite_live_loop();
        settings_notify_package_queue_changed_async();
    });
}

static BOOL settings_livewp_should_play(void)
{
    (void)settings_refresh_screen_awake_state("LiveWP playback check");
    return settings_screen_awake_cached();
}

static void settings_start_livewp_live_loop(void)
{
    if (!settings_device_supported() || settings_cleanup_in_progress()) return;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (![d boolForKey:kSettingsLiveWPEnabled] || !g_springboard_rc_ready) return;

    if (__sync_lock_test_and_set(&g_livewp_live_running, 1)) return;
    g_livewp_live_stop_requested = 0;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSUInteger tick = 0;
        @try {
            while ([d boolForKey:kSettingsLiveWPEnabled] &&
                   !settings_cleanup_in_progress() &&
                   !g_livewp_live_stop_requested &&
                   tick < kLiveWPLiveMaxTicks) {
                @synchronized (settings_rc_lock()) {
                    if (settings_cleanup_in_progress() ||
                        ![d boolForKey:kSettingsLiveWPEnabled] ||
                        !g_springboard_rc_ready) break;
                    if (settings_livewp_should_play()) {
                        (void)livewp_resume_in_session();
                        (void)livewp_repair_in_session();
                    } else {
                        (void)livewp_pause_in_session();
                    }
                }
                tick++;
                settings_live_loop_sleep_interruptible(0,
                    settings_live_interval(kLiveWPLiveIntervalUS, kLiveWPLiveBackgroundIntervalUS),
                    &g_livewp_live_stop_requested);
            }
        } @finally {
            printf("[SETTINGS] LiveWP live loop exited ticks=%lu enabled=%d stop=%d\n",
                   (unsigned long)tick,
                   [d boolForKey:kSettingsLiveWPEnabled],
                   g_livewp_live_stop_requested);
            __sync_lock_release(&g_livewp_live_running);
        }
    });
}

static void settings_pause_livewp_for_sleep_async(const char *reason)
{
    if (!settings_device_supported() || settings_cleanup_in_progress()) return;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (![d boolForKey:kSettingsLiveWPEnabled] || !g_springboard_rc_ready) return;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        @synchronized (settings_rc_lock()) {
            if (settings_cleanup_in_progress() ||
                ![d boolForKey:kSettingsLiveWPEnabled] ||
                !g_springboard_rc_ready) return;
            if (settings_livewp_should_play()) return;
            bool ok = livewp_pause_in_session();
            printf("[SETTINGS] LiveWP pause%s%s result=%d\n",
                   reason ? ": " : "", reason ?: "", ok);
        }
    });
}

static void settings_resume_livewp_after_wake_async(const char *reason)
{
    if (!settings_device_supported() || settings_cleanup_in_progress()) return;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (![d boolForKey:kSettingsLiveWPEnabled] || !g_springboard_rc_ready) return;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        bool ok = false;
        @synchronized (settings_rc_lock()) {
            if (settings_cleanup_in_progress() ||
                ![d boolForKey:kSettingsLiveWPEnabled] ||
                !g_springboard_rc_ready) return;
            if (!settings_livewp_should_play()) {
                (void)livewp_pause_in_session();
                return;
            }
            ok = livewp_resume_in_session();
            if (ok) settings_mark_tweak_applied(kSettingsLiveWPEnabled, YES);
        }
        printf("[SETTINGS] LiveWP resume%s%s result=%d\n",
               reason ? ": " : "", reason ?: "", ok);
        if (ok) settings_start_livewp_live_loop();
        settings_notify_package_queue_changed_async();
    });
}

static void settings_start_rssi_live_loop(void)
{
    if (!settings_device_supported()) return;
    if (settings_cleanup_in_progress()) return;

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (!settings_rssi_install_allowed()) return;
    if (![d boolForKey:kSettingsRSSIDisplayEnabled]) return;
    if (!g_springboard_rc_ready) return;

    if (__sync_lock_test_and_set(&g_rssi_live_running, 1)) {
        static volatile int loggedAlready = 0;
        if (__sync_bool_compare_and_swap(&loggedAlready, 0, 1)) {
            printf("[SETTINGS] RSSI live loop already running\n");
        }
        return;
    }

    if (settings_cleanup_in_progress()) {
        __sync_lock_release(&g_rssi_live_running);
        return;
    }

    g_rssi_live_stop_requested = 0;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSUInteger tick = 0;
        NSUInteger failures = 0;
        uint64_t nextTickUS = settings_now_us();
        BOOL pausedForSleep = NO;

        printf("[SETTINGS] RSSI live loop started interval=%uus background=%uus max=%lu\n",
               kRSSILiveIntervalUS,
               kRSSILiveBackgroundIntervalUS,
               (unsigned long)kRSSILiveMaxTicks);
        cyanide_upload_log_milestone(@"rssi-live-started");

        @try {
            while ([d boolForKey:kSettingsRSSIDisplayEnabled] &&
                   !settings_cleanup_in_progress() &&
                   !g_rssi_live_stop_requested &&
                   tick < kRSSILiveMaxTicks) {
                useconds_t intervalUS = settings_live_interval(kRSSILiveIntervalUS,
                                                               kRSSILiveBackgroundIntervalUS);
                if (!settings_statbar_screen_awake()) {
                    if (!pausedForSleep) {
                        pausedForSleep = YES;
                        printf("[SETTINGS] RSSI paused while screen is asleep\n");
                    }
                    settings_live_loop_sleep_interruptible(0,
                                                           intervalUS,
                                                           &g_rssi_live_stop_requested);
                    nextTickUS = settings_now_us();
                    continue;
                }
                if (pausedForSleep) {
                    pausedForSleep = NO;
                    printf("[SETTINGS] RSSI resumed after screen wake\n");
                }

                uint64_t tickStartUS = settings_now_us();
                bool ok = false;

                @synchronized (settings_rc_lock()) {
                    if (g_rssi_live_stop_requested) break;
                    if (!g_springboard_rc_ready) {
                        printf("[SETTINGS] RSSI loop has no SpringBoard RemoteCall session\n");
                        failures++;
                        break;
                    }
                    ok = rssidisplay_apply_in_session([d boolForKey:kSettingsRSSIDisplayWifi],
                                                      [d boolForKey:kSettingsRSSIDisplayCell]);
                }

                uint64_t tickEndUS = settings_now_us();
                if (tick == 0) {
                    uint64_t elapsedUS = tickEndUS >= tickStartUS ? tickEndUS - tickStartUS : 0;
                    printf("[SETTINGS] RSSI first tick result=%d elapsed=%lluus\n",
                           ok,
                           (unsigned long long)elapsedUS);
                    cyanide_upload_log_milestone(ok ? @"rssi-live-first-ok" : @"rssi-live-first-failed");
                }
                if (ok) {
                    failures = 0;
                } else {
                    failures++;
                    printf("[SETTINGS] RSSI tick failed tick=%lu failures=%lu\n",
                           (unsigned long)tick, (unsigned long)failures);
                    if (failures >= settings_live_failure_limit(5)) break;
                }

                tick++;
                if (![d boolForKey:kSettingsRSSIDisplayEnabled] ||
                    g_rssi_live_stop_requested ||
                    tick >= kRSSILiveMaxTicks) break;

                uint64_t nowUS = tickEndUS;
                if (nextTickUS != 0) {
                    intervalUS = settings_live_interval(kRSSILiveIntervalUS,
                                                        kRSSILiveBackgroundIntervalUS);
                    nextTickUS += intervalUS;
                    if (nowUS < nextTickUS) {
                        settings_live_loop_sleep_interruptible(nextTickUS,
                                                               (useconds_t)(nextTickUS - nowUS),
                                                               &g_rssi_live_stop_requested);
                    } else {
                        nextTickUS = nowUS;
                    }
                } else {
                    settings_live_loop_sleep_interruptible(0,
                                                           settings_live_interval(kRSSILiveIntervalUS,
                                                                                  kRSSILiveBackgroundIntervalUS),
                                                           &g_rssi_live_stop_requested);
                }
            }
        } @finally {
            printf("[SETTINGS] RSSI live loop exited ticks=%lu enabled=%d failures=%lu stop=%d\n",
                   (unsigned long)tick,
                   [d boolForKey:kSettingsRSSIDisplayEnabled],
                   (unsigned long)failures,
                   g_rssi_live_stop_requested);
            if (failures > 0)
                cyanide_upload_log_milestone(@"rssi-live-exited-failed");
            __sync_lock_release(&g_rssi_live_running);
        }
    });
}

static void settings_apply_rssi_once_async(const char *reason)
{
    if (!settings_device_supported()) return;
    if (settings_cleanup_in_progress()) return;

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (!settings_rssi_install_allowed()) return;
    if (![d boolForKey:kSettingsRSSIDisplayEnabled] || !g_springboard_rc_ready) return;
    if (g_rssi_live_running) return;

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if (settings_cleanup_in_progress()) return;
        bool ok = false;
        (void)settings_refresh_screen_awake_state(reason ?: "rssi apply");
        if (!settings_screen_awake_cached()) {
            printf("[SETTINGS] RSSI lifecycle apply%s%s skipped: screen asleep\n",
                   reason ? ": " : "", reason ?: "");
            settings_start_rssi_live_loop();
            return;
        }
        @synchronized (settings_rc_lock()) {
            if (settings_cleanup_in_progress() ||
                ![d boolForKey:kSettingsRSSIDisplayEnabled] ||
                !g_springboard_rc_ready) return;
            ok = rssidisplay_apply_in_session([d boolForKey:kSettingsRSSIDisplayWifi],
                                              [d boolForKey:kSettingsRSSIDisplayCell]);
        }
        printf("[SETTINGS] RSSI lifecycle apply%s%s result=%d\n",
               reason ? ": " : "", reason ?: "", ok);
        settings_start_rssi_live_loop();
    });
}

static void settings_start_axonlite_live_loop(void)
{
    if (!settings_device_supported()) return;
    if (settings_cleanup_in_progress()) return;

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (![d boolForKey:kSettingsAxonLiteEnabled]) return;
    if (!g_springboard_rc_ready) return;

    if (__sync_lock_test_and_set(&g_axonlite_live_running, 1)) {
        static volatile int loggedAlready = 0;
        if (__sync_bool_compare_and_swap(&loggedAlready, 0, 1)) {
            printf("[SETTINGS] Axon Lite live loop already running\n");
        }
        return;
    }

    if (settings_cleanup_in_progress()) {
        __sync_lock_release(&g_axonlite_live_running);
        return;
    }

    g_axonlite_live_stop_requested = 0;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSUInteger tick = 0;
        NSUInteger failures = 0;
        uint64_t nextTickUS = settings_now_us();
        BOOL pausedForUnavailableScreen = NO;

        printf("[SETTINGS] Axon Lite live loop started interval=%uus background=%uus max=%lu\n",
               kAxonLiteLiveIntervalUS,
               kAxonLiteLiveBackgroundIntervalUS,
               (unsigned long)kAxonLiteLiveMaxTicks);
        cyanide_upload_log_milestone(@"axon-lite-live-started");

        @try {
            settings_live_loop_sleep_interruptible(0,
                                                   settings_live_interval(kAxonLiteLiveIntervalUS,
                                                                          kAxonLiteLiveBackgroundIntervalUS),
                                                   &g_axonlite_live_stop_requested);
            nextTickUS = settings_now_us();
            while ([d boolForKey:kSettingsAxonLiteEnabled] &&
                   !settings_cleanup_in_progress() &&
                   !g_axonlite_live_stop_requested &&
                   tick < kAxonLiteLiveMaxTicks) {
                useconds_t intervalUS = settings_live_interval(kAxonLiteLiveIntervalUS,
                                                               kAxonLiteLiveBackgroundIntervalUS);
                // While locked/asleep, CoverSheet churn is exactly where Axon
                // can put sustained pressure on SB. Pause locally without
                // messaging SB so the existing Axon roster/filter state is
                // still there when the screen wakes. The initial cache pass
                // is exempt — interrupting it leaves SB with requests we've
                // already removed but no segmented-control polling to bring
                // them back.
                if (!settings_axonlite_can_poll_springboard() &&
                    axonlite_initial_cache_ready()) {
                    if (!pausedForUnavailableScreen) {
                        pausedForUnavailableScreen = YES;
                        printf("[SETTINGS] Axon Lite paused while %s\n",
                               settings_axonlite_pause_reason());
                    }
                    settings_live_loop_sleep_interruptible(0,
                                                           intervalUS,
                                                           &g_axonlite_live_stop_requested);
                    nextTickUS = settings_now_us();
                    continue;
                }
                if (pausedForUnavailableScreen) {
                    pausedForUnavailableScreen = NO;
                    printf("[SETTINGS] Axon Lite resumed after screen unlock/wake\n");
                }

                uint64_t tickStartUS = settings_now_us();
                bool ok = false;

                @synchronized (settings_rc_lock()) {
                    if (g_axonlite_live_stop_requested) break;
                    if (!g_springboard_rc_ready) {
                        printf("[SETTINGS] Axon Lite loop has no SpringBoard RemoteCall session\n");
                        failures++;
                        break;
                    }
                    if (!settings_axonlite_can_poll_springboard() &&
                        axonlite_initial_cache_ready()) {
                        printf("[SETTINGS] Axon Lite tick skipped inside lock: %s\n",
                               settings_axonlite_pause_reason());
                        nextTickUS = settings_now_us();
                        continue;
                    }
                    ok = axonlite_apply_in_session();
                }

                if (tick == 0) {
                    printf("[SETTINGS] Axon Lite result=%d\n", ok);
                    cyanide_upload_log_milestone(ok ? @"axon-lite-live-first-ok" : @"axon-lite-live-first-failed");
                }
                if (ok) {
                    failures = 0;
                } else {
                    failures++;
                    printf("[SETTINGS] Axon Lite tick failed tick=%lu failures=%lu\n",
                           (unsigned long)tick, (unsigned long)failures);
                    if (failures >= settings_live_failure_limit(3)) break;
                }

                tick++;
                if (![d boolForKey:kSettingsAxonLiteEnabled] ||
                    g_axonlite_live_stop_requested ||
                    tick >= kAxonLiteLiveMaxTicks) break;

                uint64_t nowUS = settings_now_us();
                if (nextTickUS != 0) {
                    intervalUS = settings_live_interval(kAxonLiteLiveIntervalUS,
                                                        kAxonLiteLiveBackgroundIntervalUS);
                    nextTickUS += intervalUS;
                    if (nowUS < nextTickUS) {
                        settings_live_loop_sleep_interruptible(nextTickUS,
                                                               (useconds_t)(nextTickUS - nowUS),
                                                               &g_axonlite_live_stop_requested);
                    } else {
                        nextTickUS = nowUS;
                    }
                } else {
                    settings_live_loop_sleep_interruptible(0,
                                                           settings_live_interval(kAxonLiteLiveIntervalUS,
                                                                                  kAxonLiteLiveBackgroundIntervalUS),
                                                           &g_axonlite_live_stop_requested);
                }

                uint64_t elapsedUS = tickStartUS != 0 && nowUS >= tickStartUS ? nowUS - tickStartUS : 0;
                if (tick == 1) {
                    printf("[SETTINGS] Axon Lite tick=0 elapsed=%lluus\n", elapsedUS);
                }
            }
        } @finally {
            printf("[SETTINGS] Axon Lite live loop exited ticks=%lu enabled=%d failures=%lu stop=%d\n",
                   (unsigned long)tick,
                   [d boolForKey:kSettingsAxonLiteEnabled],
                   (unsigned long)failures,
                   g_axonlite_live_stop_requested);
            if (failures > 0)
                cyanide_upload_log_milestone(@"axon-lite-live-exited-failed");
            __sync_lock_release(&g_axonlite_live_running);
        }
    });
}

static void settings_start_typebanner_live_loop(void)
{
    if (!settings_device_supported()) return;
    if (settings_cleanup_in_progress()) return;

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (![d boolForKey:kSettingsTypeBannerEnabled]) return;

    if (__sync_lock_test_and_set(&g_typebanner_live_running, 1)) {
        static volatile int loggedAlready = 0;
        if (__sync_bool_compare_and_swap(&loggedAlready, 0, 1)) {
            printf("[SETTINGS] TypeBanner live loop already running\n");
        }
        return;
    }

    if (settings_cleanup_in_progress()) {
        __sync_lock_release(&g_typebanner_live_running);
        return;
    }

    g_typebanner_live_stop_requested = 0;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSUInteger tick = 0;
        NSUInteger failures = 0;
        BOOL deferredLogged = NO;
        BOOL pausedForMessages = NO;
        RemoteCallSession *mobileSession = nil;
        RemoteCallSession *daemonSession = nil;

        printf("[SETTINGS] TypeBanner live loop started interval=%uus background=%uus max=%lu\n",
               kTypeBannerLiveIntervalUS,
               kTypeBannerLiveBackgroundIntervalUS,
               (unsigned long)kTypeBannerLiveMaxTicks);

        @try {
            while ([d boolForKey:kSettingsTypeBannerEnabled] &&
                   !settings_cleanup_in_progress() &&
                   !g_typebanner_live_stop_requested &&
                   tick < kTypeBannerLiveMaxTicks) {
                useconds_t intervalUS = settings_live_interval(kTypeBannerLiveIntervalUS,
                                                               kTypeBannerLiveBackgroundIntervalUS);
                uint64_t tickStartUS = settings_now_us();
                bool ok = false;

                if (!g_kexploit_done || g_settings_actions_running) {
                    if (!deferredLogged) {
                        printf("[SETTINGS] TypeBanner tick deferred krw=%d actions=%d\n",
                               g_kexploit_done, g_settings_actions_running);
                        deferredLogged = YES;
                    }
                    settings_live_loop_sleep_interruptible(0,
                                                           intervalUS,
                                                           &g_typebanner_live_stop_requested);
                    continue;
                }
                deferredLogged = NO;

                if (!settings_typebanner_can_poll_messages()) {
                    if (!pausedForMessages) {
                        pausedForMessages = YES;
                        printf("[SETTINGS] TypeBanner paused while %s\n",
                               settings_typebanner_pause_reason());
                    }
                    if (mobileSession) {
                        @synchronized (settings_rc_lock()) {
                            [mobileSession abandonRemoteCall];
                            mobileSession = nil;
                        }
                    }
                    if (daemonSession) {
                        @synchronized (settings_rc_lock()) {
                            [daemonSession abandonRemoteCall];
                            daemonSession = nil;
                        }
                    }
                    settings_live_loop_sleep_interruptible(0,
                                                           intervalUS,
                                                           &g_typebanner_live_stop_requested);
                    continue;
                }
                if (pausedForMessages) {
                    pausedForMessages = NO;
                    printf("[SETTINGS] TypeBanner resumed after screen unlock/wake\n");
                }

                // TypeBanner now uses imagent original-thread probes for
                // detection. The MobileSMS session pointer is kept only for
                // fallback builds where that path is re-enabled.
                @try {
                    @synchronized (settings_rc_lock()) {
                        if (!g_typebanner_live_stop_requested &&
                            !g_settings_actions_running &&
                            g_kexploit_done &&
                            settings_typebanner_can_poll_messages()) {
                            ok = typebanner_run_once_with_cached_sessions(&mobileSession,
                                                                          &daemonSession,
                                                                          g_springboard_rc_ready != 0);
                        } else {
                            ok = true;
                        }
                    }
                } @catch (NSException *e) {
                    printf("[SETTINGS] TypeBanner tick exception: %s\n", e.reason.UTF8String);
                    ok = false;
                }

                if (tick == 0) printf("[SETTINGS] TypeBanner result=%d\n", ok);
                if (ok) {
                    failures = 0;
                } else {
                    failures++;
                    printf("[SETTINGS] TypeBanner tick failed tick=%lu failures=%lu\n",
                           (unsigned long)tick, (unsigned long)failures);
                    if (failures >= settings_live_failure_limit(3)) break;
                }

                tick++;
                if (![d boolForKey:kSettingsTypeBannerEnabled] ||
                    g_typebanner_live_stop_requested ||
                    tick >= kTypeBannerLiveMaxTicks) break;

                uint64_t nowUS = settings_now_us();
                uint64_t elapsedUS = tickStartUS != 0 && nowUS >= tickStartUS ? nowUS - tickStartUS : 0;
                if (elapsedUS < intervalUS) {
                    settings_live_loop_sleep_interruptible(0,
                                                           (useconds_t)(intervalUS - elapsedUS),
                                                           &g_typebanner_live_stop_requested);
                }

                if (tick == 1) {
                    printf("[SETTINGS] TypeBanner tick=0 elapsed=%lluus\n", elapsedUS);
                }
            }
        } @finally {
            if (mobileSession) {
                @synchronized (settings_rc_lock()) {
                    [mobileSession destroyRemoteCall];
                    mobileSession = nil;
                }
            }
            if (daemonSession) {
                @synchronized (settings_rc_lock()) {
                    [daemonSession destroyRemoteCall];
                    daemonSession = nil;
                }
            }

            // Best-effort hide the banner before exiting — drops any stale
            // pill that might persist in SpringBoard's window list.
            if (typebanner_has_remote_state() &&
                g_kexploit_done && !g_settings_actions_running && !settings_cleanup_in_progress()) {
                @synchronized (settings_rc_lock()) {
                    RemoteCallSession *springboardSession = [[RemoteCallSession alloc] initWithProcess:@"SpringBoard"
                                                                                     useMigFilterBypass:NO
                                                                                firstExceptionTimeoutMS:TYPEBANNER_RC_FIRST_EXCEPTION_TIMEOUT_MS];
                    if (springboardSession) {
                        @try {
                            typebanner_release_mobilesms_keepalive_in_springboard_remote_session(springboardSession);
                            typebanner_hide_in_springboard_remote_session(springboardSession);
                        } @catch (NSException *e) {
                            printf("[SETTINGS] TypeBanner final hide exception: %s\n", e.reason.UTF8String);
                        }
                        [springboardSession destroyRemoteCall];
                    }
                }
            } else {
                printf("[SETTINGS] TypeBanner final hide skipped state=%d krw=%d actions=%d cleanup=%d\n",
                       typebanner_has_remote_state(),
                       g_kexploit_done, g_settings_actions_running, settings_cleanup_in_progress());
            }
            typebanner_forget_remote_state();

            printf("[SETTINGS] TypeBanner live loop exited ticks=%lu enabled=%d failures=%lu stop=%d\n",
                   (unsigned long)tick,
                   [d boolForKey:kSettingsTypeBannerEnabled],
                   (unsigned long)failures,
                   g_typebanner_live_stop_requested);
            __sync_lock_release(&g_typebanner_live_running);
        }
    });
}

static void settings_start_notificationisland_live_loop(void)
{
    if (!settings_device_supported()) return;
    if (settings_cleanup_in_progress()) return;

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (!settings_notificationisland_install_allowed()) return;
    if (![d boolForKey:kSettingsNotificationIslandEnabled]) return;
    if (!g_springboard_rc_ready) return;

    if (__sync_lock_test_and_set(&g_notificationisland_live_running, 1)) {
        static volatile int loggedAlready = 0;
        if (__sync_bool_compare_and_swap(&loggedAlready, 0, 1)) {
            printf("[SETTINGS] Notification Island live loop already running\n");
        }
        return;
    }

    if (settings_cleanup_in_progress()) {
        __sync_lock_release(&g_notificationisland_live_running);
        return;
    }

    g_notificationisland_live_stop_requested = 0;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSUInteger tick = 0;
        NSUInteger failures = 0;
        uint64_t nextTickUS = settings_now_us();
        BOOL deferredLogged = NO;

        printf("[SETTINGS] Notification Island live loop started interval=%uus background=%uus max=%lu\n",
               kNotificationIslandLiveIntervalUS,
               kNotificationIslandLiveBackgroundIntervalUS,
               (unsigned long)kNotificationIslandLiveMaxTicks);
        cyanide_upload_log_milestone(@"notification-island-live-started");

        @try {
            while ([d boolForKey:kSettingsNotificationIslandEnabled] &&
                   !settings_cleanup_in_progress() &&
                   !g_notificationisland_live_stop_requested &&
                   tick < kNotificationIslandLiveMaxTicks) {
                useconds_t intervalUS = settings_live_interval(kNotificationIslandLiveIntervalUS,
                                                               kNotificationIslandLiveBackgroundIntervalUS);
                uint64_t tickStartUS = settings_now_us();
                bool ok = false;

                if (!g_kexploit_done || g_settings_actions_running) {
                    if (!deferredLogged) {
                        printf("[SETTINGS] Notification Island tick deferred krw=%d actions=%d\n",
                               g_kexploit_done, g_settings_actions_running);
                        deferredLogged = YES;
                    }
                    settings_live_loop_sleep_interruptible(0,
                                                           intervalUS,
                                                           &g_notificationisland_live_stop_requested);
                    nextTickUS = settings_now_us();
                    continue;
                }
                deferredLogged = NO;

                @synchronized (settings_rc_lock()) {
                    if (g_notificationisland_live_stop_requested) break;
                    if (!g_springboard_rc_ready) {
                        printf("[SETTINGS] Notification Island loop has no SpringBoard RemoteCall session\n");
                        failures++;
                        break;
                    }
                    ok = notificationisland_tick_in_session();
                }

                if (tick == 0) {
                    printf("[SETTINGS] Notification Island result=%d\n", ok);
                    cyanide_upload_log_milestone(ok ? @"notification-island-live-first-ok" :
                                                     @"notification-island-live-first-failed");
                }
                if (ok) {
                    failures = 0;
                } else {
                    failures++;
                    printf("[SETTINGS] Notification Island tick failed tick=%lu failures=%lu\n",
                           (unsigned long)tick, (unsigned long)failures);
                    if (failures >= settings_live_failure_limit(3)) break;
                }

                tick++;
                if (![d boolForKey:kSettingsNotificationIslandEnabled] ||
                    g_notificationisland_live_stop_requested ||
                    tick >= kNotificationIslandLiveMaxTicks) break;

                uint64_t nowUS = settings_now_us();
                intervalUS = settings_live_interval(kNotificationIslandLiveIntervalUS,
                                                    kNotificationIslandLiveBackgroundIntervalUS);
                nextTickUS += intervalUS;
                if (nowUS < nextTickUS) {
                    settings_live_loop_sleep_interruptible(nextTickUS,
                                                           (useconds_t)(nextTickUS - nowUS),
                                                           &g_notificationisland_live_stop_requested);
                } else {
                    nextTickUS = nowUS;
                }

                uint64_t elapsedUS = tickStartUS != 0 && nowUS >= tickStartUS ? nowUS - tickStartUS : 0;
                if (tick == 1) {
                    printf("[SETTINGS] Notification Island tick=0 elapsed=%lluus\n", elapsedUS);
                }
            }
        } @finally {
            printf("[SETTINGS] Notification Island live loop exited ticks=%lu enabled=%d failures=%lu stop=%d\n",
                   (unsigned long)tick,
                   [d boolForKey:kSettingsNotificationIslandEnabled],
                   (unsigned long)failures,
                   g_notificationisland_live_stop_requested);
            if (failures > 0)
                cyanide_upload_log_milestone(@"notification-island-live-exited-failed");
            __sync_lock_release(&g_notificationisland_live_running);
        }
    });
}

static void settings_start_themer_live_loop(void)
{
    if (!settings_device_supported()) return;
    if (settings_cleanup_in_progress()) return;

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (![d boolForKey:kSettingsThemerEnabled] &&
        ![d boolForKey:kSettingsSnowBoardLiteEnabled]) return;
    if (!g_springboard_rc_ready) return;
    if (settings_themer_dynamic_updates_blocked_by_stage(d)) {
        settings_note_themer_stage_conflict(YES);
        return;
    }

    if (__sync_lock_test_and_set(&g_themer_live_running, 1)) {
        static volatile int loggedAlready = 0;
        if (__sync_bool_compare_and_swap(&loggedAlready, 0, 1)) {
            printf("[SETTINGS] Themer dynamic live loop already running\n");
        }
        return;
    }

    if (settings_cleanup_in_progress()) {
        __sync_lock_release(&g_themer_live_running);
        return;
    }

    g_themer_live_stop_requested = 0;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSUInteger tick = 0;
        NSUInteger failures = 0;
        NSInteger iosMajor = [[NSProcessInfo processInfo] operatingSystemVersion].majorVersion;
        NSUInteger maxTicks = (iosMajor > 0 && iosMajor < 26)
            ? kThemerLegacyLiveMaxTicks
            : kThemerLiveMaxTicks;

        printf("[SETTINGS] Themer dynamic live loop started interval=%uus background=%uus max=%lu iosMajor=%ld\n",
               kThemerLiveIntervalUS,
               kThemerLiveBackgroundIntervalUS,
               (unsigned long)maxTicks,
               (long)iosMajor);

        @try {
            // Start with a sleep so we don't pile a tick on top of the
            // initial Run apply that just completed.
            settings_live_loop_sleep_interruptible(0,
                                                   settings_live_interval(kThemerLiveIntervalUS,
                                                                          kThemerLiveBackgroundIntervalUS),
                                                   &g_themer_live_stop_requested);
            while (([d boolForKey:kSettingsThemerEnabled] ||
                    [d boolForKey:kSettingsSnowBoardLiteEnabled]) &&
                   !settings_themer_dynamic_updates_blocked_by_stage(d) &&
                   !settings_cleanup_in_progress() &&
                   !g_themer_live_stop_requested &&
                   tick < maxTicks) {
                useconds_t intervalUS = settings_live_interval(kThemerLiveIntervalUS,
                                                               kThemerLiveBackgroundIntervalUS);
                bool ok = false;

                @synchronized (settings_rc_lock()) {
                    if (g_themer_live_stop_requested) break;
                    if (!g_springboard_rc_ready) {
                        printf("[SETTINGS] Themer dynamic loop has no SpringBoard RemoteCall session\n");
                        failures++;
                        break;
                    }
                    if (!g_kexploit_done || g_settings_actions_running) {
                        // Wait for actions to finish before next tick.
                        ok = true;
                    } else {
                        ok = themer_repaint_dynamic_cached_views_in_session();
                    }
                }

                if (tick == 0) {
                    printf("[SETTINGS] Themer dynamic live first tick result=%d\n", ok);
                }
                failures = ok ? 0 : failures + 1;

                tick++;
                if ((![d boolForKey:kSettingsThemerEnabled] &&
                     ![d boolForKey:kSettingsSnowBoardLiteEnabled]) ||
                    settings_themer_dynamic_updates_blocked_by_stage(d) ||
                    g_themer_live_stop_requested ||
                    tick >= maxTicks) break;

                intervalUS = settings_live_interval(kThemerLiveIntervalUS,
                                                    kThemerLiveBackgroundIntervalUS);
                settings_live_loop_sleep_interruptible(0, intervalUS,
                                                       &g_themer_live_stop_requested);
            }
        } @finally {
            if (settings_themer_dynamic_updates_blocked_by_stage(d)) {
                settings_note_themer_stage_conflict(YES);
            }
            printf("[SETTINGS] Themer dynamic live loop exited ticks=%lu enabled=%d failures=%lu stop=%d\n",
                   (unsigned long)tick,
                   [d boolForKey:kSettingsThemerEnabled] || [d boolForKey:kSettingsSnowBoardLiteEnabled],
                   (unsigned long)failures,
                   g_themer_live_stop_requested);
            __sync_lock_release(&g_themer_live_running);
        }
    });
}

static void settings_schedule_themer_repair_burst_internal(const char *reason, BOOL force)
{
    (void)force;
    if (!settings_device_supported()) return;
    if (settings_cleanup_in_progress()) return;

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (![d boolForKey:kSettingsThemerEnabled] &&
        ![d boolForKey:kSettingsSnowBoardLiteEnabled]) return;
    if (!g_springboard_rc_ready) return;
    if (settings_themer_dynamic_updates_blocked_by_stage(d)) {
        settings_note_themer_stage_conflict(force);
        return;
    }

    __sync_add_and_fetch(&g_themer_repair_generation, 1);
    if (__sync_lock_test_and_set(&g_themer_repair_running, 1)) return;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        uint64_t seenGeneration = g_themer_repair_generation;
        NSUInteger tick = 0;
        NSUInteger quietTicks = 0;

        printf("[SETTINGS] Themer dynamic repair burst started%s%s\n",
               reason ? ": " : "", reason ?: "");

        @try {
            while (([d boolForKey:kSettingsThemerEnabled] ||
                    [d boolForKey:kSettingsSnowBoardLiteEnabled]) &&
                   !settings_themer_dynamic_updates_blocked_by_stage(d) &&
                   !settings_cleanup_in_progress() &&
                   !g_themer_live_stop_requested &&
                   tick < 1) {
                settings_live_loop_sleep_interruptible(0,
                                                       tick == 0
                                                           ? kThemerRepairInitialDelayUS
                                                           : kThemerRepairIntervalUS,
                                                       &g_themer_live_stop_requested);
                if (g_themer_live_stop_requested) break;

                bool ok = false;
                @synchronized (settings_rc_lock()) {
                    if (!g_springboard_rc_ready || !g_kexploit_done ||
                        g_settings_actions_running) {
                        ok = true;
                    } else {
                        ok = themer_repaint_dynamic_cached_views_in_session();
                    }
                }

                tick++;
                uint64_t currentGeneration = g_themer_repair_generation;
                if (currentGeneration != seenGeneration) {
                    seenGeneration = currentGeneration;
                    quietTicks = 0;
                } else {
                    quietTicks++;
                    if (quietTicks >= 2) break;
                }

                if (tick == 1) {
                    printf("[SETTINGS] Themer dynamic repair first repaint=%d\n", ok);
                }
            }
        } @finally {
            printf("[SETTINGS] Themer dynamic repair burst exited ticks=%lu\n",
                   (unsigned long)tick);
            __sync_lock_release(&g_themer_repair_running);
        }
    });
}

static void settings_schedule_themer_repair_burst(const char *reason)
{
    settings_schedule_themer_repair_burst_internal(reason, YES);
}

static void settings_schedule_themer_quiet_repair_burst(const char *reason)
{
    settings_schedule_themer_repair_burst_internal(reason, NO);
}

static void settings_apply_axonlite_once_async(const char *reason)
{
    if (!settings_device_supported()) return;
    if (settings_cleanup_in_progress()) return;
    if (g_axonlite_live_running) {
        if (reason) {
            printf("[SETTINGS] Axon Lite lifecycle apply skipped: live loop owns Axon (%s)\n",
                   reason);
        }
        return;
    }

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (![d boolForKey:kSettingsAxonLiteEnabled] || !g_springboard_rc_ready) return;

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if (settings_cleanup_in_progress()) return;
        bool ok = false;
        if (!settings_axonlite_can_poll_springboard()) {
            printf("[SETTINGS] Axon Lite lifecycle apply%s%s skipped: %s\n",
                   reason ? ": " : "", reason ?: "",
                   settings_axonlite_pause_reason());
            settings_start_axonlite_live_loop();
            return;
        }
        @synchronized (settings_rc_lock()) {
            if (settings_cleanup_in_progress() ||
                ![d boolForKey:kSettingsAxonLiteEnabled] ||
                !g_springboard_rc_ready) return;
            if (!settings_axonlite_can_poll_springboard()) {
                printf("[SETTINGS] Axon Lite lifecycle apply%s%s skipped inside lock: %s\n",
                       reason ? ": " : "", reason ?: "",
                       settings_axonlite_pause_reason());
                settings_start_axonlite_live_loop();
                return;
            }
            ok = axonlite_apply_in_session();
        }
        printf("[SETTINGS] Axon Lite lifecycle apply%s%s result=%d\n",
               reason ? ": " : "", reason ?: "", ok);
        settings_start_axonlite_live_loop();
    });
}

void settings_application_did_enter_background(void)
{
    if (__sync_lock_test_and_set(&g_app_in_background, 1)) return;
    if (settings_cleanup_in_progress()) return;

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    BOOL themerLiveNeeded = g_springboard_rc_ready &&
        !settings_themer_dynamic_updates_blocked_by_stage(d) &&
        ([d boolForKey:kSettingsThemerEnabled] ||
         [d boolForKey:kSettingsSnowBoardLiteEnabled]);
    BOOL anyLiveLoopNeeded =
        ([d boolForKey:kSettingsAxonLiteEnabled]    && g_springboard_rc_ready) ||
        (settings_rssi_install_allowed() && [d boolForKey:kSettingsRSSIDisplayEnabled] && g_springboard_rc_ready) ||
        ([d boolForKey:kSettingsStatBarEnabled]     && g_springboard_rc_ready) ||
        ([d boolForKey:kSettingsNSBarEnabled]       && g_springboard_rc_ready) ||
        ([d boolForKey:kSettingsNiceBarLiteEnabled] && g_springboard_rc_ready) ||
        ([d boolForKey:kSettingsGravityLiteEnabled] && g_springboard_rc_ready) ||
        themerLiveNeeded ||
        ([d boolForKey:kSettingsLiveWPEnabled]      && g_springboard_rc_ready) ||
        (settings_notificationisland_install_allowed() && [d boolForKey:kSettingsNotificationIslandEnabled] && g_springboard_rc_ready) ||
        (settings_typebanner_install_allowed() && [d boolForKey:kSettingsTypeBannerEnabled]);
    if (anyLiveLoopNeeded) {
        if ([d boolForKey:kSettingsKeepAlive]) {
            ds_keepalive_apply_enabled(YES);
        }
        settings_begin_statbar_background_task_async("entered background");
    }

    if ([d boolForKey:kSettingsAxonLiteEnabled] && g_springboard_rc_ready) {
        settings_apply_axonlite_once_async("entered background");
    }
    if (settings_notificationisland_install_allowed() &&
        [d boolForKey:kSettingsNotificationIslandEnabled] &&
        g_springboard_rc_ready) {
        settings_start_notificationisland_live_loop();
    }
    if ([d boolForKey:kSettingsGravityLiteEnabled] && g_springboard_rc_ready) {
        if (g_gravitylite_background_armed != 0) {
            settings_apply_armed_gravitylite_once_async("entered background");
        }
    }
    if (settings_rssi_install_allowed() && [d boolForKey:kSettingsRSSIDisplayEnabled] && g_springboard_rc_ready) {
        settings_apply_rssi_once_async("entered background");
    }
    if ([d boolForKey:kSettingsNSBarEnabled] && g_springboard_rc_ready) {
        settings_apply_nsbar_once_async("entered background");
    }
    if ([d boolForKey:kSettingsNiceBarLiteEnabled] && g_springboard_rc_ready) {
        settings_apply_nicebarlite_once_async("entered background");
    }
    if ([d boolForKey:kSettingsLiveWPEnabled] && g_springboard_rc_ready) {
        settings_pause_livewp_for_sleep_async("entered background");
    }
    if (![d boolForKey:kSettingsStatBarEnabled] || !g_springboard_rc_ready) {
        return;
    }

    printf("[SETTINGS] app entered background with app-side StatBar loop\n");
    settings_apply_statbar_once_async("entered background");
}

void settings_application_will_enter_foreground(void)
{
    if (!settings_app_state_is_foreground()) return;
    g_app_in_background = 0;
    settings_end_statbar_background_task_async("foreground");
    if (settings_cleanup_in_progress()) return;
    settings_apply_statbar_once_async("will enter foreground");
    settings_apply_nsbar_once_async("will enter foreground");
    settings_apply_nicebarlite_once_async("will enter foreground");
    settings_apply_rssi_once_async("will enter foreground");
    settings_apply_axonlite_once_async("will enter foreground");
    if (settings_notificationisland_install_allowed() &&
        [[NSUserDefaults standardUserDefaults] boolForKey:kSettingsNotificationIslandEnabled] &&
        g_springboard_rc_ready) {
        settings_start_notificationisland_live_loop();
    }
    settings_start_themer_live_loop();
    settings_resume_livewp_after_wake_async("will enter foreground");
    if (settings_typebanner_install_allowed() &&
        [[NSUserDefaults standardUserDefaults] boolForKey:kSettingsTypeBannerEnabled]) {
        settings_start_typebanner_live_loop();
    }
}

void settings_application_did_become_active(void)
{
    if (!settings_app_state_is_foreground()) return;
    g_app_in_background = 0;
    if (settings_cleanup_in_progress()) return;
    settings_apply_statbar_once_async("became active");
    settings_apply_nsbar_once_async("became active");
    settings_apply_nicebarlite_once_async("became active");
    settings_apply_rssi_once_async("became active");
    settings_apply_axonlite_once_async("became active");
    if (settings_notificationisland_install_allowed() &&
        [[NSUserDefaults standardUserDefaults] boolForKey:kSettingsNotificationIslandEnabled] &&
        g_springboard_rc_ready) {
        settings_start_notificationisland_live_loop();
    }
    settings_start_themer_live_loop();
    settings_resume_livewp_after_wake_async("became active");
    if (settings_typebanner_install_allowed() &&
        [[NSUserDefaults standardUserDefaults] boolForKey:kSettingsTypeBannerEnabled]) {
        settings_start_typebanner_live_loop();
    }
}

static BOOL settings_key_is_sbc(NSString *key)
{
    return [key isEqualToString:kSettingsSBCEnabled] ||
           [key isEqualToString:kSettingsSBCDockIcons] ||
           [key isEqualToString:kSettingsSBCCols] ||
           [key isEqualToString:kSettingsSBCRows] ||
           [key isEqualToString:kSettingsSBCHideLabels];
}

static BOOL settings_key_is_statbar(NSString *key)
{
    return [key isEqualToString:kSettingsStatBarEnabled] ||
           [key isEqualToString:kSettingsStatBarCelsius] ||
           [key isEqualToString:kSettingsStatBarShowNet] ||
           [key isEqualToString:kSettingsStatBarShowCPU] ||
           [key isEqualToString:kSettingsStatBarShowLabels] ||
           [key isEqualToString:kSettingsStatBarNetworkOnly] ||
           [key isEqualToString:kSettingsStatBarRefreshRateSec];
}

static BOOL settings_key_is_nsbar(NSString *key)
{
    return [key isEqualToString:kSettingsNSBarEnabled] ||
           [key isEqualToString:kSettingsNSBarPosition];
}

static BOOL settings_key_is_nicebarlite(NSString *key)
{
    if ([key isEqualToString:kSettingsNiceBarLiteEnabled] ||
        [key isEqualToString:kSettingsNiceBarLiteCelsius] ||
        [key isEqualToString:kSettingsNiceBarLiteLayoutTopSideInset] ||
        [key isEqualToString:kSettingsNiceBarLiteLayoutBottomSideInset] ||
        [key isEqualToString:kSettingsNiceBarLiteLayoutTopY] ||
        [key isEqualToString:kSettingsNiceBarLiteLayoutBottomY] ||
        [key isEqualToString:kSettingsNiceBarLiteLayoutCenterX]) {
        return YES;
    }
    for (NSInteger i = 0; i < NiceBarLiteSlotCount; i++) {
        if ([key isEqualToString:settings_nicebar_key(kSettingsNiceBarLiteSlotKindPrefix, i)] ||
            [key isEqualToString:settings_nicebar_key(kSettingsNiceBarLiteSlotSystemPrefix, i)] ||
            [key isEqualToString:settings_nicebar_key(kSettingsNiceBarLiteSlotTextPrefix, i)] ||
            [key isEqualToString:settings_nicebar_key(kSettingsNiceBarLiteSlotTimePrefix, i)] ||
            [key isEqualToString:settings_nicebar_key(kSettingsNiceBarLiteSlotWeatherPrefix, i)] ||
            [key isEqualToString:settings_nicebar_key(kSettingsNiceBarLiteSlotWeatherLanguagePrefix, i)] ||
            [key isEqualToString:settings_nicebar_key(kSettingsNiceBarLiteSlotSystemLanguagePrefix, i)]) {
            return YES;
        }
    }
    return NO;
}

static BOOL settings_key_is_rssi(NSString *key)
{
    return [key isEqualToString:kSettingsRSSIDisplayEnabled] ||
           [key isEqualToString:kSettingsRSSIDisplayWifi] ||
           [key isEqualToString:kSettingsRSSIDisplayCell];
}

static BOOL settings_key_is_axonlite(NSString *key)
{
    return [key isEqualToString:kSettingsAxonLiteEnabled];
}

static BOOL settings_key_is_typebanner(NSString *key)
{
    return [key isEqualToString:kSettingsTypeBannerEnabled];
}

static BOOL settings_key_is_notificationisland(NSString *key)
{
    return [key isEqualToString:kSettingsNotificationIslandEnabled];
}

static BOOL settings_key_is_appswitchergrid(NSString *key)
{
    return [key isEqualToString:kSettingsAppSwitcherGridEnabled];
}

static BOOL settings_key_is_gravitylite(NSString *key)
{
    return [key isEqualToString:kSettingsGravityLiteEnabled] ||
           [key isEqualToString:kSettingsGravityLiteDockEnabled] ||
           [key isEqualToString:kSettingsGravityLiteMagnitudePct] ||
           [key isEqualToString:kSettingsGravityLiteBouncePct] ||
           [key isEqualToString:kSettingsGravityLiteFrictionPct] ||
           [key isEqualToString:kSettingsGravityLiteResistancePct] ||
           [key isEqualToString:kSettingsGravityLiteAngularResistancePct];
}

static BOOL settings_key_is_location_sim(NSString *key)
{
    return [key isEqualToString:kSettingsLocationSimEnabled] ||
           [key isEqualToString:kSettingsLocationSimLatitude] ||
           [key isEqualToString:kSettingsLocationSimLongitude] ||
           [key isEqualToString:kSettingsLocationSimAltitude] ||
           [key isEqualToString:kSettingsLocationSimHorizontalAccuracy] ||
           [key isEqualToString:kSettingsLocationSimHostProcess];
}

static NSString *settings_location_sim_host_process(NSUserDefaults *d)
{
    NSString *host = [d stringForKey:kSettingsLocationSimHostProcess];
    return host.length > 0 ? host : @"Maps";
}

static NSArray<NSDictionary *> *settings_location_sim_number_tokens_from_text(NSString *text)
{
    NSMutableArray<NSDictionary *> *tokens = [NSMutableArray array];
    NSScanner *scanner = [NSScanner scannerWithString:text ?: @""];
    scanner.charactersToBeSkipped = nil;
    while (!scanner.isAtEnd) {
        double value = 0.0;
        NSUInteger start = scanner.scanLocation;
        if ([scanner scanDouble:&value]) {
            if (isfinite(value)) {
                NSRange range = NSMakeRange(start, scanner.scanLocation - start);
                [tokens addObject:@{ @"value": @(value),
                                     @"range": [NSValue valueWithRange:range] }];
            }
            continue;
        }
        scanner.scanLocation = scanner.scanLocation + 1;
    }
    return tokens;
}

static NSInteger settings_location_sim_axis_sign_for_word(NSString *word, BOOL latitude)
{
    NSString *upper = [(word ?: @"") uppercaseString];
    if (upper.length != 1) return 0;
    unichar c = [upper characterAtIndex:0];
    if (latitude) {
        if (c == 'N') return 1;
        if (c == 'S') return -1;
    } else {
        if (c == 'E') return 1;
        if (c == 'W') return -1;
    }
    return 0;
}

static NSInteger settings_location_sim_axis_kind_for_word(NSString *word)
{
    NSString *upper = [(word ?: @"") uppercaseString];
    if ([upper isEqualToString:@"LAT"] ||
        [upper isEqualToString:@"LATITUDE"]) {
        return 1;
    }
    if ([upper isEqualToString:@"LON"] ||
        [upper isEqualToString:@"LNG"] ||
        [upper isEqualToString:@"LONG"] ||
        [upper isEqualToString:@"LONGITUDE"]) {
        return 2;
    }
    return 0;
}

static BOOL settings_location_sim_is_axis_separator(unichar c)
{
    if ([NSCharacterSet.whitespaceAndNewlineCharacterSet characterIsMember:c]) return YES;
    if ([NSCharacterSet.punctuationCharacterSet characterIsMember:c]) return YES;
    if ([NSCharacterSet.symbolCharacterSet characterIsMember:c]) return YES;
    return NO;
}

static NSString *settings_location_sim_axis_word_after_range(NSString *text, NSRange range)
{
    NSUInteger i = NSMaxRange(range);
    while (i < text.length &&
           settings_location_sim_is_axis_separator([text characterAtIndex:i])) {
        i++;
    }
    NSUInteger start = i;
    while (i < text.length &&
           [NSCharacterSet.letterCharacterSet characterIsMember:[text characterAtIndex:i]]) {
        i++;
    }
    return i > start ? [text substringWithRange:NSMakeRange(start, i - start)] : @"";
}

static NSString *settings_location_sim_axis_word_before_range(NSString *text, NSRange range)
{
    if (range.location == 0) return @"";
    NSInteger i = (NSInteger)range.location - 1;
    while (i >= 0 &&
           settings_location_sim_is_axis_separator([text characterAtIndex:(NSUInteger)i])) {
        i--;
    }
    NSInteger end = i + 1;
    while (i >= 0 &&
           [NSCharacterSet.letterCharacterSet characterIsMember:[text characterAtIndex:(NSUInteger)i]]) {
        i--;
    }
    NSInteger start = i + 1;
    return end > start ? [text substringWithRange:NSMakeRange((NSUInteger)start, (NSUInteger)(end - start))] : @"";
}

static NSInteger settings_location_sim_axis_sign_near_range(NSString *text,
                                                            NSRange range,
                                                            BOOL latitude)
{
    NSInteger sign = settings_location_sim_axis_sign_for_word(settings_location_sim_axis_word_after_range(text ?: @"", range),
                                                              latitude);
    if (sign != 0) return sign;
    return settings_location_sim_axis_sign_for_word(settings_location_sim_axis_word_before_range(text ?: @"", range),
                                                   latitude);
}

static NSInteger settings_location_sim_axis_kind_near_range(NSString *text, NSRange range)
{
    NSInteger kind = settings_location_sim_axis_kind_for_word(settings_location_sim_axis_word_before_range(text ?: @"", range));
    if (kind != 0) return kind;
    return settings_location_sim_axis_kind_for_word(settings_location_sim_axis_word_after_range(text ?: @"", range));
}

static NSInteger settings_location_sim_axis_sign_from_text(NSString *text, BOOL latitude)
{
    NSString *upper = [(text ?: @"") uppercaseString];
    NSInteger sign = 0;
    for (NSUInteger i = 0; i < upper.length; i++) {
        unichar c = [upper characterAtIndex:i];
        NSInteger candidate = settings_location_sim_axis_sign_for_word([NSString stringWithCharacters:&c length:1],
                                                                       latitude);
        if (candidate == 0) continue;

        BOOL prevIsLetter = (i > 0) && [NSCharacterSet.letterCharacterSet characterIsMember:[upper characterAtIndex:i - 1]];
        BOOL nextIsLetter = (i + 1 < upper.length) && [NSCharacterSet.letterCharacterSet characterIsMember:[upper characterAtIndex:i + 1]];
        if (!prevIsLetter && !nextIsLetter) sign = candidate;
    }
    return sign;
}

static double settings_location_sim_apply_axis_sign(double value, NSInteger sign)
{
    return sign != 0 ? fabs(value) * (double)sign : value;
}

static BOOL settings_location_sim_coordinates_valid(double latitude, double longitude)
{
    return isfinite(latitude) && isfinite(longitude) &&
           latitude >= -90.0 && latitude <= 90.0 &&
           longitude >= -180.0 && longitude <= 180.0;
}

static BOOL settings_location_sim_component_valid(double value, BOOL latitude)
{
    if (!isfinite(value)) return NO;
    return latitude
        ? (value >= -90.0 && value <= 90.0)
        : (value >= -180.0 && value <= 180.0);
}

static BOOL settings_location_sim_parse_coordinate_component(NSString *text,
                                                             BOOL latitude,
                                                             double *outValue)
{
    if (!outValue) return NO;
    NSArray<NSDictionary *> *tokens = settings_location_sim_number_tokens_from_text(text);
    if (tokens.count != 1) return NO;

    NSDictionary *token = tokens.firstObject;
    double value = [token[@"value"] doubleValue];
    NSRange range = [token[@"range"] rangeValue];
    NSInteger sign = settings_location_sim_axis_sign_near_range(text, range, latitude);
    if (sign == 0) sign = settings_location_sim_axis_sign_from_text(text, latitude);
    value = settings_location_sim_apply_axis_sign(value, sign);
    if (!settings_location_sim_component_valid(value, latitude)) return NO;

    *outValue = value;
    return YES;
}

static BOOL settings_location_sim_parse_coordinate_pair(NSString *text,
                                                        double *latitudeOut,
                                                        double *longitudeOut)
{
    if (!latitudeOut || !longitudeOut) return NO;
    NSArray<NSDictionary *> *tokens = settings_location_sim_number_tokens_from_text(text);
    if (tokens.count != 2) return NO;

    NSDictionary *firstToken = tokens[0];
    NSDictionary *secondToken = tokens[1];
    double first = [firstToken[@"value"] doubleValue];
    double second = [secondToken[@"value"] doubleValue];
    NSRange firstRange = [firstToken[@"range"] rangeValue];
    NSRange secondRange = [secondToken[@"range"] rangeValue];
    NSInteger firstLatSign = settings_location_sim_axis_sign_near_range(text, firstRange, YES);
    NSInteger firstLonSign = settings_location_sim_axis_sign_near_range(text, firstRange, NO);
    NSInteger secondLatSign = settings_location_sim_axis_sign_near_range(text, secondRange, YES);
    NSInteger secondLonSign = settings_location_sim_axis_sign_near_range(text, secondRange, NO);
    NSInteger firstKind = settings_location_sim_axis_kind_near_range(text, firstRange);
    NSInteger secondKind = settings_location_sim_axis_kind_near_range(text, secondRange);

    if (firstKind == 1 && secondKind == 2) {
        double latitude = settings_location_sim_apply_axis_sign(first, firstLatSign);
        double longitude = settings_location_sim_apply_axis_sign(second, secondLonSign);
        if (!settings_location_sim_coordinates_valid(latitude, longitude)) return NO;
        *latitudeOut = latitude;
        *longitudeOut = longitude;
        return YES;
    }

    if (firstKind == 2 && secondKind == 1) {
        double latitude = settings_location_sim_apply_axis_sign(second, secondLatSign);
        double longitude = settings_location_sim_apply_axis_sign(first, firstLonSign);
        if (!settings_location_sim_coordinates_valid(latitude, longitude)) return NO;
        *latitudeOut = latitude;
        *longitudeOut = longitude;
        return YES;
    }

    if (firstLatSign != 0 && secondLonSign != 0) {
        double latitude = settings_location_sim_apply_axis_sign(first, firstLatSign);
        double longitude = settings_location_sim_apply_axis_sign(second, secondLonSign);
        if (!settings_location_sim_coordinates_valid(latitude, longitude)) return NO;
        *latitudeOut = latitude;
        *longitudeOut = longitude;
        return YES;
    }

    if (firstLonSign != 0 && secondLatSign != 0) {
        double latitude = settings_location_sim_apply_axis_sign(second, secondLatSign);
        double longitude = settings_location_sim_apply_axis_sign(first, firstLonSign);
        if (!settings_location_sim_coordinates_valid(latitude, longitude)) return NO;
        *latitudeOut = latitude;
        *longitudeOut = longitude;
        return YES;
    }

    NSInteger latitudeSign = settings_location_sim_axis_sign_from_text(text, YES);
    NSInteger longitudeSign = settings_location_sim_axis_sign_from_text(text, NO);

    double latitude = first;
    double longitude = second;
    latitude = settings_location_sim_apply_axis_sign(latitude, latitudeSign);
    longitude = settings_location_sim_apply_axis_sign(longitude, longitudeSign);
    if (!settings_location_sim_coordinates_valid(latitude, longitude)) {
        latitude = second;
        longitude = first;
        latitude = settings_location_sim_apply_axis_sign(latitude, latitudeSign);
        longitude = settings_location_sim_apply_axis_sign(longitude, longitudeSign);
        if (!settings_location_sim_coordinates_valid(latitude, longitude)) return NO;
    }

    *latitudeOut = latitude;
    *longitudeOut = longitude;
    return YES;
}

static BOOL settings_location_sim_parse_coordinate_fields(NSString *latitudeText,
                                                          NSString *longitudeText,
                                                          double *latitudeOut,
                                                          double *longitudeOut)
{
    if (!latitudeOut || !longitudeOut) return NO;
    if (settings_location_sim_parse_coordinate_pair(latitudeText, latitudeOut, longitudeOut)) return YES;
    if (settings_location_sim_parse_coordinate_pair(longitudeText, latitudeOut, longitudeOut)) return YES;

    double latitude = 0.0;
    double longitude = 0.0;
    BOOL ok = settings_location_sim_parse_coordinate_component(latitudeText, YES, &latitude) &&
              settings_location_sim_parse_coordinate_component(longitudeText, NO, &longitude) &&
              settings_location_sim_coordinates_valid(latitude, longitude);
    if (!ok) return NO;

    *latitudeOut = latitude;
    *longitudeOut = longitude;
    return YES;
}

static BOOL settings_location_sim_is_active(NSUserDefaults *d)
{
    return [d boolForKey:kSettingsLocationSimStarted];
}

static void settings_location_sim_set_target(NSUserDefaults *d,
                                             double latitude,
                                             double longitude)
{
    [d setDouble:latitude forKey:kSettingsLocationSimLatitude];
    [d setDouble:longitude forKey:kSettingsLocationSimLongitude];
    [d setObject:@"Maps" forKey:kSettingsLocationSimHostProcess];
    [d synchronize];
}

static void settings_location_sim_set_rockaway_defaults(NSUserDefaults *d)
{
    settings_location_sim_set_target(d, kLocationSimDefaultLatitude, kLocationSimDefaultLongitude);
    [d setInteger:kLocationSimDefaultAltitude forKey:kSettingsLocationSimAltitude];
    [d setInteger:kLocationSimDefaultAccuracy forKey:kSettingsLocationSimHorizontalAccuracy];
    [d synchronize];
}

static NSString *settings_location_sim_target_summary(NSUserDefaults *d)
{
    double lat = [d doubleForKey:kSettingsLocationSimLatitude];
    double lon = [d doubleForKey:kSettingsLocationSimLongitude];
    NSInteger altitude = [d integerForKey:kSettingsLocationSimAltitude];
    NSInteger accuracy = [d integerForKey:kSettingsLocationSimHorizontalAccuracy];
    if (accuracy <= 0) accuracy = kLocationSimDefaultAccuracy;
    return [NSString stringWithFormat:@"%.7f, %.7f 通过 %@ (海拔 %ldm，精度 %ldm)",
            lat,
            lon,
            settings_location_sim_host_process(d),
            (long)altitude,
            (long)accuracy];
}

static NSString *settings_location_sim_mode_summary(NSUserDefaults *d)
{
    BOOL simulationStarted = [d boolForKey:kSettingsLocationSimStarted];
    NSString *simulation = simulationStarted
        ? @"模式：模拟位置"
        : @"模式：真实位置";
    NSString *note = simulationStarted ? @"\n使用「恢复真实位置」可停止该功能。" : @"";
    return [NSString stringWithFormat:@"%@%@\n坐标: %@", simulation, note,
            settings_location_sim_target_summary(d)];
}

static NSString *settings_ipadecryptor_target_summary(NSUserDefaults *d)
{
    NSString *bundleID = [d stringForKey:kSettingsIPADecryptorTargetBundleID];
    if (bundleID.length == 0) {
        return @"未选择。请先选择一个已安装的应用。";
    }
    return ipadecryptor_display_name_for_bundle(bundleID);
}

static NSString *settings_ipadecryptor_app_store_summary(NSUserDefaults *d)
{
    NSString *appID = [d stringForKey:kSettingsIPADecryptorAppStoreID];
    NSString *name = [d stringForKey:kSettingsIPADecryptorAppStoreName];
    NSString *version = [d stringForKey:kSettingsIPADecryptorAppStoreVersion];
    NSString *url = [d stringForKey:kSettingsIPADecryptorAppStoreURL];
    if (appID.length == 0 && url.length == 0) {
        return @"无。请粘贴 App Store 链接或数字应用 ID。";
    }
    if (name.length > 0) {
        return [NSString stringWithFormat:@"%@%@%@",
                name,
                version.length > 0 ? @" " : @"",
                version.length > 0 ? version : @""];
    }
    return appID.length > 0 ? [NSString stringWithFormat:@"App Store ID %@", appID] : url;
}

static BOOL settings_apply_location_sim_from_defaults_locked(NSUserDefaults *d)
{
    NSInteger accuracy = [d integerForKey:kSettingsLocationSimHorizontalAccuracy];
    if (accuracy <= 0) accuracy = kLocationSimDefaultAccuracy;

    NSString *host = settings_location_sim_host_process(d);
    LocationSimConfig config = {
        .latitude = [d doubleForKey:kSettingsLocationSimLatitude],
        .longitude = [d doubleForKey:kSettingsLocationSimLongitude],
        .altitude = (double)[d integerForKey:kSettingsLocationSimAltitude],
        .horizontalAccuracy = (double)accuracy,
        .verticalAccuracy = (double)accuracy,
        .hostProcess = host.UTF8String,
        .launchHost = true,
    };
    return locationsim_apply_static(&config);
}

static BOOL settings_stop_location_sim_from_defaults_locked(NSUserDefaults *d)
{
    NSString *host = settings_location_sim_host_process(d);
    return locationsim_stop(host.UTF8String, true);
}

static BOOL settings_prime_location_sim_uber_stealth_locked(NSUserDefaults *d,
                                                            BOOL enable,
                                                            BOOL *systemApplyOKOut)
{
    NSInteger accuracy = [d integerForKey:kSettingsLocationSimHorizontalAccuracy];
    if (accuracy <= 0) accuracy = kLocationSimDefaultAccuracy;

    NSString *host = settings_location_sim_host_process(d);
    LocationSimConfig config = {
        .latitude = [d doubleForKey:kSettingsLocationSimLatitude],
        .longitude = [d doubleForKey:kSettingsLocationSimLongitude],
        .altitude = (double)[d integerForKey:kSettingsLocationSimAltitude],
        .horizontalAccuracy = (double)accuracy,
        .verticalAccuracy = (double)accuracy,
        .hostProcess = host.UTF8String,
        .launchHost = true,
    };

    BOOL systemOK = enable
        ? locationsim_apply_strict_hosts(&config)
        : locationsim_stop_strict_hosts(host.UTF8String, true);
    if (systemApplyOKOut) *systemApplyOKOut = systemOK;
    return systemOK;
}

static BOOL settings_key_is_dark_tweak(NSString *key)
{
    return [key isEqualToString:kSettingsDSDisableAppLibrary] ||
           [key isEqualToString:kSettingsDSDisableIconFlyIn] ||
           [key isEqualToString:kSettingsDSZeroWakeAnimation] ||
           [key isEqualToString:kSettingsDSZeroBacklightFade] ||
           [key isEqualToString:kSettingsDSDoubleTapToLock] ||
           [key isEqualToString:kSettingsDSDragCoefficientEnabled] ||
           [key isEqualToString:kSettingsDSDragCoefficientValue];
}

static BOOL settings_key_affects_package_state(NSString *key)
{
    return [settings_rc_backed_tweak_keys() containsObject:key];
}

static void settings_schedule_live_apply_for_key(NSString *key)
{
    if (settings_cleanup_in_progress()) {
        printf("[SETTINGS] live apply skipped during cleanup for %s\n", key.UTF8String);
        return;
    }

    if (!settings_device_supported()) {
        printf("[SETTINGS] live apply blocked for %s: %s\n",
               key.UTF8String, settings_unsupported_message().UTF8String);
        return;
    }

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (settings_key_is_location_sim(key)) {
        BOOL locsimStarted = [d boolForKey:kSettingsLocationSimStarted];
        if ([key isEqualToString:kSettingsLocationSimEnabled]) {
            [d setBool:NO forKey:kSettingsLocationSimEnabled];
            [d synchronize];
            settings_notify_package_queue_changed_async();
            return;
        }
        if (!locsimStarted) {
            settings_notify_package_queue_changed_async();
            return;
        }
        if (!settings_location_sim_install_allowed()) {
            log_user("[LOCSIM] Target refresh skipped: Location Simulator is unavailable in this build.\n");
            settings_notify_package_queue_changed_async();
            settings_post_actions_complete_async(NO, @"位置模拟器在此版本中不可用。");
            return;
        }
        if (settings_any_registered_live_loop_running()) {
            log_user("[LOCSIM] Location update deferred: a live SpringBoard tweak is running. Hit Apply Tweaks to serialize the process switch.\n");
            settings_notify_package_queue_changed_async();
            settings_post_actions_complete_async(NO, @"位置刷新已延迟：另一个实时插件正在运行。");
            return;
        }
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            if (__sync_lock_test_and_set(&g_settings_actions_running, 1)) {
                log_user("[LOCSIM] Location update deferred: Apply Tweaks is still running.\n");
                settings_post_actions_complete_async(NO, @"位置刷新已延迟：应用插件正在运行中。");
                settings_notify_package_queue_changed_async();
                return;
            }
            @try {
                if (!settings_ensure_kexploit()) {
                    printf("[LOCSIM] live target refresh failed to acquire KRW\n");
                    log_user("[LOCSIM] Target refresh failed: kernel primitives were not acquired. Please try running chain again.\n");
                    settings_post_actions_complete_async(NO, @"位置刷新失败：未获取到内核原语。");
                    settings_notify_package_queue_changed_async();
                    return;
                }
                if (settings_any_registered_live_loop_running()) {
                    log_user("[LOCSIM] Location update deferred: a live SpringBoard tweak started while recovery was running. Hit Apply Tweaks to serialize the process switch.\n");
                    settings_post_actions_complete_async(NO, @"位置刷新已延迟：另一个实时插件正在运行。");
                    settings_notify_package_queue_changed_async();
                    return;
                }
                @synchronized (settings_rc_lock()) {
                    settings_destroy_springboard_remote_call_locked_internal("switching to Location Simulator", NO);
                    bool ok = settings_apply_location_sim_from_defaults_locked(d);
                    if (ok) {
                        [d setBool:YES forKey:kSettingsLocationSimStarted];
                        [d synchronize];
                    }
                    log_user("%s Location Simulator %s.\n",
                             ok ? "[OK]" : "[WARN]",
                             ok ? "target refreshed" : "did not apply cleanly");
                    settings_post_actions_complete_async(ok,
                        ok ? @"位置坐标已刷新。" : @"位置刷新失败。请检查日志。");
                }
                settings_notify_package_queue_changed_async();
            } @finally {
                __sync_lock_release(&g_settings_actions_running);
            }
        });
        return;
    }

    if (settings_key_is_typebanner(key)) {
        if (!settings_typebanner_install_allowed()) {
            if ([d boolForKey:kSettingsTypeBannerEnabled]) {
                [d setBool:NO forKey:kSettingsTypeBannerEnabled];
                [d synchronize];
            }
            g_typebanner_live_stop_requested = 1;
            settings_mark_tweak_applied(kSettingsTypeBannerEnabled, NO);
            settings_notify_package_queue_changed_async();
            typebanner_forget_remote_state();
            return;
        }
        // TypeBanner owns its own daemon + SpringBoard sessions, but its
        // bootstrap is serialized with the shared RemoteCall lock.
        if ([d boolForKey:kSettingsTypeBannerEnabled]) {
            settings_mark_tweak_applied(kSettingsTypeBannerEnabled, YES);
            settings_notify_package_queue_changed_async();
            settings_start_typebanner_live_loop();
        } else {
            g_typebanner_live_stop_requested = 1;
            settings_mark_tweak_applied(kSettingsTypeBannerEnabled, NO);
            settings_notify_package_queue_changed_async();
            // Best-effort hide if a session is reachable. The live loop will
            // also hide on its own way out, but doing it here gets the pill
            // off the screen faster after the user toggles off.
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                if (g_kexploit_done) {
                    @synchronized (settings_rc_lock()) {
                        RemoteCallSession *springboardSession = [[RemoteCallSession alloc] initWithProcess:@"SpringBoard"
                                                                                         useMigFilterBypass:NO
                                                                                    firstExceptionTimeoutMS:TYPEBANNER_RC_FIRST_EXCEPTION_TIMEOUT_MS];
                        if (springboardSession) {
                            @try {
                                typebanner_release_mobilesms_keepalive_in_springboard_remote_session(springboardSession);
                                typebanner_hide_in_springboard_remote_session(springboardSession);
                            } @catch (NSException *e) {
                                printf("[SETTINGS] TypeBanner toggle-off hide exception: %s\n",
                                       e.reason.UTF8String);
                            }
                            [springboardSession destroyRemoteCall];
                        }
                    }
                }
                typebanner_forget_remote_state();
            });
        }
        return;
    }

    if (settings_key_is_notificationisland(key)) {
        if (!settings_notificationisland_install_allowed()) {
            if ([d boolForKey:kSettingsNotificationIslandEnabled]) {
                [d setBool:NO forKey:kSettingsNotificationIslandEnabled];
                [d synchronize];
            }
            g_notificationisland_live_stop_requested = 1;
            settings_mark_tweak_applied(kSettingsNotificationIslandEnabled, NO);
            settings_notify_package_queue_changed_async();
            notificationisland_forget_remote_state();
            return;
        }
        if ([d boolForKey:kSettingsNotificationIslandEnabled] && g_springboard_rc_ready) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                bool ok = false;
                @synchronized (settings_rc_lock()) {
                    if (settings_cleanup_in_progress() ||
                        ![d boolForKey:kSettingsNotificationIslandEnabled] ||
                        !g_springboard_rc_ready) return;
                    ok = notificationisland_apply_in_session();
                    settings_mark_tweak_applied(kSettingsNotificationIslandEnabled,
                                                ok && [d boolForKey:kSettingsNotificationIslandEnabled]);
                    printf("[SETTINGS] live Notification Island apply result=%d\n", ok);
                }
                if (ok) settings_start_notificationisland_live_loop();
                settings_notify_package_queue_changed_async();
            });
        } else if (![d boolForKey:kSettingsNotificationIslandEnabled]) {
            g_notificationisland_live_stop_requested = 1;
            settings_mark_tweak_applied(kSettingsNotificationIslandEnabled, NO);
            settings_notify_package_queue_changed_async();
            if (g_springboard_rc_ready) {
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    @synchronized (settings_rc_lock()) {
                        if (g_springboard_rc_ready) notificationisland_stop_in_session();
                    }
                });
            } else {
                notificationisland_forget_remote_state();
            }
        }
        return;
    }

    if (settings_key_is_appswitchergrid(key)) {
        if ([d boolForKey:kSettingsAppSwitcherGridEnabled] && g_springboard_rc_ready) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                @synchronized (settings_rc_lock()) {
                    if (settings_cleanup_in_progress() ||
                        ![d boolForKey:kSettingsAppSwitcherGridEnabled] ||
                        !g_springboard_rc_ready) return;
                    bool ok = appswitchergrid_apply_in_session();
                    settings_mark_tweak_applied(kSettingsAppSwitcherGridEnabled,
                                                ok && [d boolForKey:kSettingsAppSwitcherGridEnabled]);
                    printf("[SETTINGS] live App Switcher Grid apply result=%d\n", ok);
                }
                settings_notify_package_queue_changed_async();
            });
        } else if (![d boolForKey:kSettingsAppSwitcherGridEnabled]) {
            settings_mark_tweak_applied(kSettingsAppSwitcherGridEnabled, NO);
            settings_notify_package_queue_changed_async();
            if (g_springboard_rc_ready) {
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    @synchronized (settings_rc_lock()) {
                        if (g_springboard_rc_ready) appswitchergrid_stop_in_session();
                    }
                });
            } else {
                appswitchergrid_forget_remote_state();
            }
        }
        return;
    }

    if (settings_key_is_nsbar(key)) {
        if ([d boolForKey:kSettingsNSBarEnabled] && g_springboard_rc_ready) {
            settings_apply_nsbar_once_async("live settings");
        } else if (![d boolForKey:kSettingsNSBarEnabled]) {
            g_nsbar_live_stop_requested = 1;
            settings_mark_tweak_applied(kSettingsNSBarEnabled, NO);
            settings_notify_package_queue_changed_async();
            if (g_springboard_rc_ready) {
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    @synchronized (settings_rc_lock()) {
                        if (g_springboard_rc_ready) nsbar_stop_in_session();
                    }
                });
            }
        }
        return;
    }

    if (settings_key_is_nicebarlite(key)) {
        BOOL forceWeatherRefresh = [key isEqualToString:kSettingsNiceBarLiteCelsius];
        if (forceWeatherRefresh || [key hasPrefix:kSettingsNiceBarLiteSlotKindPrefix]) {
            settings_nicebar_refresh_weather_if_needed(forceWeatherRefresh, nil);
        }
        if ([d boolForKey:kSettingsNiceBarLiteEnabled] && g_springboard_rc_ready) {
            settings_apply_nicebarlite_once_async("live settings");
        } else if (![d boolForKey:kSettingsNiceBarLiteEnabled]) {
            g_nicebarlite_live_stop_requested = 1;
            settings_mark_tweak_applied(kSettingsNiceBarLiteEnabled, NO);
            settings_notify_package_queue_changed_async();
            if (g_springboard_rc_ready) {
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    @synchronized (settings_rc_lock()) {
                        if (g_springboard_rc_ready) nicebarlite_stop_in_session();
                    }
                });
            }
        }
        return;
    }

    if ([key isEqualToString:kSettingsLiveWPVideoPath]) {
        settings_notify_package_queue_changed_async();
        return;
    }

    if ([key isEqualToString:kSettingsLiveWPEnabled]) {
        if ([d boolForKey:kSettingsLiveWPEnabled] && g_springboard_rc_ready) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                bool ok = false;
                @synchronized (settings_rc_lock()) {
                    if (settings_cleanup_in_progress() ||
                        ![d boolForKey:kSettingsLiveWPEnabled] ||
                        !g_springboard_rc_ready) return;
                    ok = livewp_apply_in_session();
                    settings_mark_tweak_applied(kSettingsLiveWPEnabled, ok);
                }
                printf("[SETTINGS] live LiveWP apply result=%d\n", ok);
                if (ok) settings_start_livewp_live_loop();
                settings_notify_package_queue_changed_async();
            });
        } else if (![d boolForKey:kSettingsLiveWPEnabled]) {
            g_livewp_live_stop_requested = 1;
            settings_mark_tweak_applied(kSettingsLiveWPEnabled, NO);
            settings_notify_package_queue_changed_async();
            if (g_springboard_rc_ready) {
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    @synchronized (settings_rc_lock()) {
                        if (g_springboard_rc_ready) livewp_stop_in_session();
                    }
                });
            }
        }
        return;
    }

    if (settings_key_is_gravitylite(key)) {
        if ([d boolForKey:kSettingsGravityLiteEnabled] && g_springboard_rc_ready) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                @synchronized (settings_rc_lock()) {
                    if (settings_cleanup_in_progress() || !g_springboard_rc_ready) return;
                    bool ok = settings_app_state_is_foreground()
                        ? settings_arm_gravitylite_for_background_start_locked(d, "live settings")
                        : settings_apply_gravitylite_from_defaults_locked(d);
                    settings_mark_tweak_applied(kSettingsGravityLiteEnabled,
                                                ok && [d boolForKey:kSettingsGravityLiteEnabled]);
                    printf("[SETTINGS] live Gravity Lite apply result=%d\n", ok);
                }
                settings_notify_package_queue_changed_async();
            });
        } else if (![d boolForKey:kSettingsGravityLiteEnabled]) {
            __sync_lock_test_and_set(&g_gravitylite_background_armed, 0);
            settings_mark_tweak_applied(kSettingsGravityLiteEnabled, NO);
            settings_notify_package_queue_changed_async();
            if (g_springboard_rc_ready) {
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    @synchronized (settings_rc_lock()) {
                        if (g_springboard_rc_ready) gravitylite_stop_in_session();
                    }
                });
            }
        }
        return;
    }

    if (settings_key_is_axonlite(key)) {
        if ([d boolForKey:kSettingsAxonLiteEnabled] && g_springboard_rc_ready) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                if (!settings_axonlite_can_poll_springboard()) {
                    printf("[SETTINGS] live Axon Lite apply skipped: %s\n",
                           settings_axonlite_pause_reason());
                    settings_start_axonlite_live_loop();
                    settings_notify_package_queue_changed_async();
                    return;
                }
                @synchronized (settings_rc_lock()) {
                    if (settings_cleanup_in_progress() || !g_springboard_rc_ready) return;
                    if (!settings_axonlite_can_poll_springboard()) {
                        printf("[SETTINGS] live Axon Lite apply skipped inside lock: %s\n",
                               settings_axonlite_pause_reason());
                        settings_start_axonlite_live_loop();
                        settings_notify_package_queue_changed_async();
                        return;
                    }
                    bool ok = axonlite_apply_in_session();
                    settings_mark_tweak_applied(kSettingsAxonLiteEnabled,
                                                ok && [d boolForKey:kSettingsAxonLiteEnabled]);
                    printf("[SETTINGS] live Axon Lite apply result=%d\n", ok);
                }
                settings_start_axonlite_live_loop();
                settings_notify_package_queue_changed_async();
            });
        } else if (![d boolForKey:kSettingsAxonLiteEnabled]) {
            g_axonlite_live_stop_requested = 1;
            settings_mark_tweak_applied(kSettingsAxonLiteEnabled, NO);
            settings_notify_package_queue_changed_async();
            if (g_springboard_rc_ready) {
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    @synchronized (settings_rc_lock()) {
                        if (g_springboard_rc_ready) axonlite_stop_in_session();
                    }
                });
            }
        }
        return;
    }

    if (settings_key_is_statbar(key)) {
        if ([d boolForKey:kSettingsStatBarEnabled] && g_springboard_rc_ready) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                @synchronized (settings_rc_lock()) {
                    if (settings_cleanup_in_progress() || !g_springboard_rc_ready) return;
                    bool ok = statbar_apply_in_session([d boolForKey:kSettingsStatBarCelsius],
                                                       [d boolForKey:kSettingsStatBarShowNet],
                                                       [d boolForKey:kSettingsStatBarShowCPU],
                                                       [d boolForKey:kSettingsStatBarShowLabels],
                                                       [d boolForKey:kSettingsStatBarNetworkOnly]);
                    settings_mark_tweak_applied(kSettingsStatBarEnabled,
                                                ok && [d boolForKey:kSettingsStatBarEnabled]);
                    printf("[SETTINGS] live StatBar apply result=%d\n", ok);
                }
                settings_start_statbar_live_loop();
                settings_notify_package_queue_changed_async();
            });
        } else if (![d boolForKey:kSettingsStatBarEnabled]) {
            g_statbar_live_stop_requested = 1;
            settings_mark_tweak_applied(kSettingsStatBarEnabled, NO);
            settings_notify_package_queue_changed_async();
            settings_end_statbar_background_task_async("StatBar disabled");
            if (g_springboard_rc_ready) {
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    @synchronized (settings_rc_lock()) {
                        if (g_springboard_rc_ready) statbar_stop_in_session();
                    }
                });
            }
        }
    }

    if (settings_key_is_rssi(key)) {
        if (!settings_rssi_install_allowed()) {
            if ([d boolForKey:kSettingsRSSIDisplayEnabled]) {
                [d setBool:NO forKey:kSettingsRSSIDisplayEnabled];
                [d synchronize];
            }
            g_rssi_live_stop_requested = 1;
            settings_mark_tweak_applied(kSettingsRSSIDisplayEnabled, NO);
            settings_notify_package_queue_changed_async();
            if (g_springboard_rc_ready) {
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    @synchronized (settings_rc_lock()) {
                        if (g_springboard_rc_ready) rssidisplay_stop_in_session();
                    }
                });
            }
            return;
        }
        if ([d boolForKey:kSettingsRSSIDisplayEnabled] && g_springboard_rc_ready) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                @synchronized (settings_rc_lock()) {
                    if (settings_cleanup_in_progress() || !g_springboard_rc_ready) return;
                    bool ok = rssidisplay_apply_in_session([d boolForKey:kSettingsRSSIDisplayWifi],
                                                           [d boolForKey:kSettingsRSSIDisplayCell]);
                    settings_mark_tweak_applied(kSettingsRSSIDisplayEnabled,
                                                ok && [d boolForKey:kSettingsRSSIDisplayEnabled]);
                    printf("[SETTINGS] live RSSI apply result=%d\n", ok);
                }
                settings_start_rssi_live_loop();
                settings_notify_package_queue_changed_async();
            });
        } else if (![d boolForKey:kSettingsRSSIDisplayEnabled]) {
            g_rssi_live_stop_requested = 1;
            settings_mark_tweak_applied(kSettingsRSSIDisplayEnabled, NO);
            settings_notify_package_queue_changed_async();
            if (g_springboard_rc_ready) {
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    @synchronized (settings_rc_lock()) {
                        if (g_springboard_rc_ready) rssidisplay_stop_in_session();
                    }
                });
            }
        }
        return;
    }

    if (settings_key_is_dark_tweak(key)) {
        if (!g_springboard_rc_ready || ![d boolForKey:key]) return;
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            @synchronized (settings_rc_lock()) {
                if (settings_cleanup_in_progress() || !g_springboard_rc_ready) return;
                SettingsDarkTweaksResult result = settings_apply_dark_tweaks_from_defaults_locked(d);
                bool ok = settings_dark_tweaks_result_all_ok(result);
                if ([d boolForKey:kSettingsDSDisableAppLibrary])
                    settings_mark_tweak_applied(kSettingsDSDisableAppLibrary, result.disableAppLibrary);
                if ([d boolForKey:kSettingsDSDisableIconFlyIn])
                    settings_mark_tweak_applied(kSettingsDSDisableIconFlyIn, result.disableIconFlyIn);
                if ([d boolForKey:kSettingsDSZeroWakeAnimation])
                    settings_mark_tweak_applied(kSettingsDSZeroWakeAnimation, result.zeroWakeAnimation);
                if ([d boolForKey:kSettingsDSZeroBacklightFade])
                    settings_mark_tweak_applied(kSettingsDSZeroBacklightFade, result.zeroBacklightFade);
                if ([d boolForKey:kSettingsDSDoubleTapToLock])
                    settings_mark_tweak_applied(kSettingsDSDoubleTapToLock, result.doubleTapToLock);
                if ([d boolForKey:kSettingsDSDragCoefficientEnabled])
                    settings_mark_tweak_applied(kSettingsDSDragCoefficientEnabled, result.dragCoefficient);
                printf("[SETTINGS] live DarkSword tweak results appLib=%d flyIn=%d wake=%d backlight=%d dblTap=%d drag=%d all=%d\n",
                       [d boolForKey:kSettingsDSDisableAppLibrary] ? result.disableAppLibrary : -1,
                       [d boolForKey:kSettingsDSDisableIconFlyIn] ? result.disableIconFlyIn : -1,
                       [d boolForKey:kSettingsDSZeroWakeAnimation] ? result.zeroWakeAnimation : -1,
                       [d boolForKey:kSettingsDSZeroBacklightFade] ? result.zeroBacklightFade : -1,
                       [d boolForKey:kSettingsDSDoubleTapToLock] ? result.doubleTapToLock : -1,
                       [d boolForKey:kSettingsDSDragCoefficientEnabled] ? result.dragCoefficient : -1,
                       ok);
            }
            settings_notify_package_queue_changed_async();
        });
        return;
    }

    if (!settings_key_is_sbc(key) || !g_springboard_rc_ready) return;

    uint64_t generation = __sync_add_and_fetch(&g_sbc_live_apply_generation, 1);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(250 * NSEC_PER_MSEC)),
                   dispatch_get_global_queue(0, 0), ^{
        if (generation != g_sbc_live_apply_generation) return;
        if (settings_cleanup_in_progress()) return;

        @synchronized (settings_rc_lock()) {
            if (settings_cleanup_in_progress() || !g_springboard_rc_ready) return;
            bool ok = settings_apply_sbc_from_defaults_locked(d);
            settings_mark_tweak_applied(kSettingsSBCEnabled,
                                        ok && [d boolForKey:kSettingsSBCEnabled]);
            printf("[SETTINGS] live SBC apply result=%d\n", ok);
        }
        settings_notify_package_queue_changed_async();
    });
}

void settings_register_defaults(void)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:@{
        kSettingsAutoRunKexploit:    @NO,
        kSettingsRunSandboxEscape:   @YES,
        kSettingsRunPatchSandboxExt: @NO,
        kSettingsKeepAlive:          @YES,

        kSettingsSBCEnabled:    @NO,
        kSettingsSBCDockIcons:  @(kSBCDefaultDockIcons),
        kSettingsSBCCols:       @(kSBCDefaultCols),
        kSettingsSBCRows:       @(kSBCDefaultRows),
        kSettingsSBCHideLabels: @(kSBCDefaultHideLabels),

        kSettingsPowercuffEnabled: @NO,
        kSettingsPowercuffLevel:   @"nominal",

        kSettingsDSDisableAppLibrary: @NO,
        kSettingsDSDisableIconFlyIn:  @NO,
        kSettingsDSZeroWakeAnimation: @NO,
        kSettingsDSZeroBacklightFade: @NO,
        kSettingsDSDoubleTapToLock:   @NO,

        kSettingsDSDragCoefficientEnabled: @NO,
        kSettingsDSDragCoefficientValue:   @0.5,

        kSettingsLayoutExtrasEnabled:       @NO,
        kSettingsLayoutHomeExtraLeft:       @0,
        kSettingsLayoutHomeExtraRight:      @0,
        kSettingsLayoutHomeExtraTop:        @0,
        kSettingsLayoutHomeExtraBottom:     @0,
        kSettingsLayoutDockExtraHorizontal: @0,
        kSettingsLayoutHomeScalePct:        @100,
        kSettingsLayoutDockScalePct:        @100,

        kSettingsStatBarEnabled: @NO,
        kSettingsStatBarCelsius: @NO,
        kSettingsStatBarShowNet:    @NO,
        kSettingsStatBarShowCPU:    @YES,
        kSettingsStatBarShowLabels: @YES,
        kSettingsStatBarNetworkOnly: @NO,
        kSettingsStatBarRefreshRateSec: @(kStatBarDefaultRefreshRateSec),

        kSettingsNSBarEnabled: @NO,
        kSettingsNSBarPosition: @(NSBarPositionTopLeft),

        kSettingsNiceBarLiteEnabled: @NO,
        kSettingsNiceBarLiteCelsius: @YES,
        kSettingsNiceBarLiteLayoutTopSideInset: @0,
        kSettingsNiceBarLiteLayoutBottomSideInset: @0,
        kSettingsNiceBarLiteLayoutTopY: @0,
        kSettingsNiceBarLiteLayoutBottomY: @0,
        kSettingsNiceBarLiteLayoutCenterX: @0,
        settings_nicebar_key(kSettingsNiceBarLiteSlotKindPrefix, NiceBarLiteSlotTopLeft): @(NiceBarLiteContentTimeFormat),
        settings_nicebar_key(kSettingsNiceBarLiteSlotKindPrefix, NiceBarLiteSlotTopRight): @(NiceBarLiteContentSystem),
        settings_nicebar_key(kSettingsNiceBarLiteSlotKindPrefix, NiceBarLiteSlotBottomLeft): @(NiceBarLiteContentSystem),
        settings_nicebar_key(kSettingsNiceBarLiteSlotKindPrefix, NiceBarLiteSlotBottomRight): @(NiceBarLiteContentOff),
        settings_nicebar_key(kSettingsNiceBarLiteSlotKindPrefix, NiceBarLiteSlotBottomCenter): @(NiceBarLiteContentOff),
        settings_nicebar_key(kSettingsNiceBarLiteSlotSystemPrefix, NiceBarLiteSlotTopRight): @(NiceBarLiteSystemBatteryPercent),
        settings_nicebar_key(kSettingsNiceBarLiteSlotSystemPrefix, NiceBarLiteSlotBottomLeft): @(NiceBarLiteSystemFreeRAM),
        settings_nicebar_key(kSettingsNiceBarLiteSlotTimePrefix, NiceBarLiteSlotTopLeft): @"HH:mm",
        settings_nicebar_key(kSettingsNiceBarLiteSlotSystemLanguagePrefix, NiceBarLiteSlotTopRight): @"en",
        settings_nicebar_key(kSettingsNiceBarLiteSlotSystemLanguagePrefix, NiceBarLiteSlotBottomLeft): @"en",
        settings_nicebar_key(kSettingsNiceBarLiteSlotWeatherLanguagePrefix, NiceBarLiteSlotTopLeft): @"en",
        settings_nicebar_key(kSettingsNiceBarLiteSlotWeatherLanguagePrefix, NiceBarLiteSlotTopRight): @"en",
        settings_nicebar_key(kSettingsNiceBarLiteSlotWeatherLanguagePrefix, NiceBarLiteSlotBottomLeft): @"en",
        settings_nicebar_key(kSettingsNiceBarLiteSlotWeatherLanguagePrefix, NiceBarLiteSlotBottomRight): @"en",
        settings_nicebar_key(kSettingsNiceBarLiteSlotWeatherLanguagePrefix, NiceBarLiteSlotBottomCenter): @"en",
        kSettingsNiceBarLiteWeatherCache: @"天气 --",

        kSettingsRSSIDisplayEnabled: @NO,
        kSettingsRSSIDisplayWifi:    @YES,
        kSettingsRSSIDisplayCell:    @YES,

        kSettingsAxonLiteEnabled: @NO,

        kSettingsTypeBannerEnabled: @NO,
        kSettingsNotificationIslandEnabled: @NO,

        kSettingsFastLockXLiteEnabled: @NO,
        kSettingsFastLockXLiteBlockMusic: @NO,
        kSettingsFastLockXLiteBlockFlashlight: @NO,
        kSettingsFastLockXLiteBlockLowPower: @NO,
        kSettingsFastLockXLiteRetryInterval: @0.5,

        kSettingsGravityLiteEnabled: @NO,
        kSettingsGravityLiteDockEnabled: @YES,
        kSettingsGravityLiteMagnitudePct: @100,
        kSettingsGravityLiteBouncePct: @50,
        kSettingsGravityLiteFrictionPct: @50,
        kSettingsGravityLiteResistancePct: @50,
        kSettingsGravityLiteAngularResistancePct: @0,

        kSettingsStageStripEnabled: @NO,

        kSettingsLocationSimEnabled: @NO,
        kSettingsLocationSimLatitude: @(kLocationSimDefaultLatitude),
        kSettingsLocationSimLongitude: @(kLocationSimDefaultLongitude),
        kSettingsLocationSimAltitude: @(kLocationSimDefaultAltitude),
        kSettingsLocationSimHorizontalAccuracy: @(kLocationSimDefaultAccuracy),
        kSettingsLocationSimHostProcess: @"Maps",
        kSettingsLocationSimStarted: @NO,
        kSettingsIPADecryptorTargetBundleID: @"",
        kSettingsIPADecryptorAppStoreInput: @"",
        kSettingsIPADecryptorAppStoreID: @"",
        kSettingsIPADecryptorAppStoreName: @"",
        kSettingsIPADecryptorAppStoreVersion: @"",
        kSettingsIPADecryptorAppStoreURL: @"",
        kSettingsIPADecryptorDownloadedIPAPath: @"",
        kSettingsIPADecryptorDownloadStatus: @"未开始。",

        kSettingsThemerEnabled: @NO,
        kSettingsThemerThemeID: kThemerThemeNone,
        kSettingsThemerCustomThemePath: @"",
        kSettingsThemerCustomThemeName: @"",

        kSettingsSnowBoardLiteEnabled: @NO,
        kSettingsSnowBoardLiteSelectedThemeID: @"",

        kSettingsLiveWPEnabled: @NO,
        kSettingsLiveWPVideoPath: @"",

        kSettingsAppSwitcherGridEnabled: @NO,

        kSettingsExperimentalTweaksEnabled: @NO,

        kSettingsNanoMaxPairing:       @(kNanoDefaultMaxPairing),
        kSettingsNanoMinPairing:       @(kNanoDefaultMinPairing),
        kSettingsNanoMinPairingChipID: @(kNanoDefaultMinPairingChipID),
        kSettingsNanoMinQuickSwitch:   @(kNanoDefaultMinQuickSwitch),
    }];
    if (!cyanide_private_tweaks_available()) {
        BOOL changed = NO;
        NSArray<NSString *> *privateKeys = @[
            kSettingsRSSIDisplayEnabled,
            kSettingsTypeBannerEnabled,
            kSettingsNotificationIslandEnabled,
            kSettingsStageStripEnabled,
        ];
        for (NSString *key in privateKeys) {
            if ([defaults boolForKey:key]) {
                [defaults setBool:NO forKey:key];
                changed = YES;
            }
        }
        if (changed) [defaults synchronize];
    }
    if (!settings_experimental_access_allowed()) {
        if ([defaults boolForKey:kSettingsExperimentalTweaksEnabled]) {
            [defaults setBool:NO forKey:kSettingsExperimentalTweaksEnabled];
        }
        if ([defaults boolForKey:kSettingsRSSIDisplayEnabled]) {
            [defaults setBool:NO forKey:kSettingsRSSIDisplayEnabled];
        }
        if ([defaults boolForKey:kSettingsTypeBannerEnabled]) {
            [defaults setBool:NO forKey:kSettingsTypeBannerEnabled];
        }
        if ([defaults boolForKey:kSettingsNotificationIslandEnabled]) {
            [defaults setBool:NO forKey:kSettingsNotificationIslandEnabled];
        }
        if ([defaults boolForKey:kSettingsStageStripEnabled]) {
            [defaults setBool:NO forKey:kSettingsStageStripEnabled];
        }
        [defaults synchronize];
    } else if (![defaults boolForKey:kSettingsExperimentalTweaksEnabled]) {
        BOOL changed = NO;
        if ([defaults boolForKey:kSettingsRSSIDisplayEnabled]) {
            [defaults setBool:NO forKey:kSettingsRSSIDisplayEnabled];
            changed = YES;
        }
        if ([defaults boolForKey:kSettingsTypeBannerEnabled]) {
            [defaults setBool:NO forKey:kSettingsTypeBannerEnabled];
            changed = YES;
        }
        if ([defaults boolForKey:kSettingsNotificationIslandEnabled]) {
            [defaults setBool:NO forKey:kSettingsNotificationIslandEnabled];
            changed = YES;
        }
        if ([defaults boolForKey:kSettingsStageStripEnabled]) {
            [defaults setBool:NO forKey:kSettingsStageStripEnabled];
            changed = YES;
        }
        if (changed) [defaults synchronize];
    }
    if ([defaults boolForKey:kSettingsThemerEnabled]) {
        [defaults setBool:NO forKey:kSettingsThemerEnabled];
        [defaults synchronize];
    }
    if ([defaults boolForKey:kSettingsSnowBoardLiteEnabled] &&
        !settings_snowboardlite_has_selected_theme()) {
        [defaults setBool:NO forKey:kSettingsSnowBoardLiteEnabled];
        [defaults synchronize];
    }
    settings_install_screen_awake_observers();
}

static void settings_run_actions_internal(BOOL pendingOnly)
{
    if (!settings_device_supported()) {
        NSString *message = settings_unsupported_message();
        printf("[SETTINGS] run blocked: %s\n", message.UTF8String);
        log_user("[RUN] %s\n", message.UTF8String);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:PackageQueueDidChangeNotification
                                                                object:[PackageQueue sharedQueue]];
        });
        settings_post_actions_complete_async(NO, message);
        return;
    }

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if (__sync_lock_test_and_set(&g_settings_actions_running, 1)) {
            __sync_lock_test_and_set(&g_settings_actions_rerun_requested, 1);
            printf("[SETTINGS] actions already running; queued one follow-up run\n");
            log_user("[RUN] Already running. Queued one follow-up run for the latest package state.\n");
            return;
        }
        if (!pendingOnly && settings_any_registered_live_loop_running()) {
            settings_request_all_live_loops_stop("Apply Tweaks");
            settings_wait_live_loops_stopped_for_switch("Apply Tweaks");
        }
        log_session_begin();
        cyanide_start_session_uploads();
        BOOL runSucceeded = NO;
        BOOL runHadBlockingFailure = NO;
        NSString *runCompletionMessage = @"运行失败。请查看日志了解详情。";
        @try {
            BOOL patchSandboxExt = [d boolForKey:kSettingsRunPatchSandboxExt];
            BOOL runPowercuff = settings_enabled_tweak_should_run(d, kSettingsPowercuffEnabled, pendingOnly);
            BOOL forceSpringBoardRefresh = runPowercuff &&
                                           settings_has_persistent_springboard_remote_call_user();
            BOOL springBoardPendingOnly = pendingOnly && !forceSpringBoardRefresh;
            BOOL statBarEnabled = [d boolForKey:kSettingsStatBarEnabled];
            BOOL nsBarEnabled = [d boolForKey:kSettingsNSBarEnabled];
            BOOL niceBarLiteEnabled = [d boolForKey:kSettingsNiceBarLiteEnabled];
            BOOL rssiEnabled = settings_rssi_install_allowed() && [d boolForKey:kSettingsRSSIDisplayEnabled];
            BOOL axonLiteEnabled = [d boolForKey:kSettingsAxonLiteEnabled];
            BOOL typeBannerEnabled = settings_typebanner_install_allowed() && [d boolForKey:kSettingsTypeBannerEnabled];
            BOOL notificationIslandEnabled = settings_notificationisland_install_allowed() && [d boolForKey:kSettingsNotificationIslandEnabled];
            BOOL appSwitcherGridEnabled = [d boolForKey:kSettingsAppSwitcherGridEnabled];
            BOOL themerEnabled = [d boolForKey:kSettingsThemerEnabled];
            BOOL snowboardLiteEnabled = [d boolForKey:kSettingsSnowBoardLiteEnabled];
            BOOL liveWPEnabled = [d boolForKey:kSettingsLiveWPEnabled];
            BOOL layoutExtrasEnabled = [d boolForKey:kSettingsLayoutExtrasEnabled];
            BOOL stageStripEnabled = settings_stagestrip_install_allowed() && [d boolForKey:kSettingsStageStripEnabled];
            BOOL gravityLiteEnabled = [d boolForKey:kSettingsGravityLiteEnabled];
            BOOL runSBC = settings_enabled_tweak_should_run(d, kSettingsSBCEnabled, springBoardPendingOnly);
            BOOL runDarkTweaks = settings_dark_tweaks_should_run(d, springBoardPendingOnly);
            BOOL runStatBar = settings_enabled_tweak_should_run(d, kSettingsStatBarEnabled, springBoardPendingOnly);
            BOOL runNSBar = settings_enabled_tweak_should_run(d, kSettingsNSBarEnabled, springBoardPendingOnly);
            BOOL runNiceBarLite = settings_enabled_tweak_should_run(d, kSettingsNiceBarLiteEnabled, springBoardPendingOnly);
            BOOL runRSSI = settings_rssi_install_allowed() && settings_enabled_tweak_should_run(d, kSettingsRSSIDisplayEnabled, springBoardPendingOnly);
            BOOL runAxonLite = settings_enabled_tweak_should_run(d, kSettingsAxonLiteEnabled, springBoardPendingOnly);
            BOOL runTypeBanner = settings_typebanner_install_allowed() && settings_enabled_tweak_should_run(d, kSettingsTypeBannerEnabled, springBoardPendingOnly);
            BOOL runNotificationIsland = settings_notificationisland_install_allowed() && settings_enabled_tweak_should_run(d, kSettingsNotificationIslandEnabled, springBoardPendingOnly);
            BOOL runAppSwitcherGrid = settings_enabled_tweak_should_run(d, kSettingsAppSwitcherGridEnabled, springBoardPendingOnly);
            BOOL runThemer = settings_enabled_tweak_should_run(d, kSettingsThemerEnabled, springBoardPendingOnly);
            BOOL runSnowBoardLite = settings_enabled_tweak_should_run(d, kSettingsSnowBoardLiteEnabled, springBoardPendingOnly);
            BOOL runLiveWP = settings_enabled_tweak_should_run(d, kSettingsLiveWPEnabled, springBoardPendingOnly);
            BOOL runLayoutExtras = settings_enabled_tweak_should_run(d, kSettingsLayoutExtrasEnabled, springBoardPendingOnly);
            BOOL runStageStrip = settings_stagestrip_install_allowed() && settings_enabled_tweak_should_run(d, kSettingsStageStripEnabled, springBoardPendingOnly);
            BOOL runGravityLite = settings_enabled_tweak_should_run(d, kSettingsGravityLiteEnabled, springBoardPendingOnly);
            BOOL stagePausesThemerLive = settings_themer_dynamic_updates_blocked_by_stage(d);
            if (stagePausesThemerLive) {
                settings_note_themer_stage_conflict(YES);
            }
            BOOL cleanupDisabledSpringBoardTweaks = settings_disabled_applied_springboard_cleanup_needed(d);
            BOOL needsSpringBoardWork = runSBC || runDarkTweaks || runStatBar || runNSBar || runNiceBarLite || runRSSI || runAxonLite || runGravityLite || runLayoutExtras || runTypeBanner || runNotificationIsland || runAppSwitcherGrid || runThemer || runSnowBoardLite || runLiveWP || runStageStrip || cleanupDisabledSpringBoardTweaks;
            BOOL runSandboxEscape = [d boolForKey:kSettingsRunSandboxEscape] && (!pendingOnly || needsSpringBoardWork);
            // TypeBanner prewarms its hidden SpringBoard window during Apply
            // and reuses the open SpringBoard session for text-only updates.
            BOOL needsSpringBoard = runSandboxEscape || needsSpringBoardWork || forceSpringBoardRefresh;

            BOOL hasRunWork = patchSandboxExt || runPowercuff || needsSpringBoard;
            NSUInteger total = hasRunWork ? 1 : 0;
            if (patchSandboxExt) total++;
            if (runPowercuff) total++;
            if (needsSpringBoard) total++;
            if (runSandboxEscape) total++;
            if (runSBC) total++;
            if (runDarkTweaks) total++;
            if (runLayoutExtras) total++;
            if (runThemer) total++;
            if (runSnowBoardLite) total++;
            if (runLiveWP) total++;
            if (runStatBar) total++;
            if (runNSBar) total++;
            if (runNiceBarLite) total++;
            if (runRSSI) total++;
            if (runAxonLite) total++;
            if (runGravityLite) total++;
            if (runTypeBanner) total++;
            if (runNotificationIsland) total++;
            if (runAppSwitcherGrid) total++;
            if (runStageStrip) total++;
            if (cleanupDisabledSpringBoardTweaks) total++;
            NSUInteger step = 0;
            BOOL startStageStripControlLoopAfterInstall = NO;

            settings_log_run_context();
            NSMutableArray *enabledTweaks = [NSMutableArray array];
            if (runSBC) [enabledTweaks addObject:@"layout"];
            if (runLayoutExtras) [enabledTweaks addObject:@"extras"];
            if (runStatBar) [enabledTweaks addObject:@"statbar"];
            if (runNSBar) [enabledTweaks addObject:@"nsbar"];
            if (runNiceBarLite) [enabledTweaks addObject:@"nicebar"];
            if (runRSSI) [enabledTweaks addObject:@"rssi"];
            if (runAxonLite) [enabledTweaks addObject:@"axon"];
            if (runNotificationIsland) [enabledTweaks addObject:@"notification-island"];
            if (runAppSwitcherGrid) [enabledTweaks addObject:@"app-switcher-grid"];
            if (runGravityLite) [enabledTweaks addObject:[NSString stringWithFormat:@"gravity(%ld%%)", (long)[d integerForKey:kSettingsGravityLiteMagnitudePct]]];
            if (runPowercuff) [enabledTweaks addObject:[NSString stringWithFormat:@"power(%@)", [d stringForKey:kSettingsPowercuffLevel] ?: @"nominal"]];
            if (runDarkTweaks) [enabledTweaks addObject:@"dark"];
            if (runThemer) [enabledTweaks addObject:@"themer"];
            if (runSnowBoardLite) [enabledTweaks addObject:@"snowboardlite"];
            if (runLiveWP) [enabledTweaks addObject:@"livewp"];
            if (runTypeBanner) [enabledTweaks addObject:@"typebanner"];
            if (runStageStrip) [enabledTweaks addObject:@"stagestrip"];
            if (cleanupDisabledSpringBoardTweaks) [enabledTweaks addObject:@"cleanup"];
            if (forceSpringBoardRefresh) [enabledTweaks addObject:@"springboard-refresh"];
            log_user("[PLAN] %lu stages: %s\n",
                     (unsigned long)total,
                     enabledTweaks.count ? [[enabledTweaks componentsJoinedByString:@", "] UTF8String] : "none");
            cyanide_upload_log_milestone(@"run-plan");

            if (!hasRunWork) {
                if (!statBarEnabled) g_statbar_live_stop_requested = 1;
                if (!nsBarEnabled) g_nsbar_live_stop_requested = 1;
                if (!niceBarLiteEnabled) g_nicebarlite_live_stop_requested = 1;
                if (!rssiEnabled) g_rssi_live_stop_requested = 1;
                if (!axonLiteEnabled) g_axonlite_live_stop_requested = 1;
                if (!typeBannerEnabled) g_typebanner_live_stop_requested = 1;
                if (!notificationIslandEnabled) g_notificationisland_live_stop_requested = 1;
                if (!themerEnabled && !snowboardLiteEnabled) g_themer_live_stop_requested = 1;
                if (!liveWPEnabled) g_livewp_live_stop_requested = 1;
                if (!gravityLiteEnabled) settings_request_gravitylite_stop();
                if (!stageStripEnabled) settings_request_stagestrip_stop();
                log_user("[DONE] No pending runtime changes to apply.\n");
                runSucceeded = YES;
                runCompletionMessage = @"完成。没有待处理的运行时更改需要应用。";
                cyanide_upload_log_milestone(@"run-noop");
                return;
            }

            settings_progress(&step, total, "正在竞争内核分配器获取读写原语");
            if (!settings_ensure_kexploit()) {
                log_user("[RUN] Failed: kernel primitives were not acquired. Please try running chain again.\n");
                runCompletionMessage = @"失败：未获取到内核原语。请重新运行链。";
                cyanide_upload_log_milestone(@"krw-failed");
                return;
            }
            log_user("[OK] Kernel r/w armed — injection staged.\n");
            cyanide_upload_log_milestone(@"krw-ready");

            if (patchSandboxExt) {
                settings_progress(&step, total, "正在修补沙箱扩展路径");
                escape_sbx_demo3();
                log_user("[OK] Sandbox extension issue path patched.\n");
                cyanide_upload_log_milestone(@"sandbox-ext-patched");
            }
            if (runPowercuff) {
                settings_progress(&step, total, "正在通过温控守护进程（thermalmonitord）应用 Powercuff");
                if (g_springboard_rc_ready || settings_any_registered_live_loop_running()) {
                    settings_request_all_live_loops_stop("Powercuff process switch");
                    settings_wait_live_loops_stopped_for_switch("Powercuff process switch");
                }
                @synchronized (settings_rc_lock()) {
                    // This is only a transient RemoteCall target switch. Do
                    // not run SpringBoard tweak stop paths or clear applied
                    // package state; enabled tweaks are reapplied below.
                    settings_destroy_springboard_remote_call_locked_internal("switching to thermalmonitord", NO);
                    NSString *lvl = [d stringForKey:kSettingsPowercuffLevel] ?: @"nominal";
                    bool ok = powercuff_apply(lvl.UTF8String);
                    settings_mark_tweak_applied(kSettingsPowercuffEnabled,
                                                ok && [d boolForKey:kSettingsPowercuffEnabled]);
                    log_user("%s Powercuff %s through thermalmonitord.\n",
                             ok ? "[OK]" : "[WARN]",
                             ok ? "applied" : "did not apply cleanly");
                    cyanide_upload_log_milestone(ok ? @"powercuff-applied" : @"powercuff-failed");
                }
            }

            if (needsSpringBoard) {
                @synchronized (settings_rc_lock()) {
                    settings_progress(&step, total, "正在打开主屏幕（SpringBoard）注入通道");
                    if (!settings_ensure_springboard_remote_call_locked()) {
                        log_user("[RUN] Failed: could not open the SpringBoard control session. Please try installing tweaks again.\n");
                        runCompletionMessage = @"失败：无法打开主屏幕（SpringBoard）控制通道。请尝试重新安装插件。";
                        cyanide_upload_log_milestone(@"springboard-remote-call-failed");
                        return;
                    }
                    log_user("[OK] SpringBoard channel open.\n");
                    cyanide_upload_log_milestone(@"springboard-remote-call-ready");

                    if (runSandboxEscape && !g_springboard_sandbox_escaped) {
                        settings_progress(&step, total, "正在解除主屏幕（SpringBoard）文件系统沙盒");
                        int sbx = escape_sbx_demo2_in_session();
                        g_springboard_sandbox_escaped = (sbx == 0);
                        log_user("%s Filesystem sandbox %s.\n",
                                 sbx == 0 ? "[OK]" : "[WARN]",
                                 sbx == 0 ? "lifted — access granted" : "lift returned a warning");
                        cyanide_upload_log_milestone(sbx == 0 ? @"springboard-sandbox-token-ready" : @"springboard-sandbox-token-warning");
                    } else if (runSandboxEscape) {
                        settings_progress(&step, total, "正在复用上次运行获取的沙盒令牌");
                        log_user("[OK] Sandbox already lifted — reusing token.\n");
                        cyanide_upload_log_milestone(@"springboard-sandbox-token-reused");
                    }

                    if (cleanupDisabledSpringBoardTweaks) {
                        settings_progress(&step, total, "正在停止已禁用的主屏幕（SpringBoard）插件");
                        settings_stop_disabled_applied_springboard_tweaks_locked(d);
                        cyanide_upload_log_milestone(@"disabled-springboard-tweaks-stopped");
                    }

                    if (runTypeBanner) {
                        bool ok = typebanner_prepare_in_springboard_session();
                        log_user("%s TypeBanner overlay window %s.\n",
                                 ok ? "[OK]" : "[WARN]",
                                 ok ? "prewarmed" : "did not prewarm");
                        cyanide_upload_log_milestone(ok ? @"typebanner-overlay-prewarmed" : @"typebanner-overlay-prewarm-failed");
                    }

                    if (runSBC) {
                        settings_progress(&step, total, "正在应用图标布局缓存");
                        bool ok = settings_apply_sbc_from_defaults_locked(d);
                        settings_mark_tweak_applied(kSettingsSBCEnabled,
                                                    ok && [d boolForKey:kSettingsSBCEnabled]);
                        log_user("%s Home screen layout %s; dock=%ld home=%ldx%ld.\n",
                                 ok ? "[OK]" : "[WARN]",
                                 ok ? "applied" : "may need a refresh",
                                 (long)[d integerForKey:kSettingsSBCDockIcons],
                                 (long)[d integerForKey:kSettingsSBCCols],
                                 (long)[d integerForKey:kSettingsSBCRows]);
                        cyanide_upload_log_milestone(ok ? @"sbc-applied" : @"sbc-warning");
                    }

                    if (runDarkTweaks) {
                        settings_progress(&step, total, "正在应用 DarkSword 运行时 hooks");
                        SettingsDarkTweaksResult result = settings_apply_dark_tweaks_from_defaults_locked(d);
                        bool ok = settings_dark_tweaks_result_all_ok(result);
                        if ([d boolForKey:kSettingsDSDisableAppLibrary])
                            settings_mark_tweak_applied(kSettingsDSDisableAppLibrary, result.disableAppLibrary);
                        if ([d boolForKey:kSettingsDSDisableIconFlyIn])
                            settings_mark_tweak_applied(kSettingsDSDisableIconFlyIn, result.disableIconFlyIn);
                        if ([d boolForKey:kSettingsDSZeroWakeAnimation])
                            settings_mark_tweak_applied(kSettingsDSZeroWakeAnimation, result.zeroWakeAnimation);
                        if ([d boolForKey:kSettingsDSZeroBacklightFade])
                            settings_mark_tweak_applied(kSettingsDSZeroBacklightFade, result.zeroBacklightFade);
                        if ([d boolForKey:kSettingsDSDoubleTapToLock])
                            settings_mark_tweak_applied(kSettingsDSDoubleTapToLock, result.doubleTapToLock);
                        if ([d boolForKey:kSettingsDSDragCoefficientEnabled])
                            settings_mark_tweak_applied(kSettingsDSDragCoefficientEnabled, result.dragCoefficient);
                        printf("[SETTINGS] DarkSword tweak results appLib=%d flyIn=%d wake=%d backlight=%d dblTap=%d drag=%d all=%d\n",
                               [d boolForKey:kSettingsDSDisableAppLibrary] ? result.disableAppLibrary : -1,
                               [d boolForKey:kSettingsDSDisableIconFlyIn] ? result.disableIconFlyIn : -1,
                               [d boolForKey:kSettingsDSZeroWakeAnimation] ? result.zeroWakeAnimation : -1,
                               [d boolForKey:kSettingsDSZeroBacklightFade] ? result.zeroBacklightFade : -1,
                               [d boolForKey:kSettingsDSDoubleTapToLock] ? result.doubleTapToLock : -1,
                               [d boolForKey:kSettingsDSDragCoefficientEnabled] ? result.dragCoefficient : -1,
                               ok);
                        log_user("%s DarkSword hooks %s.\n",
                                 ok ? "[OK]" : "[WARN]",
                                 ok ? "applied" : "may need a refresh");
                        cyanide_upload_log_milestone(ok ? @"darksword-tweaks-applied" : @"darksword-tweaks-warning");
                    }

                    if (runLayoutExtras) {
                        settings_progress(&step, total, "正在应用主屏幕布局扩展");
                        bool ok = settings_apply_layout_extras_from_defaults_locked(d);
                        settings_mark_tweak_applied(kSettingsLayoutExtrasEnabled, ok);
                        printf("[SETTINGS] Layout extras result=%d\n", ok);
                        log_user("%s Home Layout Extras %s.\n",
                                 ok ? "[OK]" : "[WARN]",
                                 ok ? "applied" : "did not apply cleanly");
                        cyanide_upload_log_milestone(ok ? @"layout-extras-applied" : @"layout-extras-warning");
                    }

                    if (runThemer) {
                        settings_progress(&step, total, "正在应用图标主题引擎");
                        bool ok = settings_apply_themer_from_defaults_locked(d);
                        settings_mark_tweak_applied(kSettingsThemerEnabled, ok);
                        printf("[SETTINGS] Themer result=%d\n", ok);
                        log_user("%s Icon Theme Engine %s.\n",
                                 ok ? "[OK]" : "[WARN]",
                                 ok ? "applied" : "did not apply cleanly");
                        cyanide_upload_log_milestone(ok ? @"themer-applied" : @"themer-warning");
                        if (ok) {
                            settings_start_themer_live_loop();
                        }
                    }

                    if (runSnowBoardLite) {
                        settings_progress(&step, total, "正在应用 SnowBoard Lite 主题");
                        bool ok = settings_apply_snowboardlite_from_defaults_locked(d);
                        settings_mark_tweak_applied(kSettingsSnowBoardLiteEnabled,
                                                    ok && [d boolForKey:kSettingsSnowBoardLiteEnabled]);
                        printf("[SETTINGS] SnowBoard Lite result=%d\n", ok);
                        log_user("%s SnowBoard Lite %s.\n",
                                 ok ? "[OK]" : "[WARN]",
                                 ok ? "theme applied" : "did not apply cleanly");
                        cyanide_upload_log_milestone(ok ? @"snowboard-lite-applied" : @"snowboard-lite-warning");
                        if (ok) {
                            settings_start_themer_live_loop();
                        }
                    }

                    if (runGravityLite) {
                        settings_progress(&step, total, "正在启动 Gravity Lite 图标物理效果");
                        log_user("[GRAVITY] Preparing icon physics state...\n");
                        __sync_lock_test_and_set(&g_gravitylite_background_armed, 0);
                        settings_stop_gravity_motion();
                        gravitylite_stop_in_session();
                        GravityLiteConfig glConfig = settings_gravitylite_config_from_defaults(d);
                        bool ok = gravitylite_apply_in_session(glConfig);
                        settings_mark_tweak_applied(kSettingsGravityLiteEnabled,
                                                    ok && [d boolForKey:kSettingsGravityLiteEnabled]);
                        if (ok) {
                            log_user("[GRAVITY] Starting tilt sensor feed...\n");
                            settings_start_gravity_motion(glConfig.magnitude,
                                                          glConfig.explosionForce);
                        }
                        if (ok) {
                            log_user("[OK] Gravity Lite active.\n");
                            cyanide_upload_log_milestone(@"gravity-lite-applied");
                        } else {
                            log_user("[WARN] Gravity Lite did not start cleanly.\n");
                            cyanide_upload_log_milestone(@"gravity-lite-warning");
                            runHadBlockingFailure = YES;
                            runCompletionMessage = @"Gravity Lite 未能正常启动。";
                        }
                    } else if (!gravityLiteEnabled) {
                        __sync_lock_test_and_set(&g_gravitylite_background_armed, 0);
                        settings_stop_gravity_motion();
                        gravitylite_stop_in_session();
                    }

                    if (runStatBar) {
                        settings_progress(&step, total, "正在启动 StatBar 叠加层与实时数据");
                        bool ok = statbar_apply_in_session([d boolForKey:kSettingsStatBarCelsius],
                                                           [d boolForKey:kSettingsStatBarShowNet],
                                                           [d boolForKey:kSettingsStatBarShowCPU],
                                                           [d boolForKey:kSettingsStatBarShowLabels],
                                                           [d boolForKey:kSettingsStatBarNetworkOnly]);
                        settings_mark_tweak_applied(kSettingsStatBarEnabled,
                                                    ok && [d boolForKey:kSettingsStatBarEnabled]);
                        log_user("%s StatBar %s.\n",
                                 ok ? "[OK]" : "[WARN]",
                                 ok ? "showing thermal + memory overlay" : "did not start cleanly");
                        cyanide_upload_log_milestone(ok ? @"statbar-initial-applied" : @"statbar-initial-failed");
                    }

                    if (runNSBar) {
                        settings_progress(&step, total, "正在启动 NSBar 网速叠加层");
                        bool ok = nsbar_apply_in_session((NSBarPosition)[d integerForKey:kSettingsNSBarPosition]);
                        settings_mark_tweak_applied(kSettingsNSBarEnabled,
                                                    ok && [d boolForKey:kSettingsNSBarEnabled]);
                        printf("[SETTINGS] NSBar result=%d\n", ok);
                        log_user("%s NSBar %s.\n",
                                 ok ? "[OK]" : "[WARN]",
                                 ok ? "showing network speed" : "did not start cleanly");
                        cyanide_upload_log_milestone(ok ? @"nsbar-initial-applied" : @"nsbar-initial-failed");
                    }

                    if (runNiceBarLite) {
                        settings_progress(&step, total, "正在启动 NiceBar Lite 标签");
                        settings_nicebar_refresh_weather_if_needed(!settings_nicebar_has_resolved_weather(d), nil);
                        bool ok = settings_apply_nicebarlite_from_defaults_locked(d);
                        settings_mark_tweak_applied(kSettingsNiceBarLiteEnabled,
                                                    ok && [d boolForKey:kSettingsNiceBarLiteEnabled]);
                        printf("[SETTINGS] NiceBar Lite result=%d\n", ok);
                        log_user("%s NiceBar Lite %s.\n",
                                 ok ? "[OK]" : "[WARN]",
                                 ok ? "labels active" : "did not start cleanly");
                        cyanide_upload_log_milestone(ok ? @"nicebar-lite-initial-applied" : @"nicebar-lite-initial-failed");
                    }

                    if (runRSSI) {
                        settings_progress(&step, total, "正在启动 RSSI dBm 信号叠加层");
                        bool ok = rssidisplay_apply_in_session([d boolForKey:kSettingsRSSIDisplayWifi],
                                                               [d boolForKey:kSettingsRSSIDisplayCell]);
                        settings_mark_tweak_applied(kSettingsRSSIDisplayEnabled,
                                                    ok && [d boolForKey:kSettingsRSSIDisplayEnabled]);
                        printf("[SETTINGS] RSSI result=%d\n", ok);
                        log_user("%s RSSI %s.\n",
                                 ok ? "[OK]" : "[WARN]",
                                 ok ? "showing live signal strength (dBm)" : "did not start cleanly");
                        cyanide_upload_log_milestone(ok ? @"rssi-initial-applied" : @"rssi-initial-failed");
                    }

                    if (runLiveWP) {
                        settings_progress(&step, total, "正在启动 LiveWP 视频壁纸");
                        bool ok = livewp_apply_in_session();
                        settings_mark_tweak_applied(kSettingsLiveWPEnabled,
                                                    ok && [d boolForKey:kSettingsLiveWPEnabled]);
                        printf("[SETTINGS] LiveWP result=%d\n", ok);
                        log_user("%s LiveWP %s.\n",
                                 ok ? "[OK]" : "[WARN]",
                                 ok ? "video wallpaper active" : "did not start cleanly");
                        cyanide_upload_log_milestone(ok ? @"livewp-initial-applied" : @"livewp-initial-failed");
                    }

                    if (runAxonLite) {
                        settings_progress(&step, total, "正在启动 Axon Lite 通知中心");
                        bool ok = false;
                        bool deferred = false;
                        if (settings_axonlite_can_poll_springboard()) {
                            ok = axonlite_apply_in_session();
                            deferred = !ok && !axonlite_initial_cache_ready();
                        } else {
                            deferred = true;
                            printf("[SETTINGS] Axon Lite initial apply skipped: %s\n",
                                   settings_axonlite_pause_reason());
                        }
                        settings_mark_tweak_applied(kSettingsAxonLiteEnabled,
                                                    (ok || deferred) && [d boolForKey:kSettingsAxonLiteEnabled]);
                        printf("[SETTINGS] Axon Lite result=%d deferred=%d\n", ok, deferred);
                        log_user("%s Axon Lite %s.\n",
                                 (ok || deferred) ? "[OK]" : "[WARN]",
                                 ok ? "hub active — watching for notifications" :
                                 (deferred ? "standing by — fires when notifications appear" : "did not start cleanly"));
                        cyanide_upload_log_milestone(ok ? @"axon-lite-initial-applied" :
                                                     (deferred ? @"axon-lite-initial-deferred" : @"axon-lite-initial-failed"));
                    }

                    if (runNotificationIsland) {
                        settings_progress(&step, total, "正在启动通知岛");
                        bool ok = notificationisland_apply_in_session();
                        settings_mark_tweak_applied(kSettingsNotificationIslandEnabled,
                                                    ok && [d boolForKey:kSettingsNotificationIslandEnabled]);
                        printf("[SETTINGS] Notification Island result=%d\n", ok);
                        log_user("%s Notification Island %s.\n",
                                 ok ? "[OK]" : "[WARN]",
                                 ok ? "watching incoming banners" : "did not start cleanly");
                        cyanide_upload_log_milestone(ok ? @"notification-island-initial-applied" :
                                                         @"notification-island-initial-failed");
                    }

                    if (runAppSwitcherGrid) {
                        settings_progress(&step, total, "正在启用 App 切换器网格网格排布样式");
                        bool ok = appswitchergrid_apply_in_session();
                        settings_mark_tweak_applied(kSettingsAppSwitcherGridEnabled,
                                                    ok && [d boolForKey:kSettingsAppSwitcherGridEnabled]);
                        printf("[SETTINGS] App Switcher Grid result=%d\n", ok);
                        log_user("%s App Switcher Grid %s.\n",
                                 ok ? "[OK]" : "[WARN]",
                                 ok ? "enabled" : "did not apply cleanly");
                        cyanide_upload_log_milestone(ok ? @"app-switcher-grid-applied" : @"app-switcher-grid-failed");
                    } else if (!appSwitcherGridEnabled) {
                        appswitchergrid_stop_in_session();
                    }

                    if (runStageStrip) {
                        settings_progress(&step, total, "正在安装 Dynamic Stage Lite");
                        bool ok = stagestrip_apply_in_session(4);
                        startStageStripControlLoopAfterInstall = ok;
                        settings_mark_tweak_applied(kSettingsStageStripEnabled,
                                                    ok && [d boolForKey:kSettingsStageStripEnabled]);
                        printf("[SETTINGS] Dynamic Stage Lite result=%d\n", ok);
                        log_user("%s Dynamic Stage Lite %s.\n",
                                 ok ? "[OK]" : "[WARN]",
                                 ok ? "overlay active" : "did not install cleanly");
                        cyanide_upload_log_milestone(ok ? @"stagestrip-initial-applied" : @"stagestrip-initial-failed");
                    } else if (!stageStripEnabled) {
                        // Uninstall path: tear down the overlay if one survived
                        // from a prior Run. No-op when the strip was never up.
                        stagestrip_stop_in_session();
                    }
                }

                if (runStatBar) {
                    settings_start_statbar_live_loop();
                } else if (!statBarEnabled) {
                    g_statbar_live_stop_requested = 1;
                }
                if (runNSBar) {
                    settings_start_nsbar_live_loop();
                } else if (!nsBarEnabled) {
                    g_nsbar_live_stop_requested = 1;
                }
                if (runNiceBarLite) {
                    settings_start_nicebarlite_live_loop();
                } else if (!niceBarLiteEnabled) {
                    g_nicebarlite_live_stop_requested = 1;
                }
                if (runRSSI) {
                    settings_start_rssi_live_loop();
                } else if (!rssiEnabled) {
                    g_rssi_live_stop_requested = 1;
                }
                if (runLiveWP) {
                    settings_start_livewp_live_loop();
                } else if (!liveWPEnabled) {
                    g_livewp_live_stop_requested = 1;
                }
                if (runAxonLite) {
                    settings_start_axonlite_live_loop();
                } else if (!axonLiteEnabled) {
                    g_axonlite_live_stop_requested = 1;
                }
                if (runNotificationIsland) {
                    settings_start_notificationisland_live_loop();
                } else if (!notificationIslandEnabled) {
                    g_notificationisland_live_stop_requested = 1;
                }
            }

            if (runTypeBanner) {
                settings_progress(&step, total, "正在启动 TypeBanner 守护进程轮询");
                settings_mark_tweak_applied(kSettingsTypeBannerEnabled, YES);
                log_user("[OK] TypeBanner watching imagent for incoming typing indicators.\n");
                cyanide_upload_log_milestone(@"typebanner-live-starting");
                // Daemon-only detection avoids foregrounding Messages and
                // avoids the MobileSMS synthetic-thread PAC/0x401 crash path.
                printf("[TYPEBANNER] daemon-only: starting live loop without sms launch\n");
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                             (int64_t)kTypeBannerInitialDaemonSettleUS * NSEC_PER_USEC),
                               dispatch_get_global_queue(0, 0), ^{
                    settings_start_typebanner_live_loop();
                });
            } else if (!typeBannerEnabled) {
                g_typebanner_live_stop_requested = 1;
            }
            if (startStageStripControlLoopAfterInstall) {
                stagestrip_start_control_loop();
            }
            if (runStatBar || runNSBar || runNiceBarLite || runRSSI || runAxonLite || runTypeBanner || runNotificationIsland || runLiveWP || startStageStripControlLoopAfterInstall)
                cyanide_upload_log_milestone(@"live-tweaks-started");

            if (!settings_has_persistent_springboard_remote_call_user()) {
                BOOL closedNonLiveRemoteCall = NO;
                @synchronized (settings_rc_lock()) {
                    if (!settings_has_persistent_springboard_remote_call_user() &&
                        g_springboard_rc_ready) {
                        // Closing the synthetic-call channel does not undo
                        // one-shot SpringBoard patches like SBCustomizer's
                        // icon-label/layout changes. Keep the applied marker
                        // so Installer doesn't immediately re-queue a package
                        // that just finished successfully; SpringBoard restart,
                        // manual cleanup, and respring cleanup still clear it.
                        settings_destroy_springboard_remote_call_locked_internal_ex("non-live run complete",
                                                                                   YES,
                                                                                   YES);
                        closedNonLiveRemoteCall = YES;
                    }
                }
                if (closedNonLiveRemoteCall) {
                    log_user("[OK] SpringBoard channel released — no persistent hooks.\n");
                    cyanide_upload_log_milestone(@"springboard-remote-call-closed");
                }
            }

            if (runHadBlockingFailure) {
                log_user("[RUN] Incomplete: a requested live tweak did not become active.\n");
                cyanide_upload_log_milestone(@"run-incomplete");
                return;
            }

            log_user("[DONE] All tweaks active in-session — live until respring.\n");
            runSucceeded = YES;
            runCompletionMessage = @"完成 — 所有插件已应用";
            cyanide_upload_log_milestone(@"run-complete");
        } @finally {
            // Close any legacy uploader state before the final snapshot.
            cyanide_stop_session_uploads();
            log_session_end();
            __sync_lock_release(&g_settings_actions_running);
            settings_reconcile_applied_from_defaults();
            if (__sync_bool_compare_and_swap(&g_settings_actions_rerun_requested, 1, 0)) {
                log_user("[RUN] Applying queued follow-up run.\n");
                settings_run_actions_internal(pendingOnly);
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                NSDictionary *completionInfo = @{
                    kSettingsActionsDidCompleteSuccessKey: @(runSucceeded),
                    kSettingsActionsDidCompleteMessageKey: runCompletionMessage ?: @""
                };
                [[NSNotificationCenter defaultCenter] postNotificationName:PackageQueueDidChangeNotification
                                                                    object:[PackageQueue sharedQueue]];
                [[NSNotificationCenter defaultCenter] postNotificationName:kSettingsActionsDidCompleteNotification
                                                                    object:nil
                                                                  userInfo:completionInfo];
                cyanide_upload_log_if_enabled();
            });
        }
    });
}

void settings_run_actions(void)
{
    settings_run_actions_internal(NO);
}

void settings_run_pending_actions(void)
{
    settings_run_actions_internal(YES);
}

typedef NS_ENUM(NSInteger, SettingsSection) {
    SectionWarning = 0,
    SectionLaunch,
    SectionActions,
    SectionOTA,
    SectionSBC,
    SectionStatBar,
    SectionNSBar,
    SectionNiceBarLite,
    SectionRSSI,
    SectionAxonLite,
    SectionTypeBanner,
    SectionNotificationIsland,
    SectionPowercuff,
    SectionDarkSwordTweaks,
    SectionDragCoefficient,
    SectionLayoutExtras,
    SectionNanoRegistry,
    SectionThemer,
    SectionSnowBoardLite,
    SectionLiveWP,
    SectionLocationSim,
    SectionGravityLite,
    SectionAppSwitcherGrid,
    SectionIPADecryptor,
    SectionFastLockXLite,
    SectionCount,
};

typedef NS_ENUM(NSInteger, RootSection) {
    RootSectionChangelog = 0,
    RootSectionPatreon,
    RootSectionExperimental,
    RootSectionActions,
    RootSectionTweakBundles,
    RootSectionInDev,
    RootSectionSystemBundles,
    RootSectionAbout,
    RootSectionWarning,
    RootSectionCount,
};

// Loads Cyanide/Changelog.plist (generated at build time by
// scripts/gen-changelog.sh from the last N release tags). Each entry is a
// dict with keys "version" (NSString), "date" (ISO yyyy-MM-dd NSString), and
// "changes" (NSArray<NSString *>). Empty array when the plist is missing or
// malformed — the "What's New" section silently hides itself in that case.
static NSArray<NSDictionary *> *settings_changelog_entries(void)
{
    static NSArray<NSDictionary *> *entries = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *path = [[NSBundle mainBundle] pathForResource:@"Changelog" ofType:@"plist"];
        NSArray *raw = path ? [NSArray arrayWithContentsOfFile:path] : nil;
        NSMutableArray<NSDictionary *> *out = [NSMutableArray array];
        for (id obj in raw) {
            if (![obj isKindOfClass:[NSDictionary class]]) continue;
            NSDictionary *d = (NSDictionary *)obj;
            NSString *version = d[@"version"];
            NSArray *changes = d[@"changes"];
            if (![version isKindOfClass:[NSString class]] || version.length == 0) continue;
            if (![changes isKindOfClass:[NSArray class]] || changes.count == 0) continue;
            [out addObject:d];
        }
        entries = [out copy];
    });
    return entries;
}

// "2026-05-15" -> "May 15". Falls back to the raw string on parse failure.
static NSString *settings_pretty_date_for_iso(NSString *iso)
{
    if (!iso.length) return @"";
    static NSDateFormatter *in = nil;
    static NSDateFormatter *out = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        in  = [[NSDateFormatter alloc] init];
        in.dateFormat = @"yyyy-MM-dd";
        in.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        out = [[NSDateFormatter alloc] init];
        out.dateFormat = @"MMM d";
        out.locale = [NSLocale currentLocale];
    });
    NSDate *date = [in dateFromString:iso];
    return date ? [out stringFromDate:date] : iso;
}

@interface SettingsViewController () <UIDocumentPickerDelegate, PHPickerViewControllerDelegate>
@property (nonatomic, strong) UISegmentedControl *powercuffSegmented;
@property (nonatomic, assign) BOOL pendingManualActionsReload;
@property (nonatomic, assign) BOOL detailMode;
@property (nonatomic, assign) NSInteger underlyingSection;
@property (nonatomic, copy)   NSString *bundleTitle;
@property (nonatomic, assign) BOOL changelogExpanded;
@property (nonatomic, copy)   NSString *pendingThemeImportMode;
- (void)forceDisableFastLockXLiteForExperimentalGateWithDefaults:(NSUserDefaults *)defaults;
@end

// Singleton delegate so MFMailCompose's host VC doesn't need to conform. Lives
// for the app's lifetime — a single instance handles every dismissal across
// every entry point (Settings → Contact, Installer → Contact button, etc.).
@interface _CyanideMailDelegate : NSObject <MFMailComposeViewControllerDelegate>
@end
@implementation _CyanideMailDelegate
- (void)mailComposeController:(MFMailComposeViewController *)c
          didFinishWithResult:(MFMailComposeResult)r error:(NSError *)e
{
    (void)r; (void)e;
    [c dismissViewControllerAnimated:YES completion:nil];
}
@end
static _CyanideMailDelegate *_cyanide_mail_delegate(void) {
    static _CyanideMailDelegate *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ d = [[_CyanideMailDelegate alloc] init]; });
    return d;
}

@interface ThemerFormatGuideViewController : UITableViewController
@end

@implementation ThemerFormatGuideViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"主题格式";
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 72.0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return section == 2 ? 3 : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0: return @"文件夹主题";
        case 1: return @"Plist 主题";
        case 2: return @"文件";
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 0) {
        return @"仅匹配到的包名 ID 对应的图标会更换。未匹配到的 App 保持原生图标不变。";
    }
    if (section == 1) {
        return @"当你想要一个便携文件而不是 PNG 文件夹时，请使用二进制 plist。";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"guide"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:@"guide"];
        cell.detailTextLabel.numberOfLines = 0;
    }
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.textColor = UIColor.labelColor;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;

    if (indexPath.section == 0) {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = @"PNG 文件";
        cell.detailTextLabel.text =
            @"创建一个文件夹，放入以 App 包名 ID 命名的 PNG 文件：\n"
             "com.apple.mobilesafari.png\n"
             "com.apple.MobileSMS.png\n"
             "com.apple.mobiletimer.png";
    } else if (indexPath.section == 1) {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = @"包名 ID → PNG 数据";
        cell.detailTextLabel.text =
            @"创建一个字典 plist。每个键是包名 ID，每个值是原始 PNG 数据。"
             "Cyanide 导入该 plist 并将其复制到 Documents/Themes 中。";
    } else {
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        if (indexPath.row == 0) {
            cell.textLabel.text = @"分享示例主题 Plist";
            cell.detailTextLabel.text = @"导出包含示例 bundle ID 的小型二进制 plist 模板。";
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"分享 iOS 6 主题 Plist";
            cell.detailTextLabel.text = @"导出 iOS 6 主题 plist。图标来自 zagnut531/iOS-6-Icons。";
        } else {
            cell.textLabel.text = @"分享应用 Info.plist";
            cell.detailTextLabel.text = @"导出 Cyanide 附带的 Info.plist 供参考。";
        }
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (NSData *)sampleIconPNGWithText:(NSString *)text color:(UIColor *)color
{
    CGSize size = CGSizeMake(120.0, 120.0);
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = 1.0;
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size
                                                                               format:format];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGRect rect = CGRectMake(0.0, 0.0, size.width, size.height);
        [[UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:27.0] addClip];
        [color setFill];
        UIRectFill(rect);

        NSDictionary *attrs = @{
            NSFontAttributeName: [UIFont systemFontOfSize:48.0 weight:UIFontWeightBold],
            NSForegroundColorAttributeName: UIColor.whiteColor,
        };
        CGSize textSize = [text sizeWithAttributes:attrs];
        CGRect textRect = CGRectMake((size.width - textSize.width) / 2.0,
                                     (size.height - textSize.height) / 2.0,
                                     textSize.width,
                                     textSize.height);
        [text drawInRect:textRect withAttributes:attrs];
    }];
    return UIImagePNGRepresentation(image);
}

- (NSURL *)writeSamplePlist:(NSError **)error
{
    NSData *safari = [self sampleIconPNGWithText:@"S"
                                           color:[UIColor colorWithRed:0.05 green:0.45 blue:0.95 alpha:1.0]];
    NSData *sms = [self sampleIconPNGWithText:@"M"
                                        color:[UIColor colorWithRed:0.10 green:0.65 blue:0.25 alpha:1.0]];
    NSDictionary *plist = @{
        @"com.apple.mobilesafari": safari ?: [NSData data],
        @"com.apple.MobileSMS": sms ?: [NSData data],
    };
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0
                                                               error:error];
    if (!data) return nil;

    NSURL *url = [NSURL fileURLWithPath:
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"CyanideThemeTemplate.plist"]];
    if (![data writeToURL:url options:NSDataWritingAtomic error:error]) return nil;
    return url;
}

- (NSURL *)copyBuiltInIOS6Plist:(NSError **)error
{
    NSString *src = [[NSBundle mainBundle] pathForResource:@"Themes-iOS6" ofType:@"plist"];
    if (!src) {
        if (error) {
            *error = [NSError errorWithDomain:@"CyanideThemerGuide"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey: @"未找到内置的 iOS 6 plist。"}];
        }
        return nil;
    }

    NSURL *dst = [NSURL fileURLWithPath:
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"Cyanide-iOS6-Theme.plist"]];
    NSFileManager *fm = NSFileManager.defaultManager;
    if ([fm fileExistsAtPath:dst.path]) {
        [fm removeItemAtURL:dst error:nil];
    }
    if (![fm copyItemAtURL:[NSURL fileURLWithPath:src] toURL:dst error:error]) return nil;
    return dst;
}

- (NSURL *)copyAppInfoPlist:(NSError **)error
{
    NSString *src = [[NSBundle mainBundle] pathForResource:@"Info" ofType:@"plist"];
    if (!src) {
        if (error) {
            *error = [NSError errorWithDomain:@"CyanideThemerGuide"
                                         code:2
                                     userInfo:@{NSLocalizedDescriptionKey: @"未找到内置的 iOS 6 plist。"}];
        }
        return nil;
    }

    NSURL *dst = [NSURL fileURLWithPath:
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"Cyanide-Info.plist"]];
    NSFileManager *fm = NSFileManager.defaultManager;
    if ([fm fileExistsAtPath:dst.path]) {
        [fm removeItemAtURL:dst error:nil];
    }
    if (![fm copyItemAtURL:[NSURL fileURLWithPath:src] toURL:dst error:error]) return nil;
    return dst;
}

- (void)dismissGuide
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)shareURL:(NSURL *)url sourceView:(UIView *)sourceView
{
    UIActivityViewController *vc = [[UIActivityViewController alloc] initWithActivityItems:@[url]
                                                                     applicationActivities:nil];
    UIView *anchor = sourceView ?: self.view;
    vc.popoverPresentationController.sourceView = anchor;
    vc.popoverPresentationController.sourceRect = anchor.bounds;
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)showExportError:(NSError *)error
{
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"导出失败"
                                                                message:error.localizedDescription ?: @"无法写入 plist 文件。"
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 2) return;

    NSError *error = nil;
    NSURL *url = nil;
    if (indexPath.row == 0) {
        url = [self writeSamplePlist:&error];
    } else if (indexPath.row == 1) {
        url = [self copyBuiltInIOS6Plist:&error];
    } else {
        url = [self copyAppInfoPlist:&error];
    }
    if (!url) {
        [self showExportError:error];
        return;
    }

    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    [self shareURL:url sourceView:cell.contentView ?: tableView];
}

@end

@implementation SettingsViewController

+ (BOOL)liveWPHasSelectedVideo
{
    NSString *path = livewp_absolute_path();
    if (path.length == 0) return NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    // Calling [super initWithCoder:] (not initWithStyle:) so UIViewController's
    // unarchiving runs: that's what wires up the parentViewController and
    // navigationController relationships established by the storyboard's
    // rootViewController segue. Going through initWithStyle leaves nav nil.
    if ((self = [super initWithCoder:coder])) {
        _underlyingSection = NSIntegerMax;
    }
    return self;
}

- (instancetype)initWithUnderlyingSection:(NSInteger)underlyingSection
                              bundleTitle:(NSString *)bundleTitle
{
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _detailMode = YES;
        _underlyingSection = underlyingSection;
        _bundleTitle = [bundleTitle copy];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = self.detailMode ? (self.bundleTitle ?: @"设置") : @"设置";
    self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAlways;
    self.tableView.rowHeight                      = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight             = 44.0;
    self.tableView.sectionHeaderHeight            = UITableViewAutomaticDimension;
    self.tableView.estimatedSectionHeaderHeight   = 20.0;
    self.tableView.sectionFooterHeight            = UITableViewAutomaticDimension;
    self.tableView.estimatedSectionFooterHeight   = 10.0;
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"toggle"];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"stepper"];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"slider"];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"segmented"];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"action"];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"button"];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"warning"];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"bundle"];
    [self installInstallerReturnButtonIfNeeded];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(remoteCallStateDidChange:)
                                                 name:kSettingsRemoteCallStateDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(cleanupStateDidChange:)
                                                 name:kSettingsCleanupStateDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(patreonStatusDidChange:)
                                                 name:kCyanidePatreonStatusDidChangeNotification
                                               object:nil];

    // Best-effort background refresh of cached patron status when settings
    // opens. A cancelled / expired pledge silently flips the gate off here.
    if (!self.detailMode && cyanide_patreon_is_linked()) {
        cyanide_patreon_refresh(nil);
    }

    // Always-visible Respring button in the nav bar (top-right) so the user
    // doesn't have to scroll down to the Clean Up section to respring.
    // Mirrors the same flow used by the Clean Up alert: prepare → present the
    // existing WKWebView-based respring payload.
    if (!self.detailMode) {
        UIImage *icon = [UIImage systemImageNamed:@"arrow.clockwise.circle"];
        UIBarButtonItem *respringItem = [[UIBarButtonItem alloc] initWithImage:icon
                                                                          style:UIBarButtonItemStylePlain
                                                                         target:self
                                                                         action:@selector(navRespringTapped)];
        respringItem.accessibilityLabel = @"注销";
        self.navigationItem.rightBarButtonItem = respringItem;
    }
}

- (void)navRespringTapped
{
    UIAlertController *ac = [UIAlertController
        alertControllerWithTitle:@"注销？"
                         message:@"主屏幕将重新启动。任何未保存的实时状态都将被重置。"
                  preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消"
                                           style:UIAlertActionStyleCancel
                                         handler:nil]];
    __weak typeof(self) weakSelf = self;
    [ac addAction:[UIAlertAction actionWithTitle:@"注销"
                                           style:UIAlertActionStyleDestructive
                                         handler:^(UIAlertAction *_) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            if (__sync_lock_test_and_set(&g_settings_actions_running, 1)) {
                printf("[SETTINGS] nav respring blocked: actions already running\n");
                return;
            }
            __sync_lock_test_and_set(&g_settings_respring_cleanup_running, 1);
            settings_notify_cleanup_state_changed();
            @try {
                settings_prepare_for_respring_sync();
            } @finally {
                __sync_lock_release(&g_settings_actions_running);
                __sync_lock_release(&g_settings_respring_cleanup_running);
                settings_notify_cleanup_state_changed();
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                settings_show_respring_overlay(strongSelf);
            });
        });
    }]];
    settings_present_controller(ac, self);
}

- (void)cleanupStateDidChange:(NSNotification *)note
{
    (void)note;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)installInstallerReturnButtonIfNeeded
{
    if (!self.installerReturnPackageName) return;

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:17.0 weight:UIImageSymbolWeightSemibold];
    UIImage *chevron = [UIImage systemImageNamed:@"chevron.backward" withConfiguration:cfg];
    [btn setImage:chevron forState:UIControlStateNormal];
    [btn setTitle:[@" " stringByAppendingString:self.installerReturnPackageName] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightRegular];
    btn.tintColor = self.view.tintColor;
    btn.contentEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 4);
    [btn addTarget:self action:@selector(returnToInstaller) forControlEvents:UIControlEventTouchUpInside];
    [btn sizeToFit];

    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithCustomView:btn];
    self.navigationItem.leftBarButtonItem = backItem;
    self.navigationItem.hidesBackButton = YES;
}

- (void)returnToInstaller
{
    UITabBarController *tab = self.tabBarController;
    UINavigationController *settingsNav = self.navigationController;
    NSUInteger installerIdx = NSNotFound;
    for (NSUInteger i = 0; i < tab.viewControllers.count; i++) {
        UIViewController *vc = tab.viewControllers[i];
        if ([vc.tabBarItem.title isEqualToString:@"安装器"]) {
            installerIdx = i;
            break;
        }
    }
    [settingsNav popToRootViewControllerAnimated:NO];
    if (installerIdx != NSNotFound) {
        tab.selectedIndex = installerIdx;
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self reloadManualActions];

    // The NanoRegistry plist lives behind a sandbox wall on-device. Keep the
    // detail panel passive; the explicit "Load Current" button performs the
    // privileged KRW/sandbox setup before reading it.
    if (self.detailMode && self.underlyingSection == SectionNanoRegistry) {
        if (self.isViewLoaded) {
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
                          withRowAnimation:UITableViewRowAnimationNone];
        }
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self presentPowercuffNominalNoticeIfNeeded];
    if (!self.pendingManualActionsReload) return;
    self.pendingManualActionsReload = NO;
    [self reloadManualActions];
}

- (void)presentPowercuffNominalNoticeIfNeeded
{
    if (!self.detailMode || self.underlyingSection != SectionPowercuff) return;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if ([d boolForKey:kSettingsPowercuffNominalNoticeShown]) return;

    NSString *level = [d stringForKey:kSettingsPowercuffLevel] ?: @"nominal";
    BOOL alreadyNominal = [level isEqualToString:@"nominal"];
    NSString *message = @"Powercuff 现在默认为标准档位。\n\n轻度、中度、重度会刻意对 CPU 降频。这意味着可能出现卡顿或 App 启动变慢，老机型尤为明显。卡顿说明 Powercuff 正在生效，但这些档位日常用可能太慢，影响体验。\n\n日常使用请使用标准档位，仅在需要更强限制时再提高档位。";

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Powercuff 档位"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    if (!alreadyNominal) {
        [alert addAction:[UIAlertAction actionWithTitle:@"使用“标准”"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *_) {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setObject:@"nominal" forKey:kSettingsPowercuffLevel];
            [defaults setBool:YES forKey:kSettingsPowercuffNominalNoticeShown];
            [defaults synchronize];
            [weakSelf.tableView reloadData];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:alreadyNominal ? @"确定" : @"保持当前"
                                             style:UIAlertActionStyleCancel
                                           handler:^(UIAlertAction *_) {
        [d setBool:YES forKey:kSettingsPowercuffNominalNoticeShown];
        [d synchronize];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)remoteCallStateDidChange:(NSNotification *)notification
{
    [self reloadManualActions];
}

- (void)reloadManualActions
{
    if (!self.isViewLoaded) return;
    if (self.detailMode) return;
    if (!self.tableView.window) {
        self.pendingManualActionsReload = YES;
        return;
    }

    // Returning from Patreon OAuth can change the Patreon root section row
    // count (unlinked: 2, linked patron: 3, linked non-patron: 4) before the
    // status notification's full reload runs. A targeted Quick Actions
    // reload during that window makes UITableView validate the now-stale
    // Patreon section and crash with an invalid row-count assertion.
    if ([self.tableView numberOfSections] > RootSectionPatreon) {
        NSInteger visiblePatreonRows = [self.tableView numberOfRowsInSection:RootSectionPatreon];
        NSInteger desiredPatreonRows = [self tableView:self.tableView
                                numberOfRowsInSection:RootSectionPatreon];
        if (visiblePatreonRows != desiredPatreonRows) {
            [self.tableView reloadData];
            return;
        }
    }

    NSIndexSet *sections = [NSIndexSet indexSetWithIndex:RootSectionActions];
    [self.tableView reloadSections:sections withRowAnimation:UITableViewRowAnimationNone];
}

- (UITableViewCell *)buildWarningCell:(UITableViewCell *)cell
{
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = nil;
    for (UIView *v in [cell.contentView.subviews copy]) [v removeFromSuperview];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"info.circle.fill"]];
    icon.tintColor = UIColor.systemOrangeColor;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [icon setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [icon setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    UILabel *label = [[UILabel alloc] init];
    label.text = @"Cyanide 是一个受限的调整环境。本次调整在重启后恢复，少数插件会主动修改本地系统文件，其效果可能会持续到手动恢复。备份仅为尽力而为。请仅在获得许可、理解法律及服务条款影响并接受风险的前提下使用这些工具。实时调整如 StatBar 和 Axon Lite，在从 App 切换器强制退出 Cyanide 后也会随之停止。应用更改时会自动弹出进度日志，轻点“隐藏”即可关闭。";
    label.textColor = UIColor.labelColor;
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    label.numberOfLines = 0;
    label.translatesAutoresizingMaskIntoConstraints = NO;

    [cell.contentView addSubview:icon];
    [cell.contentView addSubview:label];
    UILayoutGuide *m = cell.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor   constraintEqualToAnchor:m.leadingAnchor],
        [icon.centerYAnchor   constraintEqualToAnchor:label.centerYAnchor],
        [icon.widthAnchor     constraintEqualToConstant:22],
        [icon.heightAnchor    constraintEqualToConstant:22],
        [label.leadingAnchor  constraintEqualToAnchor:icon.trailingAnchor constant:10],
        [label.trailingAnchor constraintEqualToAnchor:m.trailingAnchor],
        [label.topAnchor      constraintEqualToAnchor:m.topAnchor constant:4],
        [label.bottomAnchor   constraintEqualToAnchor:m.bottomAnchor constant:-4],
    ]];
    return cell;
}

#pragma mark - Row models

- (NSArray<NSDictionary *> *)launchRows
{
    return @[
        @{ @"key": kSettingsAutoRunKexploit,    @"title": @"自动运行 kexploit" },
        @{ @"key": kSettingsRunSandboxEscape,   @"title": @"沙盒逃逸 (escape_sbx_demo2)" },
        @{ @"key": kSettingsKeepAlive,          @"title": @"保持后台运行",
           @"subtitle": @"供应用驱动的实时插件在最小化后保持运行所需，包括 StatBar 持续接收新的实时数据。" },
    ];
}

// The master enable / install-equivalent rows have been removed from each
// tweak's row list — install/uninstall is handled by the Installer tab's
// Install button. Settings only shows configuration knobs.

- (NSArray<NSDictionary *> *)sbcRows
{
    return @[
        @{ @"kind": @"stepper", @"key": kSettingsSBCDockIcons,  @"title": @"Dock栏图标数", @"min": @4, @"max": @7, @"default": @(kSBCDefaultDockIcons) },
        @{ @"kind": @"stepper", @"key": kSettingsSBCCols,       @"title": @"主屏幕列数", @"min": @3, @"max": @7, @"default": @(kSBCDefaultCols) },
        @{ @"kind": @"stepper", @"key": kSettingsSBCRows,       @"title": @"主屏幕行数", @"min": @4, @"max": @8, @"default": @(kSBCDefaultRows) },
        @{ @"kind": @"toggle",  @"key": kSettingsSBCHideLabels, @"title": @"隐藏图标标签" },
        @{ @"kind": @"button",  @"title": @"重置为默认值" },
    ];
}

- (NSArray<NSDictionary *> *)powercuffRows
{
    return @[
        @{ @"kind": @"segmented", @"key": kSettingsPowercuffLevel,   @"title": @"档位" },
    ];
}

- (NSArray<NSDictionary *> *)otaRows
{
    return @[
        @{ @"kind": @"button", @"title": @"禁用 OTA 更新" },
        @{ @"kind": @"button", @"title": @"启用 OTA 更新" },
    ];
}

- (NSArray<NSDictionary *> *)nanoRegistryRows
{
    return @[
        @{ @"kind": @"stepper",
           @"key": kSettingsNanoMaxPairing,
           @"title": @"watchOS 配对上限",
           @"subtitle": @"调整本设备可接受的最高 watchOS 配对通信协议版本，以兼容更新的 watchOS 版本。 [范围：99] ",
           @"min": @(kNanoUIRowMin),
           @"max": @(kNanoUIRowMax),
           @"default": @(kNanoDefaultMaxPairing) },

        @{ @"kind": @"stepper",
           @"key": kSettingsNanoMinPairing,
           @"title": @"设置协议下限",
           @"subtitle": @"调整本设备可接受的最低配对通信协议版本，以确保配对消息不被拒绝。[范围：23]",
           @"min": @(kNanoUIRowMin),
           @"max": @(kNanoUIRowMax),
           @"default": @(kNanoDefaultMinPairing) },

        @{ @"kind": @"stepper",
           @"key": kSettingsNanoMinPairingChipID,
           @"title": @"旧芯片下限",
           @"subtitle": @"除非你要配对的是老款 S 芯片手表，否则请保持此设置不变。[范围：10]",
           @"min": @(kNanoUIRowMin),
           @"max": @(kNanoUIRowMax),
           @"default": @(kNanoDefaultMinPairingChipID) },

        @{ @"kind": @"stepper",
           @"key": kSettingsNanoMinQuickSwitch,
           @"title": @"多手表切换",
           @"subtitle": @"除非在多台旧配对手表之间切换不起作用，否则请保持此设置不变。[范围：6]",
           @"min": @(kNanoUIRowMin),
           @"max": @(kNanoUIRowMax),
           @"default": @(kNanoDefaultMinQuickSwitch) },

        @{ @"kind": @"button",
           @"title": @"加载已保存的覆盖",
           @"action": @"nano-load" },

        @{ @"kind": @"button",
           @"title": @"使用 watchOS",
           @"action": @"nano-preset-newer" },

        @{ @"kind": @"button",
           @"title": @"应用配对覆盖",
           @"action": @"nano-apply" },

        @{ @"kind": @"button",
           @"title": @"移除覆盖",
           @"action": @"nano-clear",
           @"destructive": @YES },
    ];
}

- (NSArray<NSDictionary *> *)darkSwordTweakRows
{
    return @[];
}

- (NSArray<NSDictionary *> *)dragCoefficientRows
{
    return @[
        @{ @"kind": @"number",
           @"key": kSettingsDSDragCoefficientValue,
           @"title": @"倍率",
           @"subtitle": @"1.00 = 默认速度，0.50 = 2 倍速度，0.25 = 4 倍速度。最低可设为 0.01。",
           @"min": @0.01, @"max": @2.0, @"step": @0.01,
           @"precision": @2, @"default": @0.5 },
    ];
}

- (NSArray<NSDictionary *> *)layoutExtrasRows
{
    return @[
        @{ @"kind": @"number", @"key": kSettingsLayoutHomeExtraLeft,
           @"title": @"主屏幕额外左边距",   @"min": @0,  @"max": @300, @"step": @1, @"unit": @"pt", @"default": @0 },
        @{ @"kind": @"number", @"key": kSettingsLayoutHomeExtraRight,
           @"title": @"主屏幕额外右边距",  @"min": @0,  @"max": @300, @"step": @1, @"unit": @"pt", @"default": @0 },
        @{ @"kind": @"number", @"key": kSettingsLayoutHomeExtraTop,
           @"title": @"主屏幕额外上边距",    @"min": @0,  @"max": @400, @"step": @1, @"unit": @"pt", @"default": @0 },
        @{ @"kind": @"number", @"key": kSettingsLayoutHomeExtraBottom,
           @"title": @"主屏幕额外下边距", @"min": @0,  @"max": @400, @"step": @1, @"unit": @"pt", @"default": @0 },
        @{ @"kind": @"number", @"key": kSettingsLayoutDockExtraHorizontal,
           @"title": @"Dock栏额外水平边距", @"min": @0,  @"max": @200, @"step": @1, @"unit": @"pt", @"default": @0 },
        @{ @"kind": @"number", @"key": kSettingsLayoutHomeScalePct,
           @"title": @"主屏幕图标缩放",   @"min": @25, @"max": @250, @"step": @1, @"unit": @"%", @"default": @100 },
        @{ @"kind": @"number", @"key": kSettingsLayoutDockScalePct,
           @"title": @"Dock栏图标缩放",   @"min": @25, @"max": @250, @"step": @1, @"unit": @"%", @"default": @100 },
    ];
}

- (NSArray<NSDictionary *> *)statbarRows
{
    return @[
        @{ @"kind": @"toggle", @"key": kSettingsStatBarCelsius,     @"title": @"摄氏度（℃）" },
        @{ @"kind": @"toggle", @"key": kSettingsStatBarShowCPU,     @"title": @"CPU 占用" },
        @{ @"kind": @"toggle", @"key": kSettingsStatBarShowLabels,  @"title": @"CPU/内存标签" },
        @{ @"kind": @"toggle", @"key": kSettingsStatBarShowNet,     @"title": @"网络速度" },
        @{ @"kind": @"toggle", @"key": kSettingsStatBarNetworkOnly, @"title": @"仅网络速度" },
        @{ @"kind": @"slider", @"key": kSettingsStatBarRefreshRateSec,
           @"title": @"刷新频率", @"min": @1, @"max": @30, @"step": @1,
           @"unit": @"s", @"default": @(kStatBarDefaultRefreshRateSec) },
    ];
}

- (NSArray<NSDictionary *> *)nsbarRows
{
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    return @[
        @{ @"kind": @"info",
           @"title": @"位置",
           @"subtitle": settings_nsbar_position_name([d integerForKey:kSettingsNSBarPosition]) },
        @{ @"kind": @"button",
           @"title": @"选择位置…",
           @"action": @"nsbar-position" },
    ];
}

- (NSArray<NSDictionary *> *)nicebarLiteRows
{
    return @[
        @{ @"kind": @"nicebar-grid" },
        @{ @"kind": @"info",
           @"title": @"布局",
           @"subtitle": @"顶部和底部行可单独移动。NiceBar Lite 运行时更改会实时更新。" },
        @{ @"kind": @"slider", @"key": kSettingsNiceBarLiteLayoutTopSideInset,
           @"title": @"顶部侧边距", @"min": @(-80), @"max": @80, @"step": @1, @"unit": @"pt", @"default": @0 },
        @{ @"kind": @"slider", @"key": kSettingsNiceBarLiteLayoutBottomSideInset,
           @"title": @"底部侧边距", @"min": @(-80), @"max": @80, @"step": @1, @"unit": @"pt", @"default": @0 },
        @{ @"kind": @"slider", @"key": kSettingsNiceBarLiteLayoutTopY,
           @"title": @"顶部 Y 偏移", @"min": @(-40), @"max": @80, @"step": @1, @"unit": @"pt", @"default": @0 },
        @{ @"kind": @"slider", @"key": kSettingsNiceBarLiteLayoutBottomY,
           @"title": @"底部 Y 偏移", @"min": @(-40), @"max": @80, @"step": @1, @"unit": @"pt", @"default": @0 },
        @{ @"kind": @"slider", @"key": kSettingsNiceBarLiteLayoutCenterX,
           @"title": @"中心 X 偏移", @"min": @(-120), @"max": @120, @"step": @1, @"unit": @"pt", @"default": @0 },
        @{ @"kind": @"toggle", @"key": kSettingsNiceBarLiteCelsius, @"title": @"使用摄氏温度" },
        @{ @"kind": @"button", @"title": @"流量历史", @"action": @"nicebar-traffic-history" },
        @{ @"kind": @"button",
           @"title": @"立即应用",
           @"action": @"nicebar-apply" },
    ];
}

- (NSArray<NSDictionary *> *)rssiRows
{
    return @[
        @{ @"kind": @"toggle", @"key": kSettingsRSSIDisplayWifi, @"title": @"WiFi（信号格数）" },
        @{ @"kind": @"toggle", @"key": kSettingsRSSIDisplayCell, @"title": @"蜂窝网络（dBm）" },
    ];
}

- (NSArray<NSDictionary *> *)axonLiteRows
{
    return @[];
}

- (NSArray<NSDictionary *> *)typebannerRows
{
    return @[
        @{ @"kind": @"button",
           @"title": @"测试：轮询守护进程并显示横幅",
           @"subtitle": @"单次运行 imagent 实时检测。结果以横幅弹出，[TYPEBANNER] 日志会详细说明找到了什么、没找到什么。",
           @"action": @"typebanner-test" },
    ];
}

- (NSArray<NSDictionary *> *)notificationIslandRows
{
    return @[
        @{ @"kind": @"button",
           @"title": @"显示示例岛",
           @"subtitle": @"启动与捕获的传入通知横幅相同的 ActivityKit 路径。",
           @"action": @"notificationisland-sample" },
    ];
}

- (NSArray<NSDictionary *> *)gravityLiteRows
{
    return @[
        @{ @"kind": @"toggle",
           @"key": kSettingsGravityLiteDockEnabled,
           @"title": @"包含 Dock 栏" },
        @{ @"kind": @"slider",
           @"key": kSettingsGravityLiteMagnitudePct,
           @"title": @"重力强度",
           @"min": @25,
           @"max": @300,
           @"step": @5,
           @"unit": @"%",
           @"default": @100 },
        @{ @"kind": @"slider",
           @"key": kSettingsGravityLiteBouncePct,
           @"title": @"弹跳",
           @"min": @0,
           @"max": @100,
           @"step": @5,
           @"unit": @"%",
           @"default": @50 },
        @{ @"kind": @"slider",
           @"key": kSettingsGravityLiteFrictionPct,
           @"title": @"摩擦力",
           @"min": @0,
           @"max": @100,
           @"step": @5,
           @"unit": @"%",
           @"default": @50 },
        @{ @"kind": @"slider",
           @"key": kSettingsGravityLiteResistancePct,
           @"title": @"阻力",
           @"min": @0,
           @"max": @200,
           @"step": @5,
           @"unit": @"%",
           @"default": @50 },
        @{ @"kind": @"slider",
           @"key": kSettingsGravityLiteAngularResistancePct,
           @"title": @"旋转阻力",
           @"min": @0,
           @"max": @200,
           @"step": @5,
           @"unit": @"%",
           @"default": @0 },
        @{ @"kind": @"button",
           @"title": @"爆发脉冲",
           @"action": @"gravitylite-explosion" },
        @{ @"kind": @"button",
           @"title": @"恢复图标布局",
           @"action": @"gravitylite-restore",
           @"destructive": @YES },
    ];
}

- (NSArray<NSDictionary *> *)locationSimRows
{
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    return @[
        @{ @"kind": @"info",
           @"title": @"状态",
           @"subtitle": settings_location_sim_mode_summary(d) },

        @{ @"kind": @"button",
           @"title": @"设置精确坐标…",
           @"action": @"locsim-set-exact" },

        @{ @"kind": @"button",
           @"title": @"主要城市…",
           @"action": @"locsim-major-cities" },

        @{ @"kind": @"button",
           @"title": @"模拟 Rockaway 测试点",
           @"action": @"locsim-preset-rockaway" },

        @{ @"kind": @"slider",
           @"key": kSettingsLocationSimAltitude,
           @"title": @"海拔",
           @"min": @(-100),
           @"max": @1000,
           @"step": @1,
           @"unit": @"m",
           @"default": @(kLocationSimDefaultAltitude) },

        @{ @"kind": @"slider",
           @"key": kSettingsLocationSimHorizontalAccuracy,
           @"title": @"精度",
           @"min": @1,
           @"max": @100,
           @"step": @1,
           @"unit": @"m",
           @"default": @(kLocationSimDefaultAccuracy) },

        @{ @"kind": @"button",
           @"title": @"模拟当前位置",
           @"action": @"locsim-apply" },

        @{ @"kind": @"button",
           @"title": @"恢复真实位置",
           @"subtitle": @"重置可能需要几分钟。如果位置看起来仍在模拟，请重启并稍等片刻。",
           @"action": @"locsim-stop",
           @"destructive": @YES },
    ];
}

- (NSArray<NSDictionary *> *)ipaDecryptorRows
{
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSString *bundleID = [d stringForKey:kSettingsIPADecryptorTargetBundleID] ?: @"";
    NSString *appStoreInput = [d stringForKey:kSettingsIPADecryptorAppStoreInput] ?: @"";
    NSString *downloadedPath = [d stringForKey:kSettingsIPADecryptorDownloadedIPAPath] ?: @"";
    NSMutableArray<NSDictionary *> *rows = [NSMutableArray arrayWithArray:@[
        @{ @"kind": @"info",
           @"title": @"App Store 账户",
           @"subtitle": ipadecryptor_app_store_account_summary() },
        @{ @"kind": @"button",
           @"title": ipadecryptor_has_app_store_account()
                ? @"重新登录…"
                : @"登录 App Store…",
           @"subtitle": @"Cyanide 需要先登录才能请求经过身份验证的 IPA 下载凭据。如果 Apple 要求两步验证，后续会提示输入验证码。",
           @"action": @"ipadec-signin" },
        @{ @"kind": @"info",
           @"title": @"已选应用",
           @"subtitle": settings_ipadecryptor_target_summary(d) },
        @{ @"kind": @"info",
           @"title": @"App Store 链接",
           @"subtitle": settings_ipadecryptor_app_store_summary(d) },
        @{ @"kind": @"info",
           @"title": @"下载状态",
           @"subtitle": [d stringForKey:kSettingsIPADecryptorDownloadStatus] ?: @"未开始。" },
        @{ @"kind": @"info",
           @"title": @"输出文件夹",
           @"subtitle": ipadecryptor_default_output_directory().length > 0
                ? ipadecryptor_default_output_directory()
                : @"Cyanide Documents/DecryptedIPAs" },
        @{ @"kind": @"button",
           @"title": @"选择已安装的应用…",
           @"action": @"ipadec-choose" },
        @{ @"kind": @"button",
           @"title": @"粘贴 App Store 链接并下载…",
           @"subtitle": @"解析链接，然后启动 IPA 下载路径。",
           @"action": @"ipadec-paste-link" },
    ]];
    if (appStoreInput.length > 0) {
        [rows addObject:@{ @"kind": @"button",
                           @"title": @"从 App Store 下载 IPA",
                           @"subtitle": @"请求经过身份验证的下载凭据，然后将加密的 IPA 下载到 Documents 目录。",
                           @"action": @"ipadec-download" }];
    }
    if (ipadecryptor_has_app_store_account()) {
        [rows addObject:@{ @"kind": @"button",
                           @"title": @"清除已保存的 App Store 令牌",
                           @"action": @"ipadec-clear-account",
                           @"destructive": @YES }];
    }
    if (downloadedPath.length > 0) {
        [rows addObject:@{ @"kind": @"info",
                           @"title": @"已下载 IPA",
                           @"subtitle": downloadedPath }];
    }
    if (bundleID.length > 0) {
        [rows addObject:@{ @"kind": @"button",
                           @"title": @"探查目标",
                           @"subtitle": @"读取应用 bundle 并报告主 Mach-O FairPlay 加密命令。",
                           @"action": @"ipadec-probe" }];
        [rows addObject:@{ @"kind": @"button",
                           @"title": @"开始解密",
                           @"subtitle": @"运行开发中的管道。转储和 IPA 写入阶段仍在开发中。",
                           @"action": @"ipadec-start" }];
    }
    return rows;
}

- (NSArray<NSDictionary *> *)themerRows
{
    BOOL hasSelection = settings_themer_has_selected_theme();
    NSString *selected = settings_themer_selected_theme_display_name();
    NSMutableArray<NSDictionary *> *rows = [NSMutableArray arrayWithArray:@[
        @{ @"kind": @"info",
           @"title": @"已选主题",
           @"subtitle": hasSelection ? selected : @"未选择。请在运行图标主题引擎之前选择一个主题。" },

        @{ @"kind": @"button",
           @"title": [selected isEqualToString:@"iOS 6 主题"]
                ? @"iOS 6 主题 ✓" : @"使用 iOS 6 主题",
           @"action": @"themer-select-ios6" },

        @{ @"kind": @"button",
           @"title": @"导入自定义主题…",
           @"action": @"themer-import" },

        @{ @"kind": @"button",
           @"title": @"主题格式指南",
           @"action": @"themer-guide" },
    ]];
    if (hasSelection) {
        [rows addObject:@{ @"kind": @"button",
                           @"title": @"清除已选主题",
                           @"action": @"themer-clear",
                           @"destructive": @YES }];
    }
    return rows;
}

- (NSArray<NSDictionary *> *)snowboardLiteRows
{
    BOOL hasSelection = settings_snowboardlite_has_selected_theme();
    NSString *selected = settings_snowboardlite_selected_theme_display_name();
    NSMutableArray<NSDictionary *> *rows = [NSMutableArray arrayWithArray:@[
        @{ @"kind": @"info",
           @"title": @"已选主题",
           @"subtitle": hasSelection ? selected : @"未选择。请在运行 SnowBoard Lite 之前选择或导入一个主题。" },
        @{ @"kind": @"button",
           @"title": [selected isEqualToString:@"iOS 6 主题"] ? @"iOS 6 主题 ✓" : @"使用 iOS 6 主题",
           @"action": @"sbl-select-ios6" },
        @{ @"kind": @"button",
           @"title": @"导入主题文件夹…",
           @"action": @"sbl-import-folder" },
        @{ @"kind": @"button",
           @"title": @"导入主题压缩包 (ZIP/DEB)…",
           @"action": @"sbl-import-archive" },
    ]];
    if (hasSelection) {
        [rows addObject:@{ @"kind": @"button",
                           @"title": @"清除已选主题",
                           @"action": @"sbl-clear",
                           @"destructive": @YES }];
    }
    return rows;
}

- (NSArray<NSDictionary *> *)liveWPRows
{
    NSMutableArray<NSDictionary *> *rows = [NSMutableArray arrayWithArray:@[
        @{ @"kind": @"info",
           @"title": @"已选主题",
           @"subtitle": settings_livewp_video_detail() },
        @{ @"kind": @"button",
           @"title": @"选择视频…",
           @"action": @"livewp-select-video" },
    ]];
    if ([[NSUserDefaults standardUserDefaults] stringForKey:kSettingsLiveWPVideoPath].length > 0) {
        [rows addObject:@{ @"kind": @"button",
                           @"title": @"清除已选视频",
                           @"action": @"livewp-clear",
                           @"destructive": @YES }];
    }
    return rows;
}

- (NSArray<NSDictionary *> *)appSwitcherGridRows
{
    BOOL applied = settings_tweak_is_applied(kSettingsAppSwitcherGridEnabled);
    return @[
        @{ @"kind": @"info",
           @"title": applied ? @"当前样式：网格" : @"当前样式：原版",
           @"subtitle": @"它不会写入系统文件；注销即可恢复原版 App 切换器。" },
        @{ @"kind": @"info",
           @"title": @"提示",
           @"subtitle": @"如果你在隐藏主屏幕横条后注销，请重新运行 App 切换器网格，因为注销会重置此功能。" },
        @{ @"kind": @"button",
           @"title": @"恢复原版 App 切换器",
           @"subtitle": @"使用时，直接恢复原版 App 切换器样式。",
           @"action": @"appswitchergrid-restore",
           @"destructive": @YES },
    ];
}

- (NSArray<NSDictionary *> *)fastLockXLiteRows
{
    return @[
        @{ @"kind": @"info",
           @"title": @"FastLockX Lite",
           @"subtitle": @"常亮模式会保持 Face ID 重试信号和解锁请求驻留在主屏幕中，直到点击关闭、清理或注销。" },
        @{ @"kind": @"button",
           @"title": @"启用常亮模式",
           @"subtitle": @"Cyanide 关闭后仍保持抬起唤醒解锁的待命状态。",
           @"action": @"fastlockx-enable" },
        @{ @"kind": @"button",
           @"title": @"禁用",
           @"subtitle": @"停止主屏幕中的计时器。",
           @"action": @"fastlockx-disable" },
        @{ @"kind": @"number",
           @"key": kSettingsFastLockXLiteRetryInterval,
           @"title": @"重试间隔",
           @"subtitle": @"原 FastLockX 默认为 0.5 秒。常亮模式以此作为关闭→开启的信号间隔。",
           @"min": @0.1, @"max": @2.0, @"step": @0.1, @"unit": @"s", @"precision": @1, @"default": @0.5 },
        @{ @"key": kSettingsFastLockXLiteBlockMusic,
           @"title": @"媒体播放时阻止 — 开发中",
           @"subtitle": @"开发中 — 尚未接入。此阻止器目前已禁用。",
           @"disabled": @YES },
        @{ @"key": kSettingsFastLockXLiteBlockFlashlight,
           @"title": @"手电筒开启时阻止 — 开发中",
           @"subtitle": @"开发中 — 尚未接入。此阻止器目前已禁用。",
           @"disabled": @YES },
        @{ @"key": kSettingsFastLockXLiteBlockLowPower,
           @"title": @"低电量模式下阻止 — 开发中",
           @"subtitle": @"开发中 — 尚未接入。此阻止器目前已禁用。",
           @"disabled": @YES },
    ];
}

+ (NSArray<NSDictionary<NSString *, NSString *> *> *)settingsSummaryForSection:(NSInteger)section
{
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSMutableArray *out = [NSMutableArray array];
    if (section == SectionSBC) {
        [out addObject:@{@"title": @"Dock栏图标数",       @"value": [@([d integerForKey:kSettingsSBCDockIcons])  stringValue]}];
        [out addObject:@{@"title": @"主屏幕列数",     @"value": [@([d integerForKey:kSettingsSBCCols])        stringValue]}];
        [out addObject:@{@"title": @"主屏幕行数",        @"value": [@([d integerForKey:kSettingsSBCRows])        stringValue]}];
        [out addObject:@{@"title": @"隐藏图标标签", @"value": [d boolForKey:kSettingsSBCHideLabels] ? @"开启" : @"关闭"}];
    } else if (section == SectionLayoutExtras) {
        [out addObject:@{@"title": @"主屏幕额外左右边距",   @"value": [NSString stringWithFormat:@"%ld/%ld",
                                                                    (long)[d integerForKey:kSettingsLayoutHomeExtraLeft],
                                                                    (long)[d integerForKey:kSettingsLayoutHomeExtraRight]]}];
        [out addObject:@{@"title": @"主屏幕额外上下边距",   @"value": [NSString stringWithFormat:@"%ld/%ld",
                                                                    (long)[d integerForKey:kSettingsLayoutHomeExtraTop],
                                                                    (long)[d integerForKey:kSettingsLayoutHomeExtraBottom]]}];
        [out addObject:@{@"title": @"Dock栏额外水平边距",     @"value": [@([d integerForKey:kSettingsLayoutDockExtraHorizontal]) stringValue]}];
        [out addObject:@{@"title": @"主屏幕缩放百分比",     @"value": [@([d integerForKey:kSettingsLayoutHomeScalePct]) stringValue]}];
        [out addObject:@{@"title": @"Dock栏缩放百分比",     @"value": [@([d integerForKey:kSettingsLayoutDockScalePct]) stringValue]}];
    } else if (section == SectionStatBar) {
        [out addObject:@{@"title": @"摄氏度（℃）",             @"value": [d boolForKey:kSettingsStatBarCelsius]    ? @"开启" : @"关闭"}];
        [out addObject:@{@"title": @"CPU 占用",          @"value": [d boolForKey:kSettingsStatBarShowCPU]    ? @"开启" : @"关闭"}];
        [out addObject:@{@"title": @"CPU/内存标签", @"value": [d boolForKey:kSettingsStatBarShowLabels] ? @"开启" : @"关闭"}];
        [out addObject:@{@"title": @"网络速度",      @"value": [d boolForKey:kSettingsStatBarShowNet]    ? @"开启" : @"关闭"}];
        [out addObject:@{@"title": @"仅网络速度",  @"value": [d boolForKey:kSettingsStatBarNetworkOnly] ? @"开启" : @"关闭"}];
        [out addObject:@{@"title": @"刷新频率",        @"value": [NSString stringWithFormat:@"%lds",
                                                                       (long)[d integerForKey:kSettingsStatBarRefreshRateSec]]}];
    } else if (section == SectionNSBar) {
        [out addObject:@{@"title": @"位置", @"value": settings_nsbar_position_name([d integerForKey:kSettingsNSBarPosition])}];
    } else if (section == SectionNiceBarLite) {
        for (NSInteger i = 0; i < NiceBarLiteSlotCount; i++) {
            NSInteger kind = [d integerForKey:settings_nicebar_key(kSettingsNiceBarLiteSlotKindPrefix, i)];
            [out addObject:@{@"title": settings_nicebar_slot_name(i),
                             @"value": settings_nicebar_kind_name(kind)}];
        }
    } else if (section == SectionRSSI) {
        [out addObject:@{@"title": @"WiFi（信号格数）", @"value": [d boolForKey:kSettingsRSSIDisplayWifi] ? @"开启" : @"关闭"}];
        [out addObject:@{@"title": @"蜂窝网络（dBm）",   @"value": [d boolForKey:kSettingsRSSIDisplayCell] ? @"开启" : @"关闭"}];
    } else if (section == SectionAppSwitcherGrid) {
        [out addObject:@{@"title": @"样式",
                         @"value": settings_tweak_is_applied(kSettingsAppSwitcherGridEnabled) ? @"网格" : @"原版"}];
    } else if (section == SectionFastLockXLite) {
        BOOL alwaysOnIntent = [d boolForKey:kSettingsFastLockXLiteEnabled];
        BOOL alwaysOnApplied = settings_tweak_is_applied(kSettingsFastLockXLiteEnabled);
        [out addObject:@{@"title": @"常亮模式",
                         @"value": alwaysOnApplied ? @"启用" : (alwaysOnIntent ? @"未知" : @"关闭")}];
        [out addObject:@{@"title": @"重试间隔",
                         @"value": [NSString stringWithFormat:@"%.1fs", settings_fastlockx_lite_retry_interval(d)]}];
        [out addObject:@{@"title": @"阻止条件",
                         @"value": @"开发中"}];
    } else if (section == SectionPowercuff) {
        NSString *lvl = [d stringForKey:kSettingsPowercuffLevel] ?: @"nominal";
        [out addObject:@{@"title": @"档位", @"value": @{@"off":@"关闭", @"nominal":@"标准", @"light":@"轻度", @"moderate":@"中度", @"heavy":@"重度"}[lvl] ?: lvl}];
    } else if (section == SectionDragCoefficient) {
        double v = settings_drag_coefficient_value(d);
        [out addObject:@{@"title": @"倍率", @"value": [NSString stringWithFormat:@"%.2f", v]}];
    } else if (section == SectionNanoRegistry) {
        [out addObject:@{@"title": @"watchOS 上限",      @"value": [@([d integerForKey:kSettingsNanoMaxPairing])       stringValue]}];
        [out addObject:@{@"title": @"设置下限",        @"value": [@([d integerForKey:kSettingsNanoMinPairing])       stringValue]}];
        [out addObject:@{@"title": @"旧芯片下限",  @"value": [@([d integerForKey:kSettingsNanoMinPairingChipID]) stringValue]}];
        [out addObject:@{@"title": @"多手表切换", @"value": [@([d integerForKey:kSettingsNanoMinQuickSwitch])   stringValue]}];
    } else if (section == SectionThemer) {
        [out addObject:@{@"title": @"主题", @"value": settings_themer_selected_theme_display_name()}];
    } else if (section == SectionSnowBoardLite) {
        [out addObject:@{@"title": @"主题", @"value": settings_snowboardlite_selected_theme_display_name()}];
    } else if (section == SectionLiveWP) {
        [out addObject:@{@"title": @"视频", @"value": settings_livewp_video_detail()}];
    } else if (section == SectionLocationSim) {
        [out addObject:@{@"title": @"坐标", @"value": settings_location_sim_target_summary(d)}];
    } else if (section == SectionIPADecryptor) {
        [out addObject:@{@"title": @"目标", @"value": settings_ipadecryptor_target_summary(d)}];
        [out addObject:@{@"title": @"App Store", @"value": settings_ipadecryptor_app_store_summary(d)}];
    } else if (section == SectionGravityLite) {
        [out addObject:@{@"title": @"Dock",         @"value": [d boolForKey:kSettingsGravityLiteDockEnabled] ? @"包含" : @"仅主屏幕"}];
        [out addObject:@{@"title": @"强度",     @"value": [NSString stringWithFormat:@"%ld%%", (long)[d integerForKey:kSettingsGravityLiteMagnitudePct]]}];
        [out addObject:@{@"title": @"弹跳",       @"value": [NSString stringWithFormat:@"%ld%%", (long)[d integerForKey:kSettingsGravityLiteBouncePct]]}];
        [out addObject:@{@"title": @"摩擦力",     @"value": [NSString stringWithFormat:@"%ld%%", (long)[d integerForKey:kSettingsGravityLiteFrictionPct]]}];
        [out addObject:@{@"title": @"阻力",   @"value": [NSString stringWithFormat:@"%ld%%", (long)[d integerForKey:kSettingsGravityLiteResistancePct]]}];
        [out addObject:@{@"title": @"旋转阻力", @"value": [NSString stringWithFormat:@"%ld%%", (long)[d integerForKey:kSettingsGravityLiteAngularResistancePct]]}];
    }
    return out;
}

- (NSArray<NSDictionary *> *)rowsForSection:(NSInteger)s
{
    switch (s) {
        case SectionLaunch:    return self.launchRows;
        case SectionSBC:       return self.sbcRows;
        case SectionDarkSwordTweaks: return self.darkSwordTweakRows;
        case SectionDragCoefficient: return self.dragCoefficientRows;
        case SectionLayoutExtras: return self.layoutExtrasRows;
        case SectionOTA:       return self.otaRows;
        case SectionNanoRegistry: return self.nanoRegistryRows;
        case SectionThemer:  return self.themerRows;
        case SectionPowercuff: return self.powercuffRows;
        case SectionStatBar:   return self.statbarRows;
        case SectionNSBar:     return self.nsbarRows;
        case SectionNiceBarLite: return self.nicebarLiteRows;
        case SectionRSSI:      return self.rssiRows;
        case SectionAxonLite:  return self.axonLiteRows;
        case SectionTypeBanner: return self.typebannerRows;
        case SectionNotificationIsland: return self.notificationIslandRows;
        case SectionAppSwitcherGrid: return self.appSwitcherGridRows;
        case SectionFastLockXLite: return settings_fastlockx_lite_install_allowed() ? self.fastLockXLiteRows : @[];
        case SectionGravityLite: return self.gravityLiteRows;
        case SectionLocationSim: return self.locationSimRows;
        case SectionIPADecryptor: return self.ipaDecryptorRows;
        case SectionSnowBoardLite: return self.snowboardLiteRows;
        case SectionLiveWP: return self.liveWPRows;
        default: return @[];
    }
}

#pragma mark - Bundle rows (root mode)

// Bundles whose underlying section has zero configuration rows are filtered
// out — install/uninstall is the only operation those tweaks expose, and
// that's already in the Installer tab.

- (NSArray<NSDictionary *> *)allTweakBundleRows
{
    return @[
        @{ @"title": @"启动选项",     @"icon": @"bolt.fill",                          @"color": [UIColor systemRedColor],    @"section": @(SectionLaunch) },
        @{ @"title": @"主屏幕定制器",       @"icon": @"square.grid.3x3.fill",                @"color": [UIColor systemBlueColor],   @"section": @(SectionSBC) },
        @{ @"title": @"状态栏监测",            @"icon": @"thermometer.medium",                  @"color": [UIColor systemRedColor],    @"section": @(SectionStatBar) },
        @{ @"title": @"状态栏网速",              @"icon": @"network",                             @"color": [UIColor systemBlueColor],   @"section": @(SectionNSBar) },
        @{ @"title": @"状态栏定制",       @"icon": @"textformat.size",                     @"color": [UIColor systemTealColor],   @"section": @(SectionNiceBarLite) },
#if CYANIDE_PRIVATE_TWEAKS_AVAILABLE
        @{ @"title": @"信号显示",     @"icon": @"antenna.radiowaves.left.and.right",   @"color": [UIColor systemBlueColor],   @"section": @(SectionRSSI), @"indev": @YES },
#endif
        @{ @"title": @"通知收纳",          @"icon": @"bell.badge.fill",                     @"color": [UIColor systemRedColor],    @"section": @(SectionAxonLite) },
#if CYANIDE_PRIVATE_TWEAKS_AVAILABLE
        @{ @"title": @"TypeBanner",         @"icon": @"ellipsis.bubble.fill",                @"color": [UIColor systemTealColor],   @"section": @(SectionTypeBanner), @"indev": @YES },
        @{ @"title": @"通知岛", @"icon": @"bell.and.waves.left.and.right.fill",  @"color": [UIColor systemOrangeColor], @"section": @(SectionNotificationIsland), @"indev": @YES },
        @{ @"title": @"IPA 解密",      @"icon": @"lock.open.fill",                      @"color": [UIColor systemPurpleColor], @"section": @(SectionIPADecryptor), @"indev": @YES },
        @{ @"title": @"FastLockX Lite",     @"icon": @"lock.open.fill",                      @"color": [UIColor systemGreenColor],  @"section": @(SectionFastLockXLite), @"experimental": @YES },
#endif
        @{ @"title": @"重力效果",       @"icon": @"arrow.down.circle.fill",              @"color": [UIColor systemGreenColor],  @"section": @(SectionGravityLite) },
        @{ @"title": @"App 切换器样式",  @"icon": @"square.grid.2x2.fill",                @"color": [UIColor systemOrangeColor], @"section": @(SectionAppSwitcherGrid) },
        @{ @"title": @"位置模拟器", @"icon": @"location.fill",                       @"color": [UIColor systemGreenColor],  @"section": @(SectionLocationSim) },
        @{ @"title": @"主题图标",     @"icon": @"square.stack.3d.up.fill",             @"color": [UIColor systemCyanColor],   @"section": @(SectionSnowBoardLite) },
        @{ @"title": @"动态壁纸",             @"icon": @"play.rectangle.fill",                 @"color": [UIColor systemPurpleColor], @"section": @(SectionLiveWP) },
        @{ @"title": @"降频省电",          @"icon": @"bolt.slash.fill",                     @"color": [UIColor systemOrangeColor], @"section": @(SectionPowercuff) },
        @{ @"title": @"主屏幕插件", @"icon": @"apps.iphone",                         @"color": [UIColor systemIndigoColor], @"section": @(SectionDarkSwordTweaks) },
        @{ @"title": @"动画倍率",   @"icon": @"dial.medium.fill",                    @"color": [UIColor systemIndigoColor], @"section": @(SectionDragCoefficient) },
        @{ @"title": @"主屏幕布局扩展", @"icon": @"square.dashed.inset.filled",          @"color": [UIColor systemPurpleColor], @"section": @(SectionLayoutExtras) },
    ];
}

- (NSArray<NSDictionary *> *)allSystemBundleRows
{
    return @[
        @{ @"title": @"OTA 更新",       @"icon": @"icloud.slash.fill",    @"color": [UIColor systemGrayColor],   @"section": @(SectionOTA) },
        @{ @"title": @"手表配对",     @"icon": @"applewatch.radiowaves.left.and.right", @"color": [UIColor systemPurpleColor], @"section": @(SectionNanoRegistry) },
    ];
}

- (NSArray<NSDictionary *> *)filterBundles:(NSArray<NSDictionary *> *)bundles
{
    BOOL experimentalOn = settings_experimental_tweaks_enabled();
    NSMutableArray<NSDictionary *> *out = [NSMutableArray array];
    for (NSDictionary *bundle in bundles) {
        if ([bundle[@"indev"] boolValue]) continue;
        if ([bundle[@"experimental"] boolValue] && !experimentalOn) continue;
        NSInteger sec = [bundle[@"section"] integerValue];
        if ([self rowsForSection:sec].count > 0) {
            [out addObject:bundle];
        }
    }
    return out;
}

- (NSArray<NSDictionary *> *)inDevBundleRows
{
    BOOL experimentalOn = settings_experimental_tweaks_enabled();
    if (!experimentalOn) return @[];
    NSMutableArray<NSDictionary *> *out = [NSMutableArray array];
    for (NSDictionary *bundle in [self allTweakBundleRows]) {
        if (![bundle[@"indev"] boolValue]) continue;
        NSInteger sec = [bundle[@"section"] integerValue];
        if ([self rowsForSection:sec].count > 0) {
            [out addObject:bundle];
        }
    }
    return out;
}

- (NSArray<NSDictionary *> *)tweakBundleRows
{
    return [self filterBundles:[self allTweakBundleRows]];
}

- (NSArray<NSDictionary *> *)systemBundleRows
{
    return [self filterBundles:[self allSystemBundleRows]];
}

- (NSArray<NSDictionary *> *)bundleRowsForRootSection:(RootSection)section
{
    if (section == RootSectionTweakBundles)  return self.tweakBundleRows;
    if (section == RootSectionInDev)        return self.inDevBundleRows;
    if (section == RootSectionSystemBundles) return self.systemBundleRows;
    return @[];
}

#pragma mark - Table data

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.detailMode ? 1 : RootSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.detailMode) {
        return (NSInteger)[self rowsForSection:self.underlyingSection].count;
    }
    switch ((RootSection)section) {
        case RootSectionChangelog: {
            NSInteger n = (NSInteger)settings_changelog_entries().count;
            if (n == 0) return 0;
            return self.changelogExpanded ? n + 2 : 1;
        }
        case RootSectionActions:        return 4;
        case RootSectionTweakBundles:   return (NSInteger)self.tweakBundleRows.count;
        case RootSectionInDev:         return (NSInteger)self.inDevBundleRows.count;
        case RootSectionSystemBundles:  return (NSInteger)self.systemBundleRows.count;
        case RootSectionPatreon: {
            // Unlinked users get two rows: "Link" (for people who already have
            // a Patreon account) and "New to Patreon? Sign Up" (jumps to the
            // creator page so they can join in Safari first). Without the
            // sign-up affordance, a first-time user has no obvious way to
            // discover that they need a Patreon account to begin with.
            if (!cyanide_patreon_is_linked()) return 2;
            // Linked-but-not-pledging gets an extra "Join Member Tier" row
            // so users have an obvious in-app path to upgrade.
            return cyanide_is_patron() ? 3 : 4;
        }
        case RootSectionExperimental:   return 1;
        case RootSectionAbout:          return 6;
        case RootSectionWarning:        return 0;
        case RootSectionCount:          return 0;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (self.detailMode) return nil;
    switch ((RootSection)section) {
        case RootSectionChangelog:      return self.changelogExpanded ? @"最新动态" : nil;
        case RootSectionActions:        return @"快捷操作";
        case RootSectionTweakBundles:   return self.tweakBundleRows.count   > 0 ? @"插件" : nil;
        case RootSectionInDev:         return self.inDevBundleRows.count   > 0 ? @"开发中" : nil;
        case RootSectionSystemBundles:  return self.systemBundleRows.count  > 0 ? @"系统" : nil;
        case RootSectionPatreon:        return @"Patreon";
        case RootSectionExperimental:   return @"实验功能";
        case RootSectionAbout:          return @"关于";
        default:                        return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (!self.detailMode) {
        if ((RootSection)section == RootSectionExperimental) {
            if (!settings_experimental_access_allowed()) {
                return @"面向 Patreon 会员等级的抢先体验。";
            }
            return nil;
        }
        if ((RootSection)section == RootSectionPatreon) {
            if (!cyanide_patreon_is_linked()) {
                return @"Cyanide 是免费的。Patreon 支持者可以获得实验功能的抢先体验。"
                       @"认证在应用内完成。";
            }
            NSDate *last = cyanide_patreon_last_refresh_date();
            if (last) {
                NSDateFormatter *df = [[NSDateFormatter alloc] init];
                df.dateStyle = NSDateFormatterMediumStyle;
                df.timeStyle = NSDateFormatterShortStyle;
                return [NSString stringWithFormat:@"上次检查：%@", [df stringFromDate:last]];
            }
            return nil;
        }
        return nil;
    }
    NSInteger s = self.underlyingSection;
    if (s == SectionLaunch) {
        return @"kexploit 每次启动仅运行一次。保活仅在 Cyanide 最小化时生效；从 App 切换器强制退出仍会终止进程。";
    }
    if (s == SectionSBC) {
        return [NSString stringWithFormat:@"系统默认值：Dock %ld，列 %ld，行 %ld。",
                (long)kSBCDefaultDockIcons, (long)kSBCDefaultCols, (long)kSBCDefaultRows];
    }
    if (s == SectionDarkSwordTweaks) {
        return @"源自 DarkSword-Tweaks。这些是主屏幕（SpringBoard）运行时补丁，关闭开关仅跳过下次应用，已生效的保持不变。";
    }
    if (s == SectionDragCoefficient) {
        return @"输入倍率：1.00 = 原速，0.50 = 2 倍速，0.25 = 4 倍速，最低 0.01。";
    }
    if (s == SectionLayoutExtras) {
        NSInteger major = [[NSProcessInfo processInfo] operatingSystemVersion].majorVersion;
        if (major >= 26) {
            return [NSString stringWithFormat:
                @"在主屏幕/Dock栏布局基础上增加额外间距和图标缩放。\n\n"
                @"当前运行在 iOS %ld：旋转屏幕、翻页等布局刷新可能触发 iOS 26 重新适配。",
                (long)major];
        }
        return @"在主屏幕/Dock 栏布局基础上增加额外间距和图标缩放。默认值为零间距和 100% 缩放（无变化）。开启开关并点“运行”生效；数值在注销后不保留。";
    }
    if (s == SectionOTA) {
        return @"编辑 launchd disabled.plist。需要重启设备或用户空间重启才能使更改生效。";
    }
    if (s == SectionNanoRegistry) {
        return @"更改此 iPhone 上保存的 watchOS 配对范围。\n\n"
               @"大多数人应该点击“使用 watchOS”，然后点击“应用配对覆盖设置”。"
               @"这些是配对协议的代数，而不是 Apple Watch 型号编号。"
               @"99 提高 watchOS 配对上限。23 保持接受第 23 代设置协议。"
               @"10 和 6 将旧芯片和多手表下限保持在正常值。\n\n"
               @"Apple Watch Ultra 3 目前无法在低于 26 的 iOS 版本上配对。\n\n"
               @"应用后先注销或重启，再尝试配对。";
    }
    if (s == SectionPowercuff) {
        return @"通过模拟热压力，借助温控守护进程（thermalmonitord）对 CPU/GPU 降频。标准为日常使用默认档。轻度、中度、重度会刻意加大降频幅度，可能使设备变卡，老机型尤为明显。";
    }
    if (s == SectionStatBar) {
        return @"当 Cyanide 最小化但屏幕仍亮着时，刷新正常生效；锁屏或休眠后 StatBar 会暂停刷新。";
    }
    if (s == SectionNSBar) {
        return @"显示实时下载和上传速度，大约每秒刷新一次。";
    }
    if (s == SectionNiceBarLite) {
        return @"点击方框可选择其显示内容。NiceBar Lite 会将纯文本放入刘海或灵动岛周围已配置的状态栏槽位中，包括底部居中位置。天气数据通过 Open-Meteo 从你的当前位置获取，并遵循摄氏度开关设置。";
    }
    if (s == SectionRSSI) {
        return @"以每个 STUI 信号视图的同级视图形式添加一个 UILabel（不创建新的 UIWindow），每秒刷新一次。蜂窝网络显示实时 RSRP dBm（隐式带符号）。WiFi 显示信号格数（0-4）；在之前的测试中，通过无线网络守护进程（wifid）XPC 获取 dBm 的路径导致主屏幕（SpringBoard）崩溃。";
    }
    if (s == SectionAxonLite) {
        return @"纯 RemoteCall 方式移植的 Axon。它靠 App 端实时循环驱动，而非依赖底层 Hook 框架（Substrate）钩子，因此仅在 Cyanide 与主屏幕（SpringBoard）通道活跃期间有效。";
    }
    if (s == SectionTypeBanner) {
        return @"TypeMillennium 部分移植版。检测通过原版线程 RemoteCall 探针针对信息守护进程（imagent）运行，同时主屏幕（SpringBoard）负责渲染已预热的横幅窗口。";
    }
    if (s == SectionNotificationIsland) {
        return @"实验性灵动岛通知路径。Cyanide 通过共享的 RemoteCall 通道轮询主屏幕（SpringBoard）的活跃横幅请求，再通过 App 的 ActivityKit 实时活动将其镜像显示。";
    }
    if (s == SectionAppSwitcherGrid) {
        return @"运行时补丁。它在内存中更改主屏幕（SpringBoard）的 App 切换器样式，不写入任何系统文件，注销即恢复原版。不受支持的版本可能导致 App 切换器显示异常或主屏幕（SpringBoard）崩溃。";
    }
    if (s == SectionGravityLite) {
        return @"Julio Verne's Gravity 的纯 RemoteCall 核心移植版。运行后会将 UIDynamicAnimator 重力、碰撞、弹跳、摩擦力、可选 Dock 栏物理效果以及加速度计转向应用于主屏幕（SpringBoard）图标快照。在主屏幕（SpringBoard）通道活跃期间，可恢复图标布局或手动触发爆发脉冲。\n\n此核心移植版未包含：Activator/主屏幕按钮 hooks、拖拽手势、自动摇晃效果及偏好设置守护进程通知。";
    }
    if (s == SectionLocationSim) {
        return @"测试版 CoreLocation 模拟。需要已安装并设置好的 Apple 地图——地图是驱动该模拟的 RemoteCall 宿主进程。\n\n这是一个手动工具，而非可安装包。使用“模拟当前位置”开始；使用“恢复真实位置”停止模拟，并将 CoreLocation 交还给设备的真实定位源。每次运行都会打开活动日志，并在请求返回时标记完成。\n\n并非所有 App 都会遵循模拟位置。使用自有位置验证或额外信号的 App 可能会忽略此模拟。\n\n鸣谢：kolbicz 提供的 RemoteCall/CLSimulationManager GPS 欺骗原型，以及 ezzuldinSt 的 LSpoof 提供的选择器/路线参考。\n\n警告：此功能的影响范围可能超出地图。与位置绑定的系统行为——包括时区和日期/时间处理——可能出现异常。请仅在清楚操作后果时使用。";
    }
    if (s == SectionIPADecryptor) {
        return @"开发中的本地 IPA 解密工具。当前版本可发现已安装的用户应用、将粘贴的 App Store 链接解析为包名 ID、登录 App Store 获取下载令牌，以及将加密 IPA 下载到 Documents 目录。下载后的 IPA 仍需经过 SINF/iTunesMetadata 修补和 KRW 转储/重建阶段才能成为已解密的 IPA。";
    }
    if (s == SectionThemer) {
        return @"旧版图标主题引擎设置。\n\n"
               @"在运行图标主题引擎之前选择一个主题。\n\n"
               @"兼容性：启用 Dynamic Stage Lite 后，实时图标修复会暂停，以避免主屏幕（SpringBoard）注销。所选主题仍会应用一次。\n\n"
               @"自定义主题可以是一个以包名 ID 命名的 PNG 文件夹（如 com.apple.mobilesafari.png），也可以是一个将包名 ID 映射到 PNG 数据的二进制 plist。导入会将主题复制到 Cyanide 的 Documents/Themes 文件夹中。主题格式指南包含示例和 plist 导出功能。";
    }
    if (s == SectionSnowBoardLite) {
        return @"SnowBoard/IconBundles 导入器，移植自 d1y/cyanide-ios。导入的文件夹会被复制到 Cyanide 的 Documents/SnowBoardLite 库中，并通过现有的图标替换流程应用。\n\n兼容性：启用 Dynamic Stage Lite 后，实时图标修复会暂停，以避免主屏幕（SpringBoard）注销。所选主题仍会应用一次。";
    }
    if (s == SectionLiveWP) {
        return @"视频壁纸，移植自 d1y/cyanide-ios。选择一个 MP4、MOV 或 M4V 文件；Cyanide 会将其复制到 Documents/LiveWP 中，并在 RemoteCall 通道保持活跃期间于主屏幕（SpringBoard）上播放。";
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (!self.detailMode) {
        if ((RootSection)section == RootSectionWarning) return CGFLOAT_MIN;
        if ((RootSection)section == RootSectionChangelog     && settings_changelog_entries().count == 0) return CGFLOAT_MIN;
        if ((RootSection)section == RootSectionTweakBundles  && self.tweakBundleRows.count  == 0) return CGFLOAT_MIN;
        if ((RootSection)section == RootSectionInDev        && self.inDevBundleRows.count  == 0) return CGFLOAT_MIN;
        if ((RootSection)section == RootSectionSystemBundles && self.systemBundleRows.count == 0) return CGFLOAT_MIN;
    }
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if ([self tableView:tableView titleForFooterInSection:section].length > 0)
        return UITableViewAutomaticDimension;
    return 6.0;
}

#pragma mark - Icon badge

+ (UIImage *)iconBadgeWithSymbol:(NSString *)symbol color:(UIColor *)color size:(CGFloat)size
{
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size) format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGFloat radius = size * (7.0 / 29.0);
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size, size) cornerRadius:radius];
        [color setFill];
        [path fill];

        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:size * 0.58 weight:UIImageSymbolWeightSemibold];
        UIImage *symbolImage = [UIImage systemImageNamed:symbol withConfiguration:cfg];
        if (symbolImage) {
            UIImage *whiteIcon = [symbolImage imageWithTintColor:UIColor.whiteColor renderingMode:UIImageRenderingModeAlwaysOriginal];
            CGFloat x = (size - whiteIcon.size.width) / 2.0;
            CGFloat y = (size - whiteIcon.size.height) / 2.0;
            [whiteIcon drawAtPoint:CGPointMake(x, y)];
        }
    }];
}

#pragma mark - Cells

- (UITableViewCell *)buildBundleCellWithRow:(NSDictionary *)row tableView:(UITableView *)tableView
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"bundle"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"bundle"];
    }
    cell.imageView.image = [SettingsViewController iconBadgeWithSymbol:row[@"icon"] color:row[@"color"] size:29.0];
    cell.textLabel.text = row[@"title"];
    cell.textLabel.font = [UIFont systemFontOfSize:17.0];
    cell.textLabel.textColor = UIColor.labelColor;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (UITableViewCell *)buildInDevCellWithRow:(NSDictionary *)row tableView:(UITableView *)tableView
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"indev"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"indev"];
    }
    cell.imageView.image = [SettingsViewController iconBadgeWithSymbol:row[@"icon"] color:[UIColor systemGrayColor] size:29.0];
    cell.textLabel.text = row[@"title"];
    cell.textLabel.font = [UIFont systemFontOfSize:17.0];
    cell.textLabel.textColor = UIColor.tertiaryLabelColor;
    cell.detailTextLabel.text = @"开发中";
    cell.detailTextLabel.font = [UIFont systemFontOfSize:13.0];
    cell.detailTextLabel.textColor = UIColor.tertiaryLabelColor;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.userInteractionEnabled = NO;
    return cell;
}

- (UITableViewCell *)buildChangelogCellAtRow:(NSInteger)row tableView:(UITableView *)tableView
{
    NSArray<NSDictionary *> *entries = settings_changelog_entries();
    NSDictionary *entry = (row >= 0 && row < (NSInteger)entries.count) ? entries[row] : nil;

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"changelog-entry"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"changelog-entry"];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.imageView.image = nil;
    cell.textLabel.text = nil;
    for (UIView *v in [cell.contentView.subviews copy]) [v removeFromSuperview];

    NSString *version = entry[@"version"] ?: @"";
    NSString *date    = settings_pretty_date_for_iso(entry[@"date"]);

    // Version pill
    UILabel *versionLabel = [[UILabel alloc] init];
    versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    versionLabel.text = [NSString stringWithFormat:@" v%@ ", version];
    versionLabel.font = [UIFont monospacedDigitSystemFontOfSize:12.0 weight:UIFontWeightSemibold];
    versionLabel.textColor = UIColor.systemBlueColor;
    versionLabel.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.12];
    versionLabel.layer.cornerRadius = 4.0;
    versionLabel.layer.masksToBounds = YES;
    versionLabel.textAlignment = NSTextAlignmentCenter;

    UILabel *dateLabel = [[UILabel alloc] init];
    dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    dateLabel.text = date;
    dateLabel.font = [UIFont systemFontOfSize:13.0];
    dateLabel.textColor = UIColor.tertiaryLabelColor;

    // Build bullet list with hanging indent
    NSArray *changes = entry[@"changes"];
    NSMutableArray<NSString *> *lines = [NSMutableArray arrayWithCapacity:changes.count];
    for (id c in changes) {
        if (![c isKindOfClass:[NSString class]]) continue;
        [lines addObject:(NSString *)c];
    }

    NSMutableParagraphStyle *bulletStyle = [[NSMutableParagraphStyle alloc] init];
    bulletStyle.headIndent = 14.0;
    bulletStyle.firstLineHeadIndent = 0.0;
    bulletStyle.paragraphSpacing = 4.0;
    bulletStyle.lineBreakMode = NSLineBreakByWordWrapping;

    NSDictionary *bulletAttrs = @{
        NSFontAttributeName: [UIFont systemFontOfSize:14.0],
        NSForegroundColorAttributeName: UIColor.labelColor,
        NSParagraphStyleAttributeName: bulletStyle,
    };
    NSDictionary *dotAttrs = @{
        NSFontAttributeName: [UIFont systemFontOfSize:14.0],
        NSForegroundColorAttributeName: UIColor.tertiaryLabelColor,
        NSParagraphStyleAttributeName: bulletStyle,
    };

    NSMutableAttributedString *body = [[NSMutableAttributedString alloc] init];
    for (NSUInteger i = 0; i < lines.count; i++) {
        if (i > 0) [body appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
        [body appendAttributedString:[[NSAttributedString alloc] initWithString:@"›  " attributes:dotAttrs]];
        [body appendAttributedString:[[NSAttributedString alloc] initWithString:lines[i] attributes:bulletAttrs]];
    }

    UILabel *bodyLabel = [[UILabel alloc] init];
    bodyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    bodyLabel.attributedText = body;
    bodyLabel.numberOfLines = 0;

    [cell.contentView addSubview:versionLabel];
    [cell.contentView addSubview:dateLabel];
    [cell.contentView addSubview:bodyLabel];

    UILayoutGuide *m = cell.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [versionLabel.leadingAnchor  constraintEqualToAnchor:m.leadingAnchor],
        [versionLabel.topAnchor      constraintEqualToAnchor:m.topAnchor],
        [dateLabel.leadingAnchor     constraintEqualToAnchor:versionLabel.trailingAnchor constant:8],
        [dateLabel.centerYAnchor     constraintEqualToAnchor:versionLabel.centerYAnchor],
        [bodyLabel.leadingAnchor     constraintEqualToAnchor:m.leadingAnchor],
        [bodyLabel.trailingAnchor    constraintEqualToAnchor:m.trailingAnchor],
        [bodyLabel.topAnchor         constraintEqualToAnchor:versionLabel.bottomAnchor constant:8],
        [bodyLabel.bottomAnchor      constraintEqualToAnchor:m.bottomAnchor],
    ]];

    return cell;
}

- (UITableViewCell *)buildChangelogFooterCellInTableView:(UITableView *)tableView
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"changelog-footer"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"changelog-footer"];
    }
    cell.imageView.image = nil;
    cell.textLabel.text = @"在 GitHub 上查看所有版本";
    cell.textLabel.font = [UIFont systemFontOfSize:15.0];
    cell.textLabel.textColor = self.view.tintColor;
    cell.detailTextLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (UITableViewCell *)buildChangelogCollapsedCellInTableView:(UITableView *)tableView
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"changelog-collapsed"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"changelog-collapsed"];
    }
    NSArray<NSDictionary *> *entries = settings_changelog_entries();
    NSDictionary *first = entries.firstObject;
    NSString *version = first[@"version"] ?: @"";
    NSInteger count = 0;
    for (id c in first[@"changes"]) { if ([c isKindOfClass:[NSString class]]) count++; }
    cell.imageView.image = [SettingsViewController iconBadgeWithSymbol:@"sparkles" color:UIColor.systemYellowColor size:29.0];
    cell.textLabel.text = [NSString stringWithFormat:@"v%@ 的新变化", version];
    cell.textLabel.font = [UIFont systemFontOfSize:17.0];
    cell.textLabel.textColor = UIColor.labelColor;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld 项更改", (long)count];
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (UITableViewCell *)buildChangelogCollapseCellInTableView:(UITableView *)tableView
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"changelog-collapse"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"changelog-collapse"];
    }
    cell.imageView.image = nil;
    cell.textLabel.text = @"收起";
    cell.textLabel.font = [UIFont systemFontOfSize:15.0];
    cell.textLabel.textColor = self.view.tintColor;
    cell.textLabel.textAlignment = NSTextAlignmentCenter;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)openReleasesPage
{
    NSURL *url = [NSURL URLWithString:@"https://github.com/zeroxjf/cyanide/releases"];
    if (url) [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (UITableViewCell *)buildDocsCellInTableView:(UITableView *)tableView
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"docs"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"docs"];
    }
    cell.imageView.image = [SettingsViewController iconBadgeWithSymbol:@"book.closed.fill" color:UIColor.systemPurpleColor size:29.0];
    cell.textLabel.font = [UIFont systemFontOfSize:17.0];
    cell.textLabel.textColor = UIColor.labelColor;
    cell.textLabel.text = @"插件 SDK";
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.detailTextLabel.text = @"如何编写 Cyanide 插件";
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (UITableViewCell *)buildAboutCellAtRow:(NSInteger)row tableView:(UITableView *)tableView
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"about"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"about"];
    }
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.textLabel.font = [UIFont systemFontOfSize:17.0];
    cell.textLabel.textColor = UIColor.labelColor;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.detailTextLabel.text = nil;

    switch (row) {
        case 0:
            cell.imageView.image = [SettingsViewController iconBadgeWithSymbol:@"at" color:UIColor.systemBlueColor size:29.0];
            cell.textLabel.text = @"Twitter";
            cell.detailTextLabel.text = @"@zeroxjf";
            break;
        case 1:
            cell.imageView.image = [SettingsViewController iconBadgeWithSymbol:@"book.closed.fill" color:UIColor.systemPurpleColor size:29.0];
            cell.textLabel.text = @"插件 SDK";
            break;
        case 2:
            cell.imageView.image = [SettingsViewController iconBadgeWithSymbol:@"app.fill" color:UIColor.systemTealColor size:29.0];
            cell.textLabel.text = @"应用图标";
            cell.detailTextLabel.text = [[self currentAppIconStyle] isEqualToString:@"classic"] ? @"经典" : @"现代";
            break;
        case 3:
            cell.imageView.image = [SettingsViewController iconBadgeWithSymbol:@"doc.text.magnifyingglass" color:UIColor.systemGrayColor size:29.0];
            cell.textLabel.text = @"查看日志";
            break;
        case 4:
            cell.imageView.image = [SettingsViewController iconBadgeWithSymbol:@"square.and.arrow.up" color:UIColor.systemGreenColor size:29.0];
            cell.textLabel.text = @"分享日志";
            break;
        default:
            cell.imageView.image = [SettingsViewController iconBadgeWithSymbol:@"icloud.and.arrow.up" color:UIColor.systemIndigoColor size:29.0];
            cell.textLabel.text = @"自动上传日志";
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            UISwitch *sw = [[UISwitch alloc] init];
            sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:kSettingsLogUploadEnabled];
            [sw addTarget:self action:@selector(logUploadSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            break;
    }
    return cell;
}

- (void)logUploadSwitchChanged:(UISwitch *)sw {
    [[NSUserDefaults standardUserDefaults] setBool:sw.isOn forKey:kSettingsLogUploadEnabled];
}

- (void)reloadThemerSectionAndQueue
{
    settings_mark_tweak_applied(kSettingsThemerEnabled, NO);
    settings_notify_package_queue_changed_async();
    if (self.detailMode && self.underlyingSection == SectionThemer) {
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
                      withRowAnimation:UITableViewRowAnimationAutomatic];
    } else {
        [self.tableView reloadData];
    }
}

- (void)selectBuiltInIOS6Theme
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:kThemerThemeBuiltinIOS6 forKey:kSettingsThemerThemeID];
    [d synchronize];
    log_user("[THEMER] Selected iOS 6 Theme.\n");
    [self reloadThemerSectionAndQueue];
}

- (void)clearSelectedTheme
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:kThemerThemeNone forKey:kSettingsThemerThemeID];
    [d setObject:@"" forKey:kSettingsThemerCustomThemePath];
    [d setObject:@"" forKey:kSettingsThemerCustomThemeName];
    if ([d boolForKey:kSettingsThemerEnabled]) {
        [d setBool:NO forKey:kSettingsThemerEnabled];
        g_themer_live_stop_requested = 1;
    }
    [d synchronize];
    log_user("[THEMER] Cleared selected theme; the icon theme engine is no longer pending activation.\n");
    [self reloadThemerSectionAndQueue];
}

- (void)presentThemerFormatGuide
{
    ThemerFormatGuideViewController *vc =
        [[ThemerFormatGuideViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    if (self.navigationController) {
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    vc.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:vc
                                                      action:@selector(dismissGuide)];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)presentThemerImporter
{
    UIAlertController *hint = [UIAlertController
        alertControllerWithTitle:@"导入主题文件夹"
                         message:@"进入你的主题文件夹，确保能看到里面的 PNG 文件，然后轻点右上角的“打开”即可导入该文件夹。"
                  preferredStyle:UIAlertControllerStyleAlert];
    [hint addAction:[UIAlertAction actionWithTitle:@"继续" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        (void)a;
        UIDocumentPickerViewController *picker =
            [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeFolder, UTTypePropertyList]];
        picker.delegate = self;
        picker.allowsMultipleSelection = NO;
        self.pendingThemeImportMode = @"themer";
        [self presentViewController:picker animated:YES completion:nil];
    }]];
    [hint addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:hint animated:YES completion:nil];
}

- (void)presentSnowBoardLiteFolderImporter
{
    UIAlertController *hint = [UIAlertController
        alertControllerWithTitle:@"导入主题文件夹"
                         message:@"选择您的主题文件夹，确保您能看到其中的 IconBundles 目录，然后点击“打开”。\n\n如果点击“打开”无反应，您的签名工具可能需要启用“Match provisioning identifier”，或者您可以使用“导入主题压缩包文件”。"
                  preferredStyle:UIAlertControllerStyleAlert];
    [hint addAction:[UIAlertAction actionWithTitle:@"继续" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        (void)a;
        UIDocumentPickerViewController *picker =
            [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeFolder]];
        picker.delegate = self;
        picker.allowsMultipleSelection = NO;
        self.pendingThemeImportMode = @"snowboardlite";
        [self presentViewController:picker animated:YES completion:nil];
    }]];
    [hint addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:hint animated:YES completion:nil];
}

- (void)presentSnowBoardLiteArchiveImporter
{
    UIAlertController *hint = [UIAlertController
        alertControllerWithTitle:@"导入主题压缩包文件"
                         message:@"选择包含 IconBundles 目录的 ZIP 或 DEB 文件。Cyanide 会解压并导入一份本地副本。"
                  preferredStyle:UIAlertControllerStyleAlert];
    [hint addAction:[UIAlertAction actionWithTitle:@"继续" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        (void)a;
        NSArray<UTType *> *types = @[
            UTTypeZIP,
            [UTType typeWithFilenameExtension:@"deb"] ?: UTTypeData,
        ];
        UIDocumentPickerViewController *picker =
            [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
        picker.delegate = self;
        picker.allowsMultipleSelection = NO;
        self.pendingThemeImportMode = @"snowboardlite";
        [self presentViewController:picker animated:YES completion:nil];
    }]];
    [hint addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:hint animated:YES completion:nil];
}

- (void)presentLiveWPVideoPicker
{
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"选择视频"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"照片"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        (void)a;
        [self presentLiveWPPhotosPicker];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"文件"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        (void)a;
        [self presentLiveWPDocumentPicker];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    UIPopoverPresentationController *pop = sheet.popoverPresentationController;
    if (pop) {
        pop.sourceView = self.view;
        pop.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
        pop.permittedArrowDirections = 0;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)presentLiveWPPhotosPicker
{
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.filter = [PHPickerFilter videosFilter];
    config.selectionLimit = 1;
    config.preferredAssetRepresentationMode = PHPickerConfigurationAssetRepresentationModeCurrent;

    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (NSArray<UTType *> *)liveWPVideoDocumentTypes
{
    NSMutableArray<UTType *> *types = [NSMutableArray array];
    NSArray<NSString *> *extensions = @[@"mp4", @"mov", @"m4v"];
    for (NSString *ext in extensions) {
        UTType *type = [UTType typeWithFilenameExtension:ext];
        if (type) [types addObject:type];
    }
    [types addObject:UTTypeMovie];
    [types addObject:UTTypeAudiovisualContent];
    return types;
}

- (void)presentLiveWPDocumentPicker
{
    UIDocumentPickerViewController *picker =
        [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:[self liveWPVideoDocumentTypes] asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    self.pendingThemeImportMode = @"livewp";
    [self presentViewController:picker animated:YES completion:nil];
}

- (BOOL)importLiveWPVideoAtURL:(NSURL *)url error:(NSError **)error
{
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    if (docs.length == 0) return NO;
    NSString *liveDir = [docs stringByAppendingPathComponent:@"LiveWP"];
    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm createDirectoryAtPath:liveDir withIntermediateDirectories:YES attributes:nil error:error]) {
        return NO;
    }

    NSString *ext = url.pathExtension.length ? url.pathExtension.lowercaseString : @"mov";
    NSSet<NSString *> *allowed = [NSSet setWithArray:@[@"mp4", @"mov", @"m4v"]];
    if (![allowed containsObject:ext]) {
        if (error) {
            *error = [NSError errorWithDomain:@"LiveWP"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey: @"请选择 MP4、MOV 或 M4V 视频。"}];
        }
        return NO;
    }

    NSString *base = url.URLByDeletingPathExtension.lastPathComponent;
    if (base.length == 0) base = @"LiveWP";
    NSCharacterSet *bad = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
    NSString *safeBase = [[base componentsSeparatedByCharactersInSet:bad] componentsJoinedByString:@"-"];
    if (safeBase.length == 0) safeBase = @"LiveWP";
    NSString *fileName = [NSString stringWithFormat:@"%@-%llu.%@",
                          safeBase,
                          (unsigned long long)(NSDate.date.timeIntervalSince1970 * 1000.0),
                          ext];
    NSString *dest = [liveDir stringByAppendingPathComponent:fileName];
    if (![fm copyItemAtURL:url toURL:[NSURL fileURLWithPath:dest] error:error]) {
        return NO;
    }

    NSString *relative = [@"LiveWP" stringByAppendingPathComponent:fileName];
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d setObject:relative forKey:kSettingsLiveWPVideoPath];
    [d synchronize];
    log_user("[LIVEWP] Selected video: %s\n", fileName.UTF8String);
    return YES;
}

- (void)finishLiveWPVideoImportAndSwapIfRunning
{
    [self reloadSectionOrAll:SectionLiveWP];

    BOOL applied = settings_tweak_is_applied(kSettingsLiveWPEnabled);
    log_user("[LIVEWP] import: applied=%d rc_ready=%d\n", applied, g_springboard_rc_ready);
    if (!applied || !g_springboard_rc_ready) {
        settings_notify_package_queue_changed_async();
        return;
    }

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        bool ok = false;
        @synchronized (settings_rc_lock()) {
            if (settings_cleanup_in_progress() || !g_springboard_rc_ready) return;
            NSString *path = livewp_absolute_path();
            log_user("[LIVEWP] import: swap path=%s\n", path ? path.UTF8String : "(nil)");
            if (path.length > 0) {
                ok = livewp_swap_video_in_session(path);
                settings_mark_tweak_applied(kSettingsLiveWPEnabled, ok);
            }
        }
        log_user("%s LiveWP video swap %s.\n",
                 ok ? "[OK]" : "[WARN]",
                 ok ? "completed" : "did not complete");
        if (ok) settings_start_livewp_live_loop();
        settings_notify_package_queue_changed_async();
    });
}

- (NSString *)liveWPPreferredTypeIdentifierForProvider:(NSItemProvider *)provider
{
    NSMutableArray<NSString *> *identifiers = [NSMutableArray array];
    for (UTType *type in [self liveWPVideoDocumentTypes]) {
        if (type.identifier.length > 0) [identifiers addObject:type.identifier];
    }
    [identifiers addObjectsFromArray:@[
        @"public.mpeg-4",
        @"com.apple.m4v-video",
        @"com.apple.quicktime-movie",
        @"public.movie",
        @"public.audiovisual-content",
    ]];
    for (NSString *identifier in identifiers) {
        if ([provider hasItemConformingToTypeIdentifier:identifier]) return identifier;
    }
    return nil;
}

- (void)finishLiveWPVideoImportFromURL:(NSURL *)url
                           displayName:(NSString *)displayName
{
    NSError *err = nil;
    BOOL ok = [self importLiveWPVideoAtURL:url error:&err];
    BOOL liveReady = settings_tweak_is_applied(kSettingsLiveWPEnabled) && g_springboard_rc_ready;
    NSString *name = displayName.length ? displayName : (url.lastPathComponent ?: @"视频");
    NSString *successMessage = liveReady
        ? [NSString stringWithFormat:@"%@ 已导入，并将切换到正在运行的 LiveWP 通道中。", name]
        : [NSString stringWithFormat:@"%@ 已就绪。打开 LiveWP 并点击运行以应用。", name];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!ok) {
            NSString *msg = err.localizedDescription ?: @"所选视频无法导入。";
            UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"导入失败"
                                                                         message:msg
                                                                  preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:ac animated:YES completion:nil];
            return;
        }
        [self finishLiveWPVideoImportAndSwapIfRunning];
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"视频已选择"
                                                                     message:successMessage
                                                              preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:ac animated:YES completion:nil];
    });
}

- (void)picker:(PHPickerViewController *)picker
didFinishPicking:(NSArray<PHPickerResult *> *)results
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    PHPickerResult *result = results.firstObject;
    if (!result) return;

    NSItemProvider *provider = result.itemProvider;
    NSString *identifier = [self liveWPPreferredTypeIdentifierForProvider:provider];
    if (identifier.length == 0) {
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"导入失败"
                                                                     message:@"请选择 MP4、MOV 或 M4V 视频。"
                                                              preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:ac animated:YES completion:nil];
        return;
    }

    NSString *displayName = provider.suggestedName ?: @"视频";
    [provider loadFileRepresentationForTypeIdentifier:identifier
                                    completionHandler:^(NSURL *url, NSError *error) {
        if (!url || error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *msg = error.localizedDescription ?: @"无法打开所选视频。";
                UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"导入失败"
                                                                             message:msg
                                                                      preferredStyle:UIAlertControllerStyleAlert];
                [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:ac animated:YES completion:nil];
            });
            return;
        }
        [self finishLiveWPVideoImportFromURL:url displayName:displayName];
    }];
}

- (BOOL)importThemerFolderAtURL:(NSURL *)url error:(NSError **)error
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *target = settings_themer_imported_theme_dir();
    NSString *root = settings_themer_documents_theme_root();
    if (!target || !root) return NO;

    [fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:error];
    if (error && *error) return NO;

    NSArray<NSURL *> *files = [fm contentsOfDirectoryAtURL:url
                                includingPropertiesForKeys:nil
                                                   options:0
                                                     error:error];
    if (!files) return NO;

    NSMutableArray<NSURL *> *pngs = [NSMutableArray array];
    for (NSURL *file in files) {
        if ([file.pathExtension.lowercaseString isEqualToString:@"png"]) {
            [pngs addObject:file];
        }
    }
    if (pngs.count == 0) return NO;

    [fm removeItemAtPath:target error:nil];
    [fm createDirectoryAtPath:target withIntermediateDirectories:YES attributes:nil error:error];
    if (error && *error) return NO;
    [fm removeItemAtPath:settings_themer_imported_plist_path() error:nil];

    for (NSURL *png in pngs) {
        NSString *dst = [target stringByAppendingPathComponent:png.lastPathComponent];
        if (![fm copyItemAtURL:png toURL:[NSURL fileURLWithPath:dst] error:error]) {
            return NO;
        }
    }

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:kThemerThemeCustom forKey:kSettingsThemerThemeID];
    [d setObject:target forKey:kSettingsThemerCustomThemePath];
    [d setObject:url.lastPathComponent.length ? url.lastPathComponent : @"导入的主题"
          forKey:kSettingsThemerCustomThemeName];
    [d synchronize];
    log_user("[THEMER] Imported custom folder theme: %lu PNG file(s).\n",
             (unsigned long)pngs.count);
    return YES;
}

- (BOOL)importThemerPlistAtURL:(NSURL *)url error:(NSError **)error
{
    NSDictionary *dict = settings_themer_load_plist_theme(url.path);
    if (dict.count == 0) return NO;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *root = settings_themer_documents_theme_root();
    NSString *target = settings_themer_imported_plist_path();
    if (!root || !target) return NO;
    [fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:error];
    if (error && *error) return NO;
    [fm removeItemAtPath:target error:nil];
    [fm removeItemAtPath:settings_themer_imported_theme_dir() error:nil];
    if (![fm copyItemAtURL:url toURL:[NSURL fileURLWithPath:target] error:error]) {
        return NO;
    }

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:kThemerThemeCustom forKey:kSettingsThemerThemeID];
    [d setObject:target forKey:kSettingsThemerCustomThemePath];
    [d setObject:url.lastPathComponent.length ? url.lastPathComponent : @"导入的主题"
          forKey:kSettingsThemerCustomThemeName];
    [d synchronize];
    log_user("[THEMER] Imported custom plist theme: %lu icon entries.\n",
             (unsigned long)dict.count);
    return YES;
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
    (void)controller;
    NSURL *url = urls.firstObject;
    if (!url) return;
    NSString *mode = self.pendingThemeImportMode ?: @"themer";
    self.pendingThemeImportMode = nil;

    BOOL scoped = [url startAccessingSecurityScopedResource];
    BOOL isDir = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:url.path isDirectory:&isDir];
    printf("[IMPORT] url=%s scoped=%d exists=%d isDir=%d mode=%s\n",
           url.path.UTF8String, scoped, exists, isDir, mode.UTF8String);
    if (!exists) {
        if (scoped) [url stopAccessingSecurityScopedResource];
        log_user("[IMPORT] Cannot access selected file. Try a different location or file provider.\n");
        UIAlertController *ac = [UIAlertController
            alertControllerWithTitle:@"导入失败"
                              message:@"无法访问所选项目。请尝试从其它位置或文件提供程序中选择。"
                       preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:ac animated:YES completion:nil];
        return;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *err = nil;
        BOOL ok = NO;
        NSString *successTitle = @"主题已导入";
        NSString *successMessage = nil;

        if ([mode isEqualToString:@"livewp"]) {
            ok = [self importLiveWPVideoAtURL:url error:&err];
            successTitle = @"视频已选择";
            BOOL liveReady = settings_tweak_is_applied(kSettingsLiveWPEnabled) && g_springboard_rc_ready;
            successMessage = liveReady
                ? [NSString stringWithFormat:@"%@ 已导入，并将切换到正在运行的 LiveWP 通道中。",
                                             url.lastPathComponent ?: @"视频"]
                : [NSString stringWithFormat:@"%@ 已就绪。打开 LiveWP 并点击运行以应用。",
                                             url.lastPathComponent ?: @"视频"];
        } else if ([mode isEqualToString:@"snowboardlite"]) {
            if (isDir) {
                ok = settings_sbl_import_folder_theme(url, &err);
            } else {
                NSString *tmpRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:
                    [NSString stringWithFormat:@"SnowBoardLite-%@", NSUUID.UUID.UUIDString]];
                ok = SBLExtractArchiveToDirectory(url, tmpRoot, &err);
                if (ok) {
                    NSString *displayName = url.URLByDeletingPathExtension.lastPathComponent ?: @"导入的主题";
                    ok = settings_sbl_import_folder_theme_named([NSURL fileURLWithPath:tmpRoot],
                                                               displayName,
                                                               @"archive",
                                                               &err);
                }
                [[NSFileManager defaultManager] removeItemAtPath:tmpRoot error:nil];
            }
            successTitle = @"SnowBoard 主题已导入";
            NSString *name = settings_snowboardlite_selected_theme_display_name();
            successMessage = [NSString stringWithFormat:@"\"%@\" 已选中。打开 SnowBoard Lite 并点击运行以应用。", name];
        } else {
            ok = isDir ? [self importThemerFolderAtURL:url error:&err]
                       : [self importThemerPlistAtURL:url error:&err];
            NSString *name = settings_themer_selected_theme_display_name();
            successMessage = [NSString stringWithFormat:@"\"%@\" 已选中。打开 SnowBoard Lite 并点击运行以应用。", name];
        }
        if (scoped) [url stopAccessingSecurityScopedResource];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (!ok) {
                NSString *msg = err.localizedDescription ?: @"所选项目无法导入。";
                UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"导入失败"
                                                                             message:msg
                                                                      preferredStyle:UIAlertControllerStyleAlert];
                [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:ac animated:YES completion:nil];
                return;
            }
            if ([mode isEqualToString:@"snowboardlite"]) {
                settings_mark_tweak_applied(kSettingsSnowBoardLiteEnabled, NO);
                settings_notify_package_queue_changed_async();
                if (self.detailMode && self.underlyingSection == SectionSnowBoardLite) {
                    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
                } else {
                    [self.tableView reloadData];
                }
            } else if ([mode isEqualToString:@"livewp"]) {
                [self finishLiveWPVideoImportAndSwapIfRunning];
            } else {
                [self reloadThemerSectionAndQueue];
            }
            UIAlertController *ac = [UIAlertController
                alertControllerWithTitle:successTitle
                                 message:successMessage
                          preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:ac animated:YES completion:nil];
        });
    });
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
    (void)controller;
    self.pendingThemeImportMode = nil;
}

- (void)reloadSectionOrAll:(NSInteger)section
{
    if (self.detailMode && self.underlyingSection == section) {
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
                      withRowAnimation:UITableViewRowAnimationAutomatic];
    } else {
        [self.tableView reloadData];
    }
}

- (void)presentNSBarPositionPicker
{
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"NSBar 位置"
                                                                 message:nil
                                                          preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray<NSNumber *> *positions = @[
        @(NSBarPositionTopLeft),
        @(NSBarPositionBottomLeft),
        @(NSBarPositionTopRight),
        @(NSBarPositionBottomRight),
        @(NSBarPositionCenter),
    ];
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    for (NSNumber *number in positions) {
        NSInteger pos = number.integerValue;
        NSString *title = settings_nsbar_position_name(pos);
        if (pos == [d integerForKey:kSettingsNSBarPosition]) {
            title = [title stringByAppendingString:@" ✓"];
        }
        [ac addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
            [d setInteger:pos forKey:kSettingsNSBarPosition];
            [d synchronize];
            settings_schedule_live_apply_for_key(kSettingsNSBarPosition);
            [self reloadSectionOrAll:SectionNSBar];
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    settings_present_controller(ac, self);
}

- (NSString *)nicebarSubtitleForSlot:(NSInteger)slot
{
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSInteger kind = [d integerForKey:settings_nicebar_key(kSettingsNiceBarLiteSlotKindPrefix, slot)];
    switch ((NiceBarLiteContentKind)kind) {
        case NiceBarLiteContentCustomText: {
            NSString *text = [d stringForKey:settings_nicebar_key(kSettingsNiceBarLiteSlotTextPrefix, slot)] ?: @"";
            return text.length ? text : @"文本";
        }
        case NiceBarLiteContentSystem: {
            NSInteger item = [d integerForKey:settings_nicebar_key(kSettingsNiceBarLiteSlotSystemPrefix, slot)];
            if (item == NiceBarLiteSystemThermalState) {
                NSString *language = [d stringForKey:settings_nicebar_key(kSettingsNiceBarLiteSlotSystemLanguagePrefix, slot)] ?: @"en";
                return [NSString stringWithFormat:@"%@ · %@",
                        settings_nicebar_system_name(item),
                        CyanideNiceBarSystemLanguageName(language)];
            }
            return settings_nicebar_system_name(item);
        }
        case NiceBarLiteContentTimeFormat: {
            NSString *format = [d stringForKey:settings_nicebar_key(kSettingsNiceBarLiteSlotTimePrefix, slot)] ?: @"HH:mm";
            return CyanideNiceBarTimeFormatName(format);
        }
        case NiceBarLiteContentWeather: {
            NSString *text = settings_nicebar_weather_text_for_slot(d, slot);
            return text.length ? text : @"天气 --";
        }
        case NiceBarLiteContentOff:
            return @"隐藏";
    }
    return @"隐藏";
}

- (UIButton *)nicebarSlotButton:(NSInteger)slot
{
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSInteger kind = [d integerForKey:settings_nicebar_key(kSettingsNiceBarLiteSlotKindPrefix, slot)];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tag = slot;
    button.layer.cornerRadius = 10;
    button.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    button.layer.borderColor = UIColor.separatorColor.CGColor;
    button.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    button.titleLabel.numberOfLines = 0;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.78;
    button.contentEdgeInsets = UIEdgeInsetsMake(10, 8, 10, 8);
    [button addTarget:self action:@selector(nicebarSlotButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    NSString *title = [NSString stringWithFormat:@"%@\n%@\n%@",
                       settings_nicebar_slot_name(slot),
                       settings_nicebar_kind_name(kind),
                       [self nicebarSubtitleForSlot:slot]];
    [button setTitle:title forState:UIControlStateNormal];
    button.accessibilityLabel = [NSString stringWithFormat:@"%@ %@", settings_nicebar_slot_name(slot), [self nicebarSubtitleForSlot:slot]];
    return button;
}

- (UITableViewCell *)buildNiceBarGridCellInTableView:(UITableView *)tableView
                                           indexPath:(NSIndexPath *)indexPath
{
    (void)indexPath;
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"nicebar-grid"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"nicebar-grid"];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = nil;
    cell.detailTextLabel.text = nil;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    for (UIView *view in [cell.contentView.subviews copy]) [view removeFromSuperview];

    UIStackView *top = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self nicebarSlotButton:NiceBarLiteSlotTopLeft],
        [self nicebarSlotButton:NiceBarLiteSlotTopRight],
    ]];
    top.axis = UILayoutConstraintAxisHorizontal;
    top.spacing = 10;
    top.distribution = UIStackViewDistributionFillEqually;

    UIStackView *bottom = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self nicebarSlotButton:NiceBarLiteSlotBottomLeft],
        [self nicebarSlotButton:NiceBarLiteSlotBottomCenter],
        [self nicebarSlotButton:NiceBarLiteSlotBottomRight],
    ]];
    bottom.axis = UILayoutConstraintAxisHorizontal;
    bottom.spacing = 10;
    bottom.distribution = UIStackViewDistributionFillEqually;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[top, bottom]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.distribution = UIStackViewDistributionFillEqually;
    [cell.contentView addSubview:stack];

    UILayoutGuide *m = cell.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [top.heightAnchor constraintEqualToConstant:84],
        [bottom.heightAnchor constraintEqualToConstant:84],
        [stack.leadingAnchor constraintEqualToAnchor:m.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:m.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:m.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:m.bottomAnchor],
    ]];
    return cell;
}

- (void)presentNiceBarTextEditorForSlot:(NSInteger)slot
{
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSString *key = settings_nicebar_key(kSettingsNiceBarLiteSlotTextPrefix, slot);
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"%@ 文本", settings_nicebar_slot_name(slot)]
                                                                 message:nil
                                                          preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"Cyanide";
        field.text = [d stringForKey:key] ?: @"";
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        NSString *value = ac.textFields.firstObject.text ?: @"";
        [d setInteger:NiceBarLiteContentCustomText forKey:settings_nicebar_key(kSettingsNiceBarLiteSlotKindPrefix, slot)];
        [d setObject:value forKey:key];
        [d synchronize];
        settings_schedule_live_apply_for_key(key);
        [self reloadSectionOrAll:SectionNiceBarLite];
    }]];
    settings_present_controller(ac, self);
}

- (void)nicebarSetTimeFormat:(NSString *)format forSlot:(NSInteger)slot
{
    if (slot < 0 || slot >= NiceBarLiteSlotCount) return;
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d setInteger:NiceBarLiteContentTimeFormat forKey:settings_nicebar_key(kSettingsNiceBarLiteSlotKindPrefix, slot)];
    [d setObject:format.length ? format : @"HH:mm" forKey:settings_nicebar_key(kSettingsNiceBarLiteSlotTimePrefix, slot)];
    [d synchronize];
    settings_schedule_live_apply_for_key(settings_nicebar_key(kSettingsNiceBarLiteSlotTimePrefix, slot));
    [self reloadSectionOrAll:SectionNiceBarLite];
}

- (void)nicebarSetKind:(NSInteger)kind forSlot:(NSInteger)slot
{
    if (slot < 0 || slot >= NiceBarLiteSlotCount) return;
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d setInteger:kind forKey:settings_nicebar_key(kSettingsNiceBarLiteSlotKindPrefix, slot)];
    [d synchronize];
    settings_schedule_live_apply_for_key(settings_nicebar_key(kSettingsNiceBarLiteSlotKindPrefix, slot));
    [self reloadSectionOrAll:SectionNiceBarLite];
}

- (void)presentNiceBarDateTimePickerForSlot:(NSInteger)slot
{
    if (slot < 0 || slot >= NiceBarLiteSlotCount) return;
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSString *selectedFormat = [d stringForKey:settings_nicebar_key(kSettingsNiceBarLiteSlotTimePrefix, slot)] ?: @"HH:mm";
    __weak typeof(self) weakSelf = self;
    CyanideNiceBarTimePresetPickerViewController *picker =
        [[CyanideNiceBarTimePresetPickerViewController alloc] initWithSlotTitle:[NSString stringWithFormat:@"%@ Date / Time", settings_nicebar_slot_name(slot)]
                                                                 selectedFormat:selectedFormat
                                                                      selection:^(NSString *format) {
        [weakSelf nicebarSetTimeFormat:format forSlot:slot];
    }];
    if (self.navigationController) {
        [self.navigationController pushViewController:picker animated:YES];
    } else {
        [self presentViewController:[[UINavigationController alloc] initWithRootViewController:picker] animated:YES completion:nil];
    }
}

- (void)refreshNiceBarWeatherForce:(BOOL)force
{
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    if (!settings_nicebar_has_weather_slots(d)) return;
    NSString *cached = [d stringForKey:kSettingsNiceBarLiteWeatherCache] ?: @"";
    if (!cached.length || force) {
        settings_nicebar_store_weather_result(d, nil, nil, @"天气...", NO);
        [self reloadSectionOrAll:SectionNiceBarLite];
    }

    __weak typeof(self) weakSelf = self;
    settings_nicebar_refresh_weather_if_needed(force, ^(BOOL ok, NSString *text) {
        (void)ok;
        (void)text;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf reloadSectionOrAll:SectionNiceBarLite];
        });
    });
}

- (void)nicebarSetWeatherLanguage:(NSString *)language forSlot:(NSInteger)slot
{
    if (slot < 0 || slot >= NiceBarLiteSlotCount) return;
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSString *resolved = [language isEqualToString:@"zh"] ? @"zh" : @"en";
    [d setInteger:NiceBarLiteContentWeather forKey:settings_nicebar_key(kSettingsNiceBarLiteSlotKindPrefix, slot)];
    [d setObject:resolved forKey:settings_nicebar_key(kSettingsNiceBarLiteSlotWeatherLanguagePrefix, slot)];
    settings_nicebar_update_weather_slot_texts(d);
    [d synchronize];
    settings_schedule_live_apply_for_key(settings_nicebar_key(kSettingsNiceBarLiteSlotWeatherLanguagePrefix, slot));
    [self reloadSectionOrAll:SectionNiceBarLite];
    [self refreshNiceBarWeatherForce:YES];
}

- (void)presentNiceBarWeatherLanguagePickerForSlot:(NSInteger)slot
{
    if (slot < 0 || slot >= NiceBarLiteSlotCount) return;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"%@ 天气", settings_nicebar_slot_name(slot)]
                                                                   message:@"选择天气显示语言。"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"English" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        [self nicebarSetWeatherLanguage:@"en" forSlot:slot];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"中文" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        [self nicebarSetWeatherLanguage:@"zh" forSlot:slot];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    settings_present_controller(sheet, self);
}

- (void)presentNiceBarSystemPickerForSlot:(NSInteger)slot
{
    if (slot < 0 || slot >= NiceBarLiteSlotCount) return;
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSInteger selectedItem = [d integerForKey:settings_nicebar_key(kSettingsNiceBarLiteSlotSystemPrefix, slot)];
    NSString *selectedLanguage = [d stringForKey:settings_nicebar_key(kSettingsNiceBarLiteSlotSystemLanguagePrefix, slot)] ?: @"en";
    __weak typeof(self) weakSelf = self;
    CyanideNiceBarSystemItemPickerViewController *picker =
        [[CyanideNiceBarSystemItemPickerViewController alloc] initWithSlotTitle:[NSString stringWithFormat:@"%@ System Item", settings_nicebar_slot_name(slot)]
                                                                   selectedItem:selectedItem
                                                               selectedLanguage:selectedLanguage
                                                                      selection:^(NSInteger item, NSString *language) {
        NSUserDefaults *innerDefaults = NSUserDefaults.standardUserDefaults;
        [innerDefaults setInteger:NiceBarLiteContentSystem forKey:settings_nicebar_key(kSettingsNiceBarLiteSlotKindPrefix, slot)];
        [innerDefaults setInteger:item forKey:settings_nicebar_key(kSettingsNiceBarLiteSlotSystemPrefix, slot)];
        [innerDefaults setObject:language.length ? language : @"en"
                          forKey:settings_nicebar_key(kSettingsNiceBarLiteSlotSystemLanguagePrefix, slot)];
        [innerDefaults synchronize];
        settings_schedule_live_apply_for_key(settings_nicebar_key(kSettingsNiceBarLiteSlotSystemPrefix, slot));
        [weakSelf reloadSectionOrAll:SectionNiceBarLite];
    }];
    if (self.navigationController) {
        [self.navigationController pushViewController:picker animated:YES];
    } else {
        [self presentViewController:[[UINavigationController alloc] initWithRootViewController:picker] animated:YES completion:nil];
    }
}

- (void)presentNiceBarSlotEditor:(NSInteger)slot
{
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:settings_nicebar_slot_name(slot)
                                                                 message:nil
                                                          preferredStyle:UIAlertControllerStyleActionSheet];
    [ac addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        [d setInteger:NiceBarLiteContentOff forKey:settings_nicebar_key(kSettingsNiceBarLiteSlotKindPrefix, slot)];
        [d synchronize];
        settings_schedule_live_apply_for_key(settings_nicebar_key(kSettingsNiceBarLiteSlotKindPrefix, slot));
        [self reloadSectionOrAll:SectionNiceBarLite];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"自定义文本" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        [self presentNiceBarTextEditorForSlot:slot];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"系统项" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        [self presentNiceBarSystemPickerForSlot:slot];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"日期/时间" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        [self presentNiceBarDateTimePickerForSlot:slot];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"天气" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        [self presentNiceBarWeatherLanguagePickerForSlot:slot];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    settings_present_controller(ac, self);
}

- (void)nicebarSlotButtonTapped:(UIButton *)sender
{
    NSInteger slot = sender.tag;
    if (slot >= 0 && slot < NiceBarLiteSlotCount) {
        [self presentNiceBarSlotEditor:slot];
    }
}

- (void)selectSnowBoardLiteIOS6Theme
{
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d setObject:kSnowBoardLiteThemeBuiltinIOS6 forKey:kSettingsSnowBoardLiteSelectedThemeID];
    [d synchronize];
    settings_mark_tweak_applied(kSettingsSnowBoardLiteEnabled, NO);
    settings_notify_package_queue_changed_async();
    [self reloadSectionOrAll:SectionSnowBoardLite];
}

- (void)clearSnowBoardLiteTheme
{
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d setObject:@"" forKey:kSettingsSnowBoardLiteSelectedThemeID];
    if ([d boolForKey:kSettingsSnowBoardLiteEnabled]) {
        [d setBool:NO forKey:kSettingsSnowBoardLiteEnabled];
        g_themer_live_stop_requested = 1;
    }
    [d synchronize];
    settings_mark_tweak_applied(kSettingsSnowBoardLiteEnabled, NO);
    settings_notify_package_queue_changed_async();
    [self reloadSectionOrAll:SectionSnowBoardLite];
}

- (void)clearLiveWPVideo
{
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d setObject:@"" forKey:kSettingsLiveWPVideoPath];
    if ([d boolForKey:kSettingsLiveWPEnabled]) {
        [d setBool:NO forKey:kSettingsLiveWPEnabled];
        g_livewp_live_stop_requested = 1;
    }
    [d synchronize];
    settings_schedule_live_apply_for_key(kSettingsLiveWPEnabled);
    [self reloadSectionOrAll:SectionLiveWP];
}

// "Classic" alternate icon is registered in Info.plist with CFBundleIconFiles
// pointing to Cyanide-Classic@{2,3}x.png at the bundle root. Modern is the
// asset-catalog primary, selected by passing nil to setAlternateIconName:.
+ (UIImage *)appIconPreviewForStyle:(NSString *)style
{
    NSString *name = [style isEqualToString:@"classic"] ? @"preview-classic" : @"preview-modern";
    UIImage *raw = [UIImage imageNamed:name];
    if (!raw) return nil;
    // Render with iOS home-screen corner radius (≈22% of side) so the thumb
    // matches what users see on SpringBoard. 52pt fits in the default subtitle
    // cell row height without forcing layout overrides.
    CGFloat side = 52.0;
    CGFloat radius = side * 0.22;
    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat preferredFormat];
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(side, side) format:fmt];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, side, side)
                                                      cornerRadius:radius];
        [p addClip];
        [raw drawInRect:CGRectMake(0, 0, side, side)];
    }];
}

- (NSString *)currentAppIconStyle
{
    NSString *alt = [UIApplication sharedApplication].alternateIconName;
    return [alt isEqualToString:@"Classic"] ? @"classic" : @"modern";
}

- (UITableViewCell *)buildAppIconCellAtRow:(NSInteger)row tableView:(UITableView *)tableView
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"appicon"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"appicon"];
        cell.detailTextLabel.numberOfLines = 0;
    }
    cell.textLabel.font = [UIFont systemFontOfSize:17.0];
    cell.textLabel.textColor = UIColor.labelColor;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:13.0];
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    NSString *style = (row == 0) ? @"modern" : @"classic";
    cell.imageView.image = [SettingsViewController appIconPreviewForStyle:style];

    if (row == 0) {
        cell.textLabel.text = @"现代";
        cell.detailTextLabel.text = @"默认 — 焕然一新的 v2 标识。";
    } else {
        cell.textLabel.text = @"经典";
        cell.detailTextLabel.text = @"最初发布时的外观。";
    }

    BOOL selected = [[self currentAppIconStyle] isEqualToString:style];
    cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)selectAppIconAtRow:(NSInteger)row inTableView:(UITableView *)tableView
{
    NSString *style = (row == 0) ? @"modern" : @"classic";
    if ([[self currentAppIconStyle] isEqualToString:style]) return;

    if (![UIApplication sharedApplication].supportsAlternateIcons) {
        UIAlertController *ac = [UIAlertController
            alertControllerWithTitle:@"无法更改图标"
                             message:@"此 iOS 版本不支持切换备用图标。"
                      preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:ac animated:YES completion:nil];
        return;
    }

    NSString *altName = [style isEqualToString:@"classic"] ? @"Classic" : nil;
    [[UIApplication sharedApplication] setAlternateIconName:altName completionHandler:^(NSError * _Nullable error) {
        if (error) {
            printf("[SETTINGS] app icon switch to '%s' failed: %s\n",
                   style.UTF8String,
                   error.localizedDescription.UTF8String);
        } else {
            printf("[SETTINGS] app icon switched to %s\n", style.UTF8String);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            NSIndexSet *idx = [NSIndexSet indexSetWithIndex:RootSectionAbout];
            [tableView reloadSections:idx withRowAnimation:UITableViewRowAnimationNone];
        });
    }];
}

- (void)showAppIconPicker
{
    if (![UIApplication sharedApplication].supportsAlternateIcons) {
        UIAlertController *ac = [UIAlertController
            alertControllerWithTitle:@"无法更改图标"
                             message:@"此 iOS 版本不支持切换备用图标。"
                      preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:ac animated:YES completion:nil];
        return;
    }
    NSString *current = [self currentAppIconStyle];
    UIAlertController *ac = [UIAlertController
        alertControllerWithTitle:@"应用图标"
                         message:nil
                  preferredStyle:UIAlertControllerStyleActionSheet];
    NSString *modernTitle = [current isEqualToString:@"modern"] ? @"现代 ✓" : @"现代";
    NSString *classicTitle = [current isEqualToString:@"classic"] ? @"经典 ✓" : @"经典";
    [ac addAction:[UIAlertAction actionWithTitle:modernTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        [self selectAppIconAtRow:0 inTableView:self.tableView];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:classicTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        [self selectAppIconAtRow:1 inTableView:self.tableView];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    ac.popoverPresentationController.sourceView = self.view;
    ac.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2, 0, 0);
    [self presentViewController:ac animated:YES completion:nil];
}

+ (UIImage *)experimentalDangerChip
{
    static UIImage *cached;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *text = @"危险";
        UIFont *font = [UIFont systemFontOfSize:10.0 weight:UIFontWeightBold];
        NSDictionary *attrs = @{
            NSFontAttributeName: font,
            NSForegroundColorAttributeName: UIColor.whiteColor,
            NSKernAttributeName: @(0.4),
        };
        CGSize ts = [text sizeWithAttributes:attrs];
        CGFloat padH = 6.5;
        CGFloat padV = 2.5;
        CGSize size = CGSizeMake(ceil(ts.width) + padH * 2.0,
                                 ceil(ts.height) + padV * 2.0);
        UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:size];
        cached = [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
            UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size.width, size.height)
                                                          cornerRadius:size.height / 2.0];
            [UIColor.systemRedColor setFill];
            [p fill];
            [text drawAtPoint:CGPointMake(padH, padV) withAttributes:attrs];
        }];
    });
    return cached;
}

- (UITableViewCell *)buildExperimentalCellInTableView:(UITableView *)tableView
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"experimental"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"experimental"];
        cell.detailTextLabel.numberOfLines = 0;
    }
    BOOL on = settings_experimental_tweaks_enabled();

    UIColor *iconColor = on ? UIColor.systemRedColor
                            : [UIColor.systemRedColor colorWithAlphaComponent:0.55];
    cell.imageView.image = [SettingsViewController iconBadgeWithSymbol:@"flask.fill"
                                                                  color:iconColor
                                                                   size:29.0];

    NSMutableAttributedString *title = [[NSMutableAttributedString alloc]
        initWithString:@"实验功能  "
            attributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:17.0],
                          NSForegroundColorAttributeName: UIColor.labelColor }];
    NSTextAttachment *att = [[NSTextAttachment alloc] init];
    UIImage *chip = [SettingsViewController experimentalDangerChip];
    att.image = chip;
    att.bounds = CGRectMake(0, -2.0, chip.size.width, chip.size.height);
    [title appendAttributedString:[NSAttributedString attributedStringWithAttachment:att]];
    cell.textLabel.attributedText = title;

#if CYANIDE_PRIVATE_TWEAKS_AVAILABLE
    cell.detailTextLabel.text = on
        ? @"已启用 — 信号读数、TypeBanner、通知岛、Dynamic Stage Lite。"
        : @"信号读数、TypeBanner、通知岛、Dynamic Stage Lite。";
#else
    cell.detailTextLabel.text = on
        ? @"已启用 — 此构建中无私有实验功能。"
        : @"此构建中无私有实验功能。";
#endif
    cell.detailTextLabel.font = [UIFont systemFontOfSize:13.0];
    cell.detailTextLabel.textColor = on
        ? [UIColor.systemRedColor colorWithAlphaComponent:0.9]
        : UIColor.secondaryLabelColor;

    cell.backgroundColor = on
        ? [UIColor.systemRedColor colorWithAlphaComponent:0.10]
        : nil;

    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    UISwitch *sw = [[UISwitch alloc] init];
    sw.onTintColor = UIColor.systemRedColor;
    sw.on = on;
    [sw addTarget:self action:@selector(experimentalSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = sw;
    return cell;
}

- (void)experimentalSwitchChanged:(UISwitch *)sw
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    BOOL enabling = sw.isOn;

    if (enabling) {
        if (!settings_experimental_access_allowed()) {
            sw.on = NO;
            [d setBool:NO forKey:kSettingsExperimentalTweaksEnabled];
            [self reloadAfterExperimentalChange];
            return;
        }
        // Hard confirm before flipping master on. If the user cancels, revert
        // the switch and stop here.
        sw.on = NO;
        UIAlertController *ac = [UIAlertController
            alertControllerWithTitle:@"启用实验功能？"
                             message:@"这些功能尚未完成，可能导致崩溃、布局异常或耗电增加。仅在您积极测试时启用。"
                      preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [ac addAction:[UIAlertAction actionWithTitle:@"仍然启用"
                                               style:UIAlertActionStyleDestructive
                                             handler:^(UIAlertAction *_) {
            [d setBool:YES forKey:kSettingsExperimentalTweaksEnabled];
            sw.on = YES;
            printf("[SETTINGS] experimental tweaks enabled\n");
            [self reloadAfterExperimentalChange];
        }]];
        [self presentViewController:ac animated:YES completion:nil];
        return;
    }

    [d setBool:NO forKey:kSettingsExperimentalTweaksEnabled];
    printf("[SETTINGS] experimental tweaks disabled; disabling gated package states\n");

    // Force-disable every experimental-gated package.
    if ([d boolForKey:kSettingsTypeBannerEnabled]) {
        [d setBool:NO forKey:kSettingsTypeBannerEnabled];
        settings_mark_tweak_applied(kSettingsTypeBannerEnabled, NO);
        settings_notify_package_queue_changed_async();
        settings_schedule_live_apply_for_key(kSettingsTypeBannerEnabled);
    }
    if ([d boolForKey:kSettingsNotificationIslandEnabled]) {
        [d setBool:NO forKey:kSettingsNotificationIslandEnabled];
        settings_mark_tweak_applied(kSettingsNotificationIslandEnabled, NO);
        settings_notify_package_queue_changed_async();
        settings_schedule_live_apply_for_key(kSettingsNotificationIslandEnabled);
    }
    if ([d boolForKey:kSettingsRSSIDisplayEnabled]) {
        [d setBool:NO forKey:kSettingsRSSIDisplayEnabled];
        settings_mark_tweak_applied(kSettingsRSSIDisplayEnabled, NO);
        settings_notify_package_queue_changed_async();
        settings_schedule_live_apply_for_key(kSettingsRSSIDisplayEnabled);
    }
    if ([d boolForKey:kSettingsStageStripEnabled]) {
        [d setBool:NO forKey:kSettingsStageStripEnabled];
        settings_mark_tweak_applied(kSettingsStageStripEnabled, NO);
        settings_notify_package_queue_changed_async();
    }
    [self forceDisableFastLockXLiteForExperimentalGateWithDefaults:d];
    [self reloadAfterExperimentalChange];
}

- (void)forceDisableFastLockXLiteForExperimentalGateWithDefaults:(NSUserDefaults *)d
{
    BOOL shouldStop = [d boolForKey:kSettingsFastLockXLiteEnabled] ||
                      settings_tweak_is_applied(kSettingsFastLockXLiteEnabled);
    if (!shouldStop) return;

    [d setBool:NO forKey:kSettingsFastLockXLiteEnabled];
    [d synchronize];
    settings_notify_package_queue_changed_async();

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        BOOL actionLockAcquired = settings_try_claim_actions_lock("FastLockX Lite cleanup",
                                                                 "[FLX] FastLockX Lite cleanup deferred: another action is running.");
        if (!actionLockAcquired) return;
        @try {
            bool stopped = false;
            if (settings_ensure_kexploit()) {
                @synchronized (settings_rc_lock()) {
                    if (!g_springboard_rc_ready) {
                        settings_ensure_springboard_remote_call_locked();
                    }
                    if (g_springboard_rc_ready) {
                        stopped = fastlockx_lite_disable_always_on_in_session();
                    }
                }
            }
            if (!stopped) {
                fastlockx_lite_forget_remote_state();
                log_user("[FLX] Experimental gate disabled; Always On will also stop on respring if timers were unreachable.\n");
            }
            settings_mark_tweak_applied(kSettingsFastLockXLiteEnabled, NO);
            settings_notify_package_queue_changed_async();
        } @finally {
            settings_release_actions_lock();
        }
    });
}

- (void)reloadAfterExperimentalChange
{
    // Tweak bundle list visibility depends on the experimental flag, and the
    // installer's package list is filtered by it too — refresh both.
    [self.tableView reloadData];
    [[NSNotificationCenter defaultCenter] postNotificationName:PackageQueueDidChangeNotification
                                                        object:[PackageQueue sharedQueue]];
}

#pragma mark - Patreon

// Drops any experimental-gated package state if the user is no longer a patron.
- (void)teardownExperimentalIfNoLongerPatron
{
    if (settings_experimental_access_allowed()) return;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (![d boolForKey:kSettingsExperimentalTweaksEnabled]) return;

    printf("[PATREON] patron status lost; force-disabling experimental tweaks\n");
    [d setBool:NO forKey:kSettingsExperimentalTweaksEnabled];
    if ([d boolForKey:kSettingsTypeBannerEnabled]) {
        [d setBool:NO forKey:kSettingsTypeBannerEnabled];
        settings_mark_tweak_applied(kSettingsTypeBannerEnabled, NO);
        settings_notify_package_queue_changed_async();
        settings_schedule_live_apply_for_key(kSettingsTypeBannerEnabled);
    }
    if ([d boolForKey:kSettingsNotificationIslandEnabled]) {
        [d setBool:NO forKey:kSettingsNotificationIslandEnabled];
        settings_mark_tweak_applied(kSettingsNotificationIslandEnabled, NO);
        settings_notify_package_queue_changed_async();
        settings_schedule_live_apply_for_key(kSettingsNotificationIslandEnabled);
    }
    if ([d boolForKey:kSettingsRSSIDisplayEnabled]) {
        [d setBool:NO forKey:kSettingsRSSIDisplayEnabled];
        settings_mark_tweak_applied(kSettingsRSSIDisplayEnabled, NO);
        settings_notify_package_queue_changed_async();
        settings_schedule_live_apply_for_key(kSettingsRSSIDisplayEnabled);
    }
    if ([d boolForKey:kSettingsStageStripEnabled]) {
        [d setBool:NO forKey:kSettingsStageStripEnabled];
        settings_mark_tweak_applied(kSettingsStageStripEnabled, NO);
        settings_notify_package_queue_changed_async();
    }
    [self forceDisableFastLockXLiteForExperimentalGateWithDefaults:d];
}

- (void)patreonStatusDidChange:(NSNotification *)note
{
    (void)note;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        BOOL nowPatron = settings_experimental_access_allowed();
        BOOL wasPatron = [d boolForKey:kCyanideLastKnownIsPatron];
        BOOL haveLastKnown = ([d objectForKey:kCyanideLastKnownIsPatron] != nil);
        if (nowPatron && (!wasPatron || !haveLastKnown)) {
            if (![d boolForKey:kSettingsExperimentalTweaksEnabled]) {
                [d setBool:YES forKey:kSettingsExperimentalTweaksEnabled];
            }
        }
        [d setBool:nowPatron forKey:kCyanideLastKnownIsPatron];

        [self teardownExperimentalIfNoLongerPatron];
        if (!self.isViewLoaded || self.detailMode) return;
        // Row count for Patreon changes between unlinked/linked states, so a
        // full reloadData is simpler than animating diffs.
        [self.tableView reloadData];
    });
}

- (UITableViewCell *)buildPatreonCellAtRow:(NSInteger)row tableView:(UITableView *)tableView
{
    BOOL linked = cyanide_patreon_is_linked();
    UIColor *patreonOrange = [UIColor colorWithRed:0.94 green:0.31 blue:0.20 alpha:1.0];

    if (!linked) {
        // Row 0: link an existing Patreon account (OAuth flow in-app).
        // Row 1: new-to-Patreon sign-up affordance (opens patreon.com/zeroxjf).
        if (row == 0) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"patreon-link"];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"patreon-link"];
                cell.detailTextLabel.numberOfLines = 0;
            }
            cell.imageView.image = [SettingsViewController iconBadgeWithSymbol:@"heart.fill"
                                                                          color:patreonOrange
                                                                           size:29.0];
            cell.textLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
            cell.textLabel.textColor = patreonOrange;
            cell.textLabel.text = @"关联 Patreon 账户";
            cell.textLabel.textAlignment = NSTextAlignmentLeft;
            cell.detailTextLabel.text = nil;
            cell.detailTextLabel.font = [UIFont systemFontOfSize:13.0];
            cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            return cell;
        }
        // row == 1: explicit "don't have one yet?" entry point.
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"patreon-signup"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"patreon-signup"];
            cell.detailTextLabel.numberOfLines = 0;
        }
        cell.imageView.image = [SettingsViewController iconBadgeWithSymbol:@"person.crop.circle.badge.plus"
                                                                      color:patreonOrange
                                                                       size:29.0];
        cell.textLabel.font = [UIFont systemFontOfSize:17.0];
        cell.textLabel.textColor = patreonOrange;
        cell.textLabel.text = @"初次使用 Patreon？注册";
        cell.textLabel.textAlignment = NSTextAlignmentLeft;
        cell.detailTextLabel.text = @"在 patreon.com/zeroxjf 加入，然后回来关联。";
        cell.detailTextLabel.font = [UIFont systemFontOfSize:13.0];
        cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        return cell;
    }

    BOOL isPatron = cyanide_is_patron();

    if (row == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"patreon-status"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"patreon-status"];
            cell.detailTextLabel.numberOfLines = 0;
        }
        UIColor *iconColor = isPatron ? patreonOrange : [patreonOrange colorWithAlphaComponent:0.45];
        cell.imageView.image = [SettingsViewController iconBadgeWithSymbol:@"heart.fill"
                                                                      color:iconColor
                                                                       size:29.0];
        cell.textLabel.font = [UIFont systemFontOfSize:17.0];
        cell.textLabel.textColor = UIColor.labelColor;
        cell.textLabel.text = cyanide_patreon_display_name() ?: @"已关联";

        NSString *tier = cyanide_patreon_tier_title();
        NSInteger cents = cyanide_patreon_pledge_cents();
        NSString *detail;
        if (isPatron) {
            if (cents <= 0) {
                // Synthetic tiers like "Creator" carry no dollar amount —
                // showing "$0/month" beside them reads as a bug.
                detail = tier.length > 0 ? tier : @"活跃支持者";
            } else {
                NSString *amount = (cents % 100 == 0)
                    ? [NSString stringWithFormat:@"$%ld/月", (long)(cents / 100)]
                    : [NSString stringWithFormat:@"$%.2f/月", cents / 100.0];
                detail = tier.length > 0
                    ? [NSString stringWithFormat:@"%@ • %@", tier, amount]
                    : amount;
            }
        } else {
            detail = @"免费用户 — 加入会员等级解锁。";
        }
        cell.detailTextLabel.text = detail;
        cell.detailTextLabel.textColor = isPatron ? patreonOrange : UIColor.secondaryLabelColor;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:13.0];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }

    // Action rows. Free-supporter layout inserts a "Join Member Tier" row
    // between the identity row and Refresh/Sign Out, so the indices shift.
    NSInteger joinRow    = isPatron ? -1 : 1;
    NSInteger refreshRow = isPatron ?  1 : 2;
    NSInteger signoutRow = isPatron ?  2 : 3;

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"patreon-action"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"patreon-action"];
    }
    cell.imageView.image = nil;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.textLabel.textAlignment = NSTextAlignmentCenter;
    cell.textLabel.font = [UIFont systemFontOfSize:17.0];
    if (row == joinRow) {
        cell.textLabel.text = @"加入 Patreon 会员等级";
        cell.textLabel.textColor = patreonOrange;
        cell.textLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    } else if (row == refreshRow) {
        cell.textLabel.text = @"刷新赞助者状态";
        cell.textLabel.textColor = self.view.tintColor;
    } else if (row == signoutRow) {
        cell.textLabel.text = @"退出 Patreon";
        cell.textLabel.textColor = UIColor.systemRedColor;
    }
    return cell;
}

- (UITableViewCell *)buildExperimentalLockedCellInTableView:(UITableView *)tableView
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"experimental-locked"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"experimental-locked"];
        cell.detailTextLabel.numberOfLines = 0;
    }
    cell.imageView.image = [SettingsViewController iconBadgeWithSymbol:@"lock.fill"
                                                                  color:UIColor.systemGrayColor
                                                                   size:29.0];
    cell.textLabel.font = [UIFont systemFontOfSize:17.0];
    cell.textLabel.textColor = UIColor.labelColor;
    cell.textLabel.text = @"实验功能";
    if (cyanide_patreon_is_linked()) {
        cell.detailTextLabel.text = @"已以免费用户关联 — 点击升级到会员等级。";
    } else {
        cell.detailTextLabel.text = @"需要 Patreon 会员等级。点击关联或注册。";
    }
    cell.detailTextLabel.font = [UIFont systemFontOfSize:13.0];
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.backgroundColor = nil;
    return cell;
}

- (void)handlePatreonTapAtRow:(NSInteger)row
{
    BOOL linked = cyanide_patreon_is_linked();

    if (!linked) {
        // Row 0 = "Link Patreon Account" → in-app OAuth.
        // Row 1 = "New to Patreon? Sign Up" → opens patreon.com/zeroxjf in Safari.
        if (row == 1) {
            [[UIApplication sharedApplication] openURL:cyanide_patreon_join_url()
                                               options:@{}
                                     completionHandler:nil];
            return;
        }
        cyanide_patreon_authenticate(self, ^(BOOL ok, NSError *err) {
            if (ok) {
                printf("[PATREON] linked successfully\n");
                return;
            }
            if ([err.domain isEqualToString:@"CyanidePatreon"] && err.code == NSUserCancelledError) return;
            UIAlertController *ac = [UIAlertController
                alertControllerWithTitle:@"无法关联 Patreon"
                                 message:err.localizedDescription ?: @"未知错误。"
                          preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:ac animated:YES completion:nil];
        });
        return;
    }

    if (row == 0) return;  // identity row, non-interactive

    BOOL isPatron = cyanide_is_patron();
    NSInteger joinRow    = isPatron ? -1 : 1;
    NSInteger refreshRow = isPatron ?  1 : 2;
    NSInteger signoutRow = isPatron ?  2 : 3;

    if (row == joinRow) {
        [[UIApplication sharedApplication] openURL:cyanide_patreon_join_url() options:@{} completionHandler:nil];
        return;
    }

    if (row == refreshRow) {
        cyanide_patreon_refresh(^(BOOL ok, NSError *err) {
            if (ok) return;
            printf("[PATREON] refresh failed: %s\n", err.localizedDescription.UTF8String ?: "unknown");
            UIAlertController *ac = [UIAlertController
                alertControllerWithTitle:@"无法刷新"
                                 message:err.localizedDescription ?: @"未知错误。"
                          preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:ac animated:YES completion:nil];
        });
        return;
    }

    if (row == signoutRow) {
        UIAlertController *ac = [UIAlertController
            alertControllerWithTitle:@"退出 Patreon？"
                             message:@"从此设备移除关联账户。仅支持者功能将被锁定，直到您重新关联。"
                      preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [ac addAction:[UIAlertAction actionWithTitle:@"退出"
                                               style:UIAlertActionStyleDestructive
                                             handler:^(UIAlertAction *_) {
            cyanide_patreon_sign_out();
        }]];
        [self presentViewController:ac animated:YES completion:nil];
    }
}

- (void)openTwitter
{
    NSURL *url = [NSURL URLWithString:@"https://twitter.com/zeroxjf"];
    if (url) [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)openViewLog
{
    NSString *logPath = log_most_recent_session_path();
    NSString *text;
    if (!logPath) {
        text = @"尚无日志。请至少运行一次链。";
    } else {
        NSError *err = nil;
        text = [NSString stringWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:&err];
        if (!text) text = [NSString stringWithFormat:@"读取日志失败：%@", err.localizedDescription];
    }

    UIViewController *vc = [[UIViewController alloc] init];
    vc.title = @"日志";
    vc.view.backgroundColor = UIColor.systemGroupedBackgroundColor;

    UITextView *tv = [[UITextView alloc] init];
    tv.translatesAutoresizingMaskIntoConstraints = NO;
    tv.editable = NO;
    tv.font = [UIFont monospacedSystemFontOfSize:11.0 weight:UIFontWeightRegular];
    tv.textColor = UIColor.labelColor;
    tv.backgroundColor = UIColor.systemGroupedBackgroundColor;
    tv.text = text;
    [vc.view addSubview:tv];
    [NSLayoutConstraint activateConstraints:@[
        [tv.topAnchor      constraintEqualToAnchor:vc.view.safeAreaLayoutGuide.topAnchor],
        [tv.bottomAnchor   constraintEqualToAnchor:vc.view.safeAreaLayoutGuide.bottomAnchor],
        [tv.leadingAnchor  constraintEqualToAnchor:vc.view.leadingAnchor constant:16.0],
        [tv.trailingAnchor constraintEqualToAnchor:vc.view.trailingAnchor constant:-16.0],
    ]];

    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openShareLog
{
    NSString *logPath = log_most_recent_session_path();
    if (!logPath.length) {
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"暂无日志"
                                                                     message:@"请先运行一次链，然后回来分享最新的诊断日志。"
                                                              preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:ac animated:YES completion:nil];
        return;
    }

    NSURL *logURL = [NSURL fileURLWithPath:logPath];
    NSString *appVersion = settings_app_version_string();
    NSString *iosVersion = [UIDevice currentDevice].systemVersion ?: @"未知";
    struct utsname info; uname(&info);
    NSString *machine = [NSString stringWithUTF8String:info.machine] ?: @"未知";
    NSString *summary = [NSString stringWithFormat:@"Cyanide 诊断日志\nCyanide %@ · iOS %@ · %@",
                         appVersion, iosVersion, machine];

    UIActivityViewController *vc = [[UIActivityViewController alloc] initWithActivityItems:@[summary, logURL]
                                                                     applicationActivities:nil];
    UIPopoverPresentationController *popover = vc.popoverPresentationController;
    if (popover) {
        popover.sourceView = self.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                        CGRectGetMidY(self.view.bounds),
                                        1.0,
                                        1.0);
        popover.permittedArrowDirections = 0;
    }
    [self presentViewController:vc animated:YES completion:nil];
}

// Session-scoped state so uploaded snapshots from one chain run get grouped on
// the server side (same sessionId, monotonically increasing seq). A fresh
// session begins at every settings_run_actions() entry.
static dispatch_source_t g_cyanide_upload_timer = NULL;
static NSString         *g_cyanide_upload_session_id = nil;
static NSMutableSet<NSString *> *g_cyanide_upload_milestones = nil;
static volatile int      g_cyanide_upload_seq = 0;

// kind = "milestone" (important chain transition) or "final"
// (post-completion). Milestones are explicit so uploads line up with exploit,
// RemoteCall, tweak, and live-loop boundaries instead of timer noise.
static void cyanide_upload_log_with_kind_event(NSString *kind, NSString *event) {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kSettingsLogUploadEnabled]) return;
    NSString *path = log_most_recent_session_path();
    if (!path) return;
    NSString *rawLog = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!rawLog.length) return;

    int seq = __sync_add_and_fetch(&g_cyanide_upload_seq, 1);
    NSString *sessionId = g_cyanide_upload_session_id ?: @"adhoc";

    NSString *appVersion = settings_app_version_string();
    NSString *appBuild = settings_app_build_string();
    NSString *iosVersion = [UIDevice currentDevice].systemVersion;

    struct utsname sysInfo;
    uname(&sysInfo);
    NSString *machine = [NSString stringWithUTF8String:sysInfo.machine];

    // Prepend a diagnostic header so each uploaded log is self-contained.
    NSString *header = [NSString stringWithFormat:
        @"=== Cyanide Diagnostic Log ===\n"
        @"app_version : %@\n"
        @"app_build   : %@\n"
        @"ios_version : %@\n"
        @"device      : %@\n"
        @"log_file    : %@\n"
        @"session_id  : %@\n"
        @"kind        : %@\n"
        @"event       : %@\n"
        @"seq         : %d\n"
        @"==============================\n\n",
        appVersion, appBuild, iosVersion, machine, path.lastPathComponent,
        sessionId, kind, event ?: @"", seq];

    NSDictionary *body = @{
        @"log": [header stringByAppendingString:rawLog],
        @"meta": @{
            @"build":      [NSString stringWithFormat:@"cyanide-%@-%@", appVersion, appBuild],
            @"appVersion": appVersion,
            @"appBuild":   appBuild,
            @"source":     @"cyanide",
            @"ios":        iosVersion,
            @"device":     machine,
            @"sessionId":  sessionId,
            @"kind":       kind,
            @"event":      event ?: @"",
            @"seq":        @(seq),
        }
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    if (!data) return;
    NSURL *url = [NSURL URLWithString:@"https://brokenblade-weblogs.hackerboii.workers.dev/log"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    req.HTTPBody = data;
    printf("[LOG] uploading diagnostic (%s%s%s seq=%d, %zu bytes)...\n",
           kind.UTF8String,
           event.length ? ":" : "",
           event.length ? event.UTF8String : "",
           seq,
           (size_t)data.length);
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (e) {
            printf("[LOG] upload %s%s%s failed: %s\n",
                   kind.UTF8String,
                   event.length ? ":" : "",
                   event.length ? event.UTF8String : "",
                   e.localizedDescription.UTF8String);
        } else {
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)r;
            printf("[LOG] upload %s%s%s ok: HTTP %ld\n",
                   kind.UTF8String,
                   event.length ? ":" : "",
                   event.length ? event.UTF8String : "",
                   (long)http.statusCode);
        }
    }] resume];
}

static void cyanide_upload_log_with_kind(NSString *kind) {
    cyanide_upload_log_with_kind_event(kind, nil);
}

static void cyanide_upload_log_milestone(NSString *event) {
    if (!event.length) return;

    @synchronized ([NSUserDefaults standardUserDefaults]) {
        if (!g_cyanide_upload_milestones)
            g_cyanide_upload_milestones = [NSMutableSet set];
        if ([g_cyanide_upload_milestones containsObject:event])
            return;
        [g_cyanide_upload_milestones addObject:event];
    }

    cyanide_upload_log_with_kind_event(@"milestone", event);
}

static void cyanide_upload_log_if_enabled(void) {
    cyanide_upload_log_with_kind(@"final");
}

// Begin a diagnostic upload session. Uploads are milestone-driven; this no
// longer starts the old 3s/8s periodic checkpoint timer.
static void cyanide_start_session_uploads(void) {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kSettingsLogUploadEnabled]) return;
    if (g_cyanide_upload_timer) return;

    g_cyanide_upload_session_id = [[NSUUID UUID] UUIDString];
    @synchronized ([NSUserDefaults standardUserDefaults]) {
        g_cyanide_upload_milestones = [NSMutableSet set];
    }
    g_cyanide_upload_seq = 0;
}

static void cyanide_stop_session_uploads(void) {
    if (g_cyanide_upload_timer) {
        dispatch_source_cancel(g_cyanide_upload_timer);
        g_cyanide_upload_timer = NULL;
    }
}

// Contact owner (zeroxjf) with the diagnostic log inline in the body. Build
// info sits between the user's typing area at the top and the log dump
// below, so the user just types above the signature and hits send.
- (void)openContactEmail
{
    cyanide_present_contact(self);
}

// Public entry point for the Contact flow. Builds the email body (signature
// + inline diagnostic log) and presents MFMailComposeViewController from
// `host` when Mail is set up, else opens a mailto: URL with a truncated log
// tail so third-party mail apps still get useful context.
void cyanide_present_contact(UIViewController *host)
{
    if (!host) return;

    NSString *appVersion = settings_app_version_string();
    NSString *iosVersion = [UIDevice currentDevice].systemVersion ?: @"未知";
    struct utsname info; uname(&info);
    NSString *machine = [NSString stringWithUTF8String:info.machine];

    // Single-line signature so it reads correctly even in mail clients that
    // collapse newlines from mailto: bodies (Gmail-iOS being the worst offender).
    NSString *signature = [NSString stringWithFormat:@"—— Cyanide %@ · iOS %@ · %@ ——",
                           appVersion, iosVersion, machine];

    NSString *subject = [NSString stringWithFormat:@"Cyanide %@ — 联系", appVersion];

    // CRLF rather than LF so iOS Mail, Gmail, Outlook, and the mailto: URL
    // path all preserve line breaks. Plain LF is fine in MFMailCompose but
    // some third-party clients eat them when the body arrives via mailto:.
    // Log inclusion is intentionally omitted for now — pipeline was unreliable
    // (in-app buffer snapshot wasn't landing in the email). Build/device info
    // still ships in the signature so I can at least see the user's setup.
    NSMutableString *body = [NSMutableString string];
    [body appendString:@"\r\n\r\n\r\n"]; // breathing room at top for the user to type
    [body appendString:signature];
    [body appendString:@"\r\n"];

    if ([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController *vc = [[MFMailComposeViewController alloc] init];
        vc.mailComposeDelegate = _cyanide_mail_delegate();
        [vc setToRecipients:@[@"zeroxjf@gmail.com"]];
        [vc setSubject:subject];
        [vc setMessageBody:body isHTML:NO];
        [host presentViewController:vc animated:YES completion:nil];
        return;
    }

    // Mail not configured — fall back to mailto:. Bodies get URL-encoded so
    // long logs produce long URLs; in practice iOS LaunchServices accepts
    // ~64KB and third-party mail apps still receive the full body. We send
    // the full log regardless and trust the client to handle it.
    NSCharacterSet *allowed = [NSCharacterSet URLQueryAllowedCharacterSet];
    NSString *q = [NSString stringWithFormat:@"subject=%@&body=%@",
        [subject stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"",
        [body stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @""];
    NSURL *url = [NSURL URLWithString:[@"mailto:zeroxjf@gmail.com?" stringByAppendingString:q]];
    if (url && [[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        return;
    }

    UIAlertController *ac = [UIAlertController
        alertControllerWithTitle:@"邮件不可用"
                         message:@"请在 iOS 设置中设置邮件以发送反馈，或在 Twitter 上私信 @zeroxjf。在设置中查看日志以复制最新的诊断日志。"
                  preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [host presentViewController:ac animated:YES completion:nil];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Preserve the table view's actual indexPath for dequeue calls (which
    // expect a path that exists in the current data source). `indexPath`
    // is remapped to the underlying SettingsSection for content lookup.
    NSIndexPath *dequeuePath = indexPath;

    if (!self.detailMode) {
        switch ((RootSection)indexPath.section) {
            case RootSectionWarning:
                indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:SectionWarning];
                break;
            case RootSectionChangelog: {
                if (!self.changelogExpanded) {
                    return [self buildChangelogCollapsedCellInTableView:tableView];
                }
                NSInteger entryCount = (NSInteger)settings_changelog_entries().count;
                if (indexPath.row == entryCount) {
                    return [self buildChangelogFooterCellInTableView:tableView];
                }
                if (indexPath.row > entryCount) {
                    return [self buildChangelogCollapseCellInTableView:tableView];
                }
                return [self buildChangelogCellAtRow:indexPath.row tableView:tableView];
            }
            case RootSectionActions:
                indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:SectionActions];
                break;
            case RootSectionTweakBundles:
                return [self buildBundleCellWithRow:self.tweakBundleRows[indexPath.row] tableView:tableView];
            case RootSectionInDev:
                return [self buildInDevCellWithRow:self.inDevBundleRows[indexPath.row] tableView:tableView];
            case RootSectionSystemBundles:
                return [self buildBundleCellWithRow:self.systemBundleRows[indexPath.row] tableView:tableView];
            case RootSectionPatreon:
                return [self buildPatreonCellAtRow:indexPath.row tableView:tableView];
            case RootSectionExperimental:
                if (!settings_experimental_access_allowed())
                    return [self buildExperimentalLockedCellInTableView:tableView];
                return [self buildExperimentalCellInTableView:tableView];
            case RootSectionAbout:
                return [self buildAboutCellAtRow:indexPath.row tableView:tableView];
            case RootSectionCount:
                return [[UITableViewCell alloc] init];
        }
    } else {
        indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:self.underlyingSection];
    }

    if (indexPath.section == SectionWarning) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"warning" forIndexPath:dequeuePath];
        return [self buildWarningCell:cell];
    }
    if (indexPath.section == SectionActions) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"action-compact"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"action-compact"];
            cell.detailTextLabel.numberOfLines = 1;
        }
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.detailTextLabel.text = nil;

        BOOL supported = settings_device_supported();
        BOOL cleanupEnabled = supported && (g_kexploit_done ||
                                            g_springboard_rc_ready ||
                                            remote_call_has_local_state());
        BOOL anyInstalledOrQueued = NO;
        for (Package *p in [PackageCatalog allPackages]) {
            if (p.isInstalled || p.isQueuedForApply) { anyInstalledOrQueued = YES; break; }
        }
        if (!anyInstalledOrQueued) {
            anyInstalledOrQueued = [[PackageQueue sharedQueue] pendingCount] > 0;
        }

        BOOL rowEnabled = supported;
        NSString *symbol = nil;
        UIColor *color = nil;

        if (indexPath.row == 0) {
            rowEnabled = cleanupEnabled;
            BOOL running = g_settings_cleanup_running;
            symbol = @"xmark.circle.fill";
            color  = UIColor.systemRedColor;
            cell.textLabel.text = running ? @"清理中…" : @"清理";
            cell.detailTextLabel.text = cleanupEnabled ? nil : @"无活跃通道";
            if (running) {
                UIActivityIndicatorView *spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
                spin.color = color;
                [spin startAnimating];
                cell.accessoryView = spin;
            }
        } else if (indexPath.row == 1) {
            BOOL running = g_settings_respring_cleanup_running;
            symbol = @"arrow.clockwise.circle.fill";
            color  = UIColor.systemOrangeColor;
            cell.textLabel.text = running ? @"准备中…" : @"注销";
            if (running) {
                UIActivityIndicatorView *spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
                spin.color = color;
                [spin startAnimating];
                cell.accessoryView = spin;
            }
        } else if (indexPath.row == 2) {
            rowEnabled = anyInstalledOrQueued;
            symbol = @"trash.fill";
            color  = UIColor.systemRedColor;
            cell.textLabel.text = @"重置所有插件";
            cell.detailTextLabel.text = anyInstalledOrQueued ? nil : @"无激活插件";
        } else {
            rowEnabled = YES;
            symbol = @"arrow.down.circle.fill";
            color  = UIColor.systemBlueColor;
            cell.textLabel.text = @"检查更新";
        }

        UIColor *effectiveColor = rowEnabled ? color : UIColor.tertiaryLabelColor;
        cell.imageView.image = [SettingsViewController iconBadgeWithSymbol:symbol color:effectiveColor size:29.0];
        cell.textLabel.font = [UIFont systemFontOfSize:17.0];
        cell.textLabel.textColor = rowEnabled ? UIColor.labelColor : UIColor.tertiaryLabelColor;
        cell.detailTextLabel.textColor = UIColor.tertiaryLabelColor;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:13.0];
        cell.selectionStyle = rowEnabled ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
        cell.userInteractionEnabled = rowEnabled;
        return cell;
    }

    NSDictionary *row = [self rowsForSection:indexPath.section][indexPath.row];
    NSString *kind = row[@"kind"] ?: @"toggle";
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    BOOL supported = settings_device_supported();

    if ([kind isEqualToString:@"nicebar-grid"]) {
        return [self buildNiceBarGridCellInTableView:tableView indexPath:dequeuePath];
    }

    if ([kind isEqualToString:@"info"]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"info"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"info"];
            cell.detailTextLabel.numberOfLines = 0;
        }
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.userInteractionEnabled = NO;
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.text = row[@"title"];
        cell.textLabel.textColor = UIColor.labelColor;
        cell.textLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
        cell.detailTextLabel.text = row[@"subtitle"];
        cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:13.0];
        return cell;
    }

    if ([kind isEqualToString:@"button"]) {
        BOOL rowSupported = supported ||
                            indexPath.section == SectionOTA ||
                            indexPath.section == SectionThemer;
        NSString *action = row[@"action"];
        if (indexPath.section == SectionNanoRegistry &&
            [action isEqualToString:@"nano-load"]) {
            rowSupported = settings_nano_load_override_enabled();
        }
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"button" forIndexPath:dequeuePath];
        cell.selectionStyle = rowSupported ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
        cell.userInteractionEnabled = rowSupported;
        cell.accessoryView = nil;
        cell.textLabel.text = row[@"title"];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.textColor = rowSupported
            ? ([row[@"destructive"] boolValue] ? UIColor.systemRedColor : self.view.tintColor)
            : UIColor.tertiaryLabelColor;
        return cell;
    }

    if ([kind isEqualToString:@"stepper"]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"stepper" forIndexPath:dequeuePath];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.textAlignment = NSTextAlignmentNatural;
        cell.textLabel.textColor = supported ? UIColor.labelColor : UIColor.tertiaryLabelColor;
        NSInteger value = [d integerForKey:row[@"key"]];
        NSString *combined = [NSString stringWithFormat:@"%@: %ld", row[@"title"], (long)value];
        NSString *subtitle = row[@"subtitle"];
        if (subtitle.length > 0) {
            UIListContentConfiguration *config = [UIListContentConfiguration cellConfiguration];
            config.text = combined;
            config.secondaryText = subtitle;
            config.textToSecondaryTextVerticalPadding = 3;
            config.textProperties.color = supported ? UIColor.labelColor : UIColor.tertiaryLabelColor;
            config.secondaryTextProperties.color = supported ? UIColor.secondaryLabelColor : UIColor.tertiaryLabelColor;
            config.secondaryTextProperties.font = [UIFont systemFontOfSize:12];
            config.secondaryTextProperties.numberOfLines = 0;
            cell.contentConfiguration = config;
        } else {
            cell.contentConfiguration = nil;
            cell.textLabel.text = combined;
        }
        UIStepper *stp = [[UIStepper alloc] init];
        stp.minimumValue = [row[@"min"] doubleValue];
        stp.maximumValue = [row[@"max"] doubleValue];
        stp.stepValue = 1;
        stp.value = (double)value;
        stp.enabled = supported;
        stp.tag = (indexPath.section << 16) | indexPath.row;
        [stp addTarget:self action:@selector(stepperChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = stp;
        return cell;
    }

    if ([kind isEqualToString:@"number"]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"number"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"number"];
            cell.detailTextLabel.numberOfLines = 0;
        }
        cell.selectionStyle = supported ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
        cell.userInteractionEnabled = supported;
        cell.accessoryType = supported ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
        cell.accessoryView = nil;
        cell.contentConfiguration = nil;

        double value = settings_number_row_current_value(row, d);
        NSString *valueText = settings_number_row_value_string(row, value, YES);
        cell.textLabel.text = [NSString stringWithFormat:@"%@: %@", row[@"title"], valueText];
        cell.textLabel.textAlignment = NSTextAlignmentNatural;
        cell.textLabel.textColor = supported ? UIColor.labelColor : UIColor.tertiaryLabelColor;
        cell.detailTextLabel.text = row[@"subtitle"] ?: @"点击输入精确数值。";
        cell.detailTextLabel.textColor = supported ? UIColor.secondaryLabelColor : UIColor.tertiaryLabelColor;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        return cell;
    }

    if ([kind isEqualToString:@"slider"]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"slider" forIndexPath:dequeuePath];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = nil;
        cell.detailTextLabel.text = nil;
        cell.accessoryView = nil;
        for (UIView *v in [cell.contentView.subviews copy]) [v removeFromSuperview];

        NSInteger minV = [row[@"min"] integerValue];
        NSInteger maxV = [row[@"max"] integerValue];
        NSInteger step = [row[@"step"] integerValue]; if (step <= 0) step = 1;
        NSInteger value = [d integerForKey:row[@"key"]];
        if (value < minV) value = minV;
        if (value > maxV) value = maxV;
        NSString *unit = row[@"unit"] ?: @"";

        UILabel *title = [[UILabel alloc] init];
        title.translatesAutoresizingMaskIntoConstraints = NO;
        title.text = row[@"title"];
        title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        title.textColor = supported ? UIColor.labelColor : UIColor.tertiaryLabelColor;

        UILabel *valueLabel = [[UILabel alloc] init];
        valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
        valueLabel.text = [NSString stringWithFormat:@"%ld%@", (long)value, unit];
        valueLabel.font = [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightRegular];
        valueLabel.textColor = supported ? UIColor.secondaryLabelColor : UIColor.tertiaryLabelColor;
        valueLabel.textAlignment = NSTextAlignmentRight;

        UISlider *slider = [[UISlider alloc] init];
        slider.translatesAutoresizingMaskIntoConstraints = NO;
        slider.minimumValue = (float)minV;
        slider.maximumValue = (float)maxV;
        slider.value = (float)value;
        slider.continuous = YES;
        slider.enabled = supported;
        slider.tag = (indexPath.section << 16) | indexPath.row;
        [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
        [slider addTarget:self action:@selector(sliderEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
        // Stash the value label so sliderChanged: can update it without a full reload.
        objc_setAssociatedObject(slider, "cyanideValueLabel", valueLabel, OBJC_ASSOCIATION_ASSIGN);
        objc_setAssociatedObject(slider, "cyanideUnit", unit, OBJC_ASSOCIATION_RETAIN);
        objc_setAssociatedObject(slider, "cyanideStep", @(step), OBJC_ASSOCIATION_RETAIN);

        [cell.contentView addSubview:title];
        [cell.contentView addSubview:valueLabel];
        [cell.contentView addSubview:slider];

        UILayoutGuide *m = cell.contentView.layoutMarginsGuide;
        [NSLayoutConstraint activateConstraints:@[
            [title.leadingAnchor      constraintEqualToAnchor:m.leadingAnchor],
            [title.topAnchor          constraintEqualToAnchor:m.topAnchor],
            [valueLabel.trailingAnchor constraintEqualToAnchor:m.trailingAnchor],
            [valueLabel.centerYAnchor  constraintEqualToAnchor:title.centerYAnchor],
            [valueLabel.leadingAnchor  constraintGreaterThanOrEqualToAnchor:title.trailingAnchor constant:8],
            [slider.leadingAnchor   constraintEqualToAnchor:m.leadingAnchor],
            [slider.trailingAnchor  constraintEqualToAnchor:m.trailingAnchor],
            [slider.topAnchor       constraintEqualToAnchor:title.bottomAnchor constant:4],
            [slider.bottomAnchor    constraintEqualToAnchor:m.bottomAnchor],
        ]];
        return cell;
    }

    if ([kind isEqualToString:@"segmented"]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"segmented" forIndexPath:dequeuePath];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = nil;
        for (UIView *v in [cell.contentView.subviews copy]) [v removeFromSuperview];
        UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:@[@"关闭", @"标准", @"轻度", @"中度", @"重度"]];
        seg.translatesAutoresizingMaskIntoConstraints = NO;
        NSString *cur = [d stringForKey:row[@"key"]] ?: @"nominal";
        NSUInteger idx = [powercuff_levels() indexOfObject:cur];
        if (idx == NSNotFound) idx = [powercuff_levels() indexOfObject:@"nominal"];
        seg.selectedSegmentIndex = (NSInteger)idx;
        seg.enabled = supported;
        [seg addTarget:self action:@selector(powercuffSegChanged:) forControlEvents:UIControlEventValueChanged];
        [cell.contentView addSubview:seg];
        [NSLayoutConstraint activateConstraints:@[
            [seg.leadingAnchor  constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.leadingAnchor],
            [seg.trailingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.trailingAnchor],
            [seg.topAnchor      constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.topAnchor],
            [seg.bottomAnchor   constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.bottomAnchor],
        ]];
        return cell;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"toggle" forIndexPath:dequeuePath];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    BOOL rowEnabled = supported && ![row[@"disabled"] boolValue];
    cell.userInteractionEnabled = rowEnabled;
    NSString *subtitle = row[@"subtitle"];
    if (subtitle.length > 0) {
        UIListContentConfiguration *config = [UIListContentConfiguration cellConfiguration];
        config.text = row[@"title"];
        config.secondaryText = subtitle;
        config.textToSecondaryTextVerticalPadding = 3;
        config.textProperties.color = rowEnabled ? UIColor.labelColor : UIColor.tertiaryLabelColor;
        config.secondaryTextProperties.color = rowEnabled ? UIColor.secondaryLabelColor : UIColor.tertiaryLabelColor;
        config.secondaryTextProperties.font = [UIFont systemFontOfSize:12];
        config.secondaryTextProperties.numberOfLines = 0;
        cell.contentConfiguration = config;
    } else {
        cell.contentConfiguration = nil;
        cell.textLabel.text = row[@"title"];
        cell.textLabel.textAlignment = NSTextAlignmentNatural;
        cell.textLabel.textColor = rowEnabled ? UIColor.labelColor : UIColor.tertiaryLabelColor;
    }
    UISwitch *sw = [[UISwitch alloc] init];
    sw.on = rowEnabled && [d boolForKey:row[@"key"]];
    sw.enabled = rowEnabled;
    sw.tag = (indexPath.section << 16) | indexPath.row;
    [sw addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = sw;
    return cell;
}

#pragma mark - Actions

- (NSDictionary *)rowForTag:(NSInteger)tag
{
    NSInteger section = (tag >> 16) & 0xFFFF;
    NSInteger row = tag & 0xFFFF;
    return [self rowsForSection:section][row];
}

- (void)presentApplyLogIfRunning
{
    // Skip if a modal is already up (e.g. the user just toggled a different
    // switch and the log is already visible).
    if (self.presentedViewController) return;
    // Skip if there's no live SpringBoard session — the change won't fire any
    // RemoteCall until the user runs the chain, so there's nothing to watch.
    if (!g_springboard_rc_ready) return;

    [self presentActivityLog];
}

- (void)presentActivityLog
{
    [self presentActivityLogWithCompletion:nil];
}

- (void)presentActivityLogWithCompletion:(dispatch_block_t)completion
{
    if (self.presentedViewController) {
        if ([self.presentedViewController isKindOfClass:UIAlertController.class]) {
            __weak typeof(self) weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(250 * NSEC_PER_MSEC)),
                           dispatch_get_main_queue(), ^{
                [weakSelf presentActivityLogWithCompletion:completion];
            });
            return;
        }
        if (completion) completion();
        return;
    }

    InstallProgressViewController *vc = [[InstallProgressViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationAutomatic;
    [self presentViewController:nav animated:YES completion:completion];
}

- (void)toggleChanged:(UISwitch *)sender
{
    if (!settings_device_supported()) {
        sender.on = !sender.isOn;
        printf("[SETTINGS] toggle blocked: %s\n", settings_unsupported_message().UTF8String);
        return;
    }

    NSDictionary *row = [self rowForTag:sender.tag];
    if ([row[@"disabled"] boolValue]) {
        sender.on = !sender.isOn;
        printf("[SETTINGS] toggle blocked: %s is in progress\n", [row[@"key"] UTF8String]);
        return;
    }
    NSString *key = row[@"key"];
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:key];
    printf("[SETTINGS] toggle %s=%d\n", key.UTF8String, sender.isOn);
    if ([key isEqualToString:kSettingsKeepAlive]) {
        ds_keepalive_apply_enabled(sender.isOn);
        return;
    }
    if (settings_key_affects_package_state(key)) {
        if (!sender.isOn) settings_mark_tweak_applied(key, NO);
        settings_notify_package_queue_changed_async();
    }
    settings_schedule_live_apply_for_key(key);
    [self presentApplyLogIfRunning];
}

- (void)sliderChanged:(UISlider *)sender
{
    if (!settings_device_supported()) return;
    NSNumber *stepNum = objc_getAssociatedObject(sender, "cyanideStep");
    NSInteger step = stepNum ? [stepNum integerValue] : 1;
    if (step <= 0) step = 1;
    NSInteger value = (NSInteger)llround((double)sender.value / (double)step) * step;
    UILabel *valueLabel = objc_getAssociatedObject(sender, "cyanideValueLabel");
    NSString *unit = objc_getAssociatedObject(sender, "cyanideUnit") ?: @"";
    if (valueLabel) {
        valueLabel.text = [NSString stringWithFormat:@"%ld%@", (long)value, unit];
    }
}

- (void)sliderEnded:(UISlider *)sender
{
    if (!settings_device_supported()) return;
    NSDictionary *row = [self rowForTag:sender.tag];
    if (!row) return;
    NSString *key = row[@"key"];
    NSInteger step = [row[@"step"] integerValue]; if (step <= 0) step = 1;
    NSInteger value = (NSInteger)llround((double)sender.value / (double)step) * step;
    sender.value = (float)value;  // snap thumb to the step grid
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    BOOL showLocationLog = settings_key_is_location_sim(key) && settings_location_sim_is_active(d);
    [d setInteger:value forKey:key];
    printf("[SETTINGS] slider %s=%ld\n", key.UTF8String, (long)value);
    if (showLocationLog) {
        [self presentActivityLogWithCompletion:^{
            settings_schedule_live_apply_for_key(key);
        }];
    } else {
        settings_schedule_live_apply_for_key(key);
        [self presentApplyLogIfRunning];
    }
    if (settings_key_is_location_sim(key)) {
        [self.tableView reloadData];
    }
}

- (void)presentNumberEntryForRow:(NSDictionary *)row section:(NSInteger)section
{
    NSString *key = row[@"key"];
    if (key.length == 0) return;

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    double current = settings_number_row_current_value(row, d);
    NSString *minText = settings_number_row_value_string(row, [row[@"min"] doubleValue], YES);
    NSString *maxText = settings_number_row_value_string(row, [row[@"max"] doubleValue], YES);
    NSString *message = [NSString stringWithFormat:@"请输入 %@ 到 %@ 之间的数值。%@%@",
                         minText,
                         maxText,
                         [row[@"subtitle"] length] > 0 ? @"\n\n" : @"",
                         row[@"subtitle"] ?: @""];

    UIAlertController *ac = [UIAlertController
        alertControllerWithTitle:row[@"title"]
                         message:message
                  preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = settings_number_row_value_string(row, current, NO);
        field.placeholder = settings_number_row_value_string(row, [row[@"default"] doubleValue], NO);
        field.keyboardType = (row[@"precision"] && [row[@"precision"] integerValue] > 0)
            ? UIKeyboardTypeDecimalPad
            : UIKeyboardTypeNumberPad;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
        [field selectAll:nil];
    }];

    __weak typeof(self) weakSelf = self;
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"保存"
                                           style:UIAlertActionStyleDefault
                                         handler:^(__unused UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        NSString *input = ac.textFields.firstObject.text ?: @"";
        NSString *trimmed = [input stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSString *normalizedInput = [trimmed stringByReplacingOccurrencesOfString:@"," withString:@"."];
        NSScanner *scanner = [NSScanner scannerWithString:normalizedInput];
        scanner.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];

        double parsed = 0.0;
        BOOL ok = [scanner scanDouble:&parsed];
        [scanner scanCharactersFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet intoString:NULL];
        if (!ok || ![scanner isAtEnd] || !isfinite(parsed)) {
            UIAlertController *err = [UIAlertController
                alertControllerWithTitle:@"无效数字"
                                 message:@"请输入纯数字，然后重试。"
                          preferredStyle:UIAlertControllerStyleAlert];
            [err addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(250 * NSEC_PER_MSEC)),
                           dispatch_get_main_queue(), ^{
                settings_present_controller(err, strongSelf);
            });
            return;
        }

        double value = settings_number_row_normalized_value(row, parsed);
        if ([key isEqualToString:kSettingsDSDragCoefficientValue] ||
            (row[@"precision"] && [row[@"precision"] integerValue] > 0)) {
            [d setDouble:value forKey:key];
        } else {
            [d setInteger:(NSInteger)llround(value) forKey:key];
        }
        [d synchronize];

        NSString *valueText = settings_number_row_value_string(row, value, YES);
        printf("[SETTINGS] number %s=%s\n", key.UTF8String, valueText.UTF8String);
        settings_schedule_live_apply_for_key(key);
        [strongSelf reloadSectionOrAll:section];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(250 * NSEC_PER_MSEC)),
                       dispatch_get_main_queue(), ^{
            [strongSelf presentApplyLogIfRunning];
        });
    }]];
    settings_present_controller(ac, self);
}

- (void)reloadLocationSimUI
{
    [self.tableView reloadData];
    [[NSNotificationCenter defaultCenter] postNotificationName:PackageQueueDidChangeNotification
                                                        object:[PackageQueue sharedQueue]];
}

- (void)reloadIPADecryptorUI
{
    [self reloadSectionOrAll:SectionIPADecryptor];
    [[NSNotificationCenter defaultCenter] postNotificationName:PackageQueueDidChangeNotification
                                                        object:[PackageQueue sharedQueue]];
}

- (void)presentIPADecryptorAppPicker
{
    NSArray<NSDictionary<NSString *, NSString *> *> *apps = ipadecryptor_installed_apps();
    if (apps.count == 0) {
        UIAlertController *ac = [UIAlertController
            alertControllerWithTitle:@"未找到应用"
                             message:@"Cyanide 尚无法列出已安装的用户应用。请先运行一次链，然后重试。"
                      preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        settings_present_controller(ac, self);
        return;
    }

    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"选择应用"
                                                                message:@"选择已安装的应用进行探查/解密。"
                                                         preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    NSUInteger shown = 0;
    for (NSDictionary<NSString *, NSString *> *app in apps) {
        if (shown >= 60) break;
        NSString *bundleID = app[@"bundleID"];
        if (bundleID.length == 0) continue;
        NSString *name = app[@"name"].length > 0 ? app[@"name"] : bundleID;
        NSString *title = name;
        if (![name isEqualToString:bundleID]) {
            title = [NSString stringWithFormat:@"%@ — %@", name, bundleID];
        }
        [ac addAction:[UIAlertAction actionWithTitle:title
                                               style:UIAlertActionStyleDefault
                                             handler:^(__unused UIAlertAction *action) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
            [d setObject:bundleID forKey:kSettingsIPADecryptorTargetBundleID];
            [d synchronize];
            log_user("[IPADEC] Selected %s (%s)\n", name.UTF8String, bundleID.UTF8String);
            [strongSelf reloadIPADecryptorUI];
        }]];
        shown++;
    }
    if (apps.count > shown) {
        [ac addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"还有 %lu 个 — 后续完善选择器",
                                                                             (unsigned long)(apps.count - shown)]
                                               style:UIAlertActionStyleDefault
                                             handler:nil]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    ac.popoverPresentationController.sourceView = self.view;
    ac.popoverPresentationController.sourceRect = self.view.bounds;
    settings_present_controller(ac, self);
}

- (void)saveIPADecryptorAppStoreMetadata:(NSDictionary<NSString *, NSString *> *)meta
                                   input:(NSString *)input
{
    if (meta.count == 0) return;
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSString *bundleID = meta[@"bundleID"] ?: @"";
    [d setObject:input ?: @"" forKey:kSettingsIPADecryptorAppStoreInput];
    [d setObject:meta[@"appStoreID"] ?: @"" forKey:kSettingsIPADecryptorAppStoreID];
    [d setObject:meta[@"name"] ?: @"" forKey:kSettingsIPADecryptorAppStoreName];
    [d setObject:meta[@"version"] ?: @"" forKey:kSettingsIPADecryptorAppStoreVersion];
    [d setObject:meta[@"trackURL"] ?: @"" forKey:kSettingsIPADecryptorAppStoreURL];
    [d setObject:@"" forKey:kSettingsIPADecryptorDownloadedIPAPath];
    [d setObject:@"已解析 App Store 元数据。下载尚未开始。"
          forKey:kSettingsIPADecryptorDownloadStatus];
    if (bundleID.length > 0) {
        [d setObject:bundleID forKey:kSettingsIPADecryptorTargetBundleID];
    }
    [d synchronize];
}

- (void)saveIPADecryptorDownloadStatus:(NSString *)status
                         downloadedIPA:(NSString *)downloadedPath
{
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d setObject:status.length > 0 ? status : @"下载状态不可用。"
          forKey:kSettingsIPADecryptorDownloadStatus];
    if (downloadedPath.length > 0) {
        [d setObject:downloadedPath forKey:kSettingsIPADecryptorDownloadedIPAPath];
    }
    [d synchronize];
}

- (void)presentIPADecryptorSignInPrompt
{
    UIAlertController *ac = [UIAlertController
        alertControllerWithTitle:@"App Store 登录"
                         message:@"使用拥有或可下载此应用的 Apple ID 登录。如果 Apple 要求两步验证，Cyanide 下一步会提示输入验证码。"
                  preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"Apple ID 邮箱";
        field.keyboardType = UIKeyboardTypeEmailAddress;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"密码";
        field.secureTextEntry = YES;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    __weak typeof(self) weakSelf = self;
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"登录"
                                           style:UIAlertActionStyleDefault
                                         handler:^(__unused UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf runIPADecryptorSignInEmail:ac.textFields[0].text
                                      password:ac.textFields[1].text
                                      authCode:nil];
    }]];
    settings_present_controller(ac, self);
}

- (void)presentIPADecryptorTwoFactorPromptForEmail:(NSString *)email
                                          password:(NSString *)password
{
    NSString *trimmedEmail = [email ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *shownEmail = trimmedEmail.length > 0 ? trimmedEmail : @"this Apple ID";
    UIAlertController *ac = [UIAlertController
        alertControllerWithTitle:@"两步验证码"
                         message:[NSString stringWithFormat:@"输入 Apple 发送给 %@ 的 6 位验证码。", shownEmail]
                  preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"验证码";
        field.keyboardType = UIKeyboardTypeNumberPad;
        field.textContentType = UITextContentTypeOneTimeCode;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    __weak typeof(self) weakSelf = self;
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"验证"
                                           style:UIAlertActionStyleDefault
                                         handler:^(__unused UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        NSString *rawCode = ac.textFields.firstObject.text ?: @"";
        NSMutableString *code = [NSMutableString string];
        NSCharacterSet *digits = NSCharacterSet.decimalDigitCharacterSet;
        for (NSUInteger i = 0; i < rawCode.length; i++) {
            unichar c = [rawCode characterAtIndex:i];
            if ([digits characterIsMember:c]) [code appendFormat:@"%C", c];
        }
        if (code.length == 0) {
            UIAlertController *retry = [UIAlertController
                alertControllerWithTitle:@"需要验证码"
                                 message:@"请输入 Apple 的 6 位验证码。"
                          preferredStyle:UIAlertControllerStyleAlert];
            [retry addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
                [strongSelf presentIPADecryptorTwoFactorPromptForEmail:email password:password];
            }]];
            settings_present_controller(retry, strongSelf);
            return;
        }
        [strongSelf runIPADecryptorSignInEmail:email
                                      password:password
                                      authCode:code];
    }]];
    settings_present_controller(ac, self);
}

- (void)runIPADecryptorSignInEmail:(NSString *)email
                          password:(NSString *)password
                          authCode:(NSString *)authCode
{
    static volatile int sIPADecryptorSignInInFlight = 0;
    if (__sync_lock_test_and_set(&sIPADecryptorSignInInFlight, 1)) {
        log_user("[IPADEC] App Store sign-in already running.\n");
        return;
    }

    NSString *emailCopy = [email copy] ?: @"";
    NSString *passwordCopy = [password copy] ?: @"";
    NSString *authCodeCopy = [authCode copy] ?: @"";
    __weak typeof(self) weakSelf = self;
    log_user("[IPADEC] Signing in to App Store as %s%s\n",
             emailCopy.UTF8String,
             authCodeCopy.length > 0 ? " with 2FA code" : "");
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        BOOL actionOK = NO;
        BOOL actionLockAcquired = NO;
        NSString *completionMessage = nil;
        @try {
            actionLockAcquired = settings_try_claim_actions_lock("IPA Decryptor App Store sign-in",
                                                                 "[IPADEC] Another action is already running.");
            if (!actionLockAcquired) {
                completionMessage = @"登录被阻止：另一操作仍在运行中。";
                return;
            }
            NSString *message = nil;
            actionOK = ipadecryptor_login_app_store(emailCopy, passwordCopy, authCodeCopy, &message);
            completionMessage = message ?: (actionOK ? @"App Store 登录完成。" : @"App Store 登录失败。");
            log_user("[IPADEC] %s\n", completionMessage.UTF8String);
        } @finally {
            if (actionLockAcquired) settings_release_actions_lock();
            __sync_lock_release(&sIPADecryptorSignInInFlight);
            BOOL messageRequestsTwoFactor =
                completionMessage.length > 0 &&
                [completionMessage rangeOfString:@"Two-factor code required"
                                         options:NSCaseInsensitiveSearch].location != NSNotFound;
            BOOL needsTwoFactor = (!actionOK &&
                                   authCodeCopy.length == 0 &&
                                   messageRequestsTwoFactor);
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                [strongSelf reloadIPADecryptorUI];
                NSDictionary *info = @{
                    kSettingsActionsDidCompleteSuccessKey: @(actionOK),
                    kSettingsActionsDidCompleteMessageKey: completionMessage ?: @""
                };
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:kSettingsActionsDidCompleteNotification
                                  object:nil
                                userInfo:info];
                if (needsTwoFactor) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(250 * NSEC_PER_MSEC)),
                                   dispatch_get_main_queue(), ^{
                        __strong typeof(weakSelf) laterSelf = weakSelf;
                        [laterSelf presentIPADecryptorTwoFactorPromptForEmail:emailCopy
                                                                      password:passwordCopy];
                    });
                }
            });
        }
    });
}

- (void)presentIPADecryptorAppStoreLinkPrompt
{
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    UIAlertController *ac = [UIAlertController
        alertControllerWithTitle:@"App Store 链接"
                         message:@"粘贴 App Store URL（如 https://apps.apple.com/us/app/name/id123456789）或输入数字应用 ID。Cyanide 会解析它，然后尝试 IPA 下载路径。"
                  preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"App Store URL 或应用 ID";
        field.text = [d stringForKey:kSettingsIPADecryptorAppStoreInput] ?: @"";
        field.keyboardType = UIKeyboardTypeURL;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    __weak typeof(self) weakSelf = self;
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"解析"
                                           style:UIAlertActionStyleDefault
                                         handler:^(__unused UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        NSString *input = ac.textFields.firstObject.text ?: @"";
        [strongSelf runIPADecryptorResolveAppStoreInput:input];
    }]];
    settings_present_controller(ac, self);
}

- (void)runIPADecryptorResolveAppStoreInput:(NSString *)input
{
    NSString *trimmed = [input stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) {
        log_user("[IPADEC] Paste an App Store link first.\n");
        return;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_block_t startAction = ^{
        log_user("[IPADEC] Resolving App Store input: %s\n", trimmed.UTF8String);
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            BOOL actionOK = NO;
            BOOL actionLockAcquired = NO;
            NSString *completionMessage = nil;
            NSDictionary<NSString *, NSString *> *meta = nil;
            BOOL downloadOK = NO;
            NSString *downloadedPath = nil;
            NSString *downloadMessage = nil;
            @try {
                actionLockAcquired = settings_try_claim_actions_lock("IPA Decryptor App Store lookup",
                                                                     "[IPADEC] Another action is already running.");
                if (!actionLockAcquired) {
                    completionMessage = @"App Store 查询被阻止：另一操作仍在运行中。";
                    return;
                }

                NSString *message = nil;
                meta = ipadecryptor_resolve_app_store_input(trimmed, &message);
                actionOK = meta != nil;
                completionMessage = message ?: (actionOK ? @"App Store 链接已解析。" : @"App Store 查找失败。");
                if (meta) {
                    log_user("[IPADEC] Resolved target bundle id: %s\n",
                             (meta[@"bundleID"] ?: @"").UTF8String);
                    log_user("[IPADEC] Starting IPA download path after resolve.\n");
                    downloadOK = ipadecryptor_download_app_store_ipa(trimmed,
                                                                     &downloadedPath,
                                                                     &downloadMessage);
                    if (downloadOK) {
                        completionMessage = downloadMessage ?: @"IPA 已下载。";
                    } else {
                        completionMessage = [NSString stringWithFormat:@"链接已解析。%@",
                                                                       downloadMessage ?: @"IPA 下载未启动。"];
                    }
                }
            } @finally {
                if (actionLockAcquired) settings_release_actions_lock();
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (meta) [strongSelf saveIPADecryptorAppStoreMetadata:meta input:trimmed];
                    if (meta) {
                        [strongSelf saveIPADecryptorDownloadStatus:downloadMessage ?: (downloadOK ? @"IPA 已下载。" : @"IPA 下载未启动。")
                                                     downloadedIPA:downloadOK ? downloadedPath : nil];
                    }
                    [strongSelf reloadIPADecryptorUI];
                    NSDictionary *info = @{
                        kSettingsActionsDidCompleteSuccessKey: @(actionOK && downloadOK),
                        kSettingsActionsDidCompleteMessageKey: completionMessage ?: @""
                    };
                    [[NSNotificationCenter defaultCenter]
                        postNotificationName:kSettingsActionsDidCompleteNotification
                                      object:nil
                                    userInfo:info];
                });
            }
        });
    };
    [self presentActivityLogWithCompletion:startAction];
}

- (void)runIPADecryptorAction:(NSString *)action
{
    if (action.length == 0) return;
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    BOOL downloadIPA = [action isEqualToString:@"ipadec-download"];
    NSString *bundleID = [d stringForKey:kSettingsIPADecryptorTargetBundleID];
    NSString *appStoreInput = [d stringForKey:kSettingsIPADecryptorAppStoreInput];
    if (!downloadIPA && bundleID.length == 0) {
        log_user("[IPADEC] Select an installed app first.\n");
        return;
    }
    if (downloadIPA && appStoreInput.length == 0) {
        log_user("[IPADEC] Paste an App Store link first.\n");
        return;
    }

    BOOL startDecrypt = [action isEqualToString:@"ipadec-start"];
    BOOL probeOnly = [action isEqualToString:@"ipadec-probe"];
    if (!startDecrypt && !probeOnly && !downloadIPA) return;

    static volatile int sIPADecryptorInFlight = 0;
    if (__sync_lock_test_and_set(&sIPADecryptorInFlight, 1)) {
        log_user("[IPADEC] Another IPA Decryptor action is already running.\n");
        return;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_block_t startAction = ^{
        log_user("[IPADEC] %s %s\n",
                 downloadIPA ? "Downloading App Store IPA for" : (startDecrypt ? "Starting decrypt pipeline for" : "Probing"),
                 downloadIPA ? appStoreInput.UTF8String : bundleID.UTF8String);
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            BOOL actionOK = NO;
            BOOL actionLockAcquired = NO;
            NSString *completionMessage = nil;
            NSString *downloadedPath = nil;
            @try {
                actionLockAcquired = settings_try_claim_actions_lock("IPA Decryptor action",
                                                                     "[IPADEC] Another action is already running.");
                if (!actionLockAcquired) {
                    completionMessage = @"IPA 解密器被阻止：另一操作仍在运行中。";
                    return;
                }
                if (startDecrypt && !settings_ensure_kexploit()) {
                    log_user("[IPADEC] Failed: kernel primitives not acquired. Please run the chain again.\n");
                    completionMessage = @"IPA 解密器失败：未获取到内核原语。";
                    return;
                }

                NSString *message = nil;
                if (downloadIPA) {
                    actionOK = ipadecryptor_download_app_store_ipa(appStoreInput,
                                                                   &downloadedPath,
                                                                   &message);
                } else {
                    actionOK = startDecrypt
                        ? ipadecryptor_start_decrypt_installed_app(bundleID, &message)
                        : ipadecryptor_probe_installed_app(bundleID, &message);
                }
                completionMessage = message ?: (actionOK ? @"IPA 解密器操作已完成。" : @"IPA 解密器操作未完成。");
            } @finally {
                if (actionLockAcquired) settings_release_actions_lock();
                __sync_lock_release(&sIPADecryptorInFlight);
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (downloadIPA) {
                        [strongSelf saveIPADecryptorDownloadStatus:completionMessage
                                                     downloadedIPA:(actionOK ? downloadedPath : nil)];
                    }
                    [strongSelf reloadIPADecryptorUI];
                    NSDictionary *info = @{
                        kSettingsActionsDidCompleteSuccessKey: @(actionOK),
                        kSettingsActionsDidCompleteMessageKey: completionMessage ?: @""
                    };
                    [[NSNotificationCenter defaultCenter]
                        postNotificationName:kSettingsActionsDidCompleteNotification
                                      object:nil
                                    userInfo:info];
                });
            }
        });
    };
    [self presentActivityLogWithCompletion:startAction];
}

- (void)runGravityLiteAction:(NSString *)action
{
    if (!settings_device_supported()) return;
    BOOL restore = [action isEqualToString:@"gravitylite-restore"];
    BOOL explosion = [action isEqualToString:@"gravitylite-explosion"];
    if (!restore && !explosion) return;

    dispatch_block_t startAction = ^{
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
            __block BOOL actionOK = NO;
            BOOL actionLockAcquired = NO;
            NSString *completionMessage = restore
                ? @"Gravity Lite 恢复失败。请检查日志。"
                : @"Gravity Lite 爆发失败。请检查日志。";
            @try {
                actionLockAcquired = settings_try_claim_actions_lock("Gravity Lite action",
                                                                     "[GRAVITY] Another action is already running.");
                if (!actionLockAcquired) {
                    completionMessage = @"Gravity Lite 已被阻止：应用插件仍在运行中。";
                    return;
                }
                if (!settings_ensure_kexploit()) {
                    log_user("[GRAVITY] Failed: kernel primitives not acquired. Please try running chain again.\n");
                    completionMessage = @"Gravity Lite 失败：未获取到内核原语。请重新运行链。";
                    return;
                }

                @synchronized (settings_rc_lock()) {
                    if (g_springboard_rc_ready) {
                        actionOK = restore
                            ? gravitylite_stop_in_session()
                            : gravitylite_explosion_in_session(settings_gravitylite_config_from_defaults(d).explosionForce);
                    } else {
                        RemoteCallSession *springboardSession =
                            [[RemoteCallSession alloc] initWithProcess:@"SpringBoard"
                                                     useMigFilterBypass:NO
                                                firstExceptionTimeoutMS:kSettingsSpringBoardRCFirstExceptionTimeoutMS];
                        if (!springboardSession) {
                            log_user("[GRAVITY] SpringBoard not reachable.\n");
                        } else {
                            remote_call_with_session(springboardSession, ^{
                                actionOK = restore
                                    ? gravitylite_stop_in_session()
                                    : gravitylite_explosion_in_session(settings_gravitylite_config_from_defaults(d).explosionForce);
                            });
                            [springboardSession destroyRemoteCall];
                        }
                    }
                }

                if (restore) {
                    __sync_lock_test_and_set(&g_gravitylite_background_armed, 0);
                    settings_stop_gravity_motion();
                    settings_mark_tweak_applied(kSettingsGravityLiteEnabled, NO);
                    completionMessage = actionOK
                        ? @"Gravity Lite 已恢复图标布局。"
                        : @"Gravity Lite 恢复未发现活跃状态。";
                    log_user("%s Gravity Lite restore %s.\n",
                             actionOK ? "[OK]" : "[WARN]",
                             actionOK ? "completed" : "found no active state");
                } else {
                    completionMessage = actionOK
                        ? @"Gravity Lite 爆发脉冲已发送。"
                        : @"Gravity Lite 爆发未发现活跃状态。";
                    log_user("%s Gravity Lite explosion %s.\n",
                             actionOK ? "[OK]" : "[WARN]",
                             actionOK ? "sent" : "found no active state");
                }
            } @finally {
                if (actionLockAcquired) settings_release_actions_lock();
                settings_notify_package_queue_changed_async();
                settings_post_actions_complete_async(actionOK, completionMessage);
            }
        });
    };
    [self presentActivityLogWithCompletion:startAction];
}

- (void)runLocationSimApply:(BOOL)apply
{
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    if (apply && !settings_location_sim_install_allowed()) {
        log_user("[LOCSIM] Location Simulator is unavailable in this build.\n");
        return;
    }

    static volatile int sLocSimButtonInFlight = 0;
    if (__sync_lock_test_and_set(&sLocSimButtonInFlight, 1)) {
        log_user("[LOCSIM] A Location Simulator action is already running.\n");
        return;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_block_t startAction = ^{
        log_user("[LOCSIM] %s %s.\n",
                 apply ? "Simulating" : "Restoring",
                 apply ? settings_location_sim_target_summary(d).UTF8String : "real location");
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            BOOL actionOK = NO;
            BOOL actionLockAcquired = NO;
            NSString *completionMessage = apply
                ? @"位置模拟器已应用。"
                : @"恢复请求已发送。真实位置可能需要几分钟。";
            @try {
                actionLockAcquired = settings_try_claim_actions_lock("Location Simulator action",
                                                                     "[LOCSIM] Another action is already running.");
                if (!actionLockAcquired) {
                    completionMessage = @"位置模拟器已被阻止：应用插件仍在运行中。";
                    return;
                }
                if (!settings_ensure_kexploit()) {
                    log_user("[LOCSIM] Failed: kernel primitives not acquired. Please try running chain again.\n");
                    completionMessage = @"位置模拟器失败：未获取到内核原语。请重新运行链。";
                    return;
                }

                bool ok = false;
                @synchronized (settings_rc_lock()) {
                    settings_destroy_springboard_remote_call_locked_internal("switching to Location Simulator", NO);
                    ok = apply
                        ? settings_apply_location_sim_from_defaults_locked(d)
                        : settings_stop_location_sim_from_defaults_locked(d);
                    if (ok) {
                        if (apply) {
                            [d setBool:YES forKey:kSettingsLocationSimStarted];
                        } else {
                            [d setBool:NO forKey:kSettingsLocationSimStarted];
                        }
                        [d synchronize];
                    }
                }
                actionOK = ok;
                completionMessage = apply
                    ? (ok ? @"位置模拟器已应用。" : @"位置模拟器失败。请检查日志。")
                    : (ok ? @"恢复请求已发送。真实位置可能需要几分钟。" : @"恢复失败。请检查日志。");
                log_user("%s Location Simulator %s.\n",
                         ok ? "[OK]" : "[WARN]",
                         apply ? (ok ? "applied" : "did not apply cleanly")
                               : (ok ? "stopped; real location should resume" : "did not stop cleanly"));
            } @finally {
                if (actionLockAcquired) settings_release_actions_lock();
                __sync_lock_release(&sLocSimButtonInFlight);
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    [strongSelf reloadLocationSimUI];
                    NSDictionary *info = @{
                        kSettingsActionsDidCompleteSuccessKey: @(actionOK),
                        kSettingsActionsDidCompleteMessageKey: completionMessage ?: @""
                    };
                    [[NSNotificationCenter defaultCenter]
                        postNotificationName:kSettingsActionsDidCompleteNotification
                                      object:nil
                                    userInfo:info];
                });
            }
        });
    };
    [self presentActivityLogWithCompletion:startAction];
}

- (void)runLocationSimUberStealth:(BOOL)enable
{
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    if (enable && !settings_location_sim_install_allowed()) {
        log_user("[LOCSIM] Location Simulator is unavailable in this build.\n");
        return;
    }

    static volatile int sLocSimUberStealthInFlight = 0;
    if (__sync_lock_test_and_set(&sLocSimUberStealthInFlight, 1)) {
        log_user("[LOCSIM] A Strict App Mode action is already running.\n");
        return;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_block_t startAction = ^{
        log_user("[LOCSIM] %s Strict App Mode for %s.\n",
                 enable ? "Priming" : "Disabling",
                 enable ? settings_location_sim_target_summary(d).UTF8String : "the running process");
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            BOOL actionOK = NO;
            BOOL actionLockAcquired = NO;
            NSString *completionMessage = enable
                ? @"严格应用模式失败。请检查日志。"
                : @"严格应用模式禁用失败。请检查日志。";
            @try {
                actionLockAcquired = settings_try_claim_actions_lock("Location Simulator strict mode",
                                                                     "[LOCSIM] Another action is already running.");
                if (!actionLockAcquired) {
                    completionMessage = @"严格应用模式已被阻止：应用插件仍在运行中。";
                    return;
                }
                if (!settings_ensure_kexploit()) {
                    log_user("[LOCSIM] Strict App Mode failed: kernel primitives not acquired. Please try running chain again.\n");
                    completionMessage = @"严格应用模式失败：未获取到内核原语。请重新运行链。";
                    return;
                }

                BOOL systemOK = NO;
                BOOL stealthOK = NO;
                @synchronized (settings_rc_lock()) {
                    settings_destroy_springboard_remote_call_locked_internal("switching to Location Simulator strict app mode", NO);
                    stealthOK = settings_prime_location_sim_uber_stealth_locked(d, enable, &systemOK);
                    if (enable && systemOK) {
                        [d setBool:YES forKey:kSettingsLocationSimStarted];
                        [d synchronize];
                    }
                }

                actionOK = stealthOK;
                if (enable) {
                    completionMessage = stealthOK
                        ? @"严格模式主机扫描完成。测试前请强制退出并重新打开严格应用。"
                        : @"严格应用模式失败。请检查日志。";
                } else {
                    completionMessage = stealthOK
                        ? @"严格模式模拟停止请求已发送。"
                        : @"严格应用模式禁用失败。请检查日志。";
                }

                log_user("%s Strict App Mode %s (hosts=%s).\n",
                         stealthOK ? "[OK]" : "[WARN]",
                         enable ? "prime finished" : "disable finished",
                         systemOK ? "ok" : "failed");
            } @finally {
                if (actionLockAcquired) settings_release_actions_lock();
                __sync_lock_release(&sLocSimUberStealthInFlight);
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    [strongSelf reloadLocationSimUI];
                    NSDictionary *info = @{
                        kSettingsActionsDidCompleteSuccessKey: @(actionOK),
                        kSettingsActionsDidCompleteMessageKey: completionMessage ?: @""
                    };
                    [[NSNotificationCenter defaultCenter]
                        postNotificationName:kSettingsActionsDidCompleteNotification
                                      object:nil
                                    userInfo:info];
                });
            }
        });
    };
    [self presentActivityLogWithCompletion:startAction];
}

- (void)setLocationSimTargetLatitude:(double)latitude
                            longitude:(double)longitude
                                 name:(NSString *)name
                        applyIfActive:(BOOL)applyIfActive
{
    if (!settings_location_sim_coordinates_valid(latitude, longitude)) {
        log_user("[LOCSIM] Invalid coordinates: lat=%f lon=%f\n", latitude, longitude);
        return;
    }

    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    BOOL wasActive = settings_location_sim_is_active(d);
    settings_location_sim_set_target(d, latitude, longitude);
    log_user("[LOCSIM] Target set to %s: %s\n",
             (name.length > 0 ? name : @"custom").UTF8String,
             settings_location_sim_target_summary(d).UTF8String);
    [self reloadLocationSimUI];
    if (applyIfActive && wasActive) {
        [self runLocationSimApply:YES];
    }
}

- (void)presentLocationSimInvalidCoordinateAlert
{
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"无效坐标"
                                                                message:@"请使用十进制度数。纬度必须在 -90 到 90 之间。经度必须在 -180 到 180 之间。"
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    settings_present_controller(ac, self);
}

- (void)presentLocationSimExactCoordinatePrompt
{
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"精确坐标"
                                                                message:@"输入经纬度，如 40.7128, -74.0060。"
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"纬度或 lat, lon";
        field.text = [NSString stringWithFormat:@"%.8f", [d doubleForKey:kSettingsLocationSimLatitude]];
        field.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"经度";
        field.text = [NSString stringWithFormat:@"%.8f", [d doubleForKey:kSettingsLocationSimLongitude]];
        field.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];

    __weak typeof(self) weakSelf = self;
    void (^commit)(BOOL) = ^(BOOL simulateNow) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        double latitude = 0.0;
        double longitude = 0.0;
        BOOL ok = settings_location_sim_parse_coordinate_fields(ac.textFields.firstObject.text,
                                                                ac.textFields.lastObject.text,
                                                                &latitude,
                                                                &longitude);
        if (!ok) {
            [strongSelf presentLocationSimInvalidCoordinateAlert];
            return;
        }
        [strongSelf setLocationSimTargetLatitude:latitude
                                       longitude:longitude
                                            name:@"精确坐标"
                                   applyIfActive:!simulateNow];
        if (simulateNow) {
            [strongSelf runLocationSimApply:YES];
        }
    };

    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"设置坐标"
                                           style:UIAlertActionStyleDefault
                                         handler:^(__unused UIAlertAction *action) {
        commit(NO);
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"设置并模拟"
                                           style:UIAlertActionStyleDefault
                                         handler:^(__unused UIAlertAction *action) {
        commit(YES);
    }]];
    settings_present_controller(ac, self);
}

- (void)presentLocationSimCityPicker
{
    NSArray<NSDictionary *> *cities = @[
        @{ @"name": @"纽约市", @"lat": @40.7128, @"lon": @(-74.0060) },
        @{ @"name": @"洛杉矶", @"lat": @34.0522, @"lon": @(-118.2437) },
        @{ @"name": @"芝加哥", @"lat": @41.8781, @"lon": @(-87.6298) },
        @{ @"name": @"迈阿密", @"lat": @25.7617, @"lon": @(-80.1918) },
        @{ @"name": @"伦敦", @"lat": @51.5074, @"lon": @(-0.1278) },
        @{ @"name": @"巴黎", @"lat": @48.8566, @"lon": @2.3522 },
        @{ @"name": @"东京", @"lat": @35.6762, @"lon": @139.6503 },
        @{ @"name": @"悉尼", @"lat": @(-33.8688), @"lon": @151.2093 },
        @{ @"name": @"迪拜", @"lat": @25.2048, @"lon": @55.2708 },
        @{ @"name": @"新加坡", @"lat": @1.3521, @"lon": @103.8198 },
    ];

    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"主要城市"
                                                                message:nil
                                                         preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    for (NSDictionary *city in cities) {
        NSString *name = city[@"name"];
        [ac addAction:[UIAlertAction actionWithTitle:name
                                               style:UIAlertActionStyleDefault
                                             handler:^(__unused UIAlertAction *action) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf setLocationSimTargetLatitude:[city[@"lat"] doubleValue]
                                           longitude:[city[@"lon"] doubleValue]
                                                name:name
                                       applyIfActive:NO];
            [strongSelf runLocationSimApply:YES];
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    ac.popoverPresentationController.sourceView = self.view;
    ac.popoverPresentationController.sourceRect = self.view.bounds;
    settings_present_controller(ac, self);
}

- (void)stepperChanged:(UIStepper *)sender
{
    if (!settings_device_supported()) {
        printf("[SETTINGS] stepper blocked: %s\n", settings_unsupported_message().UTF8String);
        return;
    }

    NSDictionary *row = [self rowForTag:sender.tag];
    NSInteger value = (NSInteger)sender.value;
    [[NSUserDefaults standardUserDefaults] setInteger:value forKey:row[@"key"]];

    // NanoRegistry steppers are seed values for an explicit Apply button;
    // they don't drive a live SpringBoard RC loop, so skip the auto-apply.
    NSString *key = row[@"key"];
    BOOL isNano = [key isEqualToString:kSettingsNanoMaxPairing]
                || [key isEqualToString:kSettingsNanoMinPairing]
                || [key isEqualToString:kSettingsNanoMinPairingChipID]
                || [key isEqualToString:kSettingsNanoMinQuickSwitch];
    if (!isNano) {
        settings_schedule_live_apply_for_key(key);
        [self presentApplyLogIfRunning];
    }

    UIView *v = sender.superview;
    while (v && ![v isKindOfClass:UITableViewCell.class]) v = v.superview;
    UITableViewCell *cell = (UITableViewCell *)v;
    if (cell) {
        NSString *combined = [NSString stringWithFormat:@"%@: %ld", row[@"title"], (long)value];
        NSString *subtitle = row[@"subtitle"];
        if (subtitle.length > 0 && [cell.contentConfiguration isKindOfClass:UIListContentConfiguration.class]) {
            UIListContentConfiguration *config = (UIListContentConfiguration *)[(id<NSCopying>)cell.contentConfiguration copyWithZone:nil];
            config.text = combined;
            cell.contentConfiguration = config;
        } else {
            cell.textLabel.text = combined;
        }
    }
}

- (void)powercuffSegChanged:(UISegmentedControl *)sender
{
    if (!settings_device_supported()) {
        printf("[SETTINGS] powercuff level blocked: %s\n", settings_unsupported_message().UTF8String);
        return;
    }

    NSArray<NSString *> *levels = powercuff_levels();
    if (sender.selectedSegmentIndex < 0 || sender.selectedSegmentIndex >= (NSInteger)levels.count) return;
    [[NSUserDefaults standardUserDefaults] setObject:levels[sender.selectedSegmentIndex]
                                              forKey:kSettingsPowercuffLevel];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (!self.detailMode) {
        switch ((RootSection)indexPath.section) {
            case RootSectionWarning:
                return;
            case RootSectionChangelog: {
                if (!self.changelogExpanded) {
                    self.changelogExpanded = YES;
                    [tableView reloadSections:[NSIndexSet indexSetWithIndex:RootSectionChangelog]
                             withRowAnimation:UITableViewRowAnimationAutomatic];
                    return;
                }
                NSInteger entryCount = (NSInteger)settings_changelog_entries().count;
                if (indexPath.row == entryCount) {
                    [self openReleasesPage];
                } else if (indexPath.row > entryCount) {
                    self.changelogExpanded = NO;
                    [tableView reloadSections:[NSIndexSet indexSetWithIndex:RootSectionChangelog]
                             withRowAnimation:UITableViewRowAnimationAutomatic];
                }
                return;
            }
            case RootSectionActions:
                indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:SectionActions];
                break;
            case RootSectionInDev:
            case RootSectionTweakBundles:
            case RootSectionSystemBundles: {
                NSArray<NSDictionary *> *bundles = (RootSection)indexPath.section == RootSectionInDev
                    ? self.inDevBundleRows
                    : ((RootSection)indexPath.section == RootSectionTweakBundles
                        ? self.tweakBundleRows
                        : self.systemBundleRows);
                NSDictionary *bundle = bundles[indexPath.row];
                NSInteger underlying = [bundle[@"section"] integerValue];
                NSString *pushTitle = bundle[@"title"];
                SettingsViewController *detail = [[SettingsViewController alloc] initWithUnderlyingSection:underlying
                                                                                              bundleTitle:pushTitle];
                [self.navigationController pushViewController:detail animated:YES];
                return;
            }
            case RootSectionPatreon:
                [self handlePatreonTapAtRow:indexPath.row];
                return;
            case RootSectionExperimental: {
                if (!settings_experimental_access_allowed()) {
                    if (cyanide_patreon_is_linked()) {
                        [[UIApplication sharedApplication] openURL:cyanide_patreon_join_url()
                                                            options:@{}
                                                  completionHandler:nil];
                    } else {
                        UIAlertController *ac = [UIAlertController
                            alertControllerWithTitle:@"需要会员等级"
                                             message:@"实验功能是面向 patreon.com/zeroxjf 上会员等级支持者的抢先体验。"
                                      preferredStyle:UIAlertControllerStyleAlert];
                        __weak typeof(self) weakSelf = self;
                        [ac addAction:[UIAlertAction actionWithTitle:@"关联账户"
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction *a) {
                            (void)a;
                            [weakSelf handlePatreonTapAtRow:0];
                        }]];
                        [ac addAction:[UIAlertAction actionWithTitle:@"在 Patreon 注册"
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction *a) {
                            (void)a;
                            [[UIApplication sharedApplication] openURL:cyanide_patreon_join_url()
                                                               options:@{}
                                                     completionHandler:nil];
                        }]];
                        [ac addAction:[UIAlertAction actionWithTitle:@"取消"
                                                               style:UIAlertActionStyleCancel
                                                             handler:nil]];
                        [self presentViewController:ac animated:YES completion:nil];
                    }
                    return;
                }
                UITableViewCell *expCell = [tableView cellForRowAtIndexPath:indexPath];
                if ([expCell.accessoryView isKindOfClass:[UISwitch class]]) {
                    UISwitch *sw = (UISwitch *)expCell.accessoryView;
                    [sw setOn:!sw.isOn animated:YES];
                    [self experimentalSwitchChanged:sw];
                }
                return;
            }
            case RootSectionAbout: {
                switch (indexPath.row) {
                    case 0: [self openTwitter]; break;
                    case 1: {
                        DocsViewController *docs = [[DocsViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
                        [self.navigationController pushViewController:docs animated:YES];
                        break;
                    }
                    case 2: [self showAppIconPicker]; break;
                    case 3: [self openViewLog]; break;
                    case 4: [self openShareLog]; break;
                    // Row 5: Auto-Upload — UISwitch handles it
                }
                return;
            }
            case RootSectionCount:
                return;
        }
    } else {
        indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:self.underlyingSection];
    }

    if (!settings_device_supported() &&
        indexPath.section != SectionWarning &&
        indexPath.section != SectionOTA &&
        indexPath.section != SectionThemer) {
        printf("[SETTINGS] tap blocked: %s\n", settings_unsupported_message().UTF8String);
        return;
    }

    NSArray<NSDictionary *> *rows = [self rowsForSection:indexPath.section];
    if (indexPath.row < (NSInteger)rows.count) {
        NSDictionary *row = rows[indexPath.row];
        if ([row[@"kind"] isEqualToString:@"number"]) {
            [self presentNumberEntryForRow:row section:indexPath.section];
            return;
        }
    }

    if (indexPath.section == SectionActions) {
        if (indexPath.row == 0) {
            UIAlertController *ac = [UIAlertController
                alertControllerWithTitle:@"清理？"
                                 message:@"停止活跃的主屏幕（SpringBoard）通道并关闭本地 KRW 状态。下次运行会先尝试恢复。"
                          preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"取消"
                                                   style:UIAlertActionStyleCancel
                                                 handler:nil]];
            [ac addAction:[UIAlertAction actionWithTitle:@"清理"
                                                   style:UIAlertActionStyleDestructive
                                                 handler:^(UIAlertAction *_) {
                settings_queue_terminal_kexploit_cleanup("manual action");
            }]];
            settings_present_controller(ac, self);
        } else if (indexPath.row == 1) {
            UIAlertController *ac = [UIAlertController
                alertControllerWithTitle:@"注销？"
                                 message:@"确定要注销吗？即将注销。"
                          preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"取消"
                                                   style:UIAlertActionStyleCancel
                                                 handler:nil]];
            __weak typeof(self) weakSelf = self;
            [ac addAction:[UIAlertAction actionWithTitle:@"注销"
                                                   style:UIAlertActionStyleDestructive
                                                 handler:^(UIAlertAction *_) {
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    if (__sync_lock_test_and_set(&g_settings_actions_running, 1)) {
                        printf("[SETTINGS] respring blocked: actions already running\n");
                        return;
                    }

                    __sync_lock_test_and_set(&g_settings_respring_cleanup_running, 1);
                    settings_notify_cleanup_state_changed();
                    @try {
                        settings_prepare_for_respring_sync();
                    } @finally {
                        __sync_lock_release(&g_settings_actions_running);
                        __sync_lock_release(&g_settings_respring_cleanup_running);
                        settings_notify_cleanup_state_changed();
                    }

                    dispatch_async(dispatch_get_main_queue(), ^{
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        if (!strongSelf) return;
                        settings_show_respring_overlay(strongSelf);
                    });
                });
            }]];
            settings_present_controller(ac, self);
        } else if (indexPath.row == 2) {
            UIAlertController *ac = [UIAlertController
                alertControllerWithTitle:@"重置所有插件？"
                                 message:@"卸载所有插件并清空待处理。已应用的补丁会持续到注销或重启。每个插件的单独设置不受影响。"
                          preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"取消"
                                                   style:UIAlertActionStyleCancel
                                                 handler:nil]];
            [ac addAction:[UIAlertAction actionWithTitle:@"重置"
                                                   style:UIAlertActionStyleDestructive
                                                 handler:^(UIAlertAction *_) {
                NSUInteger uninstalled = 0;
                for (Package *p in [PackageCatalog allPackages]) {
                    if (p.isInstalled || p.isQueuedForApply) {
                        [p applyCommittedState:NO];
                        uninstalled++;
                    }
                }
                NSInteger cleared = [[PackageQueue sharedQueue] pendingCount];
                [[PackageQueue sharedQueue] clear];
                log_user("[INSTALLER] Reset: deactivated %lu package(s), cleared %ld pending change(s).\n",
                         (unsigned long)uninstalled, (long)cleared);
                [self.tableView reloadData];
            }]];
            settings_present_controller(ac, self);
        } else if (indexPath.row == 3) {
            [[UpdateChecker shared] checkForUpdatesManuallyFrom:self];
        }
    }

    if (indexPath.section == SectionOTA) {
        settings_run_ota_action(indexPath.row == 0);
        return;
    }

    if (indexPath.section == SectionNanoRegistry) {
        NSDictionary *row = [self rowsForSection:indexPath.section][indexPath.row];
        if (![row[@"kind"] isEqualToString:@"button"]) return;
        NSString *action = row[@"action"];

        if ([action isEqualToString:@"nano-load"]) {
            if (!settings_nano_load_override_enabled()) {
                log_user("[NANO] Load Current Override requires parked KRW recovery; button is disabled until recovery is available.\n");
                return;
            }
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                if (!settings_try_claim_actions_lock("NanoRegistry load",
                                                     "[NANO] Another action is already running.")) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
                                      withRowAnimation:UITableViewRowAnimationNone];
                        [[NSNotificationCenter defaultCenter]
                            postNotificationName:kSettingsActionsDidCompleteNotification
                                          object:nil];
                    });
                    return;
                }
                @try {
                    if (!settings_ensure_kexploit_recovery_only()) {
                        log_user("[NANO] Failed: parked KRW recovery was not acquired.\n");
                    } else {
                        settings_nano_load_from_plist_into_defaults(YES);
                    }
                } @finally {
                    settings_release_actions_lock();
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
                                  withRowAnimation:UITableViewRowAnimationNone];
                    [[NSNotificationCenter defaultCenter]
                        postNotificationName:kSettingsActionsDidCompleteNotification
                                      object:nil];
                });
            });
        } else if ([action isEqualToString:@"nano-preset-newer"]) {
            settings_nano_set_defaults_values(kNanoPresetNewerMaxPairing,
                                              kNanoPresetNewerMinPairing,
                                              kNanoPresetNewerMinPairingChipID,
                                              kNanoPresetNewerMinQuickSwitch);
            log_user("[NANO] Loaded pairing range 99/23/10/6: max=%ld min=%ld minChip=%ld minQuick=%ld. Hit Apply to write.\n",
                     (long)kNanoPresetNewerMaxPairing,
                     (long)kNanoPresetNewerMinPairing,
                     (long)kNanoPresetNewerMinPairingChipID,
                     (long)kNanoPresetNewerMinQuickSwitch);
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
                          withRowAnimation:UITableViewRowAnimationNone];
        } else if ([action isEqualToString:@"nano-apply"]) {
            UIAlertController *ac = [UIAlertController
                alertControllerWithTitle:@"应用配对覆盖？"
                                 message:@"在此 iPhone 上保存这些 watchOS 配对设置。应用后需要注销或重启再尝试配对。"
                          preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
            [ac addAction:[UIAlertAction actionWithTitle:@"应用" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
                settings_run_nano_apply_action();
            }]];
            settings_present_controller(ac, self);
        } else if ([action isEqualToString:@"nano-probe"]) {
            settings_run_nano_probe_action();
        } else if ([action isEqualToString:@"nano-steer"]) {
            settings_run_nano_steer_action();
        } else if ([action isEqualToString:@"nano-seed"]) {
            UIAlertController *ac = [UIAlertController
                alertControllerWithTitle:@"写入兼容性索引？"
                                 message:@"将此手机的产品类型添加到本地 NanoRegistry 兼容性索引 MobileAsset，并在原版文件旁保存 .cyanide.bak 备份。"
                          preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
            [ac addAction:[UIAlertAction actionWithTitle:@"写入" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
                settings_run_nano_seed_action();
            }]];
            settings_present_controller(ac, self);
        } else if ([action isEqualToString:@"nano-clear"]) {
            UIAlertController *ac = [UIAlertController
                alertControllerWithTitle:@"移除配对覆盖？"
                                 message:@"移除已保存的手表配对覆盖，不会影响您手表的其它数据。之后需要注销或重启。"
                          preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
            [ac addAction:[UIAlertAction actionWithTitle:@"移除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *_) {
                settings_run_nano_clear_action();
            }]];
            settings_present_controller(ac, self);
        }
        return;
    }

    if (indexPath.section == SectionGravityLite) {
        NSDictionary *row = [self rowsForSection:indexPath.section][indexPath.row];
        if (![row[@"kind"] isEqualToString:@"button"]) return;
        [self runGravityLiteAction:row[@"action"]];
        return;
    }

    if (indexPath.section == SectionLocationSim) {
        NSDictionary *row = [self rowsForSection:indexPath.section][indexPath.row];
        if (![row[@"kind"] isEqualToString:@"button"]) return;
        NSString *action = row[@"action"];
        NSUserDefaults *d = NSUserDefaults.standardUserDefaults;

        if ([action isEqualToString:@"locsim-preset-rockaway"]) {
            settings_location_sim_set_rockaway_defaults(d);
            log_user("[LOCSIM] Loaded Rockaway test point: %s\n",
                     settings_location_sim_target_summary(d).UTF8String);
            [self reloadLocationSimUI];
            [self runLocationSimApply:YES];
            return;
        }

        if ([action isEqualToString:@"locsim-set-exact"]) {
            [self presentLocationSimExactCoordinatePrompt];
            return;
        }

        if ([action isEqualToString:@"locsim-major-cities"]) {
            [self presentLocationSimCityPicker];
            return;
        }

        if ([action isEqualToString:@"locsim-apply"] ||
            [action isEqualToString:@"locsim-stop"]) {
            BOOL apply = [action isEqualToString:@"locsim-apply"];
            [self runLocationSimApply:apply];
            return;
        }

        return;
    }

    if (indexPath.section == SectionIPADecryptor) {
        NSDictionary *row = [self rowsForSection:indexPath.section][indexPath.row];
        if (![row[@"kind"] isEqualToString:@"button"]) return;
        NSString *action = row[@"action"];
        if ([action isEqualToString:@"ipadec-choose"]) {
            [self presentIPADecryptorAppPicker];
        } else if ([action isEqualToString:@"ipadec-signin"]) {
            [self presentIPADecryptorSignInPrompt];
        } else if ([action isEqualToString:@"ipadec-clear-account"]) {
            ipadecryptor_clear_app_store_account();
            [self saveIPADecryptorDownloadStatus:@"App Store 令牌已清除。下载前请重新登录。"
                                   downloadedIPA:nil];
            [self reloadIPADecryptorUI];
        } else if ([action isEqualToString:@"ipadec-paste-link"]) {
            [self presentIPADecryptorAppStoreLinkPrompt];
        } else if ([action isEqualToString:@"ipadec-probe"] ||
                   [action isEqualToString:@"ipadec-start"] ||
                   [action isEqualToString:@"ipadec-download"]) {
            [self runIPADecryptorAction:action];
        }
        return;
    }

    if (indexPath.section == SectionTypeBanner) {
        NSDictionary *row = [self rowsForSection:indexPath.section][indexPath.row];
        if (![row[@"kind"] isEqualToString:@"button"]) return;
        NSString *action = row[@"action"];
        if ([action isEqualToString:@"typebanner-test"]) {
            static volatile int sTbTestInFlight = 0;
            if (__sync_lock_test_and_set(&sTbTestInFlight, 1)) {
                log_user("[TYPEBANNER] Test already running — wait for the previous one to finish before tapping again.\n");
                return;
            }
            __weak typeof(self) weakSelf = self;
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                BOOL actionLockAcquired = NO;
                @try {
                    actionLockAcquired = settings_try_claim_actions_lock("TypeBanner test",
                                                                         "[TYPEBANNER] Another action is already running.");
                    if (!actionLockAcquired) {
                        return;
                    }
                    if (!settings_ensure_kexploit()) {
                        log_user("[TYPEBANNER] Test failed: kernel primitives not acquired. Please try running chain again.\n");
                        return;
                    }

                    // Pause the live loop while the test runs so the one-shot
                    // diagnostics do not race the periodic banner updater.
                    BOOL liveLoopWasRunning = g_typebanner_live_running != 0;
                    if (liveLoopWasRunning) {
                        g_typebanner_live_stop_requested = 1;
                        int waitMs = 0;
                        while (g_typebanner_live_running && waitMs < 30000) {
                            usleep(100000);
                            waitMs += 100;
                        }
                        if (g_typebanner_live_running) {
                            log_user("[TYPEBANNER] Test aborted: live loop did not yield in 30s.\n");
                            return;
                        }
                    }

                    log_user("[TYPEBANNER] Test: polling imagent for typing indicators…\n");
                    NSString *detected = nil;
                    @synchronized (settings_rc_lock()) {
                        RemoteCallSession *daemonSession = [[RemoteCallSession alloc] initWithProcess:@"imagent"
                                                                                   useMigFilterBypass:NO
                                                                              firstExceptionTimeoutMS:TYPEBANNER_RC_MOBILESMS_FIRST_EXCEPTION_TIMEOUT_MS
                                                                                    originalThreadOnly:YES];
                        if (!daemonSession) {
                            RemoteCallInitFailure failure = remote_call_last_init_failure();
                            uint32_t pid = remote_call_last_init_failure_pid();
                            if (failure == RemoteCallInitFailureProcessMissing) {
                                log_user("[TYPEBANNER] imagent is not running.\n");
                            } else if (failure == RemoteCallInitFailureFirstExceptionTimeout && pid != 0) {
                                log_user("[TYPEBANNER] imagent pid=%u did not answer the original-thread bootstrap this tick.\n",
                                         pid);
                            } else if (pid != 0) {
                                log_user("[TYPEBANNER] imagent RemoteCall init failed: %s (pid=%u)\n",
                                         remote_call_init_failure_description(failure), pid);
                            } else {
                                log_user("[TYPEBANNER] imagent RemoteCall init failed: %s\n",
                                         remote_call_init_failure_description(failure));
                            }
                        } else {
                            @try {
                                detected = typebanner_poll_in_imagent_remote_session(daemonSession);
                            } @catch (NSException *e) {
                                log_user("[TYPEBANNER] imagent poll threw: %s\n", e.reason.UTF8String);
                            }
                            if (detected.length == 0) {
                                log_user("[TYPEBANNER] No daemon typing indicator detected on this poll.\n");
                            }
                            [daemonSession destroyRemoteCall];
                        }
                    }

                    if (detected.length > 0) {
                        log_user("[TYPEBANNER] Detected typing: %s. Showing banner.\n",
                                 detected.UTF8String);
                    } else {
                        log_user("[TYPEBANNER] Showing a one-shot demo banner so you can confirm the SpringBoard render path.\n");
                    }

                    @synchronized (settings_rc_lock()) {
                        RemoteCallSession *springboardSession = [[RemoteCallSession alloc] initWithProcess:@"SpringBoard"
                                                                                         useMigFilterBypass:NO
                                                                                    firstExceptionTimeoutMS:TYPEBANNER_RC_FIRST_EXCEPTION_TIMEOUT_MS];
                        if (!springboardSession) {
                            log_user("[TYPEBANNER] SpringBoard not reachable; cannot show banner.\n");
                        } else {
                            bool ok = false;
                            @try {
                                NSString *label = detected.length > 0 ? detected : @"TypeBanner 演示";
                                ok = typebanner_show_in_springboard_remote_session(springboardSession, label);
                            } @catch (NSException *e) {
                                log_user("[TYPEBANNER] SpringBoard show threw: %s\n", e.reason.UTF8String);
                            }
                            log_user("[TYPEBANNER] show=%d. Banner auto-hides in 5s.\n", ok);
                            sleep(5);
                            @try { typebanner_hide_in_springboard_remote_session(springboardSession); } @catch (NSException *e) {}
                            [springboardSession destroyRemoteCall];
                        }
                    }

                    if (liveLoopWasRunning) {
                        log_user("[TYPEBANNER] Resuming live loop.\n");
                        g_typebanner_live_stop_requested = 0;
                        settings_start_typebanner_live_loop();
                    }
                } @finally {
                    if (actionLockAcquired) settings_release_actions_lock();
                    __sync_lock_release(&sTbTestInFlight);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [weakSelf.tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
                                          withRowAnimation:UITableViewRowAnimationNone];
                    });
                }
            });
        }
        return;
    }

    if (indexPath.section == SectionNotificationIsland) {
        NSDictionary *row = [self rowsForSection:indexPath.section][indexPath.row];
        if (![row[@"kind"] isEqualToString:@"button"]) return;
        NSString *action = row[@"action"];
        if ([action isEqualToString:@"notificationisland-sample"]) {
            if (!settings_notificationisland_install_allowed()) {
                log_user("[NISLAND] Notification Island is unavailable in this build or experimental access is off.\n");
                return;
            }
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                BOOL actionLockAcquired = settings_try_claim_actions_lock("Notification Island sample",
                                                                         "[NISLAND] Another action is already running.");
                if (!actionLockAcquired) {
                    return;
                }
                @try {
                    if (!settings_ensure_kexploit()) {
                        log_user("[NISLAND] Sample failed: kernel primitives not acquired. Please try running chain again.\n");
                        return;
                    }
                    bool ok = false;
                    @synchronized (settings_rc_lock()) {
                        if (!settings_ensure_springboard_remote_call_locked()) {
                            log_user("[NISLAND] SpringBoard not reachable; cannot show sample.\n");
                            return;
                        }
                        notificationisland_apply_in_session();
                        ok = notificationisland_show_sample_in_session("Notification Island", "Sample banner route");
                    }
                    log_user("%s Notification Island sample %s.\n",
                             ok ? "[OK]" : "[WARN]",
                             ok ? "started" : "did not start");
                    if (ok) settings_start_notificationisland_live_loop();
                } @finally {
                    settings_release_actions_lock();
                }
            });
        }
        return;
    }

    if (indexPath.section == SectionFastLockXLite) {
        if (!settings_fastlockx_lite_install_allowed()) {
            log_user("[FLX] FastLockX Lite is unavailable in this build or experimental access is off.\n");
            return;
        }
        NSDictionary *row = [self rowsForSection:indexPath.section][indexPath.row];
        if (![row[@"kind"] isEqualToString:@"button"]) return;
        NSString *action = row[@"action"];
        BOOL probe = [action isEqualToString:@"fastlockx-probe"];
        BOOL enableAlways = [action isEqualToString:@"fastlockx-enable"];
        BOOL disableAlways = [action isEqualToString:@"fastlockx-disable"];
        BOOL window = [action isEqualToString:@"fastlockx-window"];
        BOOL pulse = [action isEqualToString:@"fastlockx-once"] || window;
        BOOL unlock = [action isEqualToString:@"fastlockx-once"] ||
                      [action isEqualToString:@"fastlockx-unlock"] ||
                      window;
        if (!probe && !enableAlways && !disableAlways && !pulse && !unlock) return;

        [self presentActivityLog];
        UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication]
            beginBackgroundTaskWithName:@"FastLockX Lite"
                      expirationHandler:^{
            log_user("[FLX] Background time expired; stopping FastLockX Lite action.\n");
        }];

        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            BOOL actionLockAcquired = settings_try_claim_actions_lock("FastLockX Lite",
                                                                     "[FLX] Another action is already running.");
            if (!actionLockAcquired) {
                if (bgTask != UIBackgroundTaskInvalid) {
                    [[UIApplication sharedApplication] endBackgroundTask:bgTask];
                }
                return;
            }

            @try {
                if (!settings_ensure_kexploit()) {
                    log_user("[FLX] Failed: kernel primitives not acquired. Run the chain, then try again.\n");
                    return;
                }

                NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
                @synchronized (settings_rc_lock()) {
                    if (!settings_ensure_springboard_remote_call_locked()) {
                        log_user("[FLX] SpringBoard not reachable; cannot send FastLockX Lite request.\n");
                        return;
                    }

                    if (probe) {
                        bool ok = fastlockx_lite_probe_in_session();
                        log_user("%s FastLockX Lite probe %s.\n",
                                 ok ? "[OK]" : "[WARN]",
                                 ok ? "found usable primitives" : "did not find enough primitives");
                        return;
                    }

                    if (disableAlways) {
                        bool ok = fastlockx_lite_disable_always_on_in_session();
                        if (ok) {
                            [d setBool:NO forKey:kSettingsFastLockXLiteEnabled];
                            [d synchronize];
                            settings_mark_tweak_applied(kSettingsFastLockXLiteEnabled, NO);
                            settings_notify_package_queue_changed_async();
                        }
                        log_user("%s FastLockX Lite Always On %s.\n",
                                 ok ? "[OK]" : "[WARN]",
                                 ok ? "disabled" : "could not be disabled; respring will stop it");
                    } else if (enableAlways) {
                        FastLockXLiteConfig config = settings_fastlockx_lite_config_from_defaults(d, YES, YES);
                        config.diagnosticLogging = NO;
                        bool ok = fastlockx_lite_enable_always_on_in_session(config);
                        [d setBool:ok forKey:kSettingsFastLockXLiteEnabled];
                        [d synchronize];
                        settings_mark_tweak_applied(kSettingsFastLockXLiteEnabled, ok);
                        settings_notify_package_queue_changed_async();
                        log_user("%s FastLockX Lite Always On %s.\n",
                                 ok ? "[OK]" : "[WARN]",
                                 ok ? "enabled" : "failed to enable");
                    } else if (window) {
                        NSTimeInterval deadline = [NSDate timeIntervalSinceReferenceDate] + 15.0;
                        int tick = 0;
                        log_user("[FLX] 15s auto-unlock window started. Lock the device now and let Face ID authenticate.\n");
                        while ([NSDate timeIntervalSinceReferenceDate] < deadline) {
                            if (settings_cleanup_in_progress()) {
                                log_user("[FLX] Stopping window: cleanup started.\n");
                                break;
                            }
                            FastLockXLiteConfig config = settings_fastlockx_lite_config_from_defaults(d, YES, YES);
                            config.diagnosticLogging = NO;
                            if (tick > 0) {
                                config.blockOnMusic = false;
                                config.blockOnFlashlight = false;
                                config.blockOnLowPowerMode = false;
                            }
                            bool ok = fastlockx_lite_run_in_session(config);
                            tick++;
                            printf("[FLX] window tick=%d ok=%d\n", tick, ok);
                            usleep(300000);
                        }
                        log_user("[FLX] 15s auto-unlock window stopped.\n");
                    } else {
                        FastLockXLiteConfig config = settings_fastlockx_lite_config_from_defaults(d, pulse, unlock);
                        bool ok = fastlockx_lite_run_in_session(config);
                        log_user("%s FastLockX Lite request %s.\n",
                                 ok ? "[OK]" : "[WARN]",
                                 ok ? "completed" : "did not complete");
                    }
                }
            } @finally {
                settings_release_actions_lock();
                if (bgTask != UIBackgroundTaskInvalid) {
                    [[UIApplication sharedApplication] endBackgroundTask:bgTask];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    [strongSelf reloadSectionOrAll:SectionFastLockXLite];
                    [[NSNotificationCenter defaultCenter]
                        postNotificationName:kSettingsActionsDidCompleteNotification
                                      object:nil];
                });
            }
        });
        return;
    }

    if (indexPath.section == SectionAppSwitcherGrid) {
        NSDictionary *row = [self rowsForSection:indexPath.section][indexPath.row];
        if (![row[@"kind"] isEqualToString:@"button"]) return;
        NSString *action = row[@"action"];
        if ([action isEqualToString:@"appswitchergrid-restore"]) {
            NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
            [d setBool:NO forKey:kSettingsAppSwitcherGridEnabled];
            [d synchronize];
            settings_mark_tweak_applied(kSettingsAppSwitcherGridEnabled, NO);
            settings_notify_package_queue_changed_async();
            if (!g_springboard_rc_ready) {
                appswitchergrid_forget_remote_state();
                log_user("[ASG] App Switcher Grid disabled. No active SpringBoard session was available; respring restores stock if needed.\n");
                [self reloadSectionOrAll:SectionAppSwitcherGrid];
                return;
            }
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                @synchronized (settings_rc_lock()) {
                    if (settings_cleanup_in_progress() || !g_springboard_rc_ready) return;
                    bool ok = appswitchergrid_stop_in_session();
                    log_user("%s App Switcher Grid restore %s.\n",
                             ok ? "[OK]" : "[WARN]",
                             ok ? "completed" : "did not find an active patch; respring restores stock");
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self reloadSectionOrAll:SectionAppSwitcherGrid];
                });
            });
        }
        return;
    }

    if (indexPath.section == SectionNSBar) {
        NSDictionary *row = [self rowsForSection:indexPath.section][indexPath.row];
        if ([row[@"action"] isEqualToString:@"nsbar-position"]) {
            [self presentNSBarPositionPicker];
        }
        return;
    }

    if (indexPath.section == SectionNiceBarLite) {
        NSDictionary *row = [self rowsForSection:indexPath.section][indexPath.row];
        NSString *action = row[@"action"];
        if ([action isEqualToString:@"nicebar-traffic-history"]) {
            CyanideNiceBarTrafficHistoryViewController *vc = [[CyanideNiceBarTrafficHistoryViewController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
            return;
        }
        if ([action isEqualToString:@"nicebar-apply"]) {
            if (!g_springboard_rc_ready) {
                log_user("[NICEBAR] Needs an active SpringBoard session. Hit Run first.\n");
                return;
            }
            NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
            [d setBool:YES forKey:kSettingsNiceBarLiteEnabled];
            [d synchronize];
            log_user("[NICEBAR] Manual apply requested.\n");
            [self refreshNiceBarWeatherForce:YES];
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                bool ok = false;
                @synchronized (settings_rc_lock()) {
                    if (settings_cleanup_in_progress() || !g_springboard_rc_ready) return;
                    ok = settings_apply_nicebarlite_from_defaults_locked(d);
                    settings_mark_tweak_applied(kSettingsNiceBarLiteEnabled, ok);
                }
                log_user("%s NiceBar Lite applied now.\n", ok ? "[OK]" : "[WARN]");
                if (ok) settings_start_nicebarlite_live_loop();
                settings_notify_package_queue_changed_async();
            });
            return;
        }
        if ([action hasPrefix:@"nicebar-slot-"]) {
            NSInteger slot = [[action substringFromIndex:[@"nicebar-slot-" length]] integerValue];
            if (slot >= 0 && slot < NiceBarLiteSlotCount) {
                [self presentNiceBarSlotEditor:slot];
            }
        }
        return;
    }

    if (indexPath.section == SectionSnowBoardLite) {
        NSDictionary *row = [self rowsForSection:indexPath.section][indexPath.row];
        if (![row[@"kind"] isEqualToString:@"button"]) return;
        NSString *action = row[@"action"];
        if ([action isEqualToString:@"sbl-select-ios6"]) {
            [self selectSnowBoardLiteIOS6Theme];
        } else if ([action isEqualToString:@"sbl-import-folder"]) {
            [self presentSnowBoardLiteFolderImporter];
        } else if ([action isEqualToString:@"sbl-import-archive"]) {
            [self presentSnowBoardLiteArchiveImporter];
        } else if ([action isEqualToString:@"sbl-clear"]) {
            [self clearSnowBoardLiteTheme];
        }
        return;
    }

    if (indexPath.section == SectionLiveWP) {
        NSDictionary *row = [self rowsForSection:indexPath.section][indexPath.row];
        if (![row[@"kind"] isEqualToString:@"button"]) return;
        NSString *action = row[@"action"];
        if ([action isEqualToString:@"livewp-select-video"]) {
            [self presentLiveWPVideoPicker];
        } else if ([action isEqualToString:@"livewp-clear"]) {
            [self clearLiveWPVideo];
        }
        return;
    }

    if (indexPath.section == SectionThemer) {
        NSDictionary *row = [self rowsForSection:indexPath.section][indexPath.row];
        if (![row[@"kind"] isEqualToString:@"button"]) return;
        NSString *action = row[@"action"];
        if ([action isEqualToString:@"themer-select-ios6"]) {
            [self selectBuiltInIOS6Theme];
        } else if ([action isEqualToString:@"themer-import"]) {
            [self presentThemerImporter];
        } else if ([action isEqualToString:@"themer-guide"]) {
            [self presentThemerFormatGuide];
        } else if ([action isEqualToString:@"themer-clear"]) {
            [self clearSelectedTheme];
        }
        return;
    }

    if (indexPath.section == SectionSBC) {
        NSDictionary *row = [self rowsForSection:indexPath.section][indexPath.row];
        if ([row[@"kind"] isEqualToString:@"button"]) {
            settings_reset_sbc_defaults();
            // In detail mode, SBC sits at table-view section 0.
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
                          withRowAnimation:UITableViewRowAnimationNone];
        }
    }
}

@end
