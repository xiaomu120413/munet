import { PortResult, PortScanMode } from '../model/ScanInfo';
import { common } from '@kit.AbilityKit';
import { PortScanViewModel } from '../viewmodel/PortScanViewModel';
import { UiTheme } from './UiTheme';
import { UiPageHeader } from './UiPageHeader';
import { UiScanProgress } from './UiScanProgress';
import { ErrorBanner } from './ErrorBanner';

@Component
export struct PortScanView {
  @ObjectLink vm: PortScanViewModel;
  // Use the shell width on the first frame, before any area-change callback.
  @Prop contentWidth: number = 0;
  @State expanded: boolean = false;
  private confirming: boolean = false;
  private modes: PortScanMode[] = [PortScanMode.COMMON, PortScanMode.WEB, PortScanMode.TOP1024, PortScanMode.CUSTOM];
  private modeLabels: string[] = ['常用', 'Web', '1–1024', '自定义'];
  private concurrency: number[] = [32, 64, 128, 256];
  private timeouts: number[] = [800, 1500, 3000];
  private wide(): boolean { return UiTheme.supportsWide(this.contentWidth, this.getUIContext().getHostContext() as common.Context); }
  private inset(): number { return this.contentWidth >= 600 ? 24 : 16; }
  private stacked(): boolean { return this.contentWidth < 320; }
  aboutToDisappear(): void { this.vm.leave(); }
  private start(): void {
    if (this.vm.isRunning || this.confirming) { return; }
    const probes: number = this.vm.expectedProbes();
    if (probes <= 4096) { this.vm.start(); return; }
    this.confirming = true;
    this.getUIContext().showAlertDialog({ title: '扫描范围较大',
      message: '将发起 ' + probes + ' 次探测，可能需要较长时间。', autoCancel: false,
      primaryButton: { value: '取消', action: () => { this.confirming = false; } },
      secondaryButton: { value: '开始', action: () => { this.confirming = false; this.vm.start(); } } });
  }
  @Builder
  Settings() {
    Flex({ direction: this.wide() ? FlexDirection.Row : FlexDirection.Column }) {
      Flex({ direction: this.stacked() ? FlexDirection.Column : FlexDirection.Row }) {
        Text('并发').fontSize(16).fontColor(UiTheme.text).width(this.stacked() ? '100%' : 84)
          .margin({ bottom: this.stacked() ? 8 : 0 })
        Select([{ value: '32' }, { value: '64' }, { value: '128' }, { value: '256' }])
          .selected(this.concurrency.indexOf(this.vm.concurrency)).value(String(this.vm.concurrency))
          .font({ size: 16 }).flexGrow(this.stacked() ? 0 : 1).width(this.stacked() ? '100%' : 0).flexBasis(this.stacked() ? 'auto' : 0)
          .constraintSize({ minHeight: 44 }).enabled(!this.vm.isRunning)
          .accessibilityText('扫描并发数').onSelect((index: number) => { this.vm.setConcurrency(this.concurrency[index]); })
      }.width(this.wide() ? '50%' : '100%').padding({ right: this.wide() ? 24 : 0, bottom: 12 })
      Flex({ direction: this.stacked() ? FlexDirection.Column : FlexDirection.Row }) {
        Text('超时').fontSize(16).fontColor(UiTheme.text).width(this.stacked() ? '100%' : 84)
          .margin({ bottom: this.stacked() ? 8 : 0 })
        Select([{ value: '800 ms' }, { value: '1500 ms' }, { value: '3000 ms' }])
          .selected(this.timeouts.indexOf(this.vm.timeoutMs)).value(this.vm.timeoutMs + ' ms')
          .font({ size: 16 }).flexGrow(this.stacked() ? 0 : 1).width(this.stacked() ? '100%' : 0).flexBasis(this.stacked() ? 'auto' : 0)
          .constraintSize({ minHeight: 44 }).enabled(!this.vm.isRunning)
          .accessibilityText('扫描超时').onSelect((index: number) => { this.vm.setTimeoutMs(this.timeouts[index]); })
      }.width(this.wide() ? '50%' : '100%')
    }.width('100%')
  }
  @Builder
  TargetField() {
    Flex({ direction: this.stacked() ? FlexDirection.Column : FlexDirection.Row }) {
      Text('目标').fontSize(16).fontColor(UiTheme.text).width(this.stacked() ? '100%' : 84)
        .margin({ bottom: this.stacked() ? 8 : 0 })
      if (this.vm.scanLocalHost) {
        Text('本机地址').fontSize(16).fontColor(UiTheme.secondary).flexGrow(this.stacked() ? 0 : 1)
          .width(this.stacked() ? '100%' : 0).flexBasis(this.stacked() ? 'auto' : 0)
      } else {
        TextInput({ text: this.vm.target, placeholder: 'IP 或域名' }).fontSize(16).fontColor(UiTheme.text)
          .id('port-target')
          .backgroundColor(UiTheme.background).flexGrow(this.stacked() ? 0 : 1)
          .width(this.stacked() ? '100%' : 0).flexBasis(this.stacked() ? 'auto' : 0).constraintSize({ minHeight: 44 })
          .enabled(!this.vm.isRunning).accessibilityText('扫描目标')
          .onChange((value: string) => { this.vm.setTarget(value); }).onSubmit(() => { this.start(); })
      }
    }.width('100%')
  }
  @Builder
  LocalField() {
    Row() {
      Text('扫描本机').fontSize(16).fontColor(UiTheme.text).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.vm.scanLocalHost }).enabled(!this.vm.isRunning)
        .id('port-local')
        .accessibilityText('扫描本机').onChange((value: boolean) => { this.vm.setScanLocalHost(value); })
    }.width('100%').constraintSize({ minHeight: 44 })
    Text('本机模式探测 127.0.0.1、::1 和本机 IPv4 地址，不等同于系统完整监听表。')
      .fontSize(14).fontColor(UiTheme.secondary).width('100%')
  }
  @Builder
  RangeField() {
    Flex({ direction: this.stacked() ? FlexDirection.Column : FlexDirection.Row }) {
      Text('端口范围').fontSize(16).fontColor(UiTheme.text)
        .width(this.stacked() ? '100%' : UiTheme.labelWidth(72, this.getUIContext().getHostContext() as common.Context) + 12)
        .margin({ bottom: this.stacked() ? 8 : 0 })
      Select([{ value: '常用' }, { value: 'Web' }, { value: '1–1024' }, { value: '自定义' }])
        .id('port-mode')
        .selected(this.modes.indexOf(this.vm.mode)).value(this.modeLabels[this.modes.indexOf(this.vm.mode)])
        .font({ size: 16 }).constraintSize({ minHeight: 44 }).flexGrow(this.stacked() ? 0 : 1)
        .width(this.stacked() ? '100%' : 0).flexBasis(this.stacked() ? 'auto' : 0).enabled(!this.vm.isRunning)
        .accessibilityText('端口范围').onSelect((index: number) => { this.vm.selectMode(this.modes[index]); })
    }.width('100%')
    if (this.vm.mode === PortScanMode.CUSTOM) {
      TextInput({ text: this.vm.customExpr, placeholder: '80,443,1000-2000' }).fontSize(16)
        .id('port-expression')
        .fontColor(UiTheme.text).backgroundColor(UiTheme.background).width('100%')
        .constraintSize({ minHeight: 44 }).enabled(!this.vm.isRunning).accessibilityText('自定义端口表达式')
        .onChange((value: string) => { this.vm.setCustomExpr(value); })
    }
    Text(this.vm.portCount() + ' 个端口').fontSize(14).fontColor(UiTheme.secondary).width('100%')
    if (this.vm.error.length > 0) {
      ErrorBanner({ message: this.vm.error, onClose: (): void => { this.vm.dismissError(); } })
    }
  }
  @Builder
  StartButton() {
    Button(this.vm.isRunning ? (this.vm.cancelled ? '正在停止' : '停止') : '开始扫描', { type: ButtonType.Capsule, stateEffect: true })
      .id('port-start')
      .fontSize(16).fontColor($r('app.color.ui_on_accent')).constraintSize({ minHeight: 44 })
      .width(this.wide() ? 160 : '100%').backgroundColor(this.vm.isRunning ? UiTheme.danger : UiTheme.accent)
      .enabled(!this.vm.isRunning || !this.vm.cancelled)
      .onClick(() => { if (this.vm.isRunning) { this.vm.stop(); } else { this.start(); } })
  }
  @Builder
  Parameters() {
    Column({ space: 24 }) {
      if (this.wide()) {
        Row({ space: 24 }) {
          Column() { this.TargetField() }.layoutWeight(5)
          Column({ space: 8 }) { this.LocalField() }.layoutWeight(4)
        }.width('100%').alignItems(VerticalAlign.Top)
      } else {
        this.TargetField()
        this.LocalField()
      }
      this.RangeField()
      if (this.wide()) {
        Row({ space: 24 }) {
          Column() { this.Settings() }.layoutWeight(1)
          this.StartButton()
        }.width('100%')
      } else {
        Column({ space: 16 }) {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Text((this.expanded ? '收起设置' : '扫描设置') + ' · 并发 ' + this.vm.concurrency + ' · ' + this.vm.timeoutMs + ' ms')
            .fontSize(14).fontColor(UiTheme.accent).textAlign(TextAlign.Center)
            .width('100%').padding({ left: 12, right: 12, top: 12, bottom: 12 })
        }
          .width('100%').constraintSize({ minHeight: 44 }).backgroundColor(UiTheme.selected).borderRadius(12)
          .onClick(() => { this.expanded = !this.expanded; })
        if (this.expanded) { this.Settings() }
        this.StartButton()
        }.width('100%')
      }
    }.width('100%').padding(16).alignItems(HorizontalAlign.Start).backgroundColor(UiTheme.surface).borderRadius(12)
  }
  @Builder
  ResultRow(result: PortResult) {
    if (this.wide()) {
      Row({ space: 16 }) {
        Text(String(result.port)).width(88).fontColor(UiTheme.text)
        Text(this.vm.scanLocalHost ? '占用' : '开放').width(88).fontColor(UiTheme.success)
        Text(this.vm.serviceLabel(result.port)).layoutWeight(1).fontColor(UiTheme.text)
        Text(result.rttMs + ' ms').width(104).fontColor(UiTheme.secondary)
      }.width('100%').padding({ top: 14, bottom: 14 })
    } else {
      Column({ space: 6 }) {
        Text(result.port + ' · ' + this.vm.serviceLabel(result.port)).fontSize(16).fontColor(UiTheme.text).width('100%')
        Text((this.vm.scanLocalHost ? '占用' : '开放') + ' · ' + result.rttMs + ' ms').fontSize(14)
          .fontColor(UiTheme.success).width('100%')
      }.width('100%').padding({ top: 14, bottom: 14 })
    }
    Divider().color(UiTheme.divider)
  }
  build() {
    Column() {
      UiPageHeader({ title: '端口扫描', inset: this.inset() })
      Scroll() {
        Column({ space: 16 }) {
          this.Parameters()
          if (this.vm.total > 0) {
            UiScanProgress({ done: this.vm.done, total: this.vm.total, running: this.vm.isRunning,
              cancelled: this.vm.cancelled, failed: this.vm.failed, detail: this.vm.summaryLabel() + ' · ' + this.vm.elapsedLabel() })
          }
          Column() {
            if (this.wide() && this.vm.openResults.length > 0) {
              Row({ space: 16 }) {
                Text('端口').width(88)
                Text('状态').width(88)
                Text('常见服务').layoutWeight(1)
                Text('耗时').width(104)
              }.width('100%').padding({ top: 12, bottom: 12 }).foregroundColor(UiTheme.secondary)
            }
            ForEach(this.vm.openResults, (result: PortResult) => { this.ResultRow(result) }, (result: PortResult) => String(result.port))
            if (this.vm.openResults.length === 0) {
              Text(this.vm.isRunning ? '正在探测，结果将在探测结束后汇总…' : this.vm.total === 0 ? '设置目标与端口范围后开始扫描' :
                this.vm.failed ? '扫描未完成，请检查目标与网络后重试' : this.vm.cancelled ? '扫描已停止，暂无结果' : this.vm.scanLocalHost ? '未发现被占用的端口' : '未发现开放端口')
                .fontSize(16).fontColor(UiTheme.secondary).width('100%').padding({ top: 24, bottom: 24 })
            }
          }.width('100%').padding(16).backgroundColor(UiTheme.surface).borderRadius(12)
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: this.inset(), right: this.inset(), bottom: 24 })
      }.width('100%').layoutWeight(1).align(Alignment.Top)
    }.width('100%').height('100%').backgroundColor(UiTheme.background)
  }
}
