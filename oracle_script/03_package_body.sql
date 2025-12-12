-- ============================================================================
-- Script: 03_package_body.sql
-- Description: Package Body for AP Invoice Interface Processing
-- Author: Wirayuda Senjaya
-- Date: 12-Dec-2025
-- ============================================================================

CREATE OR REPLACE PACKAGE BODY XXAP_INVOICE_INTERFACE_PKG_WIRA
AS
    -- ==========================================================================
    -- Private Procedure: LOG_MESSAGE
    -- ==========================================================================
    PROCEDURE log_message (p_message IN VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line(fnd_file.log, TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') || ' - ' || p_message);
    END log_message;
    
    -- ==========================================================================
    -- Private Procedure: OUTPUT_MESSAGE
    -- ==========================================================================
    PROCEDURE output_message (p_message IN VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line(fnd_file.output, p_message);
    END output_message;

    -- ==========================================================================
    -- Private Function: GET_VENDOR_ID
    -- ==========================================================================
    FUNCTION get_vendor_id (p_vendor_num IN VARCHAR2) RETURN NUMBER
    IS
        l_vendor_id NUMBER;
    BEGIN
        SELECT vendor_id
        INTO   l_vendor_id
        FROM   ap_suppliers
        WHERE  segment1 = p_vendor_num
        AND    enabled_flag = 'Y'
        AND    NVL(end_date_active, SYSDATE + 1) > SYSDATE;
        
        RETURN l_vendor_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
        WHEN TOO_MANY_ROWS THEN
            RETURN NULL;
    END get_vendor_id;
    
    -- ==========================================================================
    -- Private Function: GET_VENDOR_SITE_ID
    -- ==========================================================================
    FUNCTION get_vendor_site_id (
        p_vendor_id      IN NUMBER,
        p_vendor_site_code IN VARCHAR2,
        p_org_id         IN NUMBER
    ) RETURN NUMBER
    IS
        l_vendor_site_id NUMBER;
    BEGIN
        SELECT vendor_site_id
        INTO   l_vendor_site_id
        FROM   ap_supplier_sites_all
        WHERE  vendor_id = p_vendor_id
        AND    vendor_site_code = p_vendor_site_code
        AND    org_id = p_org_id
        AND    NVL(inactive_date, SYSDATE + 1) > SYSDATE;
        
        RETURN l_vendor_site_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
        WHEN TOO_MANY_ROWS THEN
            RETURN NULL;
    END get_vendor_site_id;
    
    -- ==========================================================================
    -- Private Function: GET_TERMS_ID
    -- ==========================================================================
    FUNCTION get_terms_id (p_terms_name IN VARCHAR2) RETURN NUMBER
    IS
        l_term_id NUMBER;
    BEGIN
        SELECT term_id
        INTO   l_term_id
        FROM   ap_terms
        WHERE  name = p_terms_name
        AND    enabled_flag = 'Y'
        AND    NVL(end_date_active, SYSDATE + 1) > SYSDATE;
        
        RETURN l_term_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
        WHEN TOO_MANY_ROWS THEN
            RETURN NULL;
    END get_terms_id;
    
    -- ==========================================================================
    -- Private Function: GET_CCID
    -- ==========================================================================
    FUNCTION get_ccid (p_concatenated_segments IN VARCHAR2) RETURN NUMBER
    IS
        l_ccid NUMBER;
    BEGIN
        SELECT code_combination_id
        INTO   l_ccid
        FROM   gl_code_combinations_kfv
        WHERE  concatenated_segments = p_concatenated_segments
        AND    enabled_flag = 'Y';
        
        RETURN l_ccid;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
        WHEN TOO_MANY_ROWS THEN
            RETURN NULL;
    END get_ccid;
    
    -- ==========================================================================
    -- Private Function: VALIDATE_PO
    -- ==========================================================================
    FUNCTION validate_po (
        p_po_number IN VARCHAR2,
        p_org_id    IN NUMBER,
        x_po_header_id OUT NUMBER
    ) RETURN BOOLEAN
    IS
    BEGIN
        SELECT po_header_id
        INTO   x_po_header_id
        FROM   po_headers_all
        WHERE  segment1 = p_po_number
        AND    org_id = p_org_id
        AND    approved_flag = 'Y'
        AND    NVL(cancel_flag, 'N') = 'N';
        
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            x_po_header_id := NULL;
            RETURN FALSE;
        WHEN OTHERS THEN
            x_po_header_id := NULL;
            RETURN FALSE;
    END validate_po;

    -- ==========================================================================
    -- Procedure: VALIDATE_STAGING_DATA
    -- ==========================================================================
    PROCEDURE validate_staging_data (
        p_org_id        IN  NUMBER,
        p_batch_id      IN  NUMBER DEFAULT NULL,
        x_return_status OUT VARCHAR2,
        x_error_msg     OUT VARCHAR2
    )
    IS
        l_vendor_id      NUMBER;
        l_vendor_site_id NUMBER;
        l_terms_id       NUMBER;
        l_ccid           NUMBER;
        l_po_header_id   NUMBER;
        l_error_msg      VARCHAR2(4000);
        l_has_error      BOOLEAN;
        l_count_success  NUMBER := 0;
        l_count_error    NUMBER := 0;
        
        -- Cursor for header records
        CURSOR c_headers IS
            SELECT h.*
            FROM   xxap_invoice_hdr_stg_wira h
            WHERE  h.process_flag = G_STATUS_NEW
            AND    h.org_id = p_org_id
            AND    (p_batch_id IS NULL OR h.batch_id = p_batch_id)
            FOR UPDATE OF h.process_flag;
            
        -- Cursor for line records
        CURSOR c_lines (p_staging_id NUMBER) IS
            SELECT l.*
            FROM   xxap_invoice_lines_stg_wira l
            WHERE  l.staging_id = p_staging_id
            AND    l.process_flag = G_STATUS_NEW
            FOR UPDATE OF l.process_flag;
            
    BEGIN
        log_message('Starting validation process...');
        log_message('Org ID: ' || p_org_id);
        log_message('Batch ID: ' || NVL(TO_CHAR(p_batch_id), 'ALL'));
        
        x_return_status := 'S';
        
        -- Loop through header records
        FOR r_hdr IN c_headers LOOP
            l_has_error := FALSE;
            l_error_msg := NULL;
            
            log_message('Validating Invoice: ' || r_hdr.invoice_num);
            
            -- 1. Validate Vendor
            l_vendor_id := get_vendor_id(r_hdr.vendor_num);
            IF l_vendor_id IS NULL THEN
                l_has_error := TRUE;
                l_error_msg := l_error_msg || 'Invalid Vendor Number: ' || r_hdr.vendor_num || '; ';
            END IF;
            
            -- 2. Validate Vendor Site
            IF l_vendor_id IS NOT NULL THEN
                l_vendor_site_id := get_vendor_site_id(l_vendor_id, r_hdr.vendor_site_code, p_org_id);
                IF l_vendor_site_id IS NULL THEN
                    l_has_error := TRUE;
                    l_error_msg := l_error_msg || 'Invalid Vendor Site: ' || r_hdr.vendor_site_code || '; ';
                END IF;
            END IF;
            
            -- 3. Validate Payment Terms
            IF r_hdr.terms_name IS NOT NULL THEN
                l_terms_id := get_terms_id(r_hdr.terms_name);
                IF l_terms_id IS NULL THEN
                    l_has_error := TRUE;
                    l_error_msg := l_error_msg || 'Invalid Payment Terms: ' || r_hdr.terms_name || '; ';
                END IF;
            END IF;
            
            -- 4. Validate Invoice Amount
            IF r_hdr.invoice_amount IS NULL OR r_hdr.invoice_amount = 0 THEN
                l_has_error := TRUE;
                l_error_msg := l_error_msg || 'Invoice Amount cannot be zero or null; ';
            END IF;
            
            -- 5. Check for duplicate invoice
            DECLARE
                l_dup_count NUMBER;
            BEGIN
                SELECT COUNT(1)
                INTO   l_dup_count
                FROM   ap_invoices_all
                WHERE  invoice_num = r_hdr.invoice_num
                AND    vendor_id = l_vendor_id
                AND    org_id = p_org_id;
                
                IF l_dup_count > 0 THEN
                    l_has_error := TRUE;
                    l_error_msg := l_error_msg || 'Duplicate Invoice exists in Oracle; ';
                END IF;
            END;
            
            -- Validate Lines
            FOR r_line IN c_lines(r_hdr.staging_id) LOOP
                DECLARE
                    l_line_error VARCHAR2(2000);
                BEGIN
                    l_line_error := NULL;
                    
                    -- Validate CCID
                    IF r_line.dist_code_concatenated IS NOT NULL THEN
                        l_ccid := get_ccid(r_line.dist_code_concatenated);
                        IF l_ccid IS NULL THEN
                            l_line_error := 'Invalid Account Code: ' || r_line.dist_code_concatenated || '; ';
                        ELSE
                            -- Update line with CCID
                            UPDATE xxap_invoice_lines_stg_wira
                            SET    dist_code_combination_id = l_ccid
                            WHERE  CURRENT OF c_lines;
                        END IF;
                    END IF;
                    
                    -- Validate PO if provided
                    IF r_line.po_number IS NOT NULL THEN
                        IF NOT validate_po(r_line.po_number, p_org_id, l_po_header_id) THEN
                            l_line_error := l_line_error || 'Invalid PO Number: ' || r_line.po_number || '; ';
                        ELSE
                            UPDATE xxap_invoice_lines_stg_wira
                            SET    po_header_id = l_po_header_id
                            WHERE  CURRENT OF c_lines;
                        END IF;
                    END IF;
                    
                    -- Validate Line Amount
                    IF r_line.amount IS NULL THEN
                        l_line_error := l_line_error || 'Line Amount is required; ';
                    END IF;
                    
                    IF l_line_error IS NOT NULL THEN
                        l_has_error := TRUE;
                        UPDATE xxap_invoice_lines_stg_wira
                        SET    process_flag = G_STATUS_ERROR,
                               error_message = l_line_error,
                               last_update_date = SYSDATE
                        WHERE  CURRENT OF c_lines;
                    ELSE
                        UPDATE xxap_invoice_lines_stg_wira
                        SET    process_flag = G_STATUS_VALIDATED,
                               error_message = NULL,
                               last_update_date = SYSDATE
                        WHERE  CURRENT OF c_lines;
                    END IF;
                END;
            END LOOP;
            
            -- Update Header Status
            IF l_has_error THEN
                UPDATE xxap_invoice_hdr_stg_wira
                SET    process_flag = G_STATUS_ERROR,
                       error_message = l_error_msg,
                       last_update_date = SYSDATE
                WHERE  CURRENT OF c_headers;
                       
                l_count_error := l_count_error + 1;
                log_message('  ERROR: ' || l_error_msg);
            ELSE
                UPDATE xxap_invoice_hdr_stg_wira
                SET    process_flag = G_STATUS_VALIDATED,
                       vendor_id = l_vendor_id,
                       vendor_site_id = l_vendor_site_id,
                       terms_id = l_terms_id,
                       error_message = NULL,
                       last_update_date = SYSDATE
                WHERE  CURRENT OF c_headers;
                       
                l_count_success := l_count_success + 1;
                log_message('  Validated successfully');
            END IF;
            
        END LOOP;
        
        COMMIT;
        
        log_message('Validation Complete. Success: ' || l_count_success || ', Errors: ' || l_count_error);
        output_message('Validation Summary:');
        output_message('  Records Validated: ' || l_count_success);
        output_message('  Records with Errors: ' || l_count_error);
        
        IF l_count_error > 0 THEN
            x_return_status := 'W';
            x_error_msg := 'Validation completed with ' || l_count_error || ' errors';
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            x_return_status := 'E';
            x_error_msg := 'Validation Error: ' || SQLERRM;
            log_message('ERROR: ' || x_error_msg);
    END validate_staging_data;

    -- ==========================================================================
    -- Procedure: TRANSFER_TO_INTERFACE
    -- ==========================================================================
    PROCEDURE transfer_to_interface (
        p_org_id        IN  NUMBER,
        p_batch_id      IN  NUMBER DEFAULT NULL,
        x_return_status OUT VARCHAR2,
        x_error_msg     OUT VARCHAR2
    )
    IS
        l_invoice_id     NUMBER;
        l_invoice_line_id NUMBER;
        l_count          NUMBER := 0;
        
        CURSOR c_validated_headers IS
            SELECT h.*
            FROM   xxap_invoice_hdr_stg_wira h
            WHERE  h.process_flag = G_STATUS_VALIDATED
            AND    h.org_id = p_org_id
            AND    (p_batch_id IS NULL OR h.batch_id = p_batch_id)
            FOR UPDATE OF h.process_flag;
            
    BEGIN
        log_message('Starting transfer to interface tables...');
        x_return_status := 'S';
        
        FOR r_hdr IN c_validated_headers LOOP
            BEGIN
                -- Get next invoice_id from sequence
                SELECT ap_invoices_interface_s.NEXTVAL
                INTO   l_invoice_id
                FROM   dual;
                
                -- Insert into AP_INVOICES_INTERFACE
                INSERT INTO ap_invoices_interface (
                    invoice_id,
                    invoice_num,
                    invoice_type_lookup_code,
                    invoice_date,
                    vendor_id,
                    vendor_site_id,
                    invoice_amount,
                    invoice_currency_code,
                    exchange_rate,
                    exchange_rate_type,
                    exchange_date,
                    terms_id,
                    description,
                    source,
                    payment_method_code,
                    pay_group_lookup_code,
                    gl_date,
                    org_id,
                    creation_date,
                    created_by,
                    last_update_date,
                    last_updated_by
                ) VALUES (
                    l_invoice_id,
                    r_hdr.invoice_num,
                    NVL(r_hdr.invoice_type_lookup_code, 'STANDARD'),
                    r_hdr.invoice_date,
                    r_hdr.vendor_id,
                    r_hdr.vendor_site_id,
                    r_hdr.invoice_amount,
                    NVL(r_hdr.invoice_currency_code, 'IDR'),
                    r_hdr.exchange_rate,
                    r_hdr.exchange_rate_type,
                    r_hdr.exchange_date,
                    r_hdr.terms_id,
                    r_hdr.description,
                    G_SOURCE,
                    r_hdr.payment_method_code,
                    r_hdr.pay_group_lookup_code,
                    NVL(r_hdr.gl_date, r_hdr.invoice_date),
                    r_hdr.org_id,
                    SYSDATE,
                    fnd_global.user_id,
                    SYSDATE,
                    fnd_global.user_id
                );
                
                -- Insert Lines into AP_INVOICE_LINES_INTERFACE
                FOR r_line IN (
                    SELECT *
                    FROM   xxap_invoice_lines_stg_wira
                    WHERE  staging_id = r_hdr.staging_id
                    AND    process_flag = G_STATUS_VALIDATED
                ) LOOP
                    SELECT ap_invoice_lines_interface_s.NEXTVAL
                    INTO   l_invoice_line_id
                    FROM   dual;
                    
                    INSERT INTO ap_invoice_lines_interface (
                        invoice_id,
                        invoice_line_id,
                        line_number,
                        line_type_lookup_code,
                        amount,
                        description,
                        dist_code_combination_id,
                        tax_code,
                        po_header_id,
                        po_line_id,
                        po_line_location_id,
                        po_distribution_id,
                        quantity_invoiced,
                        unit_price,
                        org_id,
                        creation_date,
                        created_by,
                        last_update_date,
                        last_updated_by
                    ) VALUES (
                        l_invoice_id,
                        l_invoice_line_id,
                        r_line.line_number,
                        NVL(r_line.line_type_lookup_code, 'ITEM'),
                        r_line.amount,
                        r_line.description,
                        r_line.dist_code_combination_id,
                        r_line.tax_code,
                        r_line.po_header_id,
                        r_line.po_line_id,
                        r_line.po_line_location_id,
                        r_line.po_distribution_id,
                        r_line.quantity_invoiced,
                        r_line.unit_price,
                        r_hdr.org_id,
                        SYSDATE,
                        fnd_global.user_id,
                        SYSDATE,
                        fnd_global.user_id
                    );
                    
                    -- Update line staging status
                    UPDATE xxap_invoice_lines_stg_wira
                    SET    process_flag = G_STATUS_PROCESSED,
                           last_update_date = SYSDATE
                    WHERE  line_staging_id = r_line.line_staging_id;
                END LOOP;
                
                -- Update header staging status
                UPDATE xxap_invoice_hdr_stg_wira
                SET    process_flag = G_STATUS_PROCESSED,
                       interface_id = l_invoice_id,
                       last_update_date = SYSDATE
                WHERE  CURRENT OF c_validated_headers;
                
                l_count := l_count + 1;
                log_message('Transferred Invoice: ' || r_hdr.invoice_num || ' (Interface ID: ' || l_invoice_id || ')');
                
            EXCEPTION
                WHEN OTHERS THEN
                    DECLARE
                        l_sqlerrm VARCHAR2(2000) := SQLERRM;
                    BEGIN
                        UPDATE xxap_invoice_hdr_stg_wira
                        SET    process_flag = G_STATUS_ERROR,
                               error_message = 'Transfer Error: ' || l_sqlerrm,
                               last_update_date = SYSDATE
                        WHERE  CURRENT OF c_validated_headers;
                        log_message('ERROR transferring invoice ' || r_hdr.invoice_num || ': ' || l_sqlerrm);
                    END;
            END;
        END LOOP;
        
        COMMIT;
        
        log_message('Transfer Complete. Total Records: ' || l_count);
        output_message('Transfer Summary:');
        output_message('  Records Transferred to Interface: ' || l_count);
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            x_return_status := 'E';
            x_error_msg := 'Transfer Error: ' || SQLERRM;
            log_message('ERROR: ' || x_error_msg);
    END transfer_to_interface;

    -- ==========================================================================
    -- Procedure: SUBMIT_IMPORT_PROGRAM
    -- ==========================================================================
    PROCEDURE submit_import_program (
        p_org_id        IN  NUMBER,
        p_batch_id      IN  NUMBER DEFAULT NULL,
        x_request_id    OUT NUMBER,
        x_return_status OUT VARCHAR2,
        x_error_msg     OUT VARCHAR2
    )
    IS
        l_request_id    NUMBER;
        l_phase         VARCHAR2(100);
        l_status        VARCHAR2(100);
        l_dev_phase     VARCHAR2(100);
        l_dev_status    VARCHAR2(100);
        l_message       VARCHAR2(4000);
        l_result        BOOLEAN;
    BEGIN
        log_message('Submitting AP Invoice Import concurrent program...');
        x_return_status := 'S';
        
        -- Set Org Context
        mo_global.set_policy_context('S', p_org_id);
        fnd_request.set_org_id(p_org_id);
        
        -- Submit Payables Open Interface Import
        -- Concurrent Program: APXIIMPT
        l_request_id := fnd_request.submit_request (
            application => 'SQLAP',
            program     => 'APXIIMPT',
            description => 'AP Invoice Import from Staging',
            start_time  => NULL,
            sub_request => FALSE,
            argument1   => p_org_id,              -- Operating Unit
            argument2   => G_SOURCE,              -- Source
            argument3   => NULL,                  -- Group
            argument4   => NULL,                  -- Batch Name
            argument5   => NULL,                  -- Hold Name
            argument6   => NULL,                  -- Hold Reason
            argument7   => NULL,                  -- GL Date
            argument8   => 'N',                   -- Purge
            argument9   => 'N',                   -- Trace Switch
            argument10  => 'N',                   -- Debug Switch
            argument11  => 'N',                   -- Summarize Report
            argument12  => 1000,                  -- Commit Batch Size
            argument13  => fnd_global.user_id,    -- User ID
            argument14  => fnd_global.login_id    -- Login ID
        );
        
        COMMIT;
        
        IF l_request_id = 0 THEN
            x_return_status := 'E';
            x_error_msg := 'Failed to submit AP Invoice Import program';
            log_message('ERROR: ' || x_error_msg);
        ELSE
            x_request_id := l_request_id;
            log_message('AP Invoice Import submitted. Request ID: ' || l_request_id);
            output_message('AP Invoice Import Request ID: ' || l_request_id);
            
            -- Wait for completion
            log_message('Waiting for Import program to complete...');
            l_result := fnd_concurrent.wait_for_request (
                request_id => l_request_id,
                interval   => 10,
                max_wait   => 0,
                phase      => l_phase,
                status     => l_status,
                dev_phase  => l_dev_phase,
                dev_status => l_dev_status,
                message    => l_message
            );
            
            log_message('Import Program completed. Status: ' || l_status);
            output_message('Import Status: ' || l_status);
            
            IF l_dev_status NOT IN ('NORMAL', 'WARNING') THEN
                x_return_status := 'W';
                x_error_msg := 'Import completed with status: ' || l_status;
            END IF;
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            x_return_status := 'E';
            x_error_msg := 'Submit Import Error: ' || SQLERRM;
            log_message('ERROR: ' || x_error_msg);
    END submit_import_program;

    -- ==========================================================================
    -- Procedure: UPDATE_STAGING_STATUS
    -- ==========================================================================
    PROCEDURE update_staging_status (
        p_org_id        IN  NUMBER,
        p_batch_id      IN  NUMBER DEFAULT NULL,
        x_return_status OUT VARCHAR2,
        x_error_msg     OUT VARCHAR2
    )
    IS
        l_count_success NUMBER := 0;
        l_count_error   NUMBER := 0;
    BEGIN
        log_message('Updating staging status based on import results...');
        x_return_status := 'S';
        
        -- Update successfully imported invoices
        UPDATE xxap_invoice_hdr_stg_wira stg
        SET    process_flag = G_STATUS_INTERFACED,
               error_message = NULL,
               last_update_date = SYSDATE
        WHERE  stg.process_flag = G_STATUS_PROCESSED
        AND    stg.org_id = p_org_id
        AND    (p_batch_id IS NULL OR stg.batch_id = p_batch_id)
        AND    EXISTS (
            SELECT 1
            FROM   ap_invoices_all ai
            WHERE  ai.invoice_num = stg.invoice_num
            AND    ai.vendor_id = stg.vendor_id
            AND    ai.org_id = stg.org_id
        );
        
        l_count_success := SQL%ROWCOUNT;
        
        -- Update lines for successful headers
        UPDATE xxap_invoice_lines_stg_wira l
        SET    process_flag = G_STATUS_INTERFACED,
               last_update_date = SYSDATE
        WHERE  EXISTS (
            SELECT 1
            FROM   xxap_invoice_hdr_stg_wira h
            WHERE  h.staging_id = l.staging_id
            AND    h.process_flag = G_STATUS_INTERFACED
        );
        
        -- Update failed invoices (still in interface table with rejections)
        UPDATE xxap_invoice_hdr_stg_wira stg
        SET    process_flag = G_STATUS_ERROR,
               error_message = (
                   SELECT 'Interface Rejection: ' || SUBSTR(aii.reject_lookup_code, 1, 200)
                   FROM   ap_invoices_interface aii
                   WHERE  aii.invoice_id = stg.interface_id
                   AND    aii.status IS NOT NULL
                   AND    ROWNUM = 1
               ),
               last_update_date = SYSDATE
        WHERE  stg.process_flag = G_STATUS_PROCESSED
        AND    stg.org_id = p_org_id
        AND    (p_batch_id IS NULL OR stg.batch_id = p_batch_id)
        AND    NOT EXISTS (
            SELECT 1
            FROM   ap_invoices_all ai
            WHERE  ai.invoice_num = stg.invoice_num
            AND    ai.vendor_id = stg.vendor_id
            AND    ai.org_id = stg.org_id
        );
        
        l_count_error := SQL%ROWCOUNT;
        
        COMMIT;
        
        log_message('Status Update Complete. Success: ' || l_count_success || ', Errors: ' || l_count_error);
        output_message('Final Status:');
        output_message('  Successfully Imported: ' || l_count_success);
        output_message('  Import Errors: ' || l_count_error);
        
    EXCEPTION
        WHEN OTHERS THEN
            x_return_status := 'E';
            x_error_msg := 'Status Update Error: ' || SQLERRM;
            log_message('ERROR: ' || x_error_msg);
    END update_staging_status;

    -- ==========================================================================
    -- Procedure: MAIN_PROCESS
    -- ==========================================================================
    PROCEDURE main_process (
        errbuf      OUT VARCHAR2,
        retcode     OUT VARCHAR2,
        p_org_id    IN  NUMBER,
        p_batch_id  IN  NUMBER DEFAULT NULL
    )
    IS
        l_return_status VARCHAR2(1);
        l_error_msg     VARCHAR2(4000);
        l_request_id    NUMBER;
        l_overall_status VARCHAR2(1) := 'S';
    BEGIN
        -- Initialize
        retcode := '0';  -- Success
        errbuf  := NULL;
        
        output_message('============================================================');
        output_message('           AP Invoice Interface Processing Report           ');
        output_message('============================================================');
        output_message('Run Date    : ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
        output_message('Org ID      : ' || p_org_id);
        output_message('Batch ID    : ' || NVL(TO_CHAR(p_batch_id), 'ALL'));
        output_message('Request ID  : ' || fnd_global.conc_request_id);
        output_message('============================================================');
        output_message(' ');
        
        log_message('=== Starting AP Invoice Interface Process ===');
        log_message('Parameters: Org ID=' || p_org_id || ', Batch ID=' || NVL(TO_CHAR(p_batch_id), 'ALL'));
        
        -- Step 1: Validate Staging Data
        output_message('Step 1: Validating Staging Data...');
        log_message('Step 1: Validating Staging Data');
        
        validate_staging_data (
            p_org_id        => p_org_id,
            p_batch_id      => p_batch_id,
            x_return_status => l_return_status,
            x_error_msg     => l_error_msg
        );
        
        IF l_return_status = 'E' THEN
            l_overall_status := 'E';
            errbuf := l_error_msg;
        ELSIF l_return_status = 'W' THEN
            IF l_overall_status <> 'E' THEN
                l_overall_status := 'W';
            END IF;
        END IF;
        
        output_message(' ');
        
        -- Step 2: Transfer to Interface Tables
        output_message('Step 2: Transferring to Interface Tables...');
        log_message('Step 2: Transfer to Interface Tables');
        
        transfer_to_interface (
            p_org_id        => p_org_id,
            p_batch_id      => p_batch_id,
            x_return_status => l_return_status,
            x_error_msg     => l_error_msg
        );
        
        IF l_return_status = 'E' THEN
            l_overall_status := 'E';
            errbuf := NVL(errbuf, '') || l_error_msg;
        END IF;
        
        output_message(' ');
        
        -- Step 3: Submit AP Invoice Import
        output_message('Step 3: Submitting AP Invoice Import...');
        log_message('Step 3: Submit AP Invoice Import');
        
        submit_import_program (
            p_org_id        => p_org_id,
            p_batch_id      => p_batch_id,
            x_request_id    => l_request_id,
            x_return_status => l_return_status,
            x_error_msg     => l_error_msg
        );
        
        -- Output request_id for SQL*Plus testing
        DBMS_OUTPUT.PUT_LINE('AP Import Request ID: ' || NVL(TO_CHAR(l_request_id), '0'));
        
        IF l_return_status = 'E' THEN
            l_overall_status := 'E';
            errbuf := NVL(errbuf, '') || l_error_msg;
        ELSIF l_return_status = 'W' THEN
            IF l_overall_status <> 'E' THEN
                l_overall_status := 'W';
            END IF;
        END IF;
        
        output_message(' ');
        
        -- Step 4: Update Staging Status
        output_message('Step 4: Updating Staging Status...');
        log_message('Step 4: Update Staging Status');
        
        update_staging_status (
            p_org_id        => p_org_id,
            p_batch_id      => p_batch_id,
            x_return_status => l_return_status,
            x_error_msg     => l_error_msg
        );
        
        IF l_return_status = 'E' THEN
            l_overall_status := 'E';
            errbuf := NVL(errbuf, '') || l_error_msg;
        END IF;
        
        -- Set final return code
        output_message(' ');
        output_message('============================================================');
        
        IF l_overall_status = 'S' THEN
            retcode := '0';
            output_message('Process Completed Successfully');
            log_message('=== Process Completed Successfully ===');
        ELSIF l_overall_status = 'W' THEN
            retcode := '1';
            output_message('Process Completed with Warnings');
            log_message('=== Process Completed with Warnings ===');
        ELSE
            retcode := '2';
            output_message('Process Completed with Errors');
            log_message('=== Process Completed with Errors ===');
        END IF;
        
        output_message('============================================================');
        
    EXCEPTION
        WHEN OTHERS THEN
            retcode := '2';
            errbuf  := 'Unexpected Error: ' || SQLERRM;
            log_message('FATAL ERROR: ' || SQLERRM);
            output_message('FATAL ERROR: ' || SQLERRM);
    END main_process;

END XXAP_INVOICE_INTERFACE_PKG_WIRA;