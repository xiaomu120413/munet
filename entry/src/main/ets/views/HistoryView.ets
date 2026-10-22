import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { DiscoveredHost, ExportFormat, ScanKind, ScanRecord } from '../model/HistoryInfo';
import { HistoryViewModel } from '../viewmodel/HistoryViewModel';
import { ErrorBanner } from './ErrorBanner';

/**
 * History view: persisted scan records and the discovered-host archive, with
 * kind filter, export, re-scan and clear actions.
 */
@Component
export struct HistoryView {
  /** Injected by the shell; navigates to the corresponding scan page. */
  onRescan: (kind: ScanKind, target: string) => void = () => {
  };

  @ObjectLink vm: HistoryViewModel;

  aboutToAppear(): void {
    this.vm.load();
  }

  onFilter(kind: ScanKind | undefined): void {
    this.vm.selectFilter(kind);
  }

  onShowView(showHosts: boolean): void {
    this.vm.showView(showHosts);
  }

  onExport(format: ExportFormat): void {
    const context: common.Context = getContext(this) as common.Context;
    this.vm.export(context, format).then((saved: boolean) => {
      promptAction.openToast({
        message: saved ? '已导出' : '未导出',
        duration: 1500
      }).catch(() => {
      });
    });
  }

  onRescanRecord(record: ScanRecord): void {
    this.onRescan(record.kind, record.target);
  }

  onClear(): void {
    this.getUIContext().showAlertDialog({
      title: '清空记录',
      message: '将删除全部扫描记录与设备档案，操作不可恢复。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '清空',
        action: () => {
          this.vm.clear();
        }
      }
    });
  }

  onDismissError(): void {
    this.vm.dismissError();
  }

  @Builder
  ModeChip(showHosts: boolean, label: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.vm.showHosts === showHosts ? '#FFFFFF' : '#444444')
      .backgroundColor(this.vm.showHosts === showHosts ? '#0A59F7' : '#F0F1F3')
      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
      .borderRadius(14)
      .margin({ right: 8 })
      .onClick(() => {
        this.onShowView(showHosts);
      })
  }

  @Builder
  FilterChip(kind: ScanKind | undefined, label: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.vm.filterKind === kind ? '#FFFFFF' : '#444444')
      .backgroundColor(this.vm.filterKind === kind ? '#0A59F7' : '#F0F1F3')
      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
      .borderRadius(14)
      .margin({ right: 8 })
      .onClick(() => {
        this.onFilter(kind);
      })
  }

  @Builder
  RecordRow(record: ScanRecord) {
    Column() {
      Row() {
        Text(this.vm.formatTime(record.ts))
          .fontSize(11)
          .fontColor('#888888')
          .width(100)
        Text(this.vm.kindLabel(record.kind))
          .fontSize(11)
          .fontColor('#5B7DB1')
          .backgroundColor('#EAF2FC')
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(4)
          .width(64)
          .textAlign(TextAlign.Center)
        Text(record.target).fontSize(13).fontColor('#333333').layoutWeight(1)
        Text('再扫')
          .fontSize(11)
          .fontColor('#0A59F7')
          .onClick(() => {
            this.onRescanRecord(record);
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.vm.summaryText(record))
        .fontSize(11)
        .fontColor('#666666')
        .margin({ top: 3 })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  HostRow(host: DiscoveredHost) {
    Column() {
      Row() {
        Text(host.ip).fontSize(14).fontWeight(FontWeight.Medium).layoutWeight(1)
        Text(this.vm.hostNameLabel(host)).fontSize(11).fontColor('#777777')
      }
      .width('100%')

      Row() {
        Text('端口 ' + this.vm.hostPortsLabel(host))
          .fontSize(11)
          .fontColor('#2E7D32')
          .layoutWeight(1)
        Text('最近 ' + this.vm.formatTime(host.lastSeen))
          .fontSize(10)
          .fontColor('#999999')
      }
      .width('100%')
      .margin({ top: 3 })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('记录').fontSize(24).fontWeight(FontWeight.Bold)
          Text('扫描历史与设备档案').fontSize(12).fontColor('#888888').margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Button('刷新')
          .fontSize(12)
          .height(30)
          .backgroundColor('#F0F1F3')
          .fontColor('#333333')
          .onClick(() => {
            this.vm.load();
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

      Row() {
        this.ModeChip(false, '扫描记录')
        this.ModeChip(true, '设备档案')
        Blank()
        if (!this.vm.showHosts) {
          Button('CSV')
            .fontSize(12)
            .height(30)
            .backgroundColor('#F0F1F3')
            .fontColor('#333333')
            .margin({ right: 8 })
            .onClick(() => {
              this.onExport(ExportFormat.CSV);
            })
          Button('JSON')
            .fontSize(12)
            .height(30)
            .backgroundColor('#F0F1F3')
            .fontColor('#333333')
            .margin({ right: 8 })
            .onClick(() => {
              this.onExport(ExportFormat.JSON);
            })
        }
        if (this.vm.records.length > 0 || this.vm.hosts.length > 0) {
          Button('清空')
            .fontSize(12)
            .height(30)
            .backgroundColor('#B3261E')
            .onClick(() => {
              this.onClear();
            })
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 4, bottom: 8 })

      if (!this.vm.showHosts) {
        Row() {
          this.FilterChip(undefined, '全部')
          this.FilterChip(ScanKind.PING, 'Ping')
          this.FilterChip(ScanKind.PORT_SCAN, '端口扫描')
          this.FilterChip(ScanKind.LAN_DISCOVERY, '局域网')
          Blank()
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 8 })
      }

      Scroll() {
        Column() {
          if (this.vm.isLoading) {
            Column() {
              LoadingProgress().width(32).height(32).color('#0A59F7')
            }
            .width('100%')
            .padding({ top: 50 })
            .alignItems(HorizontalAlign.Center)
          } else if (!this.vm.showHosts) {
            ForEach(this.vm.records, (record: ScanRecord) => {
              this.RecordRow(record)
            }, (record: ScanRecord) => String(record.id))
            if (this.vm.records.length === 0) {
              Text('暂无记录，扫描完成后会出现在这里')
                .fontSize(13)
                .fontColor('#999999')
                .width('100%')
                .textAlign(TextAlign.Center)
                .margin({ top: 50 })
            }
          } else {
            ForEach(this.vm.hosts, (host: DiscoveredHost) => {
              this.HostRow(host)
            }, (host: DiscoveredHost) => host.ip)
            if (this.vm.hosts.length === 0) {
              Text('暂无设备档案，完成局域网发现后会出现在这里')
                .fontSize(13)
                .fontColor('#999999')
                .width('100%')
                .textAlign(TextAlign.Center)
                .margin({ top: 50 })
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
    .backgroundColor('#FAFAFA')
  }
}
