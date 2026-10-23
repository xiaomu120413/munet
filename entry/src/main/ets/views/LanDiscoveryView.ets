import { common } from '@kit.AbilityKit';
import { HostResult } from '../model/ScanInfo';
import { LanDiscoveryViewModel } from '../viewmodel/LanDiscoveryViewModel';
import { UiTheme } from './UiTheme';
import { UiPageHeader } from './UiPageHeader';
import { UiScanProgress } from './UiScanProgress';
import { ErrorBanner } from './ErrorBanner';

@Component
export struct LanDiscoveryView {
  @ObjectLink vm: LanDiscoveryViewModel;
  // Use the shell width on the first frame, before any area-change callback.
  @Prop contentWidth: number = 0;
  private confirming: boolean = false;
  private wide(): boolean { return UiTheme.supportsWide(this.contentWidth, this.getUIContext().getHostContext() as common.Context); }
  private inset(): number { return this.contentWidth >= 600 ? 24 : 16; }
  aboutToAppear(): void {
    this.vm.setContext(this.getUIContext().getHostContext() as common.Context);
    this.vm.loadDefaultCidr();
  }
  aboutToDisappear(): void { this.vm.leave(); }
  private start(): void {
    if (this.vm.isRunning || this.confirming) { return; }
    const count: number = this.vm.hostCount();
    if (count <= 1024) { this.vm.start(); return; }
    this.confirming = true;
    this.getUIContext().showAlertDialog({ title: '扫描范围较大', message: '该网段含 ' + count + ' 台主机，扫描可能较慢。',
      autoCancel: false, primaryButton: { value: '取消', action: () => { this.confirming = false; } },
      secondaryButton: { value: '开始', action: () => { this.confirming = false; this.vm.start(); } } });
  }
  @Builder
  HostRow(host: HostResult) {
    if (this.wide()) {
      Row({ space: 16 }) {
        Text(host.ip).width(180).fontColor(UiTheme.text).copyOption(CopyOptions.LocalDevice)
        Text(host.openPorts.length > 0 ? host.openPorts.join(', ') : '—').layoutWeight(1).fontColor(UiTheme.secondary)
        Text(this.vm.hostnameFor(host.ip) || '—').layoutWeight(1).fontColor(UiTheme.text).wordBreak(WordBreak.BREAK_ALL)
      }.width('100%').padding({ top: 14, bottom: 14 })
    } else {
      Column({ space: 6 }) {
        Text(host.ip).fontSize(16).fontWeight(FontWeight.Medium).fontColor(UiTheme.text).width('100%')
          .copyOption(CopyOptions.LocalDevice)
        Text(this.vm.hostnameFor(host.ip) || '—').fontSize(14).fontColor(UiTheme.secondary).width('100%')
          .wordBreak(WordBreak.BREAK_ALL)
        Text('开放端口 ' + (host.openPorts.length > 0 ? host.openPorts.join(', ') : '—'))
          .fontSize(14).fontColor(UiTheme.secondary).width('100%')
      }.width('100%').padding({ top: 14, bottom: 14 })
    }
    Divider().color(UiTheme.divider)
  }
  @Builder
  CidrField() {
    Flex({ direction: this.contentWidth < 320 ? FlexDirection.Column : FlexDirection.Row }) {
      Text('网段').fontSize(16).fontColor(UiTheme.text).width(this.contentWidth < 320 ? '100%' : 76)
        .margin({ bottom: this.contentWidth < 320 ? 8 : 0 })
      TextInput({ text: this.vm.cidr, placeholder: '192.168.1.0/24' }).fontSize(16).fontColor(UiTheme.text)
        .id('lan-cidr')
        .backgroundColor(UiTheme.background).constraintSize({ minHeight: 44 })
        .flexGrow(this.contentWidth < 320 ? 0 : 1).width(this.contentWidth < 320 ? '100%' : 0).flexBasis(this.contentWidth < 320 ? 'auto' : 0)
        .enabled(!this.vm.isRunning).accessibilityText('发现网段，CIDR格式')
        .onChange((value: string) => { this.vm.setCidr(value); }).onSubmit(() => { this.start(); })
    }.width('100%')
  }
  @Builder
  StartButton() {
    Button(this.vm.isRunning ? (this.vm.cancelled ? '正在停止' : '停止') : '开始发现', { type: ButtonType.Capsule, stateEffect: true })
      .id('lan-start')
      .fontSize(16).fontColor($r('app.color.ui_on_accent')).constraintSize({ minHeight: 44 })
      .width(this.wide() ? 160 : '100%').backgroundColor(this.vm.isRunning ? UiTheme.danger : UiTheme.accent)
      .enabled(!this.vm.isRunning || !this.vm.cancelled)
      .onClick(() => { if (this.vm.isRunning) { this.vm.stop(); } else { this.start(); } })
  }
  build() {
    Column() {
      UiPageHeader({ contentWidth: this.contentWidth, title: '局域网', inset: this.inset() })
      Scroll() {
        Column({ space: 16 }) {
          Column({ space: 16 }) {
            if (this.wide()) {
              Row({ space: 24 }) {
                Column() {
                  this.CidrField()
                }.layoutWeight(1)
                this.StartButton()
              }.width('100%')
            } else {
              this.CidrField()
            }
            Text('预计探测 ' + this.vm.hostCount() + ' 台主机').fontSize(14).fontColor(UiTheme.secondary).width('100%')
            Text('输入需要诊断的局域网网段；AP 隔离可能导致部分设备不可见。')
              .fontSize(14).fontColor(UiTheme.secondary).width('100%')
            if (this.vm.error.length > 0) {
              ErrorBanner({ message: this.vm.error, onClose: (): void => { this.vm.dismissError(); } })
            }
            if (!this.wide()) { this.StartButton() }
          }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(UiTheme.surface).borderRadius(12)
          if (this.vm.total > 0) {
            UiScanProgress({ done: this.vm.done, total: this.vm.total, running: this.vm.isRunning,
              cancelled: this.vm.cancelled, failed: this.vm.failed, detail: this.vm.summaryLabel() + ' · ' + this.vm.elapsedLabel() })
          }
          Column() {
            if (this.wide() && this.vm.onlineHosts.length > 0) {
              Row({ space: 16 }) {
                Text('IP 地址').width(180)
                Text('开放端口').layoutWeight(1)
                Text('主机名').layoutWeight(1)
              }.width('100%').padding({ top: 12, bottom: 12 }).foregroundColor(UiTheme.secondary)
            }
            ForEach(this.vm.onlineHosts, (host: HostResult) => { this.HostRow(host) }, (host: HostResult) => host.ip)
            if (this.vm.onlineHosts.length === 0) {
              Text(this.vm.isRunning ? '正在发现，结果将在探测结束后汇总…' : this.vm.total === 0 ? '设置网段后开始发现设备' :
                this.vm.failed ? '发现未完成，请检查网段与网络后重试' : this.vm.cancelled ? '发现已停止，暂无设备结果' : '未发现在线设备。请检查网段；AP 隔离也可能影响发现。')
                .fontSize(16).fontColor(UiTheme.secondary).width('100%').padding({ top: 24, bottom: 24 })
            }
          }.width('100%').padding(16).backgroundColor(UiTheme.surface).borderRadius(12)
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: this.inset(), right: this.inset(), bottom: 24 })
      }.width('100%').layoutWeight(1).align(Alignment.Top)
    }.width('100%').height('100%').backgroundColor(UiTheme.background)
  }
}
