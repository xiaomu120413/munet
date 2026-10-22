import { UiTheme } from './UiTheme';
import { UiAction } from './UiAction';

@Component
export struct UiPageHeader {
  @Prop title: string = '';
  @Prop inset: number = 16;
  @Prop actionLabel: string = '';
  @Prop actionEnabled: boolean = true;
  onAction: () => void = () => {};

  build() {
    Row({ space: 12 }) {
      Text(this.title).fontSize(24).fontWeight(FontWeight.Medium)
        .fontColor(UiTheme.text).layoutWeight(1).accessibilityLevel('yes')
      if (this.actionLabel.length > 0) {
        UiAction({ label: this.actionLabel, icon: $r('sys.symbol.arrow_clockwise'),
          actionEnabled: this.actionEnabled, onAction: this.onAction })
      }
    }
    .width('100%')
    .padding({ left: this.inset, right: this.inset, top: 16, bottom: 16 })
  }
}
