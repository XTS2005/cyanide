//
//  PackageCatalog.m
//  Cyanide
//

#import "PackageCatalog.h"
#import "../SettingsViewController.h"
#import "../PatreonAuth.h"
#import "../tweaks/private_compat.h"

@implementation PackageCatalog

// Mirrors of the private SettingsSection enum values in SettingsViewController.m
// (kept in sync — must match the underlying section indices used for the
// detail-mode SettingsViewController push).
static const NSInteger kSecSBC              = 4;
static const NSInteger kSecStatBar          = 5;
static const NSInteger kSecNSBar            = 6;
static const NSInteger kSecNiceBarLite      = 7;
static const NSInteger kSecRSSI             = 8;
static const NSInteger kSecTypeBanner       = 10;
static const NSInteger kSecNotificationIsland = 11;
static const NSInteger kSecPowercuff        = 12;
static const NSInteger kSecDragCoefficient  = 14;
static const NSInteger kSecLayoutExtras     = 15;
static const NSInteger kSecNanoRegistry     = 16;
static const NSInteger kSecSnowBoardLite    = 18;
static const NSInteger kSecLiveWP           = 19;
static const NSInteger kSecLocationSim      = 20;
static const NSInteger kSecGravityLite      = 21;
static const NSInteger kSecAppSwitcherGrid  = 22;
static const NSInteger kSecIPADecryptor     = 23;
static const NSInteger kSecFastLockXLite    = 24;

+ (NSArray<Package *> *)allPackages
{
    NSArray<Package *> *full = [self allPackagesIncludingExperimental];
    BOOL creator = cyanide_is_creator();
    BOOL experimentalAccess = cyanide_is_patron() || creator;
    BOOL experimentalOn = [[NSUserDefaults standardUserDefaults]
                            boolForKey:kSettingsExperimentalTweaksEnabled]
                            && experimentalAccess;

    NSMutableArray<Package *> *out = [NSMutableArray arrayWithCapacity:full.count];
    for (Package *p in full) {
        if (p.creatorOnly && !creator) continue;
        if (p.experimental && !experimentalOn) continue;
        [out addObject:p];
    }
    return out;
}

+ (NSArray<Package *> *)allPackagesIncludingExperimental
{
    static NSArray<Package *> *list;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *version = @"1.0";

        Package *statBar = [[Package alloc] initWithIdentifier:@"com.darksword.statbar"
                                           name:@"状态栏监测"
                               shortDescription:@"电池温度 + 可用内存"
                                longDescription:@"可以在状态栏旁边显示实时电池温度和可用内存等。刷新频率可调，方便您在实时更新和续航之间取舍。"
                                        version:version
                                         author:@"zeroxjf"
                                       category:@"状态栏"
                                     symbolName:@"thermometer.medium"
                                           kind:PackageInstallKindToggle
                                     enabledKey:kSettingsStatBarEnabled
                                          isNew:NO];
        statBar.settingsSection = kSecStatBar;

        Package *nsBar = [[Package alloc] initWithIdentifier:@"com.darksword.nsbar"
                                           name:@"状态栏网速"
                               shortDescription:@"实时网速"
                                longDescription:@"可以在状态栏旁边显示实时下载和上传速度。"
                                        version:version
                                         author:@"d1y"
                                       category:@"状态栏"
                                     symbolName:@"network"
                                           kind:PackageInstallKindToggle
                                     enabledKey:kSettingsNSBarEnabled
                                          isNew:YES];
        nsBar.settingsSection = kSecNSBar;

        Package *niceBarLite = [[Package alloc] initWithIdentifier:@"com.darksword.nicebarlite"
                                           name:@"状态栏定制"
                               shortDescription:@"状态栏标签（NiceBar 风格）"
                                longDescription:@"可以在状态栏周围添加可配置的文本标签。可显示自定义文本、日期/时间格式以及系统值，如电池、内存、网速、运行时间、IP 地址、磁盘空间、状态和流量计数器。"
                                        version:version
                                         author:@"d1y"
                                       category:@"状态栏"
                                     symbolName:@"textformat.size"
                                           kind:PackageInstallKindToggle
                                     enabledKey:kSettingsNiceBarLiteEnabled
                                          isNew:YES];
        niceBarLite.settingsSection = kSecNiceBarLite;

#if CYANIDE_PRIVATE_TWEAKS_AVAILABLE
        Package *signal = [[Package alloc] initWithIdentifier:@"com.darksword.rssidisplay"
                                           name:@"信号显示"
                               shortDescription:@"蜂窝网络显示 RSRP dBm，Wi-Fi 显示信号格数"
                                longDescription:@"将状态栏中的信号强度图标替换为实时数值：蜂窝网络显示 RSRP dBm，Wi-Fi 显示当前信号格数。大约每秒更新一次。"
                                        version:version
                                         author:@"zeroxjf"
                                       category:@"开发中"
                                     symbolName:@"antenna.radiowaves.left.and.right"
                                           kind:PackageInstallKindToggle
                                     enabledKey:kSettingsRSSIDisplayEnabled
                                          isNew:NO];
        signal.settingsSection = kSecRSSI;
        signal.experimental = YES;
        signal.creatorOnly = YES;
        signal.unstableWarning = @"⚠️ 开发中 — 可能完全无法正常工作。实时状态栏刷新会干扰其它主屏幕插件，并可能导致读数完全丢失。";
#endif

        Package *sbc = [[Package alloc] initWithIdentifier:@"com.darksword.sbcustomizer"
                                           name:@"主屏幕布局定制"
                               shortDescription:@"自定义Dock栏图标数和主屏幕网格"
                                longDescription:@"自定义Dock栏图标数量以及主屏幕图标的网格（列数和行数）。可选择隐藏图标标签。"
                                        version:version
                                         author:@"zeroxjf"
                                       category:@"主屏幕布局"
                                     symbolName:@"square.grid.3x3.fill"
                                           kind:PackageInstallKindToggle
                                     enabledKey:kSettingsSBCEnabled
                                          isNew:NO];
        sbc.settingsSection = kSecSBC;

        Package *powercuff = [[Package alloc] initWithIdentifier:@"com.darksword.powercuff"
                                           name:@"降频省电"
                               shortDescription:@"通过降低 CPU/GPU 频率来达到省电效果"
                                longDescription:@"通过模拟热压力驱动温控守护进程（thermalmonitord）来降低 CPU 和 GPU 频率。适用于对散热敏感的工作负载或在负载下延长运行时间。效果持续到重启。"
                                        version:version
                                         author:@"rpetrich"
                                       category:@"性能"
                                     symbolName:@"bolt.slash.fill"
                                           kind:PackageInstallKindToggle
                                     enabledKey:kSettingsPowercuffEnabled
                                          isNew:NO];
        powercuff.settingsSection = kSecPowercuff;

        Package *axon = [[Package alloc] initWithIdentifier:@"com.darksword.axonlite"
                                           name:@"通知收纳"
                               shortDescription:@"按 App 分组通知中心"
                                longDescription:@"按应用把你通知中心里的消息分组显示，同时自动过滤掉重复的内容。"
                                        version:version
                                         author:@"zeroxjf"
                                       category:@"测试"
                                     symbolName:@"bell.badge.fill"
                                           kind:PackageInstallKindToggle
                                     enabledKey:kSettingsAxonLiteEnabled
                                          isNew:YES];
        axon.unstableWarning = @"⚠️ 实验性功能：开发中。可能会出现主屏幕崩溃、通知丢失、布局错乱，以及不同 Cyanide 版本间的不兼容。重要用途请勿依赖此功能。";

#if CYANIDE_PRIVATE_TWEAKS_AVAILABLE
        Package *typeBanner = [[Package alloc] initWithIdentifier:@"com.darksword.typebanner"
                                           name:@"TypeBanner"
                               shortDescription:@"灵动岛下方的 iMessage 输入提示横幅"
                                longDescription:@"TypeMillennium 的移植版。将 iMessage 的“对方正在输入…”状态，从“信息”App 里搬出来，直接在灵动岛下方弹窗提醒，不用一直盯着聊天界面。"
                                        version:version
                                         author:@"zeroxjf"
                                       category:@"开发中"
                                     symbolName:@"ellipsis.bubble.fill"
                                           kind:PackageInstallKindToggle
                                     enabledKey:kSettingsTypeBannerEnabled
                                          isNew:YES];
        typeBanner.experimental = YES;
        typeBanner.settingsSection = kSecTypeBanner;
        typeBanner.creatorOnly = YES;
        typeBanner.unstableWarning = @"⚠️ 开发中 — 极不稳定。可能会错过输入提示或导致主屏幕（SpringBoard）不稳定。";

        Package *notificationIsland = [[Package alloc] initWithIdentifier:@"com.darksword.notificationisland"
                                           name:@"通知岛"
                               shortDescription:@"灵动岛通知"
                                longDescription:@"将系统通知横幅的内容实时抓取并显示到灵动岛上。"
                                        version:version
                                         author:@"zeroxjf"
                                       category:@"开发中"
                                     symbolName:@"bell.and.waves.left.and.right.fill"
                                           kind:PackageInstallKindToggle
                                     enabledKey:kSettingsNotificationIslandEnabled
                                          isNew:YES];
        notificationIsland.settingsSection = kSecNotificationIsland;
        notificationIsland.experimental = YES;
        notificationIsland.creatorOnly = YES;
        notificationIsland.unstableWarning = @"⚠️ 开发中 — 可能会出现漏消息、重复显示或导致主屏幕（SpringBoard）不稳定的情况。";

        Package *ipaDecryptor = [[Package alloc] initWithIdentifier:@"com.darksword.ipadecryptor"
                                           name:@"IPA 解密"
                               shortDescription:@"解密已安装的 App Store 应用安装包"
                                longDescription:@"开发中的本地 IPA 解密器。选择一个已安装的 App 或粘贴 App Store 链接，解析为包名 ID，登录获取 App Store 下载令牌，将加密 IPA 下载到 Documents 目录，探测 FairPlay 加密元数据，然后运行解密流程。\n\n当前版本已完成：App 发现、App Store 链接解析、登录、加密 IPA 下载及加密探测。SINF/iTunesMetadata 补丁、解密页面转储及 Payload IPA 重建正在同一设置工具中逐步添加。"
                                        version:version
                                         author:@"londek / zeroxjf"
                                       category:@"开发中"
                                     symbolName:@"lock.open.fill"
                                           kind:PackageInstallKindDirectTool
                                     enabledKey:nil
                                          isNew:YES];
        ipaDecryptor.settingsSection = kSecIPADecryptor;
        ipaDecryptor.experimental = YES;
        ipaDecryptor.creatorOnly = YES;
        ipaDecryptor.unstableWarning = @"⚠️ 开发中 — 加密 IPA 下载功能为实验性。SINF/iTunesMetadata 修补、任务端口转储和 IPA 写入器阶段尚未完成。";

        Package *stageStrip = [[Package alloc] initWithIdentifier:@"com.darksword.stagestrip"
                                           name:@"Dynamic Stage Lite"
                               shortDescription:@"悬浮应用窗口（iPad 风格）"
                                longDescription:
            @"在主屏幕上以悬浮、可调整大小的窗口同时运行 App。\n\n"
            @"Dynamic Stage Lite 是 Dynamic Stage 插件的独立重新实现版本，此版本未使用原版插件的任何代码或资源。\n\n"
            @"使用方法:\n"
            @"• 点击屏幕右下角的圆点，即可打开选择器。\n"
            @"• 点击两个 App，即可将它们并排启动。\n"
            @"• 拖移顶部栏可移动窗口；拖移任意角落可调整大小。\n"
            @"• 点击窗口左上角的 X 可关闭该窗口。\n"
            @"• 选择器托盘中的齿轮图标可跳转回 Cyanide 设置。\n\n"
            @"首次运行预计需要 1-2 分钟。后续运行会复用缓存，速度很快。\n\n"
            @"尚待完善之处:\n"
            @"• 悬浮窗口暂不支持触控交互——窗口目前仅用于查看和切换，无法滚动或输入文字。\n"
            @"• 全屏启动 App 时不会自动关闭悬浮窗，如需关闭请手动点击窗口左上角的 X。\n"
            @"• App 资源库仍在加载时，手势操作可能会出现卡顿。"
                                        version:version
                                         author:@"zeroxjf"
                                       category:@"实验性"
                                     symbolName:@"sidebar.left"
                                           kind:PackageInstallKindToggle
                                     enabledKey:kSettingsStageStripEnabled
                                          isNew:YES];
        stageStrip.experimental = YES;
        stageStrip.unstableWarning = @"⚠️ 早期开发阶段。首次运行需要 1-2 分钟，因为选择器会遍历每个已安装的应用并为每个应用构建一个磁贴。重新运行时会很快。尚未接入对托管窗口的触摸路由，因此浮动窗口内的滚动/输入可能无法正常工作。";
#endif

        Package *locationSim = [[Package alloc] initWithIdentifier:@"com.darksword.locationsim"
                                           name:@"位置模拟器"
                               shortDescription:@"位置模拟"
                                longDescription:@"定位模拟器可以伪装设备的 GPS 位置。需要先安装并设置好 Apple 地图作为宿主进程。选择一个目标位置即可开始模拟，点击“恢复真实位置”即可停止。仅支持固定点位模拟。部分 App 可能会无视模拟位置，也可能影响时区、天气等系统功能。请自行承担使用风险。"
                                        version:version
                                         author:@"zeroxjf, kolbicz, ezzuldinSt"
                                       category:@"测试"
                                     symbolName:@"location.fill"
                                           kind:PackageInstallKindDirectTool
                                     enabledKey:nil
                                          isNew:YES];
        locationSim.settingsSection = kSecLocationSim;
        locationSim.experimental = NO;
        locationSim.unstableWarning = @"测试：需要已安装并设置好 Apple 地图。可能影响时区、日期/时间以及其它与位置相关的行为。某些应用和服务禁止或检测模拟位置。只有在您清楚自己在做什么的情况下才使用此功能。";

        Package *snowboardLite = [[Package alloc] initWithIdentifier:@"com.darksword.snowboardlite"
                                           name:@"图标主题"
                               shortDescription:@"自定义主屏幕应用图标"
                                longDescription:@"自定义主屏幕应用图标，支持内置的 iOS 6 主题和本地文件夹以及压缩包导入。"
                                        version:version
                                         author:@"d1y"
                                       category:@"测试"
                                     symbolName:@"square.stack.3d.up.fill"
                                          kind:PackageInstallKindToggle
                                     enabledKey:kSettingsSnowBoardLiteEnabled
                                          isNew:YES];
        snowboardLite.settingsSection = kSecSnowBoardLite;
        snowboardLite.unstableWarning = @"预览：在应用前请先导入或选择一个图标主题。";

        Package *liveWP = [[Package alloc] initWithIdentifier:@"com.darksword.livewp"
                                           name:@"动态壁纸"
                               shortDescription:@"锁屏和主屏幕动态壁纸"
                                longDescription:@"可选择 MP4、MOV 或 M4V 格式的视频，设为锁屏及主屏幕的动态壁纸。"
                                        version:version
                                         author:@"d1y"
                                       category:@"测试"
                                     symbolName:@"play.rectangle.fill"
                                           kind:PackageInstallKindToggle
                                     enabledKey:kSettingsLiveWPEnabled
                                          isNew:YES];
        liveWP.settingsSection = kSecLiveWP;

        Package *layoutExtras = [[Package alloc] initWithIdentifier:@"com.darksword.layoutextras"
                                           name:@"主屏幕布局扩展"
                               shortDescription:@"主屏幕与Dock栏额外边距和图标缩放"
                                longDescription:@"在主屏幕网格或 Dock 栏周围添加额外间距，并可缩放图标大小。注销后不会保留。"
                                        version:version
                                         author:@"kolbicz"
                                      category:@"主屏幕布局"
                                     symbolName:@"square.dashed.inset.filled"
                                           kind:PackageInstallKindToggle
                                     enabledKey:kSettingsLayoutExtrasEnabled
                                          isNew:YES];
        layoutExtras.settingsSection = kSecLayoutExtras;
        NSInteger iosMajor = [[NSProcessInfo processInfo] operatingSystemVersion].majorVersion;
        if (iosMajor >= 26) {
            layoutExtras.knownIssues = @[
                @"iOS 26：布局可能在旋转屏幕或翻页后重置。请重新运行以重新应用。",
            ];
        }

        Package *gravityLite = [[Package alloc] initWithIdentifier:@"com.darksword.gravitylite"
                                           name:@"重力效果"
                               shortDescription:@"主屏幕图标物理重力效果"
                                longDescription:@"为主屏幕图标引入基于重力的动态物理行为：图标不再固定在网格上，而是像真实物体一样受重力影响，可随设备倾斜自然滑落、相互碰撞并产生弹跳效果。"
                                        version:version
                                         author:@"Julio Verne / zeroxjf"
                                       category:@"测试"
                                     symbolName:@"arrow.down.circle.fill"
                                           kind:PackageInstallKindToggle
                                     enabledKey:kSettingsGravityLiteEnabled
                                          isNew:YES];
        gravityLite.settingsSection = kSecGravityLite;
        gravityLite.unstableWarning = @"测试：可能会因主屏幕重新布局而重置，例如翻页、旋转屏幕、文件夹切换或注销。如果图标仍偏移未复原，请使用“恢复图标布局”。";
        gravityLite.knownIssues = @[
            @"要禁用此功能，请使用 App 切换器返回 Cyanide 并停用「重力效果」。目前没有其它方法可以停止它。",
            @"尚不支持触摸已偏移的图标。在此环境中转发触摸是一个重要的开发中功能。",
            @"安装过程非常缓慢。Cyanide 必须在物理效果开始前捕获每个可见的图标和小部件。",
            @"翻页、打开文件夹或主屏幕重新布局可能会导致效果停止。请重新运行「重力效果」。",
        ];

        Package *appSwitcherGrid = [[Package alloc] initWithIdentifier:@"com.darksword.appswitchergrid"
                                           name:@"App 切换器样式"
                               shortDescription:@"App 切换器排布样式"
                                longDescription:@"给 App 切换器添加网格排布样式。\n这不会写入系统文件。注销即恢复原版 App 切换器。如果你在隐藏主屏幕横条后注销，请重新运行。"
                                        version:version
                                         author:@"rooootdev"
                                       category:@"测试"
                                     symbolName:@"square.grid.2x2.fill"
                                           kind:PackageInstallKindToggle
                                     enabledKey:kSettingsAppSwitcherGridEnabled
                                          isNew:YES];
        appSwitcherGrid.settingsSection = kSecAppSwitcherGrid;
        appSwitcherGrid.unstableWarning = @"测试：注销即恢复原版，但不受支持的版本可能会导致 App 切换器显示异常或主屏幕崩溃。每次注销后请重新运行。";

#if CYANIDE_PRIVATE_TWEAKS_AVAILABLE
        Package *fastLockXLite = [[Package alloc] initWithIdentifier:@"com.darksword.fastlockx-lite"
                                           name:@"FastLockX Lite"
                               shortDescription:@"Face ID 重试 + 解锁控制"
                                longDescription:@"RemoteCall-only port of the usable FastLockX primitives recovered from the iOS 15 tweak by Artem Kasper.\n\nCredits: original FastLockX by Artem Kasper; Cyanide FastLockX Lite port by zeroxjf.\n\nIt can pulse SpringBoard's biometric retry path, ask the iOS 26 biometric coordinator to start a Mesa/Face ID unlock, and send the original Lock Screen unlock request as a fallback. The Always On button keeps those retry/unlock requests armed with SpringBoard timers so pickup-to-unlock can work after Cyanide's 15-second test window ends.\n\nUse Disable, Clean Up, or a respring to stop the timers."
                                        version:version
                                         author:@"Artem Kasper / zeroxjf"
                                       category:@"实验性"
                                     symbolName:@"lock.open.fill"
                                           kind:PackageInstallKindDirectTool
                                     enabledKey:nil
                                          isNew:YES];
        fastLockXLite.settingsSection = kSecFastLockXLite;
        fastLockXLite.experimental = YES;
        fastLockXLite.unstableWarning = @"实验性：发送私有主屏幕锁屏及生物识别资源消息。“常量模式”会运行重复的主屏幕定时器，如果 Face ID 感觉异常或不稳定，请将其关闭或注销。";
#endif

        Package *nanoRegistry = [[Package alloc] initWithIdentifier:@"com.darksword.nanoregistry"
                                           name:@"手表配对"
                               shortDescription:@"配对较新的手表或恢复旧款手表配对"
                                longDescription:@"修改保存在这台 iPhone 上的 watchOS 配对范围值，以支持更多的手表。\nApple Watch Ultra 3 目前无法在低于 26 的 iOS 版本上配对。\n应用后先注销或重启，再尝试配对。"
                                        version:version
                                         author:@"zeroxjf"
                                       category:@"测试"
                                     symbolName:@"applewatch.radiowaves.left.and.right"
                                           kind:PackageInstallKindNanoRegistry
                                     enabledKey:nil
                                          isNew:YES];
        nanoRegistry.settingsSection = kSecNanoRegistry;
        nanoRegistry.unstableWarning = @"警告：修改本地的 NanoRegistry MobileAsset。Cyanide 会在原文件旁保存一份 .cyanide.bak 备份，但系统文件修改可能会失败，或需要注销/重启才能生效。应用或移除此覆盖设置的风险由你自行承担。";

        Package *callRecordingSound = [[Package alloc] initWithIdentifier:@"com.darksword.callrecording-sound"
                                           name:@"通话录音"
                               shortDescription:@"禁用通话录音提示音"
                                longDescription:@"将 iOS 通话录音时强制播放的提示音替换为空音频，使录音开始与结束不再发出任何声音。\n启用此功能会自动备份原生音频，可随时恢复。\n请注意：通话录音提示音在某些地区可能属于法律合规要求，请仅在获得许可并了解适用法规的前提下使用。"
                                        version:version
                                         author:@"YangJiiii (@duongduong0908) / zeroxjf"
                                       category:@"测试"
                                     symbolName:@"speaker.slash.fill"
                                           kind:PackageInstallKindCallRecordingSound
                                     enabledKey:nil
                                          isNew:YES];
        callRecordingSound.experimental = NO;
        callRecordingSound.unstableWarning = @"测试：你所在地区可能法律要求保留提示音；你对自己的使用行为负责，应用此功能的风险由你自行承担。如果你希望 Cyanide 的备份被写回，请在移除 Cyanide 之前使用“恢复默认声音”。";

        Package *hideHomeBar = [[Package alloc] initWithIdentifier:@"com.darksword.hide-home-bar"
                                           name:@"主屏幕横条"
                               shortDescription:@"隐藏主屏幕底部横条"
                                longDescription:@"隐藏主屏幕底部横条，释放全屏显示空间，减少日常使用中的视觉干扰。"
                                        version:version
                                         author:@"C4ndyF1sh / jailbreakdotparty / zeroxjf"
                                       category:@"测试"
                                     symbolName:@"line.3.horizontal"
                                           kind:PackageInstallKindHideHomeBar
                                     enabledKey:nil
                                          isNew:YES];
        hideHomeBar.unstableWarning = @"测试：请单独运行，隐藏后注销。要恢复主屏幕横条，请选择“恢复主屏幕横条”并注销。";

        Package *otaBlock = [[Package alloc] initWithIdentifier:@"com.darksword.ota-block"
                                           name:@"OTA 更新"
                               shortDescription:@"启用或禁用系统 OTA 更新"
                                longDescription:@"通过编辑 disabled.plist 来禁用或启用负责系统 OTA 更新的 launchd 任务。状态在重启后仍保留。\n\n系统文件警告：这会修改 /private/var/db/com.apple.xpc.launchd/disabled.plist。不完整或部分写入可能会影响跨启动的 launchd 任务状态。禁用或重新启用 OTA 更新请自行承担风险。\n\n此包无需“运行”操作。使用“禁用”来阻止 OTA 更新，或使用“启用”来恢复更新。"
                                        version:version
                                         author:@"kolbicz"
                                       category:@"系统更新"
                                     symbolName:@"icloud.slash.fill"
                                          kind:PackageInstallKindOTA
                                    enabledKey:nil
                                         isNew:NO];
        otaBlock.unstableWarning = @"警告：持久的系统文件编辑。此包修改 launchd disabled.plist 以更改跨启动的 OTA 任务状态。禁用或重新启用 OTA 更新请自行承担风险。";

        Package *disableAppLibrary = [[Package alloc] initWithIdentifier:@"com.darksword.disable-app-library"
                                           name:@"App 资源库"
                               shortDescription:@"移除 App 资源库页面"
                                longDescription:@"移除位于最后一个主屏幕页面右侧的 App 资源库页面。滑过最后一页将无操作。"
                                        version:version
                                         author:@"kolbicz"
                                       category:@"主屏幕插件"
                                     symbolName:@"square.grid.2x2.fill"
                                           kind:PackageInstallKindToggle
                                     enabledKey:kSettingsDSDisableAppLibrary
                                          isNew:NO];

        list = @[
            statBar,
            nsBar,
            niceBarLite,
            sbc,
            layoutExtras,
            gravityLite,
            powercuff,

            disableAppLibrary,

            [[Package alloc] initWithIdentifier:@"com.darksword.disable-icon-flyin"
                                           name:@"图标弹入动画"
                               shortDescription:@"禁用图标弹簧动画"
                                longDescription:@"禁用解锁或切换应用后主屏幕图标出现时的弹簧动画。图标直接出现在最终位置。"
                                        version:version
                                         author:@"kolbicz"
                                       category:@"主屏幕插件"
                                     symbolName:@"sparkles"
                                           kind:PackageInstallKindToggle
                                     enabledKey:kSettingsDSDisableIconFlyIn
                                          isNew:NO],

            [[Package alloc] initWithIdentifier:@"com.darksword.zero-wake-animation"
                                           name:@"亮屏动画"
                               shortDescription:@"禁用亮屏动画"
                                longDescription:@"移除唤醒显示屏时的淡入动画。屏幕立即以全亮度亮起。"
                                        version:version
                                         author:@"kolbicz"
                                       category:@"主屏幕插件"
                                     symbolName:@"moon.zzz.fill"
                                           kind:PackageInstallKindToggle
                                     enabledKey:kSettingsDSZeroWakeAnimation
                                          isNew:NO],

            [[Package alloc] initWithIdentifier:@"com.darksword.zero-backlight-fade"
                                           name:@"熄屏动画"
                               shortDescription:@"禁用熄屏动画"
                                longDescription:@"将背光淡入淡出持续时间减少到零，锁定和解锁时显示屏立即开关。"
                                        version:version
                                         author:@"kolbicz"
                                       category:@"主屏幕插件"
                                     symbolName:@"sun.max.fill"
                                           kind:PackageInstallKindToggle
                                     enabledKey:kSettingsDSZeroBacklightFade
                                          isNew:NO],

            [[Package alloc] initWithIdentifier:@"com.darksword.double-tap-to-lock"
                                           name:@"双击锁定"
                               shortDescription:@"双击壁纸空白区域锁定设备"
                                longDescription:@"双击壁纸空白区域锁定设备。无需再伸手去按侧边按钮。"
                                        version:version
                                         author:@"kolbicz"
                                       category:@"主屏幕插件"
                                     symbolName:@"hand.tap.fill"
                                           kind:PackageInstallKindToggle
                                     enabledKey:kSettingsDSDoubleTapToLock
                                          isNew:NO],

            ({
                Package *drag = [[Package alloc] initWithIdentifier:@"com.darksword.drag-coefficient"
                                                               name:@"动画倍率"
                                                   shortDescription:@"自定义主屏幕动画速度倍率"
                                                    longDescription:@"自定义主屏幕动画速度倍率。数值越大动画越慢，数值越小动画越快。"
                                                            version:version
                                                             author:@"kolbicz"
                                                           category:@"主屏幕插件"
                                                         symbolName:@"dial.medium.fill"
                                                               kind:PackageInstallKindToggle
                                                         enabledKey:kSettingsDSDragCoefficientEnabled
                                                              isNew:YES];
                drag.settingsSection = kSecDragCoefficient;
                drag;
            }),

            otaBlock,

            // Beta last so the warning sits at the bottom of the Installer.
#if CYANIDE_PRIVATE_TWEAKS_AVAILABLE
            signal,
#endif
            axon,
            nanoRegistry,
            callRecordingSound,
            hideHomeBar,
#if CYANIDE_PRIVATE_TWEAKS_AVAILABLE
            typeBanner,
            notificationIsland,
            ipaDecryptor,
            stageStrip,
            fastLockXLite,
#endif
            locationSim,
            snowboardLite,
            liveWP,
            appSwitcherGrid,
        ];
    });
    return list;
}

+ (NSArray<NSString *> *)categoriesInOrder
{
    NSArray<NSString *> *preferred = @[
        @"开发中",
        @"实验性",
        @"测试",
        @"状态栏",
        @"主屏幕布局",
        @"其它插件",
        @"性能",
        @"系统更新",
        @"系统",
        @"主屏幕插件",
    ];
    NSMutableArray<NSString *> *all = [NSMutableArray array];
    for (Package *p in [self allPackages]) {
        if (![all containsObject:p.category]) [all addObject:p.category];
    }
    NSMutableArray<NSString *> *order = [NSMutableArray array];
    for (NSString *cat in preferred) {
        if ([all containsObject:cat]) [order addObject:cat];
    }
    for (NSString *cat in all) {
        if (![order containsObject:cat]) [order addObject:cat];
    }
    return order;
}

+ (NSDictionary<NSString *, NSArray<Package *> *> *)packagesByCategory
{
    NSMutableDictionary<NSString *, NSMutableArray<Package *> *> *buckets = [NSMutableDictionary dictionary];
    for (Package *p in [self allPackages]) {
        NSMutableArray<Package *> *bucket = buckets[p.category];
        if (!bucket) {
            bucket = [NSMutableArray array];
            buckets[p.category] = bucket;
        }
        [bucket addObject:p];
    }
    return buckets;
}

@end
