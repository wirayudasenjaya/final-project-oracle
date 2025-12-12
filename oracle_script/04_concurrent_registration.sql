-- ============================================================================
-- Script: 04_concurrent_registration.sql
-- Description: Register PL/SQL Package as Concurrent Program in Oracle EBS
-- Author: Wirayuda Senjaya
-- Date: 12-Dec-2025
-- ============================================================================

-- =============================================================================
-- STEP 1: Create Executable
-- Navigation: System Administrator > Concurrent > Program > Executable
-- =============================================================================
BEGIN
    fnd_program.executable (
        executable          => 'XXAP_INVOICE_INTERFACE_WIRA',      -- Executable Short Name
        application         => 'XXAP',                              -- Application Short Name (Custom)
        short_name          => 'XXAP_INVOICE_INTERFACE_WIRA',      -- Same as executable
        description         => 'AP Invoice Interface from Staging Table',
        execution_method    => 'PL/SQL Stored Procedure',          -- Execution Method
        execution_file_name => 'XXAP_INVOICE_INTERFACE_PKG_WIRA.MAIN_PROCESS', -- Package.Procedure
        subroutine_name     => NULL,
        icon_name           => NULL,
        language_code       => 'US',
        execution_file_path => NULL
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Executable created successfully.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error creating executable: ' || SQLERRM);
        ROLLBACK;
END;
/

-- =============================================================================
-- STEP 2: Create Concurrent Program
-- Navigation: System Administrator > Concurrent > Program > Define
-- =============================================================================
BEGIN
    fnd_program.register (
        program             => 'XXAP Invoice Interface Program',    -- Program Name
        application         => 'XXAP',                              -- Application Short Name
        enabled             => 'Y',
        short_name          => 'XXAP_INVOICE_INTERFACE_PGM',        -- Program Short Name
        description         => 'Process AP Invoice data from Staging to Oracle EBS Interface',
        executable_short_name => 'XXAP_INVOICE_INTERFACE_WIRA',     -- Executable Short Name
        executable_application => 'XXAP',
        execution_options   => NULL,
        priority            => NULL,
        save_output         => 'Y',
        print               => 'Y',
        cols                => 180,
        rows                => 45,
        style               => NULL,
        style_required      => 'N',
        printer             => NULL,
        request_type        => NULL,
        request_type_application => NULL,
        use_in_srs          => 'Y',                                 -- Submit from SRS
        allow_disabled_values => 'N',
        run_alone           => 'N',
        output_type         => 'TEXT',
        enable_trace        => 'N',
        restart             => 'N',
        nls_compliant       => 'Y',
        icon_name           => NULL,
        language_code       => 'US',
        mls_function_short_name => NULL,
        mls_function_application => NULL,
        incrementor         => NULL,
        refresh_portlet     => NULL
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Concurrent Program created successfully.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error creating program: ' || SQLERRM);
        ROLLBACK;
END;
/

-- =============================================================================
-- STEP 3: Create Program Parameters
-- Navigation: System Administrator > Concurrent > Program > Define > Parameters
-- =============================================================================

-- Parameter 1: Operating Unit (ORG_ID)
BEGIN
    fnd_program.parameter (
        program             => 'XXAP_INVOICE_INTERFACE_PGM',
        application         => 'XXAP',
        sequence            => 10,
        parameter           => 'P_ORG_ID',
        description         => 'Operating Unit',
        enabled             => 'Y',
        value_set           => 'XX_OPERATING_UNIT_VS',              -- Use existing OU value set
        default_type        => NULL,
        default_value       => NULL,
        required            => 'Y',
        enable_security     => 'N',
        range               => NULL,
        display             => 'Y',
        display_size        => 30,
        description_size    => 50,
        concatenated_description_size => 25,
        prompt              => 'Operating Unit',
        token               => 'P_ORG_ID'
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Parameter P_ORG_ID created successfully.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error creating P_ORG_ID: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Parameter 2: Batch ID (Optional)
BEGIN
    fnd_program.parameter (
        program             => 'XXAP_INVOICE_INTERFACE_PGM',
        application         => 'XXAP',
        sequence            => 20,
        parameter           => 'P_BATCH_ID',
        description         => 'Batch ID (Optional)',
        enabled             => 'Y',
        value_set           => 'FND_NUMBER',                        -- Standard number value set
        default_type        => NULL,
        default_value       => NULL,
        required            => 'N',
        enable_security     => 'N',
        range               => NULL,
        display             => 'Y',
        display_size        => 15,
        description_size    => 50,
        concatenated_description_size => 25,
        prompt              => 'Batch ID',
        token               => 'P_BATCH_ID'
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Parameter P_BATCH_ID created successfully.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error creating P_BATCH_ID: ' || SQLERRM);
        ROLLBACK;
END;
/

-- =============================================================================
-- STEP 4: Add Program to Request Group (Assign to Responsibility)
-- Navigation: System Administrator > Security > Responsibility > Request
-- =============================================================================

-- Add to Payables Request Group (for Payables responsibility)
BEGIN
    fnd_program.add_to_group (
        program_short_name  => 'XXAP_INVOICE_INTERFACE_PGM',
        program_application => 'XXAP',
        request_group       => 'Payables Request Group',            -- Request Group Name
        group_application   => 'SQLAP'                              -- Request Group Application
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Program added to Payables Request Group.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error adding to request group: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Alternative: Add to All Reports Request Group
BEGIN
    fnd_program.add_to_group (
        program_short_name  => 'XXAP_INVOICE_INTERFACE_PGM',
        program_application => 'XXAP',
        request_group       => 'All Reports',
        group_application   => 'SQLAP'
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Program added to All Reports Request Group.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error adding to All Reports: ' || SQLERRM);
        ROLLBACK;
END;
/

-- =============================================================================
-- STEP 5: Create Custom Request Group (Optional - for dedicated access)
-- =============================================================================
BEGIN
    fnd_program.request_group (
        request_group       => 'XXAP Invoice Interface Group',
        application         => 'XXAP',
        code                => 'XXAP_INV_INT_GROUP',
        description         => 'Request Group for AP Invoice Interface Programs'
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Custom Request Group created.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error creating request group: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Add program to custom request group
BEGIN
    fnd_program.add_to_group (
        program_short_name  => 'XXAP_INVOICE_INTERFACE_PGM',
        program_application => 'XXAP',
        request_group       => 'XXAP Invoice Interface Group',
        group_application   => 'XXAP'
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Program added to custom request group.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- =============================================================================
-- STEP 6: Create Value Set for Operating Unit (if not exists)
-- Navigation: Application Developer > Validation > Set
-- =============================================================================
BEGIN
    fnd_flex_val_api.create_valueset_independent (
        p_validation_type       => 'I',
        p_value_set_name        => 'XX_OPERATING_UNIT_VS',
        p_description           => 'Operating Unit List of Values',
        p_security_enabled      => 'N',
        p_enable_longlist       => 'N',
        p_format_type           => 'N',                             -- Number
        p_maximum_size          => 15,
        p_precision             => NULL,
        p_numbers_only          => 'Y',
        p_uppercase_only        => 'N',
        p_right_justify_zero_fill => 'N',
        p_min_value             => NULL,
        p_max_value             => NULL
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Value Set created.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Value Set may already exist or error: ' || SQLERRM);
END;
/

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================

-- Verify Executable
SELECT executable_name, execution_file_name, execution_method_code
FROM   fnd_executables
WHERE  executable_name = 'XXAP_INVOICE_INTERFACE_WIRA';

-- Verify Concurrent Program
SELECT concurrent_program_name, user_concurrent_program_name, enabled_flag
FROM   fnd_concurrent_programs_vl
WHERE  concurrent_program_name = 'XXAP_INVOICE_INTERFACE_PGM';

-- Verify Parameters
SELECT p.parameter_seq, p.parameter_name, p.required_flag, p.default_type
FROM   fnd_concurrent_programs_vl cp,
       fnd_descr_flex_col_usage_vl p
WHERE  cp.concurrent_program_name = 'XXAP_INVOICE_INTERFACE_PGM'
AND    p.descriptive_flexfield_name = '$SRS$.' || cp.concurrent_program_name
ORDER BY p.parameter_seq;

-- Verify Request Group Assignment
SELECT frg.request_group_name, fcp.concurrent_program_name
FROM   fnd_request_groups frg,
       fnd_request_group_units frgu,
       fnd_concurrent_programs fcp
WHERE  frg.request_group_id = frgu.request_group_id
AND    frgu.request_unit_id = fcp.concurrent_program_id
AND    fcp.concurrent_program_name = 'XXAP_INVOICE_INTERFACE_PGM';

COMMIT;
/

-- =============================================================================
-- MANUAL STEPS (If API approach doesn't work):
-- =============================================================================
/*
MANUAL REGISTRATION STEPS VIA ORACLE EBS FORMS:

1. CREATE EXECUTABLE:
   Navigation: System Administrator > Concurrent > Program > Executable
   - Executable: XXAP_INVOICE_INTERFACE_WIRA
   - Short Name: XXAP_INVOICE_INTERFACE_WIRA
   - Application: Custom Application (XXAP)
   - Execution Method: PL/SQL Stored Procedure
   - Execution File Name: XXAP_INVOICE_INTERFACE_PKG_WIRA.MAIN_PROCESS

2. CREATE CONCURRENT PROGRAM:
   Navigation: System Administrator > Concurrent > Program > Define
   - Program: XXAP Invoice Interface Program
   - Short Name: XXAP_INVOICE_INTERFACE_PGM
   - Application: Custom Application (XXAP)
   - Executable Name: XXAP_INVOICE_INTERFACE_WIRA
   - Output Format: Text

3. ADD PARAMETERS:
   In the same form, click on Parameters button:
   
   Parameter 1:
   - Seq: 10
   - Parameter: P_ORG_ID
   - Description: Operating Unit
   - Value Set: (Use any OU LOV value set)
   - Required: Yes
   
   Parameter 2:
   - Seq: 20
   - Parameter: P_BATCH_ID
   - Description: Batch ID
   - Value Set: FND_NUMBER
   - Required: No

4. ASSIGN TO REQUEST GROUP:
   Navigation: System Administrator > Security > Responsibility > Request
   - Find the responsibility you want to grant access
   - Add XXAP_INVOICE_INTERFACE_PGM to the request group

5. RUN THE PROGRAM:
   Navigation: Payables Responsibility > View > Requests > Submit a New Request
   - Select: XXAP Invoice Interface Program
   - Enter Parameters and Submit
*/
