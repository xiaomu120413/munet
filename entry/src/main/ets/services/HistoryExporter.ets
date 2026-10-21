import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ExportFormat, ScanRecord } from '../model/HistoryInfo';
import { buildExportFileName, recordsToCsv, recordsToJson } from './HistoryExportFormat';

/**
 * Data source: writes scan history to a user-chosen file via the system
 * document picker. Serialization lives in HistoryExportFormat.
 */
export async function exportHistory(context: common.Context, records: ScanRecord[],
  format: ExportFormat): Promise<boolean> {
  if (records.length === 0) {
    return false;
  }
  const content: string = format === ExportFormat.CSV
    ? recordsToCsv(records)
    : recordsToJson(records);

  const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
  const options: picker.DocumentSaveOptions = {
    newFileNames: [buildExportFileName(format)]
  };
  const uris: string[] = await documentPicker.save(options);
  if (uris.length === 0) {
    return false;
  }

  const file: fs.File = fs.openSync(uris[0],
    fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
  try {
    fs.writeSync(file.fd, content);
    hilog.info(0x0000, 'NetTools', 'history exported %{public}d bytes as %{public}s',
      content.length, format);
  } finally {
    fs.closeSync(file);
  }
  return true;
}
