import oracledb from "oracledb";
import { execute, executeProc } from "../../database/connection";
import { SCHEMA } from "../../config/database";
import type { InvoiceModel } from "./model";

interface StagingHeaderRow {
  STAGING_ID: number;
  BATCH_ID: number | null;
  INVOICE_NUM: string;
  INVOICE_DATE: Date;
  INVOICE_TYPE_LOOKUP_CODE: string;
  INVOICE_AMOUNT: number;
  INVOICE_CURRENCY_CODE: string;
  VENDOR_NUM: string;
  VENDOR_SITE_CODE: string;
  TERMS_NAME: string | null;
  DESCRIPTION: string | null;
  ORG_ID: number;
  PROCESS_FLAG: string;
  ERROR_MESSAGE: string | null;
}

interface StagingLineRow {
  LINE_STAGING_ID: number;
  STAGING_ID: number;
  LINE_NUMBER: number;
  LINE_TYPE_LOOKUP_CODE: string;
  AMOUNT: number;
  DESCRIPTION: string | null;
  DIST_CODE_COMBINATION_ID: number | null;
  PROCESS_FLAG: string;
  ERROR_MESSAGE: string | null;
}

const STATUS_MAP: Record<string, string> = {
  N: "New",
  V: "Validated",
  E: "Error",
  P: "Processed",
  I: "Interfaced",
  X: "Cancelled",
};

/**
 * Repository layer for Oracle database operations
 */
export abstract class InvoiceRepository {
  /**
   * Insert invoice header into staging table
   */
  static async insertHeader(invoice: InvoiceModel.createBody): Promise<number> {
    const sql = `
      BEGIN
        INSERT INTO ${SCHEMA.STAGING_HEADER} (
          STAGING_ID,
          BATCH_ID,
          INVOICE_NUM,
          INVOICE_DATE,
          INVOICE_TYPE_LOOKUP_CODE,
          INVOICE_AMOUNT,
          INVOICE_CURRENCY_CODE,
          VENDOR_NUM,
          VENDOR_SITE_CODE,
          TERMS_NAME,
          DESCRIPTION,
          ORG_ID,
          PROCESS_FLAG
        ) VALUES (
          XXAP_INVOICE_HDR_STG_S.NEXTVAL,
          :batch_id,
          :invoice_num,
          TO_DATE(:invoice_date, 'YYYY-MM-DD'),
          :invoice_type,
          :invoice_amount,
          :currency_code,
          :vendor_num,
          :vendor_site_code,
          :terms_name,
          :description,
          :org_id,
          'N'
        ) RETURNING STAGING_ID INTO :staging_id;
      END;
    `;

    const result = await executeProc(sql, {
      batch_id: invoice.batch_id ?? null,
      invoice_num: invoice.invoice_num,
      invoice_date: invoice.invoice_date,
      invoice_type: invoice.invoice_type ?? "STANDARD",
      invoice_amount: invoice.invoice_amount,
      currency_code: invoice.currency_code ?? "USD",
      vendor_num: invoice.vendor_num,
      vendor_site_code: invoice.vendor_site_code,
      terms_name: invoice.terms_name ?? null,
      description: invoice.description ?? null,
      org_id: invoice.org_id,
      staging_id: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
    });

    return (result.outBinds as { staging_id: number }).staging_id;
  }

  /**
   * Insert invoice line into staging table
   */
  static async insertLine(
    stagingId: number,
    line: InvoiceModel.line,
    _userId: number = -1
  ): Promise<number> {
    const sql = `
      BEGIN
        INSERT INTO ${SCHEMA.STAGING_LINES} (
          LINE_STAGING_ID,
          STAGING_ID,
          LINE_NUMBER,
          LINE_TYPE_LOOKUP_CODE,
          AMOUNT,
          DESCRIPTION,
          DIST_CODE_COMBINATION_ID,
          PROCESS_FLAG
        ) VALUES (
          XXAP_INVOICE_LINES_STG_S.NEXTVAL,
          :staging_id,
          :line_number,
          :line_type,
          :amount,
          :description,
          :dist_code_combination_id,
          'N'
        ) RETURNING LINE_STAGING_ID INTO :line_staging_id;
      END;
    `;

    const result = await executeProc(sql, {
      staging_id: stagingId,
      line_number: line.line_number,
      line_type: line.line_type,
      amount: line.amount,
      description: line.description ?? null,
      dist_code_combination_id: line.dist_code_ccid ?? null,
      line_staging_id: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
    });

    return (result.outBinds as { line_staging_id: number }).line_staging_id;
  }

  /**
   * Get invoice status by staging ID
   */
  static async getStatus(stagingId: number): Promise<InvoiceModel.statusResponse | null> {
    const sql = `
      SELECT 
        STAGING_ID,
        PROCESS_FLAG,
        ERROR_MESSAGE
      FROM ${SCHEMA.STAGING_HEADER}
      WHERE STAGING_ID = :staging_id
    `;

    const result = await execute<StagingHeaderRow>(sql, { staging_id: stagingId });

    if (!result.rows || result.rows.length === 0) {
      return null;
    }

    const row = result.rows[0];
    return {
      staging_id: row.STAGING_ID,
      process_flag: row.PROCESS_FLAG,
      status: STATUS_MAP[row.PROCESS_FLAG] ?? "Unknown",
      error_message: row.ERROR_MESSAGE ?? "",
    };
  }

  /**
   * Search invoice by number and org_id
   */
  static async search(
    invoiceNum: string,
    orgId?: number
  ): Promise<InvoiceModel.searchResponse | null> {
    let sql = `
      SELECT 
        STAGING_ID,
        INVOICE_NUM,
        TO_CHAR(INVOICE_DATE, 'YYYY-MM-DD') AS INVOICE_DATE,
        INVOICE_TYPE_LOOKUP_CODE,
        INVOICE_AMOUNT,
        INVOICE_CURRENCY_CODE,
        VENDOR_NUM,
        VENDOR_SITE_CODE,
        PROCESS_FLAG,
        ERROR_MESSAGE,
        ORG_ID
      FROM ${SCHEMA.STAGING_HEADER}
      WHERE INVOICE_NUM = :invoice_num
    `;

    const binds: oracledb.BindParameters = { invoice_num: invoiceNum };

    if (orgId !== undefined) {
      sql += " AND ORG_ID = :org_id";
      (binds as Record<string, unknown>).org_id = orgId;
    }

    const result = await execute<StagingHeaderRow & { INVOICE_DATE: string }>(sql, binds);

    if (!result.rows || result.rows.length === 0) {
      return null;
    }

    const header = result.rows[0];

    // Get lines
    const linesSql = `
      SELECT 
        LINE_STAGING_ID,
        STAGING_ID,
        LINE_NUMBER,
        LINE_TYPE_LOOKUP_CODE,
        AMOUNT,
        DESCRIPTION,
        DIST_CODE_COMBINATION_ID,
        PROCESS_FLAG,
        ERROR_MESSAGE
      FROM ${SCHEMA.STAGING_LINES}
      WHERE STAGING_ID = :staging_id
      ORDER BY LINE_NUMBER
    `;

    const linesResult = await execute<StagingLineRow>(linesSql, {
      staging_id: header.STAGING_ID,
    });

    return {
      staging_id: header.STAGING_ID,
      invoice_num: header.INVOICE_NUM,
      invoice_date: header.INVOICE_DATE,
      invoice_type: header.INVOICE_TYPE_LOOKUP_CODE,
      invoice_amount: header.INVOICE_AMOUNT,
      currency_code: header.INVOICE_CURRENCY_CODE,
      vendor_num: header.VENDOR_NUM,
      vendor_site_code: header.VENDOR_SITE_CODE,
      process_flag: header.PROCESS_FLAG,
      process_status: STATUS_MAP[header.PROCESS_FLAG] ?? "Unknown",
      error_message: header.ERROR_MESSAGE,
      lines: (linesResult.rows ?? []).map((line: StagingLineRow) => ({
        line_staging_id: line.LINE_STAGING_ID,
        line_number: line.LINE_NUMBER,
        line_type: line.LINE_TYPE_LOOKUP_CODE,
        amount: line.AMOUNT,
        description: line.DESCRIPTION,
        dist_code_ccid: line.DIST_CODE_COMBINATION_ID,
        process_flag: line.PROCESS_FLAG,
        error_message: line.ERROR_MESSAGE,
      })),
    };
  }

  /**
   * Call main_process procedure to validate, transfer, and import invoices
   * Matches: XXAP_INVOICE_INTERFACE_PKG_WIRA.main_process
   */
  static async process(params: InvoiceModel.processBody): Promise<InvoiceModel.processResponse> {
    const sql = `
      BEGIN
        fnd_global.apps_initialize(0, 20639, 200);
        fnd_request.set_org_id(:org_id);
        
        XXAP_INVOICE_INTERFACE_PKG_WIRA.main_process(
          errbuf     => :errbuf,
          retcode    => :retcode,
          p_org_id   => :org_id,
          p_batch_id => :batch_id
        );
      END;
    `;

    const result = await executeProc(sql, {
      org_id: params.org_id,
      batch_id: params.batch_id ?? null,
      retcode: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 10 },
      errbuf: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 4000 },
    });

    const outBinds = result.outBinds as {
      retcode: string;
      errbuf: string | null;
    };

    const statusMap: Record<string, "success" | "warning" | "error"> = {
      "0": "success",
      "1": "warning",
      "2": "error",
    };

    return {
      status: statusMap[outBinds.retcode] ?? "error",
      return_code: outBinds.retcode,
      message: outBinds.errbuf ?? "Completed",
    };
  }

  /**
   * Cancel invoice in staging
   */
  static async cancel(stagingId: number): Promise<{ success: boolean; message: string }> {
    // Check current status
    const checkSql = `
      SELECT PROCESS_FLAG, INVOICE_NUM 
      FROM ${SCHEMA.STAGING_HEADER} 
      WHERE STAGING_ID = :staging_id
    `;

    const checkResult = await execute<{ PROCESS_FLAG: string; INVOICE_NUM: string }>(
      checkSql,
      { staging_id: stagingId }
    );

    if (!checkResult.rows || checkResult.rows.length === 0) {
      return { success: false, message: `Invoice with staging_id ${stagingId} not found` };
    }

    const row = checkResult.rows[0];
    if (row.PROCESS_FLAG !== "N" && row.PROCESS_FLAG !== "E") {
      return {
        success: false,
        message: `Cannot cancel invoice with status '${STATUS_MAP[row.PROCESS_FLAG]}'. Only New or Error status can be cancelled.`,
      };
    }

    // Update header
    const updateHeaderSql = `
      UPDATE ${SCHEMA.STAGING_HEADER}
      SET PROCESS_FLAG = 'X',
          ERROR_MESSAGE = 'Cancelled by user'
      WHERE STAGING_ID = :staging_id
    `;
    await execute(updateHeaderSql, { staging_id: stagingId });

    // Update lines
    const updateLinesSql = `
      UPDATE ${SCHEMA.STAGING_LINES}
      SET PROCESS_FLAG = 'X',
          ERROR_MESSAGE = 'Cancelled by user'
      WHERE STAGING_ID = :staging_id
    `;
    await execute(updateLinesSql, { staging_id: stagingId });

    return { success: true, message: `Invoice ${row.INVOICE_NUM} cancelled successfully` };
  }
}
