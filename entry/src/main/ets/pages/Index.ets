import { deviceInfo } from '@kit.BasicServicesKit';
import { ScanKind } from '../model/HistoryInfo';
import { LocalNetView } from '../views/LocalNetView';
import { PingView } from '../views/PingView';
import { PortScanView } from '../views/PortScanView';
import { LanDiscoveryView } from '../views/LanDiscoveryView';
import { HistoryView } from '../views/HistoryView';
import { AboutView } from '../views/AboutView';
import { ToolsView } from '../views/ToolsView';
import { UiTheme } from '../views/UiTheme';
import { UiAction } from '../views/UiAction';
import { LocalNetViewModel } from '../viewmodel/LocalNetViewModel';
import { PingViewModel } from '../viewmodel/PingViewModel';
import { PortScanViewModel } from '../viewmodel/PortScanViewModel';
import { LanDiscoveryViewModel } from '../viewmodel/LanDiscoveryViewModel';
import { HistoryViewModel } from '../viewmodel/HistoryViewModel';

interface NavItem { title: string; icon: Resource; }

@Entry
@Component
struct Index {
  @State current: number = 0;
  @State windowWidth: number = 0;
  @State localVm: LocalNetViewModel = new LocalNetViewModel();
  @State pingVm: PingViewModel = new PingViewModel();
  @State portVm: PortScanViewModel = new PortScanViewModel();
  @State lanVm: LanDiscoveryViewModel = new LanDiscoveryViewModel();
  @State historyVm: HistoryViewModel = new HistoryViewModel();
  private readonly desktop: boolean = deviceInfo.deviceType === '2in1' || deviceInfo.deviceType === 'pc';
  private confirmingLeave: boolean = false;
  private navItems: NavItem[] = [
    { title: '本机网络', icon: $r('sys.symbol.worldclock') },
    { title: 'Ping', icon: $r('sys.symbol.waveform_path_ecg_square') },
    { title: '端口扫描', icon: $r('sys.symbol.square_grid_2x2') },
    { title: '局域网', icon: $r('sys.symbol.wifi_router') },
    { title: '记录', icon: $r('sys.symbol.list_bullet') },
    { title: '关于', icon: $r('sys.symbol.info_circle') }
  ];
  private bottomItems: NavItem[] = [
    { title: '网络', icon: $r('sys.symbol.worldclock') },
    { title: '工具', icon: $r('sys.symbol.wrench_and_screwdriver') },
    { title: '记录', icon: $r('sys.symbol.list_bullet') },
    { title: '更多', icon: $r('sys.symbol.ellipsis_circle') }
  ];
  private sideNavigation(): boolean { return this.desktop || this.windowWidth >= 840; }
  private compactNavigation(): boolean { return this.desktop && this.windowWidth < 840; }
  private narrowNavigation(): boolean { return !this.desktop && this.windowWidth < 840; }
  private isTool(): boolean { return this.current >= 1 && this.current <= 3; }
  private selectedBottom(): number {
    return this.current === 0 ? 0 : this.current === 4 ? 2 : this.current === 5 ? 3 : 1;
  }
  private running(): boolean {
    return this.pingVm.isRunning || this.portVm.isRunning || this.lanVm.isRunning;
  }
  private stopTask(): void {
    if (this.pingVm.isRunning) { this.pingVm.stop(); }
    if (this.portVm.isRunning) { this.portVm.stop(); }
    if (this.lanVm.isRunning) { this.lanVm.stop(); }
  }
  private finishLeave(index: number): void {
    if (this.running()) {
      setTimeout(() => { this.finishLeave(index); }, 50);
      return;
    }
    this.current = index;
    this.confirmingLeave = false;
  }
  private navigate(index: number): void {
    if (this.current === index || this.confirmingLeave) { return; }
    if (!this.running()) { this.current = index; return; }
    this.confirmingLeave = true;
    this.getUIContext().showAlertDialog({
      title: '停止当前任务并离开？', message: '已得到的结果会保留，确认后停止当前探测。', autoCancel: false,
      primaryButton: { value: '取消', action: () => { this.confirmingLeave = false; } },
      secondaryButton: { value: '停止并离开', action: () => {
        this.stopTask(); this.finishLeave(index);
      } }
    });
  }
  private onRescan(kind: ScanKind, target: string): void {
    if (kind === ScanKind.PING) { this.pingVm.setTarget(target); this.navigate(1); }
    else if (kind === ScanKind.PORT_SCAN) {
      this.portVm.setScanLocalHost(target === '本机');
      if (target !== '本机') { this.portVm.setTarget(target); }
      this.navigate(2);
    } else { this.lanVm.setCidr(target); this.navigate(3); }
  }
  onBackPress(): boolean {
    if ((this.isTool() && this.narrowNavigation()) || this.running()) {
      this.navigate(6); return true;
    }
    return false;
  }

  @Builder
  Content() {
    if (this.current === 0) { LocalNetView({ vm: this.localVm }) }
    else if (this.current === 1) { PingView({ vm: this.pingVm }) }
    else if (this.current === 2) { PortScanView({ vm: this.portVm }) }
    else if (this.current === 3) { LanDiscoveryView({ vm: this.lanVm }) }
    else if (this.current === 4) {
      HistoryView({ vm: this.historyVm, onRescan: (kind: ScanKind, target: string): void => {
        this.onRescan(kind, target);
      } })
    } else if (this.current === 5) { AboutView({ title: this.narrowNavigation() ? '更多' : '关于' }) }
    else { ToolsView({ onSelect: (index: number): void => { this.navigate(index); } }) }
  }

  @Builder
  NavigationItem(item: NavItem, index: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      if (this.compactNavigation()) {
        Column({ space: 6 }) {
          SymbolGlyph(item.icon).fontSize(22)
            .fontColor([this.current === index ? UiTheme.accent : UiTheme.secondary])
          Text(item.title).fontSize(12)
            .fontColor(this.current === index ? UiTheme.accent : UiTheme.text).textAlign(TextAlign.Center)
        }.width('100%').padding({ left: 4, right: 4, top: 12, bottom: 12 }).constraintSize({ minHeight: 64 })
      } else {
      Row({ space: 12 }) {
        SymbolGlyph(item.icon).fontSize(22)
          .fontColor([this.current === index ? UiTheme.accent : UiTheme.secondary])
        Text(item.title).fontSize(16).fontWeight(this.current === index ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.current === index ? UiTheme.accent : UiTheme.text)
      }.width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 }).constraintSize({ minHeight: 48 })
      }
    }
    .borderRadius(this.compactNavigation() ? 12 : 24)
    .backgroundColor(this.current === index ? UiTheme.selected : Color.Transparent)
    .id('nav-' + index).accessibilitySelected(this.current === index)
    .accessibilityText(item.title + (this.current === index ? '，已选中' : ''))
    .onClick(() => { this.navigate(index); })
  }

  @Builder
  SideNav() {
    Scroll() {
      Column({ space: 8 }) {
      if (this.compactNavigation()) {
        Image($r('app.media.app_icon')).width(40).height(40).borderRadius(10)
          .accessibilityText($r('app.string.app_brand')).margin({ top: 16, bottom: 16 })
      } else {
        Text('木络').fontSize(22).fontWeight(FontWeight.Medium).fontColor(UiTheme.text)
          .width('100%').padding({ left: 16, top: 16, bottom: 24 })
      }
      ForEach(this.navItems, (item: NavItem, index: number) => {
        this.NavigationItem(item, index)
      }, (item: NavItem) => item.title)
      }.width('100%').padding({ left: 8, right: 8, bottom: 16 })
    }.id(this.desktop ? 'desktop-navigation' : 'tablet-navigation')
      .width(this.compactNavigation() ? 72 : 192).height('100%').align(Alignment.TopStart)
      .scrollBar(BarState.Auto).backgroundColor(UiTheme.background)
      .border({ width: { right: 1 }, color: UiTheme.divider })
  }

  @Builder
  BottomNav() {
    Row() {
      ForEach(this.bottomItems, (item: NavItem, index: number) => {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Column({ space: 4 }) {
            SymbolGlyph(item.icon).fontSize(22)
              .fontColor([this.selectedBottom() === index ? UiTheme.accent : UiTheme.secondary])
            Text(item.title).fontSize(12)
              .fontColor(this.selectedBottom() === index ? UiTheme.accent : UiTheme.secondary)
          }.width('100%').padding({ top: 10, bottom: 10 })
        }.layoutWeight(1).borderRadius(8).backgroundColor(Color.Transparent)
          .id('bottom-nav-' + index).accessibilitySelected(this.selectedBottom() === index)
          .accessibilityText(item.title + (this.selectedBottom() === index ? '，已选中' : ''))
          .onClick(() => { this.navigate(index === 0 ? 0 : index === 1 ? 6 : index === 2 ? 4 : 5); })
      }, (item: NavItem) => item.title)
    }.id('bottom-navigation').width('100%').backgroundColor(UiTheme.surface)
      .border({ width: { top: 1 }, color: UiTheme.divider })
  }

  build() {
    Column() {
      // Content stays at the same tree position when navigation changes shape.
      Flex({ direction: this.sideNavigation() ? FlexDirection.Row : FlexDirection.Column }) {
        if (this.sideNavigation()) { this.SideNav() }
        Column() {
          if (this.narrowNavigation() && this.isTool()) {
            Row() {
              UiAction({ label: '返回工具', icon: $r('sys.symbol.chevron_left'),
                onAction: (): void => { this.navigate(6); } })
            }.width('100%').padding({ left: this.windowWidth >= 600 ? 24 : 16, top: 8 })
          }
          Column() { this.Content() }.width('100%').layoutWeight(1)
        }.layoutWeight(1).width(this.sideNavigation() ? 'auto' : '100%')
          // The system caption buttons remain visible when window decor is hidden.
          .padding({ top: this.desktop ? 40 : 0 })
      }.width('100%').layoutWeight(1)
      if (this.narrowNavigation()) { this.BottomNav() }
    }.id('app-shell').width('100%').height('100%').backgroundColor(UiTheme.background)
      .onAreaChange((oldArea: Area, newArea: Area) => { this.windowWidth = Number(newArea.width); })
  }
}
