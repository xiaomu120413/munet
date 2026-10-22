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
  @Builder
  Detail(label: string, value: string) {
    Row({ space: 16 }) {
      Text(label).fontSize(16).fontColor(UiTheme.secondary).width(96)
      Text(value).fontSize(16).fontColor(UiTheme.text).layoutWeight(1).copyOption(CopyOptions.InApp)
    }.width('100%').padding({ top: 16, bottom: 16 }).alignItems(VerticalAlign.Top)
    Divider().color(UiTheme.divider)
  }
  build() {
    Column() {
      UiPageHeader({ title: this.title, inset: this.inset() })
      Scroll() {
        Column({ space: 24 }) {
          Row({ space: 16 }) {
            Image($r('app.media.app_icon')).width(72).height(72).borderRadius(16)
            Column({ space: 8 }) {
              Text('木络 · MuNet').fontSize(22).fontWeight(FontWeight.Medium).fontColor(UiTheme.text)
              Text('网络状态与连接诊断').fontSize(16).fontColor(UiTheme.secondary)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }.width('100%')
          Column() {
            this.Detail('应用版本', this.vm.appVersion())
            this.Detail('核心版本', this.vm.coreVersion())
            this.Detail('应用标识', this.vm.bundleName())
          }.width('100%')
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
