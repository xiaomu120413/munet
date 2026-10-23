import { describe, expect, it } from '@ohos/hypium';
import { ExportFormat, ScanKind, ScanRecord, ScanStatus } from '../../../main/ets/model/HistoryInfo';
import { deriveCidr, hostCountForCidr } from '../../../main/ets/net/Subnet';
import {
  buildExportFileName,
  recordsToCsv,
  recordsToJson
} from '../../../main/ets/services/HistoryExportFormat';

/**
 * Unit tests for pure modules: subnet helpers and export serialization.
 * Run with: aa test -b com.muge.munet -m entry_test -s unittest OpenHarmonyTestRunner
 */
export default function netToolsUnitTest() {
  describe('Subnet', () => {
    it('deriveCidr_truncatesHostBits', 0, () => {
      expect(deriveCidr('192.168.1.23', 24)).assertEqual('192.168.1.0/24');
      expect(deriveCidr('10.0.2.15', 16)).assertEqual('10.0.0.0/16');
      expect(deriveCidr('172.30.1.2', 23)).assertEqual('172.30.0.0/23');
    });

    it('deriveCidr_rejectsInvalidInput', 0, () => {
      expect(deriveCidr('999.1.1.1', 24)).assertEqual('');
      expect(deriveCidr('1.2.3', 24)).assertEqual('');
      expect(deriveCidr('1.2.3.4', 33)).assertEqual('');
    });

    it('hostCountForCidr', 0, () => {
      expect(hostCountForCidr('192.168.1.0/24')).assertEqual(254);
      expect(hostCountForCidr('100.70.104.0/23')).assertEqual(510);
      expect(hostCountForCidr('127.0.0.1/32')).assertEqual(1);
      expect(hostCountForCidr('bad')).assertEqual(0);
    });
  });

  describe('HistoryExportFormat', () => {
    it('csv_hasHeaderAndEscapesQuotes', 0, () => {
      const record: ScanRecord = {
        id: 1,
        ts: 0,
        kind: ScanKind.PING,
        target: 'a"b',
        status: ScanStatus.DONE,
        summary: '{"x":1}'
      };
      const lines: string[] = recordsToCsv([record]).split('\r\n');
      expect(lines.length).assertEqual(2);
      expect(lines[0]).assertEqual('time,kind,target,status,summary');
      expect(lines[1]).assertContain('"a""b"');
    });

    it('json_containsKindAndStatus', 0, () => {
      const record: ScanRecord = {
        id: 1,
        ts: 0,
        kind: ScanKind.PORT_SCAN,
        target: 'x',
        status: ScanStatus.CANCELLED,
        summary: '{}'
      };
      const json: string = recordsToJson([record]);
      expect(json).assertContain('portscan');
      expect(json).assertContain('cancelled');
    });

    it('csv_treatsFormulaLikeTargetsAsTextAndJsonPreservesOriginal', 0, () => {
      for (const target of ['=1+1', '+SUM(1,2)', '-1+2', '@SUM(1,2)', '  =1+1', '\tformula', '\rformula', '\nformula',
        '＝1+1', '＋1+1', '－1+1', '＠SUM(1,2)']) {
        const record: ScanRecord = { id: 1, ts: 0, kind: ScanKind.PING, target: target,
          status: ScanStatus.ERROR, summary: '{}' };
        const csv: string = recordsToCsv([record]);
        expect(csv).assertContain('"\'' + target + '"');
        const parsed: ScanRecord[] = JSON.parse(recordsToJson([record])) as ScanRecord[];
        expect(parsed[0].target).assertEqual(target);
      }
      const ordinary: ScanRecord = { id: 1, ts: 0, kind: ScanKind.PING, target: '木络.example',
        status: ScanStatus.DONE, summary: '{}' };
      expect(recordsToCsv([ordinary])).assertContain('"木络.example"');
    });

    it('fileName_hasExpectedSuffix', 0, () => {
      expect(buildExportFileName(ExportFormat.CSV)).assertContain('.csv');
      expect(buildExportFileName(ExportFormat.JSON)).assertContain('.json');
    });
  });
}
