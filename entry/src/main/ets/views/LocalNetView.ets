import { promptAction } from '@kit.ArkUI';
import { IfaceInfo, LinkAddr, NicInfo, WifiInfo } from '../model/NetworkInfo';
import { LocalNetViewModel } from '../viewmodel/LocalNetViewModel';
import { ErrorBanner } from './ErrorBanner';

/**
 * Local-network view. Pure rendering + event forwarding: all state and
 * async work live in LocalNetViewModel.
 */
@Component
export struct LocalNetView {
  @State twoColumns: boolean = false;
  @State vm: LocalNetViewModel = new LocalNetViewModel();

  aboutToAppear(): void {
    this.vm.load();
  }

  onCopy(text: string): void {
    this.vm.copy(text).then((ok: boolean) => {
      promptAction.openToast({
        message: ok ? '已复制 ' + text : '复制失败',
        duration: 1200
      }).catch(() => {
      });
    });
  }

  onRefresh(): void {
    this.vm.load();
  }

  onDismissError(): void {
    this.vm.dismissError();
  }

  @Builder
  StatusCard() {
    Row() {
      Text(this.vm.isConnected ? '●' : '○')
        .fontSize(14)
        .fontColor(this.vm.isConnected ? '#2E7D32' : '#999999')
        .margin({ right: 10 })
      Column() {
        Text(this.vm.statusTitle).fontSize(16).fontWeight(FontWeight.Medium)
        if (this.vm.statusDetail.length > 0) {
          Text(this.vm.statusDetail).fontSize(20).fontWeight(FontWeight.Bold).margin({ top: 4 })
        }
        if (this.vm.statusNote.length > 0) {
          Text(this.vm.statusNote).fontSize(13).fontColor('#59616B').margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(6)
    .border({ width: 1, color: '#DDE1E6' })
  }

  @Builder
  AddressRow(addr: LinkAddr) {
    Row() {
      Text(addr.family === 'v4' ? 'v4' : 'v6')
        .fontSize(10)
        .fontColor('#45617E')
        .backgroundColor('#EAF2FC')
        .padding({ left: 5, right: 5, top: 1, bottom: 1 })
        .borderRadius(3)
        .margin({ right: 8 })
      Text(addr.address + '/' + addr.prefixLength).fontSize(15).fontWeight(FontWeight.Medium)
        .layoutWeight(1).wordBreak(WordBreak.BREAK_ALL)
      Text('复制')
        .fontSize(13)
        .fontColor('#2159A6')
        .padding({ left: 10, top: 6, bottom: 6 })
        .onClick(() => {
          this.onCopy(addr.address);
        })
    }
    .width('100%')
    .margin({ top: 6 })
  }

  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(13).fontColor('#59616B').width(72)
      Text(value).fontSize(14).fontColor('#24292F').layoutWeight(1)
        .wordBreak(WordBreak.BREAK_ALL)
    }
    .width('100%')
    .margin({ top: 6 })
    .alignItems(VerticalAlign.Top)
    .onClick(() => {
      this.onCopy(value);
    })
  }

  @Builder
  NicCard(nic: NicInfo) {
    Column() {
      Row() {
        Text(nic.interfaceName).fontSize(16).fontWeight(FontWeight.Medium)
        if (nic.bearerTypes.length > 0) {
          Text(nic.bearerTypes.join(' · '))
            .fontSize(11)
            .fontColor('#45617E')
            .backgroundColor('#EAF2FC')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(4)
            .margin({ left: 8 })
        }
        if (nic.isDefault) {
          Text('默认')
            .fontSize(11)
            .fontColor('#2E7D32')
            .backgroundColor('#E6F4EA')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(4)
            .margin({ left: 6 })
        }
        Blank()
      }
      .width('100%')

      Divider().margin({ top: 10, bottom: 4 })

      ForEach(nic.linkAddresses, (addr: LinkAddr) => {
        this.AddressRow(addr)
      }, (addr: LinkAddr) => addr.address)

      if (nic.linkAddresses.length === 0) {
        Text('无地址').fontSize(13).fontColor('#59616B').margin({ top: 4 })
      }

      if (nic.gateway.length > 0) {
        this.InfoRow('网关', nic.gateway)
      }
      if (nic.dns.length > 0) {
        this.InfoRow('DNS', nic.dns.join(' · '))
      }
      this.InfoRow('MTU', String(nic.mtu))
      if (nic.domains.length > 0) {
        this.InfoRow('搜索域', nic.domains)
      }
      if (nic.ipv4Valid !== undefined || nic.ipv6Valid !== undefined) {
        Row() {
          Text('协议').fontSize(13).fontColor('#59616B').width(72)
          if (nic.ipv4Valid !== undefined) {
            Text('IPv4 ' + (nic.ipv4Valid === true ? '可用' : '不可用'))
              .fontSize(12)
              .fontColor(nic.ipv4Valid === true ? '#2E7D32' : '#B3261E')
              .margin({ right: 12 })
          }
          if (nic.ipv6Valid !== undefined) {
            Text('IPv6 ' + (nic.ipv6Valid === true ? '可用' : '不可用'))
              .fontSize(12)
              .fontColor(nic.ipv6Valid === true ? '#2E7D32' : '#B3261E')
          }
        }
        .width('100%')
        .margin({ top: 6 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(6)
    .border({ width: 1, color: '#DDE1E6' })
    .margin({ top: 10 })
  }

  @Builder
  WifiCard(wifi: WifiInfo) {
    Column() {
      Row() {
        Text('Wi-Fi 连接').fontSize(16).fontWeight(FontWeight.Medium)
        Blank()
        Text(wifi.ssid).fontSize(13).fontColor('#444C56').layoutWeight(1)
          .textAlign(TextAlign.End).margin({ left: 12 })
      }
      .width('100%')

      Divider().margin({ top: 10, bottom: 4 })

      this.InfoRow('信号', wifi.rssi + ' dBm')
      this.InfoRow('频段', this.vm.bandLabel(wifi.band) + ' · ' + wifi.frequency + ' MHz')
      this.InfoRow('速率', wifi.linkSpeed + ' Mbps')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(6)
    .border({ width: 1, color: '#DDE1E6' })
    .margin({ top: 10 })
  }

  @Builder
  IfaceCard() {
    Column() {
      Row() {
        Text('全部网卡').fontSize(16).fontWeight(FontWeight.Medium)
        Blank()
      }
      .width('100%')

      Divider().margin({ top: 10, bottom: 4 })

      ForEach(this.vm.ifaces, (iface: IfaceInfo) => {
        Row() {
          Text(iface.name).fontSize(13).fontWeight(FontWeight.Medium).width(72)
          Text(iface.family === 'v4' ? 'v4' : 'v6')
            .fontSize(10)
            .fontColor('#45617E')
            .backgroundColor('#EAF2FC')
            .padding({ left: 5, right: 5, top: 1, bottom: 1 })
            .borderRadius(3)
            .margin({ right: 8 })
          Text(iface.address + '/' + iface.prefixLength).fontSize(13).layoutWeight(1)
            .wordBreak(WordBreak.BREAK_ALL)
          if (iface.loopback) {
            Text('回环').fontSize(12).fontColor('#59616B').margin({ left: 6 })
          }
          if (!iface.up) {
            Text('未启用').fontSize(12).fontColor('#B3261E').margin({ left: 6 })
          }
        }
        .width('100%')
        .margin({ top: 6 })
      }, (iface: IfaceInfo) => iface.name + '|' + iface.address)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(6)
    .border({ width: 1, color: '#DDE1E6' })
    .margin({ top: 10 })
  }

  @Builder
  NetworkCards() {
    ForEach(this.vm.nics, (nic: NicInfo) => {
      this.NicCard(nic)
    }, (nic: NicInfo) => String(nic.netId))
  }

  @Builder
  ConnectionCards() {
    if (this.vm.wifi !== null) {
      this.WifiCard(this.vm.wifi as WifiInfo)
    }
    if (this.vm.ifaces.length > 0) {
      this.IfaceCard()
    }
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('本机网络').fontSize(22).fontWeight(FontWeight.Medium)
          Text('查看当前连接与网络接口').fontSize(13).fontColor('#59616B').margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Button('刷新')
          .fontSize(13)
          .height(34)
          .borderRadius(6)
          .backgroundColor('#EFF2F6')
          .fontColor('#2159A6')
          .onClick(() => {
          this.onRefresh();
          })
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
          if (this.vm.isLoading) {
            Column() {
              LoadingProgress().width(36).height(36).color('#0A59F7')
              Text('正在读取网络信息…').fontSize(13).fontColor('#59616B').margin({ top: 8 })
            }
            .width('100%')
            .padding({ top: 60 })
            .alignItems(HorizontalAlign.Center)
          } else {
            this.StatusCard()
            if (this.twoColumns && this.vm.nics.length > 0 &&
              (this.vm.wifi !== null || this.vm.ifaces.length > 0)) {
              Row({ space: 16 }) {
                Column() {
                  this.NetworkCards()
                }
                .layoutWeight(1)
                Column() {
                  this.ConnectionCards()
                }
                .layoutWeight(1)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            } else {
              this.NetworkCards()
              this.ConnectionCards()
            }
            if (this.vm.nics.length === 0) {
              Text('未发现可用网络')
                .fontSize(13)
                .fontColor('#59616B')
                .margin({ top: 40 })
                .width('100%')
                .textAlign(TextAlign.Center)
            }
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
    .backgroundColor('#F7F8FA')
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.twoColumns = Number(newArea.width) >= 760;
    })
  }
}
