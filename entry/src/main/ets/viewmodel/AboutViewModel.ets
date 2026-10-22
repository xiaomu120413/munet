import BuildProfile from 'BuildProfile';
import { SystemRepository } from '../repository/SystemRepository';

/**
 * ViewModel for the About view: build/version information and usage disclaimer.
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

  disclaimer(): string {
    return '本工具仅用于诊断自有或经授权的网络。请勿对未经授权的网络或设备进行探测。';
  }
}
