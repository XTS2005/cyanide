//
//  QueueReviewViewController.m
//  Cyanide
//

#import "QueueReviewViewController.h"
#import "PackageQueue.h"
#import "PackageCatalog.h"
#import "InstallProgressViewController.h"
#import "../LogTextView.h"

typedef NS_ENUM(NSInteger, QueueReviewSection) {
    QueueReviewSectionInstall = 0,
    QueueReviewSectionUninstall,
    QueueReviewSectionReApply,
    QueueReviewSectionCount,
};

@interface QueueReviewViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIButton *confirmButton;
@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, strong) UILabel *emptyLabel;
@end

@implementation QueueReviewViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"待处理";
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];

    UIView *footer = [self buildFooter];
    footer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:footer];

    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyLabel.text = @"暂无待处理更改\n请在“安装器”标签页中加入待处理";
    self.emptyLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    self.emptyLabel.textColor = UIColor.tertiaryLabelColor;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.numberOfLines = 0;
    [self.view addSubview:self.emptyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor      constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor   constraintEqualToAnchor:footer.topAnchor],

        [footer.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [footer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [footer.bottomAnchor   constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],

        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.emptyLabel.leadingAnchor  constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:24.0],
        [self.emptyLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-24.0],
    ]];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(queueChanged:)
                                                 name:PackageQueueDidChangeNotification
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self refreshUI];
}

- (UIView *)buildFooter
{
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = UIColor.systemGroupedBackgroundColor;

    UIButtonConfiguration *confirmCfg = [UIButtonConfiguration filledButtonConfiguration];
    confirmCfg.title = @"确认";
    confirmCfg.cornerStyle = UIButtonConfigurationCornerStyleLarge;
    confirmCfg.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey,id> *(NSDictionary<NSAttributedStringKey,id> *incoming) {
        NSMutableDictionary *attrs = [incoming mutableCopy];
        attrs[NSFontAttributeName] = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
        return attrs;
    };
    self.confirmButton = [UIButton buttonWithConfiguration:confirmCfg primaryAction:[UIAction actionWithHandler:^(UIAction *_) {
        [self didTapConfirm];
    }]];
    self.confirmButton.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.confirmButton];

    UIButtonConfiguration *clearCfg = [UIButtonConfiguration plainButtonConfiguration];
    clearCfg.title = @"清空待处理";
    clearCfg.baseForegroundColor = UIColor.systemRedColor;
    clearCfg.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey,id> *(NSDictionary<NSAttributedStringKey,id> *incoming) {
        NSMutableDictionary *attrs = [incoming mutableCopy];
        attrs[NSFontAttributeName] = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
        return attrs;
    };
    self.clearButton = [UIButton buttonWithConfiguration:clearCfg primaryAction:[UIAction actionWithHandler:^(UIAction *_) {
        [self didTapClear];
    }]];
    self.clearButton.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.clearButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.confirmButton.topAnchor      constraintEqualToAnchor:container.topAnchor constant:8.0],
        [self.confirmButton.leadingAnchor  constraintEqualToAnchor:container.leadingAnchor constant:16.0],
        [self.confirmButton.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-16.0],
        [self.confirmButton.heightAnchor   constraintEqualToConstant:50.0],

        [self.clearButton.topAnchor        constraintEqualToAnchor:self.confirmButton.bottomAnchor constant:2.0],
        [self.clearButton.centerXAnchor    constraintEqualToAnchor:container.centerXAnchor],
        [self.clearButton.bottomAnchor     constraintEqualToAnchor:container.bottomAnchor constant:-8.0],
    ]];
    return container;
}

- (void)refreshUI
{
    [self.tableView reloadData];
    [self updateHomeBarWarningHeader];
    NSInteger count = [PackageQueue sharedQueue].pendingCount;
    self.emptyLabel.hidden = (count > 0);
    self.tableView.hidden = (count == 0);
    self.confirmButton.enabled = (count > 0);
    self.clearButton.enabled = (count > 0);

    NSString *confirmTitle;
    if (count == 1) {
        confirmTitle = @"确认 1 项更改";
    } else if (count > 1) {
        confirmTitle = [NSString stringWithFormat:@"确认 %ld 项更改", (long)count];
    } else {
        confirmTitle = @"确认";
    }
    UIButtonConfiguration *cfg = self.confirmButton.configuration;
    cfg.title = confirmTitle;
    self.confirmButton.configuration = cfg;
}

- (UIView *)homeBarWarningHeaderView
{
    CGFloat width = self.tableView.bounds.size.width;
    if (width <= 0.0) width = self.view.bounds.size.width;
    if (width <= 0.0) width = UIScreen.mainScreen.bounds.size.width;

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, width, 1.0)];
    container.backgroundColor = UIColor.systemGroupedBackgroundColor;

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor.systemOrangeColor colorWithAlphaComponent:0.14];
    card.layer.cornerRadius = 16.0;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [UIColor.systemOrangeColor colorWithAlphaComponent:0.28].CGColor;
    [container addSubview:card];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"exclamationmark.triangle.fill"]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = UIColor.systemOrangeColor;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [card addSubview:icon];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"隐藏主屏幕横条必须单独运行";
    title.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightBold];
    title.textColor = UIColor.labelColor;
    [card addSubview:title];

    UILabel *body = [[UILabel alloc] init];
    body.translatesAutoresizingMaskIntoConstraints = NO;
    body.text = @"它会修改系统主屏幕指示器资源，因此需要注销。请仅确认隐藏主屏幕横条，注销后，再加入其它插件。";
    body.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightRegular];
    body.textColor = UIColor.secondaryLabelColor;
    body.numberOfLines = 0;
    [card addSubview:body];

    [NSLayoutConstraint activateConstraints:@[
        [card.topAnchor constraintEqualToAnchor:container.topAnchor constant:12.0],
        [card.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:16.0],
        [card.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-16.0],
        [card.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-8.0],

        [icon.topAnchor constraintEqualToAnchor:card.topAnchor constant:14.0],
        [icon.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14.0],
        [icon.widthAnchor constraintEqualToConstant:24.0],
        [icon.heightAnchor constraintEqualToConstant:24.0],

        [title.topAnchor constraintEqualToAnchor:card.topAnchor constant:12.0],
        [title.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:10.0],
        [title.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14.0],

        [body.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:4.0],
        [body.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [body.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [body.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12.0],
    ]];

    CGSize size = [container systemLayoutSizeFittingSize:CGSizeMake(width, 0.0)
                           withHorizontalFittingPriority:UILayoutPriorityRequired
                                 verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    container.frame = CGRectMake(0.0, 0.0, width, ceil(size.height));
    return container;
}

- (void)updateHomeBarWarningHeader
{
    if (![self queueIncludesHideHomeBar]) {
        self.tableView.tableHeaderView = nil;
        return;
    }
    self.tableView.tableHeaderView = [self homeBarWarningHeaderView];
}

- (void)queueChanged:(NSNotification *)note
{
    [self refreshUI];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return QueueReviewSectionCount;
}

- (NSArray<Package *> *)reApplyPackages
{
    if ([self queueIncludesHideHomeBar]) return @[];

    PackageQueue *q = [PackageQueue sharedQueue];
    NSMutableArray<Package *> *out = [NSMutableArray array];
    for (Package *p in [PackageCatalog allPackages]) {
        if (!p.isInstalled) continue;
        if ([q intentForPackage:p] == PackageQueueIntentUninstall) continue;
        [out addObject:p];
    }
    return out;
}

- (NSArray<Package *> *)packagesForSection:(NSInteger)section
{
    PackageQueue *q = [PackageQueue sharedQueue];
    switch ((QueueReviewSection)section) {
        case QueueReviewSectionInstall:   return q.queuedInstalls;
        case QueueReviewSectionUninstall: return q.queuedUninstalls;
        case QueueReviewSectionReApply:   return [self reApplyPackages];
        case QueueReviewSectionCount:     return @[];
    }
    return @[];
}

- (BOOL)queueIncludesHideHomeBar
{
    for (Package *pkg in [PackageQueue sharedQueue].queuedInstalls) {
        if (pkg.kind == PackageInstallKindHideHomeBar) return YES;
    }
    for (Package *pkg in [PackageQueue sharedQueue].queuedUninstalls) {
        if (pkg.kind == PackageInstallKindHideHomeBar) return YES;
    }
    return NO;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)[self packagesForSection:section].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSArray<Package *> *list = [self packagesForSection:section];
    if (list.count == 0) return nil;
    PackageInstallKind commonKind = list.firstObject.kind;
    BOOL allSameKind = YES;
    for (Package *pkg in list) {
        if (pkg.kind != commonKind) {
            allSameKind = NO;
            break;
        }
    }
    NSString *label;
    switch ((QueueReviewSection)section) {
        case QueueReviewSectionInstall:
            if (allSameKind && commonKind == PackageInstallKindOTA) {
                label = @"禁用";
            } else if (allSameKind && commonKind == PackageInstallKindNanoRegistry) {
                label = @"应用";
            } else if (allSameKind && commonKind == PackageInstallKindCallRecordingSound) {
                label = @"静音";
            } else if (allSameKind && commonKind == PackageInstallKindHideHomeBar) {
                label = @"隐藏";
            } else {
                label = @"激活";
            }
            break;
        case QueueReviewSectionUninstall:
            if (allSameKind && commonKind == PackageInstallKindOTA) {
                label = @"启用";
            } else if (allSameKind && commonKind == PackageInstallKindNanoRegistry) {
                label = @"移除";
            } else if (allSameKind && commonKind == PackageInstallKindCallRecordingSound) {
                label = @"恢复";
            } else if (allSameKind && commonKind == PackageInstallKindHideHomeBar) {
                label = @"恢复";
            } else {
                label = @"停用";
            }
            break;
        case QueueReviewSectionReApply:   label = @"已激活";   break;
        default:                          return nil;
    }
    return [NSString stringWithFormat:@"%@  ·  %ld", label, (long)list.count];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    switch ((QueueReviewSection)section) {
        case QueueReviewSectionInstall:
            if (![self queueIncludesHideHomeBar]) return nil;
            return @"隐藏主屏幕横条必须单独运行，因为它会修改系统主屏幕指示器资源并需要随后注销。请先单独运行它，注销后再应用其它插件。";
        case QueueReviewSectionReApply:
            if ([self reApplyPackages].count == 0) return nil;
            return @"这些是已激活的插件。如需停止某个插件，可从“安装器”标签页中将其停用，或使用“设置 → 快速操作”中的“重置所有插件”。";
        default:
            return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"QueueRow"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"QueueRow"];
    }
    NSArray<Package *> *packages = [self packagesForSection:indexPath.section];
    if (indexPath.row >= (NSInteger)packages.count) {
        cell.textLabel.text = @"不再待处理";
        cell.textLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightRegular];
        cell.detailTextLabel.text = @"此待处理项已被应用或清除。";
        cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
        cell.imageView.image = [UIImage systemImageNamed:@"checkmark.circle"];
        cell.imageView.tintColor = UIColor.tertiaryLabelColor;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    }

    Package *pkg = packages[indexPath.row];
    cell.textLabel.text = pkg.name;
    cell.textLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];

    QueueReviewSection s = (QueueReviewSection)indexPath.section;
    switch (s) {
        case QueueReviewSectionInstall:
            switch (pkg.kind) {
                case PackageInstallKindOTA:
                    cell.detailTextLabel.text = @"待禁用 OTA";
                    cell.detailTextLabel.textColor = UIColor.systemOrangeColor;
                    break;
                case PackageInstallKindNanoRegistry:
                    cell.detailTextLabel.text = @"待应用覆盖设置";
                    cell.detailTextLabel.textColor = self.view.tintColor;
                    break;
                case PackageInstallKindCallRecordingSound:
                    cell.detailTextLabel.text = @"待静音通话录音";
                    cell.detailTextLabel.textColor = UIColor.systemOrangeColor;
                    break;
                case PackageInstallKindHideHomeBar:
                    cell.detailTextLabel.text = @"单独运行；需重启 SpringBoard";
                    cell.detailTextLabel.textColor = UIColor.systemOrangeColor;
                    break;
                default:
                    cell.detailTextLabel.text = @"待激活";
                    cell.detailTextLabel.textColor = UIColor.systemGreenColor;
                    break;
            }
            break;
        case QueueReviewSectionUninstall:
            switch (pkg.kind) {
                case PackageInstallKindOTA:
                    cell.detailTextLabel.text = @"待启用 OTA";
                    cell.detailTextLabel.textColor = UIColor.systemGreenColor;
                    break;
                case PackageInstallKindNanoRegistry:
                    cell.detailTextLabel.text = @"待移除覆盖设置";
                    cell.detailTextLabel.textColor = UIColor.systemRedColor;
                    break;
                case PackageInstallKindCallRecordingSound:
                    cell.detailTextLabel.text = @"待恢复通话录音声音";
                    cell.detailTextLabel.textColor = UIColor.systemGreenColor;
                    break;
                case PackageInstallKindHideHomeBar:
                    cell.detailTextLabel.text = @"待恢复（需重启 SpringBoard）";
                    cell.detailTextLabel.textColor = UIColor.systemGreenColor;
                    break;
                default:
                    cell.detailTextLabel.text = @"待停用";
                    cell.detailTextLabel.textColor = UIColor.systemRedColor;
                    break;
            }
            break;
        case QueueReviewSectionReApply:
            cell.detailTextLabel.text = @"已激活；将刷新";
            cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
            break;
        default:
            cell.detailTextLabel.text = nil;
            break;
    }
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
    cell.imageView.image = [UIImage systemImageNamed:pkg.symbolName];
    cell.imageView.tintColor = (s == QueueReviewSectionReApply)
        ? UIColor.tertiaryLabelColor
        : self.view.tintColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    return cell;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Swipe-to-remove only applies to the pending queue rows. "Will Re-Apply"
    // is informational — to drop one, the user uninstalls it from the
    // Installer tab or runs Reset All Packages.
    QueueReviewSection s = (QueueReviewSection)indexPath.section;
    if (s != QueueReviewSectionInstall && s != QueueReviewSectionUninstall) return nil;

    NSArray<Package *> *packages = [self packagesForSection:indexPath.section];
    if (indexPath.row >= (NSInteger)packages.count) return nil;

    Package *pkg = packages[indexPath.row];
    UIContextualAction *remove = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                         title:@"移除"
                                                                       handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [[PackageQueue sharedQueue] removePackage:pkg];
        completionHandler(YES);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[remove]];
}

#pragma mark - Actions

- (void)didTapConfirm
{
    if ([PackageQueue sharedQueue].pendingCount == 0) return;
    NSInteger count = [PackageQueue sharedQueue].pendingCount;
    BOOL includesHideHomeBar = NO;
    for (Package *pkg in [PackageQueue sharedQueue].queuedInstalls) {
        if (pkg.kind == PackageInstallKindHideHomeBar) {
            includesHideHomeBar = YES;
            break;
        }
    }
    if (!includesHideHomeBar) {
        for (Package *pkg in [PackageQueue sharedQueue].queuedUninstalls) {
            if (pkg.kind == PackageInstallKindHideHomeBar) {
                includesHideHomeBar = YES;
                break;
            }
        }
    }
    if (includesHideHomeBar && count > 1) {
        UIAlertController *ac = [UIAlertController
            alertControllerWithTitle:@"隐藏主屏幕条必须单独运行"
                             message:@"隐藏主屏幕横条会修改系统主屏幕指示器资源，应用后需要注销。请移除其它待处理更改，单独运行隐藏主屏幕横条，注销后再应用其它插件。"
                      preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"确定"
                                               style:UIAlertActionStyleDefault
                                             handler:nil]];
        [self presentViewController:ac animated:YES completion:nil];
        return;
    }

    InstallProgressViewController *vc = [[InstallProgressViewController alloc] init];
    vc.promptsForHideHomeBarRespring = includesHideHomeBar;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationAutomatic;
    [self presentViewController:nav animated:YES completion:^{
        log_user("[INSTALLER] ── Applying %ld pending change(s) ──\n", (long)count);
        [[PackageQueue sharedQueue] commit];
    }];
}

- (void)didTapClear
{
    if ([PackageQueue sharedQueue].pendingCount == 0) return;
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"清空待处理？"
                                                                message:@"丢弃所有待处理的激活/停用更改。"
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"清空" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *_) {
        [[PackageQueue sharedQueue] clear];
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

@end
