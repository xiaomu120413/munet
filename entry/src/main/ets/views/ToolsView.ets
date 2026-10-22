import { UiTheme } from './UiTheme';
import { UiPageHeader } from './UiPageHeader';

interface ToolEntry {
  title: string;
  detail: string;
  icon: Resource;
}

@Component
export struct ToolsView {
  onSelect: (index: number) => void = () => {};
  private tools: ToolEntry[] = [
    { title: 'Ping', detail: 'TCP 连通性探测', icon: $r('sys.symbol.waveform_path_ecg_square') },
    { title: '端口扫描', detail: '探测开放端口或本机占用端口', icon: $r('sys.symbol.square_grid_2x2') },
    { title: '局域网', detail: '发现当前网段的设备', icon: $r('sys.symbol.wifi_router') }
  ];

  build() {
    Column() {
      UiPageHeader({ title: '工具' })
      Scroll() {
        Column() {
          ForEach(this.tools, (tool: ToolEntry, index: number) => {
            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Row({ space: 16 }) {
                SymbolGlyph(tool.icon).fontSize(24).fontColor([UiTheme.text])
                Column({ space: 6 }) {
                  Text(tool.title).fontSize(18).fontWeight(FontWeight.Medium).fontColor(UiTheme.text)
                  Text(tool.detail).fontSize(14).fontColor(UiTheme.secondary)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([UiTheme.secondary])
              }.width('100%').constraintSize({ minHeight: 80 }).padding(16)
            }
            .width('100%').borderRadius(8).backgroundColor(UiTheme.surface)
            .accessibilityText(tool.title + '，' + tool.detail)
            .onClick(() => { this.onSelect(index + 1); })
            Divider().color(UiTheme.divider)
          }, (tool: ToolEntry) => tool.title)
        }.width('100%').padding({ left: 16, right: 16, bottom: 24 })
      }.layoutWeight(1).width('100%').align(Alignment.Top)
    }.width('100%').height('100%').backgroundColor(UiTheme.background)
  }
}
