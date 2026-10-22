import { PingRecord } from '../model/ScanInfo';
import { common } from '@kit.AbilityKit';
import { PingViewModel } from '../viewmodel/PingViewModel';
import { ErrorBanner } from './ErrorBanner';
import { UiTheme } from './UiTheme';
import { UiPageHeader } from './UiPageHeader';

@Component
export struct PingView {
  @ObjectLink vm: PingViewModel;
  @State contentWidth: number = 0;
  private ports: number[] = [80, 443, 22, 3389, 8080];
  private counts: number[] = [1, 4, 10];
  private wide(): boolean { return UiTheme.supportsWide(this.contentWidth, this.getUIContext().getHostContext() as common.Context); }
  private inset(): number { return this.contentWidth >= 600 ? 24 : 16; }
  aboutToDisappear(): void { this.vm.leave(); }

  @Builder
  Parameters() {
    Column({ space: 16 }) {
      Text('TCP 连通性探测').fontSize(14).fontColor(UiTheme.secondary).width('100%')
      Row({ space: 12 }) {
        Text('目标').fontSize(16).fontColor(UiTheme.text).width(64)
        TextInput({ text: this.vm.target, placeholder: 'IP 或域名' })
          .fontSize(16).fontColor(UiTheme.text).backgroundColor(UiTheme.background)
          .constraintSize({ minHeight: 44 }).layoutWeight(1).borderRadius(12)
          .enabled(!this.vm.isRunning).accessibilityText('探测目标，IP或域名')
          .onChange((value: string) => { this.vm.setTarget(value); })
          .onSubmit(() => { this.vm.start(); })
      }.width('100%')
      Flex({ direction: this.wide() ? FlexDirection.Row : FlexDirection.Column }) {
        Column({ space: 12 }) {
          Row({ space: 12 }) {
            Text('端口').fontSize(16).fontColor(UiTheme.text).width(64)
            Select([{ value: '80' }, { value: '443' }, { value: '22' }, { value: '3389' }, { value: '8080' }])
              .value(this.vm.smartFallback ? '自动回退' : String(this.vm.selectedPort))
              .selected(this.ports.indexOf(this.vm.selectedPort)).font({ size: 16 })
              .enabled(!this.vm.isRunning && !this.vm.smartFallback)
              .constraintSize({ minHeight: 44 }).layoutWeight(1).accessibilityText('探测端口')
              .onSelect((index: number) => { this.vm.selectPort(this.ports[index]); })
          }.width('100%')
          Row() {
            Text('智能回退').fontSize(16).fontColor(UiTheme.text).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.vm.smartFallback }).enabled(!this.vm.isRunning)
              .accessibilityText('智能回退').onChange((value: boolean) => {
                if (value !== this.vm.smartFallback) { this.vm.toggleSmartFallback(); }
              })
          }.width('100%').constraintSize({ minHeight: 44 })
          Text('探测 443、80、22、8080、3389，任一可达即成功')
            .fontSize(14).fontColor(UiTheme.secondary).width('100%')
        }.width(this.wide() ? '50%' : '100%').padding({ right: this.wide() ? 24 : 0, bottom: 16 })
        Column({ space: 12 }) {
          Row({ space: 12 }) {
            Text('次数').fontSize(16).fontColor(UiTheme.text).width(64)
            Select([{ value: '1 次' }, { value: '4 次' }, { value: '10 次' }])
              .value(this.vm.continuous ? '持续探测' : this.vm.count + ' 次')
              .selected(this.counts.indexOf(this.vm.count)).font({ size: 16 })
              .enabled(!this.vm.isRunning && !this.vm.continuous)
              .constraintSize({ minHeight: 44 }).layoutWeight(1).accessibilityText('探测次数')
              .onSelect((index: number) => { this.vm.setCount(this.counts[index]); })
          }.width('100%')
          Row() {
            Text('持续模式').fontSize(16).fontColor(UiTheme.text).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.vm.continuous }).enabled(!this.vm.isRunning)
              .accessibilityText('持续模式').onChange((value: boolean) => {
                if (value !== this.vm.continuous) { this.vm.toggleContinuous(); }
              })
          }.width('100%').constraintSize({ minHeight: 44 })
        }.width(this.wide() ? '50%' : '100%')
      }.width('100%')
      Button(this.vm.isRunning ? (this.vm.cancelled ? '正在停止' : '停止') : '开始', { type: ButtonType.Capsule, stateEffect: true })
        .fontSize(16).constraintSize({ minHeight: 44 }).width(this.wide() ? 144 : '100%')
        .backgroundColor(this.vm.isRunning ? UiTheme.danger : UiTheme.accent)
        .fontColor($r('app.color.ui_on_accent'))
        .enabled(!this.vm.isRunning || !this.vm.cancelled)
        .onClick(() => { if (this.vm.isRunning) { this.vm.stop(); } else { this.vm.start(); } })
    }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
      .backgroundColor(UiTheme.surface).borderRadius(12)
  }

  @Builder
  RecordRow(record: PingRecord) {
    if (this.wide()) {
      Row({ space: 16 }) {
        Text(String(record.seq)).width(56).fontColor(UiTheme.secondary)
        Text(record.ok ? '成功' : this.vm.errorLabel(record.error))
          .width(120).fontColor(record.ok ? UiTheme.success : UiTheme.danger)
        Text(record.ok ? record.rttMs + ' ms' : '—').layoutWeight(1).fontColor(UiTheme.text)
        Text(record.port > 0 ? String(record.port) : '—').width(80).fontColor(UiTheme.text)
        Text(this.vm.formatTime(record.timestamp)).width(136).fontColor(UiTheme.secondary)
      }.width('100%').padding({ top: 14, bottom: 14 })
    } else {
      Column({ space: 8 }) {
        Row({ space: 12 }) {
          Text('#' + record.seq).fontSize(14).fontColor(UiTheme.secondary)
          Text(record.ok ? '成功' : this.vm.errorLabel(record.error)).fontSize(16)
            .fontColor(record.ok ? UiTheme.success : UiTheme.danger).layoutWeight(1)
          Text(record.ok ? record.rttMs + ' ms' : '—').fontSize(16).fontColor(UiTheme.text)
        }.width('100%')
        Text('端口 ' + (record.port > 0 ? String(record.port) : '—') + ' · ' + this.vm.formatTime(record.timestamp))
          .fontSize(14).fontColor(UiTheme.secondary).width('100%')
      }.width('100%').padding({ top: 14, bottom: 14 })
    }
    Divider().color(UiTheme.divider)
  }

  build() {
    Column() {
      UiPageHeader({ title: 'Ping', inset: this.inset() })
      Scroll() {
        Column({ space: 16 }) {
          this.Parameters()
          if (this.vm.error.length > 0) {
            ErrorBanner({ message: this.vm.error, onClose: (): void => { this.vm.dismissError(); } })
          }
          if (this.vm.resolvedAddress.length > 0) {
            Text('目标地址 ' + this.vm.resolvedAddress).fontSize(14).fontColor(UiTheme.secondary)
              .width('100%').wordBreak(WordBreak.BREAK_ALL)
          }
          Text('TCP 探测：目标端口关闭或防火墙拦截，不代表主机离线。')
            .fontSize(14).fontColor(UiTheme.secondary).width('100%')
          if (this.vm.stats.sent > 0) {
            Text('发送 ' + this.vm.stats.sent + '   接收 ' + this.vm.stats.received + '   丢失 ' +
              this.vm.stats.lossPercent + '%\n平均 ' + (this.vm.stats.received > 0 ? this.vm.stats.avgMs + ' ms' : '—') +
              '   最小 ' + (this.vm.stats.received > 0 ? this.vm.stats.minMs + ' ms' : '—') +
              '   最大 ' + (this.vm.stats.received > 0 ? this.vm.stats.maxMs + ' ms' : '—'))
              .fontSize(16).fontColor(UiTheme.text).width('100%')
          }
          Column() {
            if (this.wide() && this.vm.records.length > 0) {
              Row({ space: 16 }) {
                Text('序号').width(56)
                Text('结果').width(120)
                Text('耗时').layoutWeight(1)
                Text('端口').width(80)
                Text('时间').width(136)
              }.width('100%').padding({ top: 12, bottom: 12 }).foregroundColor(UiTheme.secondary)
            }
            ForEach(this.vm.records, (record: PingRecord) => { this.RecordRow(record) },
              (record: PingRecord) => record.seq + '-' + record.timestamp)
            if (this.vm.records.length === 0) {
              Text(this.vm.isRunning ? '正在解析目标或等待探测结果…' : '输入目标后开始 TCP 探测')
                .fontSize(16).fontColor(UiTheme.secondary).width('100%').padding({ top: 24, bottom: 24 })
            }
          }.width('100%').padding(16).backgroundColor(UiTheme.surface).borderRadius(12)
        }.width('100%').alignItems(HorizontalAlign.Start)
          .padding({ left: this.inset(), right: this.inset(), bottom: 24 })
      }.width('100%').layoutWeight(1).align(Alignment.Top).scrollBar(BarState.Auto)
    }.width('100%').height('100%').backgroundColor(UiTheme.background)
      .onAreaChange((oldArea: Area, newArea: Area) => { this.contentWidth = Number(newArea.width); })
  }
}
