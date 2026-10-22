import { common } from '@kit.AbilityKit';
import { HostResult } from '../model/ScanInfo';
import { LanDiscoveryViewModel } from '../viewmodel/LanDiscoveryViewModel';
import { ErrorBanner } from './ErrorBanner';

const LARGE_SWEEP_THRESHOLD: number = 1024;

/**
 * LAN discovery view: CIDR input, sweep progress, online hosts and mDNS
 * hostnames. Pure rendering + event forwarding; state is in the ViewModel.
 */
@Component
export struct LanDiscoveryView {
  /** CIDR injected by the shell when re-scanning from history. */
  pendingCidr: string = '';

  @ObjectLink vm: LanDiscoveryViewModel;

  aboutToAppear(): void {
    this.vm.setContext(getContext(this) as common.Context);
    if (this.pendingCidr.length > 0) {
      this.vm.setCidr(this.pendingCidr);
    } else {
      this.vm.loadDefaultCidr();
    }
  }

  aboutToDisappear(): void {
    this.vm.leave();
  }

  onStart(): void {
    const count: number = this.vm.hostCount();
    if (count > LARGE_SWEEP_THRESHOLD) {
      this.getUIContext().showAlertDialog({
        title: '扫描范围较大',
        message: '该网段含 ' + count + ' 台主机，扫描可能较慢。',
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

  onCidrChange(value: string): void {
    this.vm.setCidr(value);
  }

  onDismissError(): void {
    this.vm.dismissError();
  }

  @Builder
  PortChip(port: number) {
    Text(String(port))
      .fontSize(10)
      .fontColor('#2E7D32')
      .backgroundColor('#E6F4EA')
      .padding({ left: 5, right: 5, top: 1, bottom: 1 })
      .borderRadius(3)
      .margin({ right: 4 })
  }

  @Builder
  HostRow(host: HostResult) {
    Row() {
      Text(host.ip).fontSize(13).fontWeight(FontWeight.Medium).width(150)
      Row() {
        ForEach(host.openPorts, (port: number) => {
          this.PortChip(port)
        }, (port: number) => String(port))
      }
      .width(120)
      Text(this.vm.hostnameFor(host.ip)).fontSize(11).fontColor('#777777').layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('局域网').fontSize(24).fontWeight(FontWeight.Bold)
          Text('子网设备发现').fontSize(12).fontColor('#888888').margin({ top: 2 })
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
          Button('开始发现')
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
            Text('网段').fontSize(13).fontColor('#666666').width(52)
            TextInput({ text: this.vm.cidr, placeholder: '192.168.1.0/24' })
              .fontSize(13)
              .height(36)
              .layoutWeight(1)
              .borderRadius(8)
              .backgroundColor('#F5F6F8')
              .onChange((value: string) => {
                this.onCidrChange(value);
              })
              .onSubmit((enterKey: EnterKeyType) => {
                this.onStart();
              })
            Text(this.vm.hostCount() + ' 台')
              .fontSize(11)
              .fontColor('#999999')
              .margin({ left: 10 })
          }
          .width('100%')

          Text('仅扫描本机所在网段；若路由器开启 AP 隔离，部分设备可能不可见。')
            .fontSize(11)
            .fontColor('#999999')
            .margin({ top: 10 })

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

          ForEach(this.vm.onlineHosts, (host: HostResult) => {
            this.HostRow(host)
          }, (host: HostResult) => host.ip)

          if (!this.vm.isRunning && this.vm.total > 0 && this.vm.onlineHosts.length === 0) {
            Text('未发现在线设备；若确认网段正确，可能是路由器开启了 AP 隔离')
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
