import { UiTheme } from './UiTheme';

@Component
export struct ErrorBanner {
  @Prop message: string = '';
  onClose: () => void = () => {};

  build() {
    Row({ space: 8 }) {
      Text(this.message).fontSize(14).fontColor(UiTheme.danger).layoutWeight(1)
      Button('关闭', { type: ButtonType.Normal, stateEffect: true })
        .fontSize(14).fontColor(UiTheme.danger).backgroundColor(Color.Transparent)
        .constraintSize({ minWidth: 44, minHeight: 44 }).borderRadius(22)
        .accessibilityText('关闭错误提示').onClick(() => { this.onClose(); })
    }.width('100%').padding({ left: 16, right: 8 }).backgroundColor(UiTheme.errorSurface)
  }
}
