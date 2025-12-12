import type { InvoiceModel } from "./model";
import { InvoiceRepository } from "./repository";

/**
 * Service layer for Invoice operations
 * Decoupled from HTTP/Elysia context
 */
export abstract class InvoiceService {
  /**
   * Create a new invoice in staging
   */
  static async create(invoice: InvoiceModel.createBody): Promise<{
    staging_id: number;
    line_count: number;
  }> {
    // Insert header
    const stagingId = await InvoiceRepository.insertHeader(invoice);

    // Insert lines
    let lineCount = 0;
    if (invoice.lines?.length) {
      for (const line of invoice.lines) {
        await InvoiceRepository.insertLine(stagingId, line, invoice.user_id);
        lineCount++;
      }
    }

    return { staging_id: stagingId, line_count: lineCount };
  }

  /**
   * Get invoice status by staging ID
   */
  static async getStatus(stagingId: number): Promise<InvoiceModel.statusResponse | null> {
    return InvoiceRepository.getStatus(stagingId);
  }

  /**
   * Search invoice by number and optional org_id
   */
  static async search(
    invoiceNum: string,
    orgId?: number
  ): Promise<InvoiceModel.searchResponse | null> {
    return InvoiceRepository.search(invoiceNum, orgId);
  }

  /**
   * Process invoices: Validate → Transfer → Import
   */
  static async process(params: InvoiceModel.processBody): Promise<InvoiceModel.processResponse> {
    return InvoiceRepository.process(params);
  }

  /**
   * Cancel invoice in staging (only for N or E status)
   */
  static async cancel(stagingId: number): Promise<{ success: boolean; message: string }> {
    return InvoiceRepository.cancel(stagingId);
  }
}
