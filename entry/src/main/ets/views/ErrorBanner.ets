/**
 * Inline error banner shared by all pages: renders a message with a dismiss
 * action. The caller decides visibility (render only when a message is set).
 */
@Component
export struct ErrorBanner {
  message: string = '';
  onClose: () => void = () => {
  };

  build() {
    Row() {
      Text(this.message).fontSize(13).fontColor('#B3261E')
      Blank()
      Text('✕')
        .fontSize(13)
        .fontColor('#B3261E')
        .onClick(() => {
          this.onClose();
        })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor('#FCEEEE')
    .borderRadius(8)
    .margin({ left: 20, right: 20, top: 8 })
  }
}
