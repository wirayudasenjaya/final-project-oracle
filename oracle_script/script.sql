-- 1. Clean up staging
DELETE FROM XXAP_INVOICE_LINES_STG_WIRA;
DELETE FROM XXAP_INVOICE_HDR_STG_WIRA;
COMMIT;

-- 2. Insert fresh test data with VALID CCID
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
        17021,   -- VALID CCID: 01-520-5250-0000-000
        'N'
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

-- 4. Check result
SELECT invoice_id, invoice_num, invoice_amount, vendor_id
FROM   ap_invoices_all
WHERE  invoice_num LIKE 'WIRA-TEST-%'
AND    org_id = 204
ORDER BY creation_date DESC;