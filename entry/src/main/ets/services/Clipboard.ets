import { pasteboard } from '@kit.BasicServicesKit';

/**
 * Platform service: write plain text to the system clipboard.
 * Returns false when the text is empty or the platform call fails.
 */
export async function copyText(text: string): Promise<boolean> {
  if (text.length === 0) {
    return false;
  }
  try {
    const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    await pasteboard.getSystemPasteboard().setData(data);
    return true;
  } catch (err) {
    return false;
  }
}
