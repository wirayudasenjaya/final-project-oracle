# Invoice Interface REST API

AP Invoice Interface REST API for Oracle E-Business Suite (EBS) R12.

**Author:** Wirayuda Senjaya  
**Date:** December 2025

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
- [API Endpoints](#api-endpoints)
- [Oracle Objects](#oracle-objects)
- [Environment Variables](#environment-variables)
- [Testing](#testing)

---

## Overview

This REST API provides an interface to create AP Invoices in Oracle EBS through custom staging tables. The workflow is:

```
┌─────────────┐     ┌─────────────────┐     ┌──────────────────┐     ┌─────────────┐
│  REST API   │────▶│  Staging Tables │────▶│ Interface Tables │────▶│  Oracle AP  │
│  (Elysia)   │     │  (Custom)       │     │ (Standard)       │     │  (Standard) │
└─────────────┘     └─────────────────┘     └──────────────────┘     └─────────────┘
     POST               XXAP_*_STG           AP_*_INTERFACE          AP_INVOICES_ALL
    /create                                                          AP_INVOICE_LINES_ALL
```

### Process Flow

1. **Create Invoice** → Insert header and lines into staging tables
2. **Process Invoice** → Validate → Transfer to Interface → Run AP Invoice Import
3. **Check Status** → Monitor processing status (N → V → P → I)

---

## Architecture

```
src/
├── config/
│   └── database.ts          # Oracle DB configuration
├── database/
│   └── connection.ts        # Connection pool & query helpers
├── modules/
│   └── invoice/
│       ├── index.ts         # Controller (routes)
│       ├── service.ts       # Business logic
│       ├── repository.ts    # Oracle SQL queries
│       └── model.ts         # TypeBox validation schemas
└── index.ts                 # Entry point + Swagger
```

**Tech Stack:**
- Runtime: [Bun](https://bun.sh/)
- Framework: [Elysia](https://elysiajs.com/)
- Database: Oracle 11g/12c/19c (via `oracledb`)
- Documentation: Swagger/OpenAPI

---

## Getting Started

### Prerequisites

- [Bun](https://bun.sh/) v1.0+
- Oracle Instant Client (for Thick mode)
- Access to Oracle EBS database

### Installation

```bash
# Clone repository
git clone <repo-url>
cd final-project-oracle

# Install dependencies
bun install
```

### Configuration

Create a `.env` file:

```env
# Oracle Database
ORACLE_USER=apps
ORACLE_PASSWORD=apps
ORACLE_CONNECTION_STRING=your-ebs-server:1521/PROD

# Oracle Instant Client path (required for older Oracle versions)
ORACLE_CLIENT_PATH=C:\oracle\instantclient_21_3
```

### Run Development Server

```bash
bun run dev
```

Open:
- API: http://localhost:3000
- Swagger UI: http://localhost:3000/docs

---

## API Endpoints

### Base URL

```
http://localhost:3000/ap/invoice
```

### Endpoints Summary

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/create` | Create invoice (header + lines) |
| GET | `/status/:staging_id` | Get invoice processing status |
| POST | `/process` | Process invoices (validate → import) |
| POST | `/cancel` | Cancel invoice in staging |
| GET | `/search` | Search invoice by number |

---

### POST /create

Create a new invoice with header and lines.

**Request Body:**

```json
{
  "invoice_num": "WIRA-TEST-001",
  "invoice_date": "2025-12-12",
  "invoice_type": "STANDARD",
  "invoice_amount": 5000,
  "currency_code": "USD",
  "vendor_num": "1000",
  "vendor_site_code": "GE PLASTICS",
  "terms_name": "Immediate",
  "description": "Test Invoice from REST API",
  "org_id": 204,
  "batch_id": 100,
  "lines": [
    {
      "line_number": 1,
      "line_type": "ITEM",
      "amount": 5000,
      "description": "Test Line Item",
      "dist_code_ccid": 17021
    }
  ]
}
```

**Response (201 Created):**

```json
{
  "status": "success",
  "staging_id": 8,
  "message": "Invoice created successfully with 1 line(s)"
}
```

---

### GET /status/:staging_id

Get the processing status of an invoice.

**Response:**

```json
{
  "staging_id": 8,
  "process_flag": "I",
  "status": "Interfaced",
  "error_message": ""
}
```

**Status Codes:**

| Code | Status | Description |
|:----:|--------|-------------|
| N | New | Pending validation |
| V | Validated | Passed validation |
| E | Error | Validation/processing error |
| P | Processed | Transferred to AP interface |
| I | Interfaced | Successfully imported to Oracle AP |
| X | Cancelled | Cancelled by user |

---

### POST /process

Execute main_process to validate and import invoices.

**Request Body:**

```json
{
  "org_id": 204,
  "batch_id": 100
}
```

**Response:**

```json
{
  "status": "success",
  "return_code": "0",
  "message": "Completed"
}
```

**Return Codes:**
- `0` = Success
- `1` = Warning
- `2` = Error

---

### POST /cancel

Cancel an invoice in staging (only for N or E status).

**Request Body:**

```json
{
  "staging_id": 8
}
```

---

### GET /search

Search invoice by number.

**Query Parameters:**
- `invoice_num` (required): Invoice number
- `org_id` (optional): Operating Unit ID

**Example:**

```
GET /ap/invoice/search?invoice_num=WIRA-TEST-001&org_id=204
```

---

## Oracle Objects

### Custom Staging Tables

#### XXAP_INVOICE_HDR_STG_WIRA

| Column | Type | Description |
|--------|------|-------------|
| STAGING_ID | NUMBER | Primary key (sequence) |
| BATCH_ID | NUMBER | Batch ID for grouping |
| INVOICE_NUM | VARCHAR2 | Unique invoice number |
| INVOICE_DATE | DATE | Invoice date |
| INVOICE_TYPE_LOOKUP_CODE | VARCHAR2 | STANDARD, CREDIT, etc. |
| INVOICE_AMOUNT | NUMBER | Total amount |
| INVOICE_CURRENCY_CODE | VARCHAR2 | USD, IDR, etc. |
| VENDOR_NUM | VARCHAR2 | Vendor number |
| VENDOR_SITE_CODE | VARCHAR2 | Vendor site |
| TERMS_NAME | VARCHAR2 | Payment terms |
| DESCRIPTION | VARCHAR2 | Invoice description |
| ORG_ID | NUMBER | Operating Unit ID |
| PROCESS_FLAG | VARCHAR2(1) | N/V/E/P/I/X |
| ERROR_MESSAGE | VARCHAR2 | Error details |

#### XXAP_INVOICE_LINES_STG_WIRA

| Column | Type | Description |
|--------|------|-------------|
| LINE_STAGING_ID | NUMBER | Primary key (sequence) |
| STAGING_ID | NUMBER | FK to header |
| LINE_NUMBER | NUMBER | Line sequence |
| LINE_TYPE_LOOKUP_CODE | VARCHAR2 | ITEM, TAX, FREIGHT |
| AMOUNT | NUMBER | Line amount |
| DESCRIPTION | VARCHAR2 | Line description |
| DIST_CODE_COMBINATION_ID | NUMBER | GL CCID |
| PROCESS_FLAG | VARCHAR2(1) | N/V/E/P/I/X |
| ERROR_MESSAGE | VARCHAR2 | Error details |

### Sequences

- `XXAP_INVOICE_HDR_STG_S` - Header staging ID
- `XXAP_INVOICE_LINES_STG_S` - Line staging ID

### Package

#### XXAP_INVOICE_INTERFACE_PKG_WIRA

```sql
PROCEDURE main_process(
  errbuf     OUT VARCHAR2,
  retcode    OUT VARCHAR2,
  p_org_id   IN  NUMBER,
  p_batch_id IN  NUMBER
);
```

**Process Steps:**
1. Validate staging data (vendor, site, CCID)
2. Transfer to AP_INVOICES_INTERFACE / AP_INVOICE_LINES_INTERFACE
3. Submit AP Invoice Import concurrent program
4. Update staging status

---

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| ORACLE_USER | Database username | `apps` |
| ORACLE_PASSWORD | Database password | `apps` |
| ORACLE_CONNECTION_STRING | TNS connect string | `host:1521/SID` |
| ORACLE_CLIENT_PATH | Oracle Instant Client path | `C:\oracle\instantclient_21_3` |

---

## Testing

### Using Swagger UI

1. Open http://localhost:3000/docs
2. Try out the endpoints with prefilled examples

### Using cURL

```bash
# Create Invoice
curl -X POST http://localhost:3000/ap/invoice/create \
  -H "Content-Type: application/json" \
  -d '{
    "invoice_num": "TEST-001",
    "invoice_date": "2025-12-12",
    "invoice_type": "STANDARD",
    "invoice_amount": 5000,
    "currency_code": "USD",
    "vendor_num": "1000",
    "vendor_site_code": "GE PLASTICS",
    "org_id": 204,
    "batch_id": 100,
    "lines": [{
      "line_number": 1,
      "line_type": "ITEM",
      "amount": 5000,
      "dist_code_ccid": 17021
    }]
  }'

# Check Status
curl http://localhost:3000/ap/invoice/status/1

# Process Invoices
curl -X POST http://localhost:3000/ap/invoice/process \
  -H "Content-Type: application/json" \
  -d '{"org_id": 204, "batch_id": 100}'

# Search Invoice
curl "http://localhost:3000/ap/invoice/search?invoice_num=TEST-001&org_id=204"
```

### Using SQL Script

```sql
-- 1. Clean up staging
DELETE FROM XXAP_INVOICE_LINES_STG_WIRA;
DELETE FROM XXAP_INVOICE_HDR_STG_WIRA;
COMMIT;

-- 2. Insert test data
DECLARE
    l_staging_id      NUMBER;
    l_line_staging_id NUMBER;
BEGIN
    SELECT XXAP_INVOICE_HDR_STG_S.NEXTVAL INTO l_staging_id FROM dual;
    
    INSERT INTO XXAP_INVOICE_HDR_STG_WIRA (
        staging_id, batch_id, invoice_num, invoice_date,
        invoice_type_lookup_code, invoice_amount, invoice_currency_code,
        vendor_num, vendor_site_code, terms_name, description, org_id, process_flag
    ) VALUES (
        l_staging_id, 100, 'WIRA-TEST-' || TO_CHAR(SYSDATE, 'YYMMDDHH24MISS'),
        SYSDATE, 'STANDARD', 5000, 'USD', '1000', 'GE PLASTICS',
        'Immediate', 'Test Invoice', 204, 'N'
    );
    
    SELECT XXAP_INVOICE_LINES_STG_S.NEXTVAL INTO l_line_staging_id FROM dual;
    INSERT INTO XXAP_INVOICE_LINES_STG_WIRA (
        line_staging_id, staging_id, line_number, line_type_lookup_code,
        amount, description, dist_code_combination_id, process_flag
    ) VALUES (
        l_line_staging_id, l_staging_id, 1, 'ITEM', 5000, 'Test Line', 
        17021, 'N'  -- CCID: 01-520-5250-0000-000
    );
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Created Staging ID: ' || l_staging_id);
END;
/

-- 3. Run main_process
DECLARE
    l_errbuf  VARCHAR2(4000);
    l_retcode VARCHAR2(10);
BEGIN
    fnd_global.apps_initialize(0, 20639, 200);
    fnd_request.set_org_id(204);
    
    XXAP_INVOICE_INTERFACE_PKG_WIRA.main_process(
        errbuf     => l_errbuf,
        retcode    => l_retcode,
        p_org_id   => 204,
        p_batch_id => 100
    );
    
    DBMS_OUTPUT.PUT_LINE('Return Code: ' || l_retcode);
    DBMS_OUTPUT.PUT_LINE('Message: ' || NVL(l_errbuf, 'Completed'));
END;
/

-- 4. Check result in Oracle AP
SELECT invoice_id, invoice_num, invoice_amount, vendor_id
FROM   ap_invoices_all
WHERE  invoice_num LIKE 'WIRA-TEST-%'
AND    org_id = 204
ORDER BY creation_date DESC;
```

---

## License

MIT
