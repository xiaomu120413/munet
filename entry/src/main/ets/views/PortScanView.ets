import { PortResult, PortScanMode } from '../model/ScanInfo';
import { PortScanViewModel } from '../viewmodel/PortScanViewModel';
import { ErrorBanner } from './ErrorBanner';

const LARGE_SCAN_THRESHOLD: number = 4096;

/**
 * Port-scan view: port-set selection, scan parameters, progress and results.
 * Pure rendering + event forwarding; state lives in PortScanViewModel.
 */
@Component
export struct PortScanView {
  /** Target injected by the shell when re-scanning from history. */
  pendingTarget: string = '';

  @ObjectLink vm: PortScanViewModel;

  aboutToAppear(): void {
    if (this.pendingTarget === '本机') {
      this.vm.setScanLocalHost(true);
    } else if (this.pendingTarget.length > 0) {
      this.vm.setTarget(this.pendingTarget);
    }
  }

  aboutToDisappear(): void {
    this.vm.leave();
  }

  onStart(): void {
    const probes: number = this.vm.expectedProbes();
    if (probes > LARGE_SCAN_THRESHOLD) {
      this.getUIContext().showAlertDialog({
        title: '扫描范围较大',
        message: '本次将发起 ' + probes + ' 次探测，可能需要较长时间。',
        primaryButton: {
          value: '取消',
          action: () => {
          }
        },
        secondaryButton: {
          value: '开始',
          action: () => {
            this.vm.start();
          }
        }
      });
      return;
    }
    this.vm.start();
  }

  onStop(): void {
    this.vm.stop();
  }

  onTargetChange(value: string): void {
    this.vm.setTarget(value);
  }

  onModeSelect(mode: PortScanMode): void {
    this.vm.selectMode(mode);
  }

  onExprChange(value: string): void {
    this.vm.setCustomExpr(value);
  }

  onConcurrencySelect(value: number): void {
    this.vm.setConcurrency(value);
  }

  onTimeoutSelect(value: number): void {
    this.vm.setTimeoutMs(value);
  }

  onDismissError(): void {
    this.vm.dismissError();
  }

  @Builder
  ModeChip(mode: PortScanMode, label: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.vm.mode === mode ? '#FFFFFF' : '#444444')
      .backgroundColor(this.vm.mode === mode ? '#0A59F7' : '#F0F1F3')
      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
      .borderRadius(14)
      .margin({ right: 8 })
      .onClick(() => {
        this.onModeSelect(mode);
      })
  }

  @Builder
  ConcurrencyChip(value: number) {
    Text(String(value))
      .fontSize(12)
      .fontColor(this.vm.concurrency === value ? '#FFFFFF' : '#444444')
      .backgroundColor(this.vm.concurrency === value ? '#0A59F7' : '#F0F1F3')
      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
      .borderRadius(14)
      .margin({ right: 8 })
      .onClick(() => {
        this.onConcurrencySelect(value);
      })
  }

  @Builder
  TimeoutChip(value: number) {
    Text(String(value) + ' ms')
      .fontSize(12)
      .fontColor(this.vm.timeoutMs === value ? '#FFFFFF' : '#444444')
      .backgroundColor(this.vm.timeoutMs === value ? '#0A59F7' : '#F0F1F3')
      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
      .borderRadius(14)
      .margin({ right: 8 })
      .onClick(() => {
        this.onTimeoutSelect(value);
      })
  }

  @Builder
  PortRow(result: PortResult) {
    Row() {
      Text(String(result.port)).fontSize(14).fontWeight(FontWeight.Medium).width(64)
      Text(this.vm.scanLocalHost ? '占用' : '开放')
        .fontSize(11)
        .fontColor('#2E7D32')
        .backgroundColor('#E6F4EA')
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .borderRadius(4)
        .margin({ right: 10 })
      Text(this.vm.serviceLabel(result.port)).fontSize(12).fontColor('#666666').width(130)
      Text(result.rttMs + ' ms').fontSize(12).fontColor('#888888')
      Blank()
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('端口扫描').fontSize(24).fontWeight(FontWeight.Bold)
          Text('TCP connect 扫描').fontSize(12).fontColor('#888888').margin({ top: 2 })
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
          Button('开始扫描')
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
            if (this.vm.scanLocalHost) {
              Text('本机（127.0.0.1、::1 与本机 IPv4 地址）')
                .fontSize(13)
                .fontColor('#555555')
                .layoutWeight(1)
            } else {
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
          }
          .width('100%')

          Row() {
            Text('扫描本机').fontSize(13).fontColor('#666666').width(52)
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.vm.scanLocalHost })
              .onChange((isOn: boolean) => {
                this.vm.setScanLocalHost(isOn);
              })
          }
          .width('100%')
          .margin({ top: 8 })

          Text('列出本机正在监听的端口；扫描 127.0.0.1、::1 与本机所有 IPv4 地址')
            .fontSize(10)
            .fontColor('#999999')
            .margin({ top: 2, left: 52 })

          Row() {
            Text('端口').fontSize(13).fontColor('#666666').width(52)
            this.ModeChip(PortScanMode.COMMON, '常用')
            this.ModeChip(PortScanMode.WEB, 'Web')
            this.ModeChip(PortScanMode.TOP1024, '1-1024')
            this.ModeChip(PortScanMode.CUSTOM, '自定义')
            Blank()
            Text(this.vm.portCount() + ' 个')
              .fontSize(11)
              .fontColor('#999999')
          }
          .width('100%')
          .margin({ top: 10 })

          if (this.vm.mode === PortScanMode.CUSTOM) {
            Row() {
              Text('表达式').fontSize(13).fontColor('#666666').width(52)
              TextInput({ text: this.vm.customExpr, placeholder: '80,443,1000-2000' })
                .fontSize(13)
                .height(36)
                .layoutWeight(1)
                .borderRadius(8)
                .backgroundColor('#F5F6F8')
                .onChange((value: string) => {
                  this.onExprChange(value);
                })
            }
            .width('100%')
            .margin({ top: 8 })
          }

          Row() {
            Text('并发').fontSize(13).fontColor('#666666').width(52)
            this.ConcurrencyChip(32)
            this.ConcurrencyChip(64)
            this.ConcurrencyChip(128)
            this.ConcurrencyChip(256)
            Blank()
          }
          .width('100%')
          .margin({ top: 8 })

          Row() {
            Text('超时').fontSize(13).fontColor('#666666').width(52)
            this.TimeoutChip(800)
            this.TimeoutChip(1500)
            this.TimeoutChip(3000)
            Blank()
          }
          .width('100%')
          .margin({ top: 8 })

          if (this.vm.total > 0) {
            Column() {
              Progress({ value: this.vm.done, total: this.vm.total, type: ProgressType.Linear })
                .height(6)
                .width('100%')
                .color('#0A59F7')
              Row() {
                Text(this.vm.done + ' / ' + this.vm.total)
                  .fontSize(11)
                  .fontColor('#666666')
                Blank()
                Text(this.vm.elapsedLabel()).fontSize(11).fontColor('#666666')
              }
              .width('100%')
              .margin({ top: 4 })
            }
            .width('100%')
            .margin({ top: 12 })
          }

          if (!this.vm.isRunning && this.vm.total > 0) {
            Text(this.vm.summaryLabel())
              .fontSize(12)
              .fontColor('#555555')
              .margin({ top: 8 })
          }

          Divider().margin({ top: 12, bottom: 2 })

          ForEach(this.vm.openResults, (result: PortResult) => {
            this.PortRow(result)
          }, (result: PortResult) => String(result.port))

          if (!this.vm.isRunning && this.vm.total > 0 && this.vm.openResults.length === 0) {
            Text(this.vm.scanLocalHost ? '未发现被占用的端口' : '未发现开放端口')
              .fontSize(13)
              .fontColor('#999999')
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 30 })
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
