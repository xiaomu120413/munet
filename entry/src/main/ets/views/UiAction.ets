import { UiTheme } from './UiTheme';

/** A real Button supplies native pressed, hover, keyboard and focus behavior. */
@Component
export struct UiAction {
  @Prop label: string = '';
  icon: Resource | undefined = undefined;
  @Prop actionEnabled: boolean = true;
  onAction: () => void = () => {};

  build() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 6 }) {
        if (this.icon !== undefined) {
          SymbolGlyph(this.icon).fontSize(20).fontColor([UiTheme.accent])
        }
        if (this.label.length > 0) {
          Text(this.label).fontSize(14).fontColor(UiTheme.accent)
        }
      }
      .padding({ left: 12, right: 12 })
      .constraintSize({ minWidth: 44, minHeight: 44 })
    }
    .constraintSize({ minWidth: 44, minHeight: 44 })
    .borderRadius(22)
    .backgroundColor(UiTheme.selected)
    .enabled(this.actionEnabled)
    .accessibilityText(this.label)
    .onClick(() => { this.onAction(); })
  }
}
