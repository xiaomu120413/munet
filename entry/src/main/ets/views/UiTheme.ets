import { common } from '@kit.AbilityKit';

/** Semantic resources have base/dark variants and follow the system theme. */
export class UiTheme {
  static labelWidth(width: number, context: common.Context | undefined): number {
    const scale: number = (context as common.UIAbilityContext | undefined)?.config.fontSizeScale ?? 1;
    return width * Math.min(2, Math.max(1, scale));
  }
  static supportsWide(width: number, context: common.Context | undefined, threshold: number = 768): boolean {
    const scale: number = (context as common.UIAbilityContext | undefined)?.config.fontSizeScale ?? 1;
    return width >= threshold * Math.max(1, scale);
  }
  static readonly background: Resource = $r('app.color.ui_background');
  static readonly surface: Resource = $r('app.color.ui_surface');
  static readonly text: Resource = $r('app.color.ui_text');
  static readonly secondary: Resource = $r('app.color.ui_secondary');
  static readonly accent: Resource = $r('app.color.ui_accent');
  static readonly selected: Resource = $r('app.color.ui_selected');
  static readonly divider: Resource = $r('app.color.ui_divider');
  static readonly success: Resource = $r('app.color.ui_success');
  static readonly danger: Resource = $r('app.color.ui_danger');
  static readonly errorSurface: Resource = $r('app.color.ui_error_surface');
}
