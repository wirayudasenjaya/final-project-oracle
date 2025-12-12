export const dbConfig = {
  user: process.env.ORACLE_USER || "apps",
  password: process.env.ORACLE_PASSWORD || "apps",
  connectString: process.env.ORACLE_CONNECTION_STRING || "localhost:1521/ORCL",
  // Pool settings
  poolMin: 2,
  poolMax: 10,
  poolIncrement: 1,
};

/**
 * Environment variables:
 * - ORACLE_USER: Database username
 * - ORACLE_PASSWORD: Database password
 * - ORACLE_CONNECTION_STRING: host:port/service_name
 * - ORACLE_CLIENT_PATH: Path to Oracle Instant Client (for Thick mode)
 *   Windows: C:\oracle\instantclient_21_3
 *   Linux:   /opt/oracle/instantclient_21_3
 */

export const SCHEMA = {
  STAGING_HEADER: "XXAP_INVOICE_HDR_STG_WIRA",
  STAGING_LINES: "XXAP_INVOICE_LINES_STG_WIRA",
  INTERFACE_HEADER: "AP_INVOICES_INTERFACE",
  INTERFACE_LINES: "AP_INVOICE_LINES_INTERFACE",
};

