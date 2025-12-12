import { Elysia } from "elysia";
import { InvoiceModel } from "./model";
import { InvoiceService } from "./service";

/**
 * Invoice Controller
 * Handles HTTP routing and request validation
 */
export const invoice = new Elysia({ prefix: "/ap/invoice", tags: ["Invoice"] })
  // POST /create - Create invoice with header and lines
  .post(
    "/create",
    async ({ body, set }) => {
      const result = await InvoiceService.create(body);

      set.status = 201;
      return {
        status: "success" as const,
        staging_id: result.staging_id,
        message: `Invoice created successfully with ${result.line_count} line(s)`,
      };
    },
    {
      body: InvoiceModel.createBody,
      response: {
        201: InvoiceModel.createResponse,
        400: InvoiceModel.errorResponse,
      },
      detail: {
        summary: "Create Invoice",
        description:
          "Create a new AP Invoice with header and optional lines in staging table.",
      },
    }
  )

  // GET /status/:staging_id - Get invoice processing status
  .get(
    "/status/:staging_id",
    async ({ params, set }) => {
      const stagingId = parseInt(params.staging_id);

      if (isNaN(stagingId)) {
        set.status = 400;
        return { status: "error" as const, message: "Invalid staging_id format" };
      }

      const result = await InvoiceService.getStatus(stagingId);

      if (!result) {
        set.status = 404;
        return {
          status: "error" as const,
          message: `Invoice with staging_id ${stagingId} not found`,
        };
      }

      return result;
    },
    {
      params: InvoiceModel.statusParams,
      response: {
        200: InvoiceModel.statusResponse,
        400: InvoiceModel.errorResponse,
        404: InvoiceModel.errorResponse,
      },
      detail: {
        summary: "Get Invoice Status",
        description: `Get the processing status of an invoice by staging_id.

**Status Codes:**
- N = New (pending validation)
- V = Validated
- E = Error
- P = Processed (in interface table)
- I = Interfaced (imported to Oracle AP)
- X = Cancelled`,
      },
    }
  )

  // GET /search - Search invoice by number
  .get(
    "/search",
    async ({ query, set }) => {
      const orgId = query.org_id ? parseInt(query.org_id) : undefined;
      const result = await InvoiceService.search(query.invoice_num, orgId);

      if (!result) {
        set.status = 404;
        return {
          status: "error" as const,
          message: `Invoice ${query.invoice_num} not found`,
        };
      }

      return result;
    },
    {
      query: InvoiceModel.searchQuery,
      response: {
        200: InvoiceModel.searchResponse,
        404: InvoiceModel.errorResponse,
      },
      detail: {
        summary: "Search Invoice",
        description: "Search invoice by number and org_id.",
      },
    }
  )

  // POST /process - Process invoices (Validate → Transfer → Import)
  .post(
    "/process",
    async ({ body }) => {
      return await InvoiceService.process(body);
    },
    {
      body: InvoiceModel.processBody,
      response: {
        200: InvoiceModel.processResponse,
      },
      detail: {
        summary: "Process Invoice",
        description: `Execute main_process to:
1. Validate staging data
2. Transfer to interface tables
3. Submit AP Invoice Import
4. Update staging status

**Return Codes:**
- 0 = Success
- 1 = Warning
- 2 = Error`,
      },
    }
  )

  // POST /cancel - Cancel invoice in staging
  .post(
    "/cancel",
    async ({ body, set }) => {
      const result = await InvoiceService.cancel(body.staging_id);

      if (!result.success) {
        set.status = 400;
        return { status: "error" as const, message: result.message };
      }

      return {
        status: "success" as const,
        staging_id: body.staging_id,
        message: result.message,
      };
    },
    {
      body: InvoiceModel.cancelBody,
      response: {
        200: InvoiceModel.cancelResponse,
        400: InvoiceModel.errorResponse,
      },
      detail: {
        summary: "Cancel Invoice",
        description: "Cancel invoice in staging (only for N or E status).",
      },
    }
  );
