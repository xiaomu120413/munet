/** Semantic resources have base/dark variants and follow the system theme. */
export class UiTheme {
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
