import { t } from "elysia";

export namespace InvoiceModel {
  // Line schema
  export const line = t.Object(
    {
      line_number: t.Number({ description: "Line sequence number", examples: [1] }),
      line_type: t.Union(
        [
          t.Literal("ITEM"),
          t.Literal("TAX"),
          t.Literal("FREIGHT"),
          t.Literal("MISCELLANEOUS"),
        ],
        { description: "Line type lookup code", examples: ["ITEM"] }
      ),
      amount: t.Number({ description: "Line amount", examples: [5000] }),
      description: t.Optional(t.String({ description: "Line description", examples: ["Test Line Item"] })),
      dist_code_ccid: t.Optional(
        t.Number({ description: "Code Combination ID (CCID) for GL distribution", examples: [17021] })
      ),
      account_code: t.Optional(t.String({ description: "Account code segment" })),
      po_number: t.Optional(t.String({ description: "PO number for matching" })),
      po_line_number: t.Optional(t.Number({ description: "PO line number" })),
      quantity: t.Optional(t.Number({ description: "Quantity invoiced" })),
      unit_price: t.Optional(t.Number({ description: "Unit price" })),
      tax_code: t.Optional(t.String({ description: "Tax code" })),
      tax_rate: t.Optional(t.Number({ description: "Tax rate percentage" })),
      tax_amount: t.Optional(t.Number({ description: "Tax amount" })),
    },
    {
      examples: [
        {
          line_number: 1,
          line_type: "ITEM",
          amount: 5000,
          description: "Test Line Item",
          dist_code_ccid: 17021,
        },
      ],
    }
  );
  export type line = typeof line.static;

  // Create invoice request body
  export const createBody = t.Object(
    {
      invoice_num: t.String({ description: "Unique invoice number", examples: ["WIRA-TEST-001"] }),
      invoice_date: t.String({ description: "Invoice date (YYYY-MM-DD)", examples: ["2025-12-12"] }),
      invoice_type: t.Optional(t.String({ description: "Invoice type lookup code", default: "STANDARD", examples: ["STANDARD"] })),
      invoice_amount: t.Number({ description: "Total invoice amount (must match sum of lines)", examples: [5000] }),
      currency_code: t.Optional(t.String({ description: "Currency code", default: "USD", examples: ["USD"] })),
      exchange_rate: t.Optional(t.Number({ description: "Exchange rate for foreign currency" })),
      exchange_rate_type: t.Optional(t.String({ description: "Exchange rate type" })),
      exchange_date: t.Optional(t.String({ description: "Exchange rate date" })),
      vendor_num: t.String({ description: "Vendor number from PO_VENDORS", examples: ["1000"] }),
      vendor_site_code: t.String({ description: "Vendor site code", examples: ["GE PLASTICS"] }),
      terms_name: t.Optional(t.String({ description: "Payment terms name", examples: ["Immediate"] })),
      description: t.Optional(t.String({ description: "Invoice description", examples: ["Test Invoice from REST API"] })),
      gl_date: t.Optional(t.String({ description: "GL date (YYYY-MM-DD)" })),
      org_id: t.Number({ description: "Operating Unit ID", examples: [204] }),
      batch_id: t.Optional(t.Number({ description: "Batch ID for grouping invoices", examples: [100] })),
      user_id: t.Optional(t.Number({ description: "User ID for audit" })),
      lines: t.Optional(t.Array(line, { description: "Invoice lines" })),
    },
    {
      examples: [
        {
          invoice_num: "WIRA-TEST-001",
          invoice_date: "2025-12-12",
          invoice_type: "STANDARD",
          invoice_amount: 5000,
          currency_code: "USD",
          vendor_num: "1000",
          vendor_site_code: "GE PLASTICS",
          terms_name: "Immediate",
          description: "Test Invoice from REST API",
          org_id: 204,
          batch_id: 100,
          lines: [
            {
              line_number: 1,
              line_type: "ITEM",
              amount: 5000,
              description: "Test Line Item",
              dist_code_ccid: 17021,
            },
          ],
        },
      ],
    }
  );
  export type createBody = typeof createBody.static;

  // Create invoice response
  export const createResponse = t.Object(
    {
      status: t.Literal("success"),
      staging_id: t.Number({ description: "Generated staging ID" }),
      message: t.String({ description: "Success message" }),
    },
    {
      examples: [
        {
          status: "success",
          staging_id: 8,
          message: "Invoice created successfully with 1 line(s)",
        },
      ],
    }
  );
  export type createResponse = typeof createResponse.static;

  // Status response
  export const statusResponse = t.Object(
    {
      staging_id: t.Number({ description: "Staging ID" }),
      process_flag: t.String({ description: "Process flag code (N/V/E/P/I/X)" }),
      status: t.String({ description: "Human-readable status" }),
      error_message: t.String({ description: "Error message if any" }),
    },
    {
      examples: [
        { staging_id: 8, process_flag: "N", status: "New", error_message: "" },
        { staging_id: 8, process_flag: "I", status: "Interfaced", error_message: "" },
        { staging_id: 9, process_flag: "E", status: "Error", error_message: "Invalid Vendor Number" },
      ],
    }
  );
  export type statusResponse = typeof statusResponse.static;

  // Line response
  export const lineResponse = t.Object({
    line_staging_id: t.Number({ description: "Line staging ID" }),
    line_number: t.Number({ description: "Line number" }),
    line_type: t.String({ description: "Line type" }),
    amount: t.Number({ description: "Line amount" }),
    description: t.Nullable(t.String({ description: "Line description" })),
    dist_code_ccid: t.Nullable(t.Number({ description: "Distribution CCID" })),
    process_flag: t.String({ description: "Process flag" }),
    error_message: t.Nullable(t.String({ description: "Error message" })),
  });
  export type lineResponse = typeof lineResponse.static;

  // Search response
  export const searchResponse = t.Object(
    {
      staging_id: t.Number(),
      invoice_num: t.String(),
      invoice_date: t.String(),
      invoice_type: t.String(),
      invoice_amount: t.Number(),
      currency_code: t.String(),
      vendor_num: t.String(),
      vendor_site_code: t.String(),
      process_flag: t.String(),
      process_status: t.String(),
      error_message: t.Nullable(t.String()),
      lines: t.Array(lineResponse),
    },
    {
      examples: [
        {
          staging_id: 8,
          invoice_num: "WIRA-TEST-001",
          invoice_date: "2025-12-12",
          invoice_type: "STANDARD",
          invoice_amount: 5000,
          currency_code: "USD",
          vendor_num: "1000",
          vendor_site_code: "GE PLASTICS",
          process_flag: "N",
          process_status: "New",
          error_message: null,
          lines: [
            {
              line_staging_id: 10,
              line_number: 1,
              line_type: "ITEM",
              amount: 5000,
              description: "Test Line Item",
              dist_code_ccid: 17021,
              process_flag: "N",
              error_message: null,
            },
          ],
        },
      ],
    }
  );
  export type searchResponse = typeof searchResponse.static;

  // Error response
  export const errorResponse = t.Object(
    {
      status: t.Literal("error"),
      message: t.String({ description: "Error message" }),
    },
    {
      examples: [{ status: "error", message: "Invoice with staging_id 999 not found" }],
    }
  );
  export type errorResponse = typeof errorResponse.static;

  // Query params
  export const searchQuery = t.Object({
    invoice_num: t.String({ description: "Invoice number to search", examples: ["WIRA-TEST-001"] }),
    org_id: t.Optional(t.String({ description: "Operating Unit ID", examples: ["204"] })),
  });
  export type searchQuery = typeof searchQuery.static;

  // Path params
  export const statusParams = t.Object({
    staging_id: t.String({ description: "Staging ID", examples: ["8"] }),
  });
  export type statusParams = typeof statusParams.static;

  // Process request body
  export const processBody = t.Object(
    {
      org_id: t.Number({ description: "Operating Unit ID", examples: [204] }),
      batch_id: t.Optional(t.Number({ description: "Batch ID to process (processes all invoices in batch)", examples: [100] })),
      staging_id: t.Optional(t.Number({ description: "Specific staging ID to process (overrides batch_id)" })),
    },
    {
      examples: [
        { org_id: 204, batch_id: 100 },
        { org_id: 204, staging_id: 8 },
      ],
    }
  );
  export type processBody = typeof processBody.static;

  // Process response
  export const processResponse = t.Object(
    {
      status: t.Union([t.Literal("success"), t.Literal("warning"), t.Literal("error")]),
      return_code: t.String({ description: "Return code: 0=Success, 1=Warning, 2=Error" }),
      request_id: t.Optional(t.Number({ description: "Concurrent request ID" })),
      message: t.String({ description: "Process result message" }),
    },
    {
      examples: [
        { status: "success", return_code: "0", request_id: 7648512, message: "Completed" },
        { status: "warning", return_code: "1", message: "Process completed with warnings" },
        { status: "error", return_code: "2", message: "Invalid Vendor Number" },
      ],
    }
  );
  export type processResponse = typeof processResponse.static;

  // Cancel request body
  export const cancelBody = t.Object(
    {
      staging_id: t.Number({ description: "Staging ID to cancel", examples: [8] }),
    },
    {
      examples: [{ staging_id: 8 }],
    }
  );
  export type cancelBody = typeof cancelBody.static;

  // Cancel response
  export const cancelResponse = t.Object(
    {
      status: t.Literal("success"),
      staging_id: t.Number(),
      message: t.String(),
    },
    {
      examples: [{ status: "success", staging_id: 8, message: "Invoice WIRA-TEST-001 cancelled successfully" }],
    }
  );
  export type cancelResponse = typeof cancelResponse.static;
}
