import { PingRecord } from '../model/ScanInfo';
import { PingViewModel } from '../viewmodel/PingViewModel';
import { ErrorBanner } from './ErrorBanner';

/**
 * TCP ping view: target/port/count controls, live records and statistics.
 * Pure rendering + event forwarding; state lives in PingViewModel.
 */
@Component
export struct PingView {
  /** Target injected by the shell when re-scanning from history. */
  pendingTarget: string = '';

  @State vm: PingViewModel = new PingViewModel();

  aboutToAppear(): void {
    if (this.pendingTarget.length > 0) {
      this.vm.setTarget(this.pendingTarget);
    }
  }

  aboutToDisappear(): void {
    this.vm.leave();
  }

  onStart(): void {
    this.vm.start();
  }

  onStop(): void {
    this.vm.stop();
  }

  onTargetChange(value: string): void {
    this.vm.setTarget(value);
  }

  onToggleSmartFallback(): void {
    this.vm.toggleSmartFallback();
  }

  onToggleContinuous(): void {
    this.vm.toggleContinuous();
  }

  onDismissError(): void {
    this.vm.dismissError();
  }

  @Builder
  PortChip(port: number) {
    Text(String(port))
      .fontSize(12)
      .fontColor(!this.vm.smartFallback && this.vm.selectedPort === port ? '#FFFFFF' : '#444444')
      .backgroundColor(!this.vm.smartFallback && this.vm.selectedPort === port ? '#0A59F7' : '#F0F1F3')
      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
      .borderRadius(14)
      .margin({ right: 8 })
      .onClick(() => {
        this.vm.selectPort(port);
      })
  }

  @Builder
  CountChip(count: number) {
    Text(String(count))
      .fontSize(12)
      .fontColor(this.vm.count === count ? '#FFFFFF' : '#444444')
      .backgroundColor(this.vm.count === count ? '#0A59F7' : '#F0F1F3')
      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
      .borderRadius(14)
      .margin({ right: 8 })
      .onClick(() => {
        this.vm.setCount(count);
      })
  }

  @Builder
  RecordRow(record: PingRecord) {
    Row() {
      Text('#' + record.seq).fontSize(12).fontColor('#888888').width(44)
      Text(record.ok ? '✓' : '✗')
        .fontSize(13)
        .fontColor(record.ok ? '#2E7D32' : '#B3261E')
        .width(24)
      Text(record.ok ? record.rttMs + ' ms' : this.vm.errorLabel(record.error))
        .fontSize(13)
        .fontColor(record.ok ? '#333333' : '#B3261E')
        .layoutWeight(1)
      if (record.ok && record.port > 0) {
        Text(':' + record.port).fontSize(11).fontColor('#999999').margin({ right: 12 })
      }
      Text(this.vm.formatTime(record.timestamp)).fontSize(11).fontColor('#AAAAAA')
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('Ping').fontSize(24).fontWeight(FontWeight.Bold)
          Text('TCP 连通性探测').fontSize(12).fontColor('#888888').margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        if (this.vm.isRunning) {
          Button('停止')
            .fontSize(13)
            .height(32)
            .backgroundColor('#B3261E')
            .onClick(() => {
              this.onStop();
            })
        } else {
          Button('开始')
            .fontSize(13)
            .height(32)
            .onClick(() => {
              this.onStart();
            })
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 8 })

      if (this.vm.error.length > 0) {
        ErrorBanner({
          message: this.vm.error,
          onClose: (): void => {
            this.onDismissError();
          }
        })
      }

      Scroll() {
        Column() {
          Row() {
            Text('目标').fontSize(13).fontColor('#666666').width(52)
            TextInput({ text: this.vm.target, placeholder: 'IP 或域名，例如 192.168.1.1' })
              .fontSize(13)
              .height(36)
              .layoutWeight(1)
              .borderRadius(8)
              .backgroundColor('#F5F6F8')
              .onChange((value: string) => {
                this.onTargetChange(value);
              })
              .onSubmit((enterKey: EnterKeyType) => {
                this.onStart();
              })
          }
          .width('100%')

          Row() {
            Text('端口').fontSize(13).fontColor('#666666').width(52)
            this.PortChip(80)
            this.PortChip(443)
            this.PortChip(22)
            this.PortChip(3389)
            this.PortChip(8080)
            Blank()
          }
          .width('100%')
          .margin({ top: 10 })

          Row() {
            Text('智能回退').fontSize(13).fontColor('#666666').width(52)
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.vm.smartFallback })
              .onChange((isOn: boolean) => {
                this.onToggleSmartFallback();
              })
          }
          .width('100%')
          .margin({ top: 6 })

          Text('自动尝试 443→80→22→8080→3389，任一可达即成功')
            .fontSize(10)
            .fontColor('#999999')
            .margin({ top: 2, left: 52 })

          Row() {
            Text('次数').fontSize(13).fontColor('#666666').width(52)
            this.CountChip(1)
            this.CountChip(4)
            this.CountChip(10)
            Blank()
            Text('持续模式').fontSize(12).fontColor('#666666').margin({ right: 6 })
            Toggle({ type: ToggleType.Switch, isOn: this.vm.continuous })
              .onChange((isOn: boolean) => {
                this.onToggleContinuous();
              })
          }
          .width('100%')
          .margin({ top: 6 })

          if (this.vm.resolvedAddress.length > 0) {
            Text(this.vm.target.trim() + ' → ' + this.vm.resolvedAddress)
              .fontSize(12)
              .fontColor('#5B7DB1')
              .margin({ top: 12 })
          }

          Text('TCP 探测（非 ICMP）：目标端口关闭或防火墙拦截会显示超时/拒绝，不代表主机离线。')
            .fontSize(11)
            .fontColor('#999999')
            .margin({ top: 10 })

          if (this.vm.stats.sent > 0) {
            Row() {
              Text('发送 ' + this.vm.stats.sent).fontSize(12).fontColor('#555555')
              Text('接收 ' + this.vm.stats.received)
                .fontSize(12)
                .fontColor('#555555')
                .margin({ left: 12 })
              Text('丢失 ' + this.vm.stats.lossPercent + '%')
                .fontSize(12)
                .fontColor(this.vm.stats.lossPercent > 0 ? '#B3261E' : '#2E7D32')
                .margin({ left: 12 })
              if (this.vm.stats.received > 0) {
                Text('avg ' + this.vm.stats.avgMs + ' ms')
                  .fontSize(12)
                  .fontColor('#555555')
                  .margin({ left: 12 })
                Text('min ' + this.vm.stats.minMs)
                  .fontSize(12)
                  .fontColor('#555555')
                  .margin({ left: 12 })
                Text('max ' + this.vm.stats.maxMs)
                  .fontSize(12)
                  .fontColor('#555555')
                  .margin({ left: 12 })
              }
              Blank()
            }
            .width('100%')
            .padding({ top: 12, bottom: 6 })
          }

          Divider()

          ForEach(this.vm.records, (record: PingRecord) => {
            this.RecordRow(record)
          }, (record: PingRecord) => String(record.timestamp) + '-' + record.seq)

          if (this.vm.records.length === 0 && !this.vm.isRunning) {
            Text('尚未开始')
              .fontSize(13)
              .fontColor('#999999')
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 40 })
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 24 })
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FAFAFA')
  }
}
