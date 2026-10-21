import BuildProfile from 'BuildProfile';
import { SystemRepository } from '../repository/SystemRepository';

/**
 * ViewModel for the About view: build/version information, privacy policy
 * placeholder and the usage disclaimer (compliance, see DESIGN §12).
 */
export class AboutViewModel {
  private readonly systemRepo: SystemRepository;

  constructor(systemRepo: SystemRepository = new SystemRepository()) {
    this.systemRepo = systemRepo;
  }

  appVersion(): string {
    return BuildProfile.VERSION_NAME;
  }

  coreVersion(): string {
    return this.systemRepo.coreVersion();
  }

  bundleName(): string {
    return BuildProfile.BUNDLE_NAME;
  }

  privacyPolicyNote(): string {
    return '上架版本将在此展示隐私政策链接（由 AGC 隐私托管生成，零数据收集声明）。';
  }

  disclaimer(): string {
    return '本工具仅用于诊断自有或经授权的网络。请勿对未经授权的网络或设备进行探测。';
  }
}
