import { ExportFormat, ScanRecord } from '../model/HistoryInfo';

/**
 * Pure serialization for history export. No platform IO, so it can be unit
 * tested independently of the document picker.
 */

interface ExportItem {
  ts: number;
  kind: string;
  target: string;
  status: string;
  summary: string;
}

function pad(value: number): string {
  return value < 10 ? '0' + value : String(value);
}

export function buildExportFileName(format: ExportFormat): string {
  const now: Date = new Date();
  const stamp: string = String(now.getFullYear()) + pad(now.getMonth() + 1) + pad(now.getDate()) +
    '-' + pad(now.getHours()) + pad(now.getMinutes());
  return 'nettools-history-' + stamp + '.' + (format === ExportFormat.CSV ? 'csv' : 'json');
}

function csvEscape(value: string): string {
  return '"' + value.replace(/"/g, '""') + '"';
}

export function recordsToCsv(records: ScanRecord[]): string {
  const lines: string[] = ['time,kind,target,status,summary'];
  for (const record of records) {
    lines.push(csvEscape(new Date(record.ts).toISOString()) + ',' +
      csvEscape(record.kind) + ',' + csvEscape(record.target) + ',' +
      csvEscape(record.status) + ',' + csvEscape(record.summary));
  }
  return lines.join('\r\n');
}

export function recordsToJson(records: ScanRecord[]): string {
  const items: ExportItem[] = [];
  for (const record of records) {
    const item: ExportItem = {
      ts: record.ts,
      kind: record.kind,
      target: record.target,
      status: record.status,
      summary: record.summary
    };
    items.push(item);
  }
  return JSON.stringify(items, null, 2);
}
