import oracledb from "oracledb";
import { dbConfig } from "../config/database";

let pool: oracledb.Pool | null = null;

/**
 * Initialize Oracle Thick mode (requires Oracle Instant Client)
 * Download from: https://www.oracle.com/database/technologies/instant-client/downloads.html
 */
function initThickMode(): void {
  try {
    // Set path to Oracle Instant Client (adjust for your system)
    // Windows: oracledb.initOracleClient({ libDir: 'C:\\oracle\\instantclient_21_3' });
    // Linux/Mac: oracledb.initOracleClient({ libDir: '/opt/oracle/instantclient_21_3' });
    oracledb.initOracleClient({ libDir: process.env.ORACLE_CLIENT_PATH });
    console.log("✅ Oracle Thick mode initialized");
  } catch (err) {
    // Already initialized or not available
    if ((err as Error).message?.includes("already initialized")) {
      return;
    }
    console.warn("⚠️  Oracle Thick mode not available, using Thin mode");
  }
}

/**
 * Initialize Oracle connection pool
 */
export async function initializePool(): Promise<void> {
  try {
    // Initialize Thick mode for older Oracle DB password verifiers
    initThickMode();

    pool = await oracledb.createPool(dbConfig);
    console.log("✅ Oracle connection pool initialized");
  } catch (err) {
    console.error("❌ Failed to create Oracle connection pool:", err);
    throw err;
  }
}

/**
 * Get a connection from the pool
 */
export async function getConnection(): Promise<oracledb.Connection> {
  if (!pool) {
    await initializePool();
  }
  return pool!.getConnection();
}

/**
 * Execute a query with auto-release connection
 */
export async function execute<T>(
  sql: string,
  binds: oracledb.BindParameters = {},
  options: oracledb.ExecuteOptions = {}
): Promise<oracledb.Result<T>> {
  const connection = await getConnection();
  try {
    const result = await connection.execute<T>(sql, binds, {
      outFormat: oracledb.OUT_FORMAT_OBJECT,
      autoCommit: true,
      ...options,
    });
    return result;
  } finally {
    await connection.close();
  }
}

/**
 * Execute a PL/SQL procedure
 */
export async function executeProc(
  sql: string,
  binds: oracledb.BindParameters = {}
): Promise<oracledb.Result<unknown>> {
  const connection = await getConnection();
  try {
    const result = await connection.execute(sql, binds, {
      autoCommit: true,
    });
    return result;
  } finally {
    await connection.close();
  }
}

/**
 * Close the connection pool
 */
export async function closePool(): Promise<void> {
  if (pool) {
    await pool.close(0);
    pool = null;
    console.log("Oracle connection pool closed");
  }
}

