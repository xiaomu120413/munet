import { common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { DiscoveredHost, ExportFormat, ScanKind, ScanRecord } from '../model/HistoryInfo';
import { HistoryViewModel } from '../viewmodel/HistoryViewModel';
import { UiTheme } from './UiTheme';
import { UiAction } from './UiAction';
import { ErrorBanner } from './ErrorBanner';

@Component
export struct HistoryView {
  @ObjectLink vm: HistoryViewModel;
  onRescan: (kind: ScanKind, target: string) => void = () => {};
  @State contentWidth: number = 0;
  @State contentHeight: number = 0;
  @State actionsOpen: boolean = false;
  private pendingAction: () => void = () => {};
  private scroller: Scroller = new Scroller();
  private confirming: boolean = false;
  private restoring: boolean = false;
  private kinds: (ScanKind | undefined)[] = [undefined, ScanKind.PING, ScanKind.PORT_SCAN, ScanKind.LAN_DISCOVERY];
  private readonly desktop: boolean = deviceInfo.deviceType === '2in1' || deviceInfo.deviceType === 'pc';
  private labels: string[] = ['全部类型', 'Ping', '端口扫描', '局域网'];
  private wide(): boolean { return UiTheme.supportsWide(this.contentWidth, this.getUIContext().getHostContext() as common.Context); }
  private inset(): number { return this.contentWidth >= 600 ? 24 : 16; }
  private stackedHeader(): boolean {
    return this.contentWidth < UiTheme.labelWidth(280, this.getUIContext().getHostContext() as common.Context);
  }
  private stackedTabs(): boolean {
    return this.contentWidth < UiTheme.labelWidth(240, this.getUIContext().getHostContext() as common.Context);
  }
  private busy(): boolean { return this.vm.isLoading || this.vm.isExporting || this.vm.isClearing; }
  aboutToAppear(): void { this.vm.load().then(() => { this.restore(); }); }
  private restore(): void {
    this.restoring = true;
    const offset: number = this.vm.showHosts ? this.vm.hostOffset : this.vm.recordOffset;
    setTimeout(() => {
      this.scroller.scrollTo({ xOffset: 0, yOffset: offset });
      this.restoring = false;
    }, 0);
  }
  private switchView(hosts: boolean): void { this.vm.showView(hosts); this.restore(); }
  private async export(format: ExportFormat): Promise<void> {
    if (await this.vm.export(this.getUIContext().getHostContext() as common.Context, format)) {
      this.getUIContext().getPromptAction().showToast({ message: '记录已导出' });
    }
  }
  private clear(): void {
    if (this.confirming || this.busy()) { return; }
    this.confirming = true;
    this.getUIContext().showAlertDialog({ title: '清空全部记录与档案？',
      message: '将删除所有扫描记录和设备档案，清空后无法恢复。已导出的文件不受影响。', autoCancel: false,
      primaryButton: { value: '取消', defaultFocus: true, action: () => { this.confirming = false; } },
      secondaryButton: { value: '清空', fontColor: UiTheme.danger,
        action: () => { this.confirming = false; this.vm.clear(); } } });
  }
  private more(): void {
    if (this.busy()) { return; }
    this.actionsOpen = true;
  }
  private closeActions(action: () => void): void {
    this.pendingAction = action;
    this.actionsOpen = false;
  }
  @Builder
  MobileActions() {
    Scroll() {
      Column({ space: 12 }) {
        Text('记录操作').fontSize(20).fontWeight(FontWeight.Medium).fontColor(UiTheme.text).width('100%')
        Text(this.vm.showHosts ? '清空操作会同时删除扫描记录和设备档案。' : '导出包含全部扫描记录，不受类型筛选影响。')
          .fontSize(14).fontColor(UiTheme.secondary).width('100%').margin({ bottom: 8 })
        if (!this.vm.showHosts && this.vm.hasRecords()) {
          Button('导出全部扫描记录 · CSV', { type: ButtonType.Normal, stateEffect: true })
            .id('history-sheet-csv').width('100%').constraintSize({ minHeight: 56 }).padding(12)
            .fontSize(16).fontColor(UiTheme.accent).backgroundColor(UiTheme.selected).borderRadius(12)
            .onClick(() => { this.closeActions(() => { this.export(ExportFormat.CSV); }); })
          Button('导出全部扫描记录 · JSON', { type: ButtonType.Normal, stateEffect: true })
            .id('history-sheet-json').width('100%').constraintSize({ minHeight: 56 }).padding(12)
            .fontSize(16).fontColor(UiTheme.accent).backgroundColor(UiTheme.selected).borderRadius(12)
            .onClick(() => { this.closeActions(() => { this.export(ExportFormat.JSON); }); })
        }
        Button('清空全部记录与档案', { type: ButtonType.Normal, stateEffect: true })
          .id('history-sheet-clear').width('100%').constraintSize({ minHeight: 56 }).padding(12)
          .fontSize(16).fontColor(UiTheme.danger).backgroundColor(UiTheme.surface).borderRadius(12)
          .onClick(() => { this.closeActions(() => { this.clear(); }); })
        Button('取消', { type: ButtonType.Normal, stateEffect: true })
          .id('history-sheet-cancel').width('100%').constraintSize({ minHeight: 56 }).padding(12)
          .fontSize(16).fontColor(UiTheme.text).backgroundColor(UiTheme.surface).borderRadius(12)
          .onClick(() => { this.actionsOpen = false; })
      }.width('100%').padding(24)
    }.width('100%').constraintSize({ maxHeight: Math.max(160, this.contentHeight * 0.8) })
  }
  @Builder
  ExportMenu() {
    Menu() {
      MenuItem({ content: '导出全部扫描记录 · CSV' }).onClick(() => { this.export(ExportFormat.CSV); })
      MenuItem({ content: '导出全部扫描记录 · JSON' }).onClick(() => { this.export(ExportFormat.JSON); })
    }
  }
  @Builder
  Actions() {
    Menu() {
      MenuItem({ content: '清空全部记录与档案' }).onClick(() => { this.clear(); })
    }
  }
  @Builder
  DesktopActions() {
    Menu() {
      if (!this.vm.showHosts && this.vm.hasRecords()) {
        MenuItem({ content: '导出全部扫描记录 · CSV' }).onClick(() => { this.export(ExportFormat.CSV); })
        MenuItem({ content: '导出全部扫描记录 · JSON' }).onClick(() => { this.export(ExportFormat.JSON); })
      }
      MenuItem({ content: '清空全部记录与档案' }).onClick(() => { this.clear(); })
    }
  }
  @Builder
  ScanRow(record: ScanRecord) {
    if (this.wide()) {
      Row({ space: 16 }) {
        Text(this.vm.formatTime(record.ts)).fontSize(14).fontColor(UiTheme.secondary).width(120)
        Text(this.vm.kindLabel(record.kind)).fontSize(16).fontColor(UiTheme.text).width(90)
        Text(record.target).fontSize(16).fontColor(UiTheme.text).layoutWeight(1).copyOption(CopyOptions.InApp)
        Text(this.vm.summaryText(record)).fontSize(14).fontColor(UiTheme.secondary).layoutWeight(2)
        UiAction({ label: '重测', onAction: () => { this.onRescan(record.kind, record.target); } })
      }.width('100%').padding({ top: 12, bottom: 12 })
    } else {
      Column({ space: 8 }) {
        Row({ space: 12 }) {
          Text(record.target).fontSize(16).fontColor(UiTheme.text).layoutWeight(1).copyOption(CopyOptions.InApp)
          Text(this.vm.kindLabel(record.kind)).fontSize(14).fontColor(UiTheme.secondary)
        }.width('100%')
        Text(this.vm.summaryText(record)).fontSize(14).fontColor(UiTheme.secondary).width('100%')
        Row() {
          Text(this.vm.formatTime(record.ts)).fontSize(14).fontColor(UiTheme.secondary).layoutWeight(1)
          UiAction({ label: '重测', onAction: () => { this.onRescan(record.kind, record.target); } })
        }.width('100%')
      }.width('100%').padding({ top: 16, bottom: 12 })
    }
    Divider().color(UiTheme.divider)
  }
  @Builder
  HostRow(host: DiscoveredHost) {
    Flex({ direction: this.wide() ? FlexDirection.Row : FlexDirection.Column }) {
      Text(host.ip).fontSize(16).fontColor(UiTheme.text).width(this.wide() ? '25%' : '100%').copyOption(CopyOptions.InApp)
      Text((this.wide() ? '' : '名称：') + this.vm.hostNameLabel(host)).fontSize(14).fontColor(UiTheme.secondary).width(this.wide() ? '25%' : '100%').margin({ top: this.wide() ? 0 : 8 })
      Text((this.wide() ? '' : '开放端口：') + this.vm.hostPortsLabel(host)).fontSize(14).fontColor(UiTheme.secondary).width(this.wide() ? '25%' : '100%').margin({ top: this.wide() ? 0 : 8 })
      Text((this.wide() ? '' : '最近发现 ') + this.vm.formatTime(host.lastSeen)).fontSize(14).fontColor(UiTheme.secondary).width(this.wide() ? '25%' : '100%').margin({ top: this.wide() ? 0 : 8 })
    }.width('100%').padding({ top: 20, bottom: 20 })
    Divider().color(UiTheme.divider)
  }
  @Builder
  HeaderActions() {
    Row({ space: 8 }) {
        UiAction({ label: '刷新', icon: $r('sys.symbol.arrow_clockwise'), actionEnabled: !this.busy(), onAction: () => { this.vm.load(); } })
        if (this.wide()) {
          if (!this.vm.showHosts) {
            Button('导出全部', { stateEffect: true }).height(44).fontSize(14).fontColor(UiTheme.accent)
              .id('history-export')
              .backgroundColor(UiTheme.selected).enabled(!this.busy() && this.vm.hasRecords()).bindMenu(this.ExportMenu)
          }
          Button('更多', { stateEffect: true }).height(44).fontSize(14).fontColor(UiTheme.accent)
            .id('history-more')
            .backgroundColor(UiTheme.selected).enabled(!this.busy()).bindMenu(this.Actions)
        } else if (this.desktop) {
          Button('更多', { stateEffect: true }).height(44).fontSize(14).fontColor(UiTheme.accent)
            .id('history-more')
            .backgroundColor(UiTheme.selected).enabled(!this.busy()).bindMenu(this.DesktopActions)
        } else {
          UiAction({ label: '更多', actionEnabled: !this.busy(), onAction: () => { this.more(); } }).id('history-more')
        }
    }.justifyContent(FlexAlign.End)
      .bindSheet($$this.actionsOpen, this.MobileActions, {
        height: SheetSize.FIT_CONTENT, dragBar: true, showClose: false,
        onDisappear: () => {
          const action: () => void = this.pendingAction;
          this.pendingAction = () => {};
          action();
        }
      })
  }
  @Builder
  HistoryTab(hosts: boolean) {
    if (!hosts) {
        Button('扫描记录', { type: ButtonType.Capsule, stateEffect: true }).height(44).fontSize(16)
          .id('history-scans')
          .backgroundColor(this.vm.showHosts ? UiTheme.surface : UiTheme.accent)
          .fontColor(this.vm.showHosts ? UiTheme.secondary : $r('app.color.ui_on_accent'))
          .width(this.stackedTabs() ? '100%' : 'auto').layoutWeight(this.stackedTabs() ? 0 : 1)
          .accessibilitySelected(!this.vm.showHosts).onClick(() => { this.switchView(false); })
    } else {
        Button('设备档案', { type: ButtonType.Capsule, stateEffect: true }).height(44).fontSize(16)
          .id('history-hosts')
          .backgroundColor(this.vm.showHosts ? UiTheme.accent : UiTheme.surface)
          .fontColor(this.vm.showHosts ? $r('app.color.ui_on_accent') : UiTheme.secondary)
          .width(this.stackedTabs() ? '100%' : 'auto').layoutWeight(this.stackedTabs() ? 0 : 1)
          .accessibilitySelected(this.vm.showHosts).onClick(() => { this.switchView(true); })
    }
  }
  build() {
    Column() {
      Column({ space: 8 }) {
        if (this.stackedHeader()) {
          Text('记录').fontSize(24).fontWeight(FontWeight.Medium).fontColor(UiTheme.text).width('100%')
          Row() { this.HeaderActions() }.width('100%').justifyContent(FlexAlign.End)
        } else {
          Row({ space: 8 }) {
            Text('记录').fontSize(24).fontWeight(FontWeight.Medium).fontColor(UiTheme.text).layoutWeight(1)
            this.HeaderActions()
          }.width('100%')
        }
      }.width('100%').padding({ left: this.inset(), right: this.inset(), top: 16, bottom: 16 })
      Column() {
        if (this.stackedTabs()) {
          Column({ space: 8 }) {
            this.HistoryTab(false)
            this.HistoryTab(true)
          }.width('100%')
        } else {
          Row({ space: 8 }) {
            this.HistoryTab(false)
            this.HistoryTab(true)
          }.width('100%').constraintSize({ maxWidth: this.wide() ? 360 : this.contentWidth })
        }
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: this.inset(), right: this.inset(), bottom: 16 })
      if (!this.vm.showHosts) {
        Row() {
          Select([{ value: '全部类型' }, { value: 'Ping' }, { value: '端口扫描' }, { value: '局域网' }])
            .id('history-filter')
            .selected(this.kinds.indexOf(this.vm.filterKind)).value(this.labels[this.kinds.indexOf(this.vm.filterKind)])
            .font({ size: 16 }).constraintSize({ minHeight: 44 }).accessibilityText('筛选记录类型')
            .onSelect((index: number) => { this.vm.selectFilter(this.kinds[index]); this.vm.recordOffset = 0; this.restore(); })
          Blank()
          Text(this.vm.records.length + ' 条').fontSize(14).fontColor(UiTheme.secondary)
        }.width('100%').padding({ left: this.inset(), right: this.inset(), bottom: 12 })
      }
      if (this.vm.error.length > 0) {
        ErrorBanner({ message: this.vm.error, onClose: () => { this.vm.dismissError(); } })
      }
      Scroll(this.scroller) {
        Column() {
          if (this.vm.isLoading) {
            Text('正在读取记录…').fontSize(16).fontColor(UiTheme.secondary).padding(32)
          } else if (this.vm.showHosts) {
            if (this.wide() && this.vm.hosts.length > 0) {
              Row() {
                Text('IP 地址').width('25%')
                Text('主机名').width('25%')
                Text('已发现端口').width('25%')
                Text('最近发现').width('25%')
              }.width('100%').padding({ top: 12, bottom: 12 }).foregroundColor(UiTheme.secondary)
              Divider().color(UiTheme.divider)
            }
            if (this.vm.hosts.length === 0) {
              Text('暂无设备档案').fontSize(18).fontColor(UiTheme.text).padding({ top: 48, bottom: 12 })
              Text('局域网扫描发现的设备会保存在这里。').fontSize(14).fontColor(UiTheme.secondary)
            }
            ForEach(this.vm.hosts, (host: DiscoveredHost) => { this.HostRow(host) }, (host: DiscoveredHost) => host.ip)
          } else {
            if (this.wide() && this.vm.records.length > 0) {
              Row({ space: 16 }) {
                Text('时间').width(120)
                Text('类型').width(90)
                Text('目标').layoutWeight(1)
                Text('结果摘要').layoutWeight(2)
                Text('操作').width(64)
              }.width('100%').padding({ top: 12, bottom: 12 }).foregroundColor(UiTheme.secondary)
              Divider().color(UiTheme.divider)
            }
            if (this.vm.records.length === 0) {
              Text(this.vm.hasRecords() ? '此类型暂无记录' : '暂无扫描记录').fontSize(18).fontColor(UiTheme.text).padding({ top: 48, bottom: 12 })
              Text('完成一次诊断后，可在这里查看结果并重测。').fontSize(14).fontColor(UiTheme.secondary)
            }
            ForEach(this.vm.records, (record: ScanRecord) => { this.ScanRow(record) }, (record: ScanRecord) => String(record.id))
          }
        }.width('100%').padding({ left: this.inset(), right: this.inset(), bottom: 24 })
      }.layoutWeight(1).width('100%').align(Alignment.Top)
        .onScroll(() => {
          if (this.restoring) { return; }
          if (this.vm.showHosts) { this.vm.hostOffset = this.scroller.currentOffset().yOffset; }
          else { this.vm.recordOffset = this.scroller.currentOffset().yOffset; }
        })
    }.width('100%').height('100%').backgroundColor(UiTheme.background)
      .onAreaChange((_old: Area, area: Area) => {
        this.contentWidth = Number(area.width);
        this.contentHeight = Number(area.height);
      })
  }
}
