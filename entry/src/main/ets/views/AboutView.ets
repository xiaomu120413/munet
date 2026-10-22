import { DebugViewModel } from '../viewmodel/DebugViewModel';
import { AboutViewModel } from '../viewmodel/AboutViewModel';

/**
 * About view: version info, privacy policy placeholder and disclaimer.
 */
@Component
export struct AboutView {
  @State showDiagnostics: boolean = false;
  @State selfTest: string = '';
  private debugVm: DebugViewModel = new DebugViewModel();
  @State vm: AboutViewModel = new AboutViewModel();

  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(12).fontColor('#888888').width(96)
      Text(value).fontSize(13).fontColor('#333333').layoutWeight(1)
    }
    .width('100%')
    .margin({ top: 8 })
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  Diagnostics() {
    Column() {
      Button(this.showDiagnostics ? '收起开发诊断' : '开发诊断')
        .fontSize(13)
        .fontColor('#59616B')
        .backgroundColor(Color.Transparent)
        .borderRadius(6)
        .onClick(() => {
          this.showDiagnostics = !this.showDiagnostics;
        })
      if (this.showDiagnostics) {
        Text('仅用于开发排查').fontSize(13).fontColor('#59616B')
        Button('运行原生探测自检')
          .fontSize(13)
          .margin({ top: 8 })
          .onClick(() => {
            this.selfTest = this.debugVm.probeSelfTest();
          })
        if (this.selfTest.length > 0) {
          Text(this.selfTest).fontSize(13).fontColor('#333333').margin({ top: 8 })
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .margin({ top: 16 })
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('关于').fontSize(24).fontWeight(FontWeight.Bold)
          Text('版本 · 隐私 · 声明').fontSize(12).fontColor('#888888').margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 8 })

      Scroll() {
        Column() {
          Column() {
            Image($r('app.media.app_icon')).width(72).height(72).borderRadius(16)
              .accessibilityText('木络应用图标').margin({ bottom: 12 })
            Text($r('app.string.app_brand')).fontSize(20).fontWeight(FontWeight.Bold)
            Text('本地网络诊断工具箱').fontSize(12).fontColor('#888888').margin({ top: 4 })
            Divider().margin({ top: 12, bottom: 4 })
            this.InfoRow('应用版本', this.vm.appVersion())
            this.InfoRow('原生核心', this.vm.coreVersion())
            this.InfoRow('包名', this.vm.bundleName())
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .border({ width: 1, color: '#ECECEC' })

          Column() {
            Text('隐私政策').fontSize(15).fontWeight(FontWeight.Medium)
            Text(this.vm.privacyPolicyNote())
              .fontSize(12)
              .fontColor('#666666')
              .margin({ top: 8 })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .border({ width: 1, color: '#ECECEC' })
          .margin({ top: 10 })

          Column() {
            Text('使用声明').fontSize(15).fontWeight(FontWeight.Medium)
            Text(this.vm.disclaimer())
              .fontSize(12)
              .fontColor('#666666')
              .margin({ top: 8 })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .border({ width: 1, color: '#ECECEC' })
          .margin({ top: 10 })
          if (this.debugVm.isDebug()) {
            this.Diagnostics()
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
