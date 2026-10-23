import { UiTheme } from './UiTheme';
import { UiAction } from './UiAction';
import { common } from '@kit.AbilityKit';

@Component
export struct UiPageHeader {
  @Prop title: string = '';
  @Prop inset: number = 16;
  @Prop actionLabel: string = '';
  @Prop actionEnabled: boolean = true;
  @Prop contentWidth: number = 0;
  onAction: () => void = () => {};
  private stacked(): boolean {
    return this.actionLabel.length > 0 && this.contentWidth <
      UiTheme.labelWidth(280, this.getUIContext().getHostContext() as common.Context);
  }

  build() {
    Column({ space: 8 }) {
      if (this.stacked()) {
        Text(this.title).fontSize(24).fontWeight(FontWeight.Medium)
          .fontColor(UiTheme.text).width('100%').accessibilityLevel('yes')
        Row() {
          UiAction({ label: this.actionLabel, icon: $r('sys.symbol.arrow_clockwise'),
            actionEnabled: this.actionEnabled, onAction: this.onAction })
        }.width('100%').justifyContent(FlexAlign.End)
      } else {
        Row({ space: 12 }) {
          Text(this.title).fontSize(24).fontWeight(FontWeight.Medium)
            .fontColor(UiTheme.text).layoutWeight(1).accessibilityLevel('yes')
          if (this.actionLabel.length > 0) {
            UiAction({ label: this.actionLabel, icon: $r('sys.symbol.arrow_clockwise'),
              actionEnabled: this.actionEnabled, onAction: this.onAction })
          }
        }.width('100%')
      }
    }
    .width('100%')
    .padding({ left: this.inset, right: this.inset, top: 16, bottom: 16 })
  }
}
