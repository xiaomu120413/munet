import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { IfaceInfo, LinkAddr, NicInfo, WifiInfo } from '../model/NetworkInfo';
import { LocalNetViewModel } from '../viewmodel/LocalNetViewModel';
import { ErrorBanner } from './ErrorBanner';
import { UiTheme } from './UiTheme';
import { UiAction } from './UiAction';
import { UiPageHeader } from './UiPageHeader';

@Component
export struct LocalNetView {
  @ObjectLink vm: LocalNetViewModel;
  // The shell supplies the width before the first content frame.
  @Prop contentWidth: number = 0;

  aboutToAppear(): void { if (!this.vm.hasLoaded) { this.vm.load(); } }
  private wide(): boolean { return UiTheme.supportsWide(this.contentWidth, this.getUIContext().getHostContext() as common.Context, 720); }
  private inset(): number { return this.contentWidth >= 600 ? 24 : 16; }
  private copy(value: string): void {
    this.vm.copy(value).then((ok: boolean) => {
      promptAction.openToast({ message: ok ? '已复制' : '复制失败，请重试', duration: 1200 }).catch(() => {});
    });
  }

  @Builder
  SectionTitle(title: string) {
    Text(title).fontSize(18).fontWeight(FontWeight.Medium).fontColor(UiTheme.text)
      .width('100%').margin({ bottom: 12 })
  }

  @Builder
  InfoRow(label: string, value: string) {
    if (this.contentWidth < 320) {
      Column({ space: 8 }) {
        Text(label).fontSize(14).fontColor(UiTheme.secondary).width('100%')
        Text(value).fontSize(16).fontColor(UiTheme.text).width('100%')
          .wordBreak(WordBreak.BREAK_ALL).copyOption(CopyOptions.LocalDevice)
      }.width('100%').padding({ top: 10, bottom: 10 })
    } else {
    Row({ space: 12 }) {
      Text(label).fontSize(14).fontColor(UiTheme.secondary)
        .width(UiTheme.labelWidth(76, this.getUIContext().getHostContext() as common.Context))
      Text(value).fontSize(16).fontColor(UiTheme.text).layoutWeight(1)
        .wordBreak(WordBreak.BREAK_ALL).copyOption(CopyOptions.LocalDevice)
    }.width('100%').constraintSize({ minHeight: 44 }).alignItems(VerticalAlign.Top)
      .padding({ top: 10, bottom: 10 })
    }
    Divider().color(UiTheme.divider)
  }

  @Builder
  AddressRow(addr: LinkAddr) {
    if (this.contentWidth < 320) {
      Column({ space: 8 }) {
        Row() {
          Text(addr.family === 'v4' ? 'IPv4' : 'IPv6').fontSize(14).fontColor(UiTheme.secondary).layoutWeight(1)
          UiAction({ label: '复制', onAction: (): void => { this.copy(addr.address); } })
        }.width('100%')
        Text(addr.address + '/' + addr.prefixLength).fontSize(16).fontColor(UiTheme.text)
          .width('100%').wordBreak(WordBreak.BREAK_ALL).copyOption(CopyOptions.LocalDevice)
      }.width('100%').padding({ top: 8, bottom: 8 })
    } else {
    Row({ space: 8 }) {
      Text(addr.family === 'v4' ? 'IPv4' : 'IPv6').fontSize(14).fontColor(UiTheme.secondary).width(76)
      Text(addr.address + '/' + addr.prefixLength).fontSize(16).fontColor(UiTheme.text)
        .layoutWeight(1).wordBreak(WordBreak.BREAK_ALL).copyOption(CopyOptions.LocalDevice)
      UiAction({ label: '复制', onAction: (): void => { this.copy(addr.address); } })
    }.width('100%').padding({ top: 8, bottom: 8 }).alignItems(VerticalAlign.Top)
    }
    Divider().color(UiTheme.divider)
  }

  @Builder
  NicSection(nic: NicInfo) {
    Column() {
      Row({ space: 8 }) {
        Text(nic.interfaceName).fontSize(18).fontWeight(FontWeight.Medium).fontColor(UiTheme.text)
        Text(nic.bearerTypes.join(' · ') + (nic.isDefault ? ' · 默认' : ''))
          .fontSize(14).fontColor(UiTheme.secondary).layoutWeight(1)
      }.width('100%').margin({ bottom: 12 })
      ForEach(nic.linkAddresses, (addr: LinkAddr) => { this.AddressRow(addr) },
        (addr: LinkAddr) => addr.family + '|' + addr.address)
      if (nic.linkAddresses.length === 0) { this.InfoRow('地址', '无地址') }
      if (nic.gateway.length > 0) { this.InfoRow('网关', nic.gateway) }
      if (nic.dns.length > 0) { this.InfoRow('DNS', nic.dns.join('\n')) }
      this.InfoRow('MTU', String(nic.mtu))
      if (nic.domains.length > 0) { this.InfoRow('搜索域', nic.domains) }
      if (nic.ipv4Valid !== undefined) { this.InfoRow('IPv4', nic.ipv4Valid ? '可用' : '不可用') }
      if (nic.ipv6Valid !== undefined) { this.InfoRow('IPv6', nic.ipv6Valid ? '可用' : '不可用') }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
      .backgroundColor(UiTheme.surface).borderRadius(12).margin({ bottom: 16 })
  }

  @Builder
  Networks() {
    Column() {
      this.SectionTitle('网络信息')
      ForEach(this.vm.nics, (nic: NicInfo) => { this.NicSection(nic) }, (nic: NicInfo) => String(nic.netId))
      if (this.vm.nics.length === 0) {
        Text('当前无默认网络连接').fontSize(16).fontColor(UiTheme.secondary).padding(16)
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  WifiSection(wifi: WifiInfo) {
    Column() {
      this.SectionTitle('Wi-Fi 信息')
      Column() {
        this.InfoRow('SSID', wifi.ssid.length > 0 ? wifi.ssid : '—')
        this.InfoRow('信号', wifi.rssi + ' dBm')
        this.InfoRow('频段', this.vm.bandLabel(wifi.band) + ' · ' + wifi.frequency + ' MHz')
        this.InfoRow('连接速率', wifi.linkSpeed + ' Mbps')
      }.width('100%').padding(16).backgroundColor(UiTheme.surface).borderRadius(12)
    }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 16 })
  }

  @Builder
  InterfaceRow(iface: IfaceInfo) {
    if (this.wide()) {
      Row({ space: 16 }) {
        Text(iface.name).fontSize(16).fontColor(UiTheme.text).width(104)
        Text(iface.family === 'v4' ? 'IPv4' : 'IPv6').fontSize(14).fontColor(UiTheme.secondary).width(56)
        Text(iface.address + '/' + iface.prefixLength).fontSize(16).fontColor(UiTheme.text)
          .layoutWeight(1).wordBreak(WordBreak.BREAK_ALL).copyOption(CopyOptions.LocalDevice)
        Text(!iface.up ? '未启用' : iface.loopback ? '回环' : '—')
          .fontSize(14).fontColor(UiTheme.secondary).width(64)
      }.width('100%').constraintSize({ minHeight: 48 }).padding({ top: 10, bottom: 10 })
    } else {
      Column({ space: 6 }) {
        Row({ space: 12 }) {
          Text(iface.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor(UiTheme.text).layoutWeight(1)
          Text(!iface.up ? '未启用' : iface.loopback ? '回环' : '')
            .fontSize(14).fontColor(UiTheme.secondary)
        }.width('100%')
        Text((iface.family === 'v4' ? 'IPv4  ' : 'IPv6  ') + iface.address + '/' + iface.prefixLength)
          .fontSize(16).fontColor(UiTheme.secondary).width('100%').wordBreak(WordBreak.BREAK_ALL)
          .copyOption(CopyOptions.LocalDevice)
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 12, bottom: 12 })
    }
    Divider().color(UiTheme.divider)
  }

  @Builder
  Interfaces() {
    Column() {
      this.SectionTitle('全部网卡')
      Column() {
        if (this.wide()) {
          Row({ space: 16 }) {
            Text('接口').width(104)
            Text('协议').width(56)
            Text('地址').layoutWeight(1)
            Text('状态').width(64)
          }.width('100%').padding({ top: 12, bottom: 12 }).backgroundColor(UiTheme.background)
            .foregroundColor(UiTheme.secondary)
        }
        ForEach(this.vm.ifaces, (iface: IfaceInfo) => { this.InterfaceRow(iface) },
          (iface: IfaceInfo) => iface.name + '|' + iface.family + '|' + iface.address)
        if (this.vm.ifaces.length === 0) {
          Text('未读取到网卡信息').fontSize(14).fontColor(UiTheme.secondary).padding(16)
        }
      }.width('100%').padding(16).backgroundColor(UiTheme.surface).borderRadius(12)
    }.width('100%').alignItems(HorizontalAlign.Start).margin({ top: 8 })
  }

  build() {
    Column() {
      UiPageHeader({ contentWidth: this.contentWidth, title: '本机网络', inset: this.inset(), actionLabel: this.vm.isLoading ? '刷新中' : '刷新',
        actionEnabled: !this.vm.isLoading, onAction: (): void => { this.vm.load(); } })
      if (this.vm.error.length > 0) {
        ErrorBanner({ message: this.vm.error, onClose: (): void => { this.vm.dismissError(); } })
      }
      Scroll() {
        Column({ space: 16 }) {
          if (!this.vm.hasLoaded && this.vm.isLoading) {
            LoadingProgress().width(36).height(36).color(UiTheme.accent)
            Text('正在读取网络信息…').fontSize(14).fontColor(UiTheme.secondary)
          } else {
            Row({ space: 12 }) {
              SymbolGlyph($r('sys.symbol.worldclock')).fontSize(24).fontColor([UiTheme.accent])
              Column({ space: 4 }) {
                Text(this.vm.statusTitle).fontSize(16).fontWeight(FontWeight.Medium).fontColor(UiTheme.text)
                Text(this.vm.isConnected ? '默认网络已连接' : '当前无默认网络连接')
                  .fontSize(14).fontColor(UiTheme.secondary)
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              if (this.wide() && this.vm.statusDetail.length > 0) {
                Text(this.vm.statusDetail).fontSize(16).fontColor(UiTheme.text)
              }
            }.width('100%').padding(16).backgroundColor(UiTheme.surface).borderRadius(12)
            // Flex changes direction while keeping children and their state stable.
            Flex({ direction: this.wide() && this.vm.wifi !== null ? FlexDirection.Row : FlexDirection.Column, alignItems: ItemAlign.Start }) {
              Column() { this.Networks() }
                .width(this.wide() && this.vm.wifi !== null ? '55%' : '100%')
                .padding({ right: this.wide() && this.vm.wifi !== null ? 16 : 0 })
              if (this.vm.wifi !== null) {
                Column() { this.WifiSection(this.vm.wifi as WifiInfo) }
                  .width(this.wide() ? '45%' : '100%')
              }
            }.width('100%')
            this.Interfaces()
          }
        }.width('100%').alignItems(HorizontalAlign.Start)
          .padding({ left: this.inset(), right: this.inset(), bottom: 24 })
      }.layoutWeight(1).width('100%').align(Alignment.Top).scrollBar(BarState.Auto)
    }.width('100%').height('100%').backgroundColor(UiTheme.background)
  }
}
