import { copyText } from '../services/Clipboard';

/**
 * Repository boundary for platform clipboard access, keeping ViewModels free
 * of direct service imports (see DESIGN §4.1.2).
 */
export class ClipboardRepository {
  async copy(text: string): Promise<boolean> {
    return copyText(text);
  }
}
