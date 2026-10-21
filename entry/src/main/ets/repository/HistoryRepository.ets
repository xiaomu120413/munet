import { common } from '@kit.AbilityKit';
import { DiscoveredHost, ExportFormat, ScanRecord } from '../model/HistoryInfo';
import { HostResult } from '../model/ScanInfo';
import { exportHistory as exportToFile } from '../services/HistoryExporter';
import {
  addScanRecord as addRecord,
  clearAll as clearStore,
  initialize as initializeStore,
  isReady as storeIsReady,
  queryDiscoveredHosts as queryHosts,
  queryScanRecords as queryRecords,
  upsertDiscoveredHosts as upsertHosts
} from '../store/HistoryStore';

/**
 * Use-case level access to persisted scan history and discovered hosts.
 */
export class HistoryRepository {
  async initialize(context: common.Context): Promise<void> {
    return initializeStore(context);
  }

  isReady(): boolean {
    return storeIsReady();
  }

  async addScanRecord(record: ScanRecord): Promise<void> {
    return addRecord(record);
  }

  async queryScanRecords(): Promise<ScanRecord[]> {
    return queryRecords();
  }

  async upsertHosts(hosts: HostResult[], names: Map<string, string>): Promise<void> {
    return upsertHosts(hosts, names);
  }

  async queryHosts(): Promise<DiscoveredHost[]> {
    return queryHosts();
  }

  async exportHistory(context: common.Context, format: ExportFormat): Promise<boolean> {
    const records: ScanRecord[] = await queryRecords();
    return exportToFile(context, records, format);
  }

  async clearAll(): Promise<void> {
    return clearStore();
  }
}
