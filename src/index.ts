import { Elysia } from "elysia";
import { swagger } from "@elysiajs/swagger";
import { invoice } from "./modules/invoice";
import { initializePool, closePool } from "./database";

const app = new Elysia()
  .use(
    swagger({
      documentation: {
        info: {
          title: "XXAP Invoice Interface API",
          version: "1.0.0",
          description: `## AP Invoice Interface REST API for Oracle EBS

**Author:** Wirayuda Senjaya  
**Date:** 12-Dec-2025

---

### Workflow

1. **Create Invoice** → Insert to staging tables
2. **Process Invoice** → Validate → Transfer to Interface → Import to AP
3. **Check Status** → Monitor processing status

---

### Process Flag Codes

| Code | Status | Description |
|:----:|--------|-------------|
| **N** | New | Pending validation |
| **V** | Validated | Passed validation |
| **E** | Error | Validation/processing error |
| **P** | Processed | Transferred to AP interface |
| **I** | Interfaced | Successfully imported to Oracle AP |
| **X** | Cancelled | Cancelled by user |

---

### Tables Used

- \`XXAP_INVOICE_HDR_STG_WIRA\` - Invoice header staging
- \`XXAP_INVOICE_LINES_STG_WIRA\` - Invoice lines staging
- \`AP_INVOICES_INTERFACE\` - Oracle AP interface (target)
- \`AP_INVOICE_LINES_INTERFACE\` - Oracle AP lines interface (target)`,
          contact: {
            name: "Wirayuda Senjaya",
          },
        },
        tags: [
          {
            name: "Invoice",
            description: "Create, search, and manage AP invoices in staging",
          },
        ],
        servers: [
          {
            url: "http://localhost:3000",
            description: "Development server",
          },
        ],
      },
      path: "/docs",
      exclude: ["/docs", "/docs/json"],
    })
  )
  .use(invoice)
  .onError(({ code, error, set }) => {
    if (code === "VALIDATION") {
      set.status = 400;
      return {
        status: "error",
        message: `Validation error: ${error.message}`,
      };
    }

    if (code === "PARSE") {
      set.status = 400;
      return {
        status: "error",
        message: "Invalid JSON format",
      };
    }

    set.status = 500;
    return {
      status: "error",
      message: `Internal server error: ${String(error)}`,
    };
  });

// Initialize database and start server
async function start() {
  try {
    await initializePool();
    
    app.listen(3000);
    
    console.log(
      `🦊 Elysia is running at ${app.server?.hostname}:${app.server?.port}`
    );
    console.log(`
📋 AP Invoice API Endpoints:
   POST   /ap/invoice/create          - Create invoice (header + lines)
   GET    /ap/invoice/status/:id      - Get invoice status
   POST   /ap/invoice/process         - Process invoice (validate → import)
   POST   /ap/invoice/cancel          - Cancel invoice
   GET    /ap/invoice/search          - Search invoice by number

📚 Swagger UI: http://localhost:3000/docs
`);
  } catch (err) {
    console.error("Failed to start server:", err);
    process.exit(1);
  }
}

// Graceful shutdown
process.on("SIGINT", async () => {
  console.log("\nShutting down...");
  await closePool();
  process.exit(0);
});

process.on("SIGTERM", async () => {
  await closePool();
  process.exit(0);
});

start();
