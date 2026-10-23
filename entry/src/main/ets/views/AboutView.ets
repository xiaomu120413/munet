import { AboutViewModel } from '../viewmodel/AboutViewModel';
import { DebugViewModel } from '../viewmodel/DebugViewModel';
import { UiTheme } from './UiTheme';
import { UiPageHeader } from './UiPageHeader';
import { UiAction } from './UiAction';

@Component
export struct AboutView {
  @Prop title: string = '关于';
  @State diagnostics: boolean = false;
  @State diagnosticResult: string = '';
  @State contentWidth: number = 0;
  private inset(): number { return this.contentWidth >= 600 ? 24 : 16; }
  private vm: AboutViewModel = new AboutViewModel();
  private debug: DebugViewModel = new DebugViewModel();
  build() {
    Column() {
      UiPageHeader({ title: this.title, inset: this.inset() })
      Scroll() {
        Column({ space: 24 }) {
          Row({ space: 16 }) {
            Image($r('app.media.app_icon')).width(72).height(72).borderRadius(16)
            Column({ space: 8 }) {
              Text('木络').fontSize(22).fontWeight(FontWeight.Medium).fontColor(UiTheme.text)
              Text('网络状态与连接诊断').fontSize(16).fontColor(UiTheme.secondary)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }.width('100%')
          Text('木络是一款本地网络诊断工具，帮助你查看网络状态、检查连接和发现局域网设备。')
            .fontSize(16).fontColor(UiTheme.text).lineHeight(25).width('100%')
          Column({ space: 12 }) {
            Text('可以做什么').fontSize(18).fontWeight(FontWeight.Medium).fontColor(UiTheme.text)
            Text('查看本机网络与 Wi-Fi 信息；通过 TCP 探测连接、扫描端口；发现局域网设备，并保存和导出扫描记录。')
              .fontSize(16).fontColor(UiTheme.secondary).lineHeight(25)
          }.width('100%').alignItems(HorizontalAlign.Start)
          Column({ space: 12 }) {
            Text('使用说明').fontSize(18).fontWeight(FontWeight.Medium).fontColor(UiTheme.text)
            Text(this.vm.disclaimer()).fontSize(16).fontColor(UiTheme.secondary).lineHeight(25)
          }.width('100%').alignItems(HorizontalAlign.Start)
          if (this.debug.isDebug()) {
            Column({ space: 12 }) {
              UiAction({ label: this.diagnostics ? '收起诊断信息' : '诊断信息',
                onAction: () => { this.diagnostics = !this.diagnostics; } })
              if (this.diagnostics) {
                Text('仅在调试版本显示').fontSize(14).fontColor(UiTheme.secondary)
                UiAction({ label: '运行核心自检', onAction: () => { this.diagnosticResult = this.debug.probeSelfTest(); } })
                if (this.diagnosticResult.length > 0) {
                  Text(this.diagnosticResult).fontSize(14).fontColor(UiTheme.secondary).copyOption(CopyOptions.InApp)
                }
              }
            }.width('100%').alignItems(HorizontalAlign.Start)
          }
        }.width('100%').constraintSize({ maxWidth: 840 }).padding({ left: this.inset(), right: this.inset(), top: 8, bottom: 32 })
      }.width('100%').layoutWeight(1).align(Alignment.TopStart)
    }.width('100%').height('100%').backgroundColor(UiTheme.background)
      .onAreaChange((_old: Area, area: Area) => { this.contentWidth = Number(area.width); })
  }
}
