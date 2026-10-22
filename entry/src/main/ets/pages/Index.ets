import { ScanKind } from '../model/HistoryInfo';
import { LocalNetView } from '../views/LocalNetView';
import { PingView } from '../views/PingView';
import { PortScanView } from '../views/PortScanView';
import { LanDiscoveryView } from '../views/LanDiscoveryView';
import { HistoryView } from '../views/HistoryView';
import { AboutView } from '../views/AboutView';

interface NavItem {
  title: string;
  short: string;
  subtitle: string;
}

/**
 * App shell: owns navigation state, assembles views and coordinates the
 * history "re-scan" jump. Holds no business logic or data access.
 */
@Entry
@Component
struct Index {
  @State current: number = 0;
  @State isWide: boolean = true;
  @State pendingKind: ScanKind | undefined = undefined;
  @State pendingTarget: string = '';


  private navItems: NavItem[] = [
    { title: '本机网络', short: '本机', subtitle: 'IP · 网关 · DNS' },
    { title: 'Ping', short: 'Ping', subtitle: 'TCP 连通性' },
    { title: '端口扫描', short: '端口', subtitle: '开放端口' },
    { title: '局域网', short: '局域网', subtitle: '设备发现' },
    { title: '记录', short: '记录', subtitle: '历史扫描' },
    { title: '关于', short: '关于', subtitle: '版本 · 隐私 · 声明' }
  ];

  /** Shell-level navigation for the history page's "re-scan" action. */
  private onRescanRequest(kind: ScanKind, target: string): void {
    this.pendingKind = kind;
    this.pendingTarget = target;
    if (kind === ScanKind.PING) {
      this.current = 1;
    } else if (kind === ScanKind.PORT_SCAN) {
      this.current = 2;
    } else {
      this.current = 3;
    }
  }

  @Builder
  NavButton(index: number) {
    Row() {
      Column() {
        Text(this.navItems[index].title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.current === index ? '#174B8C' : '#333333')
        Text(this.navItems[index].subtitle)
          .fontSize(12)
          .fontColor(this.current === index ? '#365D8A' : '#59616B')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 16, right: 12, top: 10, bottom: 10 })
    .borderRadius(8)
    .backgroundColor(this.current === index ? '#E6ECF4' : Color.Transparent)
    .margin({ bottom: 4 })
    .onClick(() => {
      this.pendingKind = undefined;
      this.pendingTarget = '';
      this.current = index;
    })
  }

  @Builder
  Content() {
    if (this.current === 0) {
      LocalNetView()
    } else if (this.current === 1) {
      PingView({ pendingTarget: this.pendingKind === ScanKind.PING ? this.pendingTarget : '' })
    } else if (this.current === 2) {
      PortScanView({
        pendingTarget: this.pendingKind === ScanKind.PORT_SCAN ? this.pendingTarget : ''
      })
    } else if (this.current === 3) {
      LanDiscoveryView({
        pendingCidr: this.pendingKind === ScanKind.LAN_DISCOVERY ? this.pendingTarget : ''
      })
    } else if (this.current === 4) {
      HistoryView({
        onRescan: (kind: ScanKind, target: string): void => {
          this.onRescanRequest(kind, target);
        }
      })
    } else {
      AboutView()
    }
  }

  @Builder
  SideNav() {
    Column() {
      Text('NetTools')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 4 })
      Text('网络诊断工具箱')
        .fontSize(12)
        .fontColor('#59616B')
        .margin({ bottom: 24 })
      ForEach(this.navItems, (item: NavItem, index: number) => {
        this.NavButton(index)
      }, (item: NavItem) => item.title)
      Blank()

    }
    .width(200)
    .height('100%')
    .padding(16)
    .backgroundColor('#F5F6F8')
  }

  @Builder
  BottomNav() {
    Row() {
      ForEach(this.navItems, (item: NavItem, index: number) => {
        Column() {
          Text(item.short)
            .fontSize(10)
            .fontColor(this.current === index ? '#0A59F7' : '#666666')
        }
        .layoutWeight(1)
        .padding({ top: 9, bottom: 9 })
        .onClick(() => {
          this.pendingKind = undefined;
          this.pendingTarget = '';
          this.current = index;
        })
      }, (item: NavItem) => item.title)
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .border({ width: { top: 1 }, color: '#ECECEC' })
  }

  build() {
    Column() {
      Row() {
        if (this.isWide) {
          this.SideNav()
        }
        Column() {
          this.Content()
        }
        .layoutWeight(1)
        .height('100%')
      }
      .width('100%')
      .layoutWeight(1)

      if (!this.isWide) {
        this.BottomNav()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .onAreaChange((oldValue: Area, newValue: Area) => {
      const width: number = Number(newValue.width);
      this.isWide = width >= 600;
    })
  }
}
