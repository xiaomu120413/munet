import { UiTheme } from './UiTheme';

@Component
export struct UiScanProgress {
  @Prop done: number = 0;
  @Prop total: number = 0;
  @Prop running: boolean = false;
  @Prop cancelled: boolean = false;
  @Prop failed: boolean = false;
  @Prop detail: string = '';
  build() {
    Column({ space: 8 }) {
      Progress({ value: this.done, total: Math.max(1, this.total), type: ProgressType.Linear })
        .width('100%').color(UiTheme.accent)
      Text((this.running ? (this.cancelled ? '正在停止' : '扫描中') : this.failed ? '扫描失败' : this.cancelled ? '已停止' : '已完成') +
        ' ' + this.done + '/' + this.total + ' · ' + this.detail)
        .fontSize(14).fontColor(UiTheme.secondary).width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
