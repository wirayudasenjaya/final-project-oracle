-- ============================================================================
-- Script: 02_package_spec.sql
-- Description: Package Specification for AP Invoice Interface Processing
-- Author: Wirayuda Senjaya
-- Date: 12-Dec-2025
-- ============================================================================

CREATE OR REPLACE PACKAGE XXAP_INVOICE_INTERFACE_PKG_WIRA
AS
    -- ==========================================================================
    -- Global Constants
    -- ==========================================================================
    G_STATUS_NEW        CONSTANT VARCHAR2(1) := 'N';  -- New Record
    G_STATUS_VALIDATED  CONSTANT VARCHAR2(1) := 'V';  -- Validated
    G_STATUS_ERROR      CONSTANT VARCHAR2(1) := 'E';  -- Error
    G_STATUS_PROCESSED  CONSTANT VARCHAR2(1) := 'P';  -- Processed to Interface
    G_STATUS_INTERFACED CONSTANT VARCHAR2(1) := 'I';  -- Interfaced (Import Complete)
    
    G_SOURCE            CONSTANT VARCHAR2(30) := 'XXAP_INVOICE_STG_WIRA';
    
    -- ==========================================================================
    -- Procedure: MAIN_PROCESS
    -- Description: Main procedure to be called from Concurrent Program
    -- Parameters:
    --   errbuf  - Error buffer for concurrent program
    --   retcode - Return code (0=Success, 1=Warning, 2=Error)
    --   p_org_id - Operating Unit ID
    --   p_batch_id - Optional Batch ID to process specific batch
    -- ==========================================================================
    PROCEDURE main_process (
        errbuf      OUT VARCHAR2,
        retcode     OUT VARCHAR2,
        p_org_id    IN  NUMBER,
        p_batch_id  IN  NUMBER DEFAULT NULL
    );
    
    -- ==========================================================================
    -- Procedure: VALIDATE_STAGING_DATA
    -- Description: Validate all staging data against Oracle master data
    -- ==========================================================================
    PROCEDURE validate_staging_data (
        p_org_id    IN  NUMBER,
        p_batch_id  IN  NUMBER DEFAULT NULL,
        x_return_status OUT VARCHAR2,
        x_error_msg OUT VARCHAR2
    );
    
    -- ==========================================================================
    -- Procedure: TRANSFER_TO_INTERFACE
    -- Description: Transfer validated staging data to AP Interface tables
    -- ==========================================================================
    PROCEDURE transfer_to_interface (
        p_org_id    IN  NUMBER,
        p_batch_id  IN  NUMBER DEFAULT NULL,
        x_return_status OUT VARCHAR2,
        x_error_msg OUT VARCHAR2
    );
    
    -- ==========================================================================
    -- Procedure: SUBMIT_IMPORT_PROGRAM
    -- Description: Submit the standard AP Invoice Import concurrent program
    -- ==========================================================================
    PROCEDURE submit_import_program (
        p_org_id    IN  NUMBER,
        p_batch_id  IN  NUMBER DEFAULT NULL,
        x_request_id OUT NUMBER,
        x_return_status OUT VARCHAR2,
        x_error_msg OUT VARCHAR2
    );
    
    -- ==========================================================================
    -- Procedure: UPDATE_STAGING_STATUS
    -- Description: Update staging status after import completes
    -- ==========================================================================
    PROCEDURE update_staging_status (
        p_org_id    IN  NUMBER,
        p_batch_id  IN  NUMBER DEFAULT NULL,
        x_return_status OUT VARCHAR2,
        x_error_msg OUT VARCHAR2
    );

END XXAP_INVOICE_INTERFACE_PKG_WIRA;
/

SHOW ERRORS;
