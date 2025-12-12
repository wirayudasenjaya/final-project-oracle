-- ============================================================================
-- Script: 01_staging_tables.sql
-- Description: Create Staging Tables for AP Invoice Interface
-- Author: Wirayuda Senjaya
-- Date: 12-Dec-2025
-- ============================================================================

-- =============================================================================
-- Table: XXAP_INVOICE_HDR_STG (Invoice Header Staging)
-- =============================================================================
CREATE TABLE XXAP_INVOICE_HDR_STG_WIRA
(
    STAGING_ID              NUMBER          NOT NULL,
    BATCH_ID                NUMBER,
    INVOICE_NUM             VARCHAR2(50)    NOT NULL,
    INVOICE_DATE            DATE            NOT NULL,
    INVOICE_TYPE_LOOKUP_CODE VARCHAR2(25)   DEFAULT 'STANDARD',
    INVOICE_AMOUNT          NUMBER          NOT NULL,
    INVOICE_CURRENCY_CODE   VARCHAR2(15)    DEFAULT 'IDR',
    EXCHANGE_RATE           NUMBER,
    EXCHANGE_RATE_TYPE      VARCHAR2(30),
    EXCHANGE_DATE           DATE,
    VENDOR_NUM              VARCHAR2(30)    NOT NULL,
    VENDOR_SITE_CODE        VARCHAR2(15)    NOT NULL,
    VENDOR_ID               NUMBER,
    VENDOR_SITE_ID          NUMBER,
    PAYMENT_METHOD_CODE     VARCHAR2(30),
    PAY_GROUP_LOOKUP_CODE   VARCHAR2(25),
    TERMS_NAME              VARCHAR2(50),
    TERMS_ID                NUMBER,
    DESCRIPTION             VARCHAR2(240),
    SOURCE                  VARCHAR2(80)    DEFAULT 'REST API',
    GL_DATE                 DATE,
    ORG_ID                  NUMBER          NOT NULL,
    -- Processing Status Fields
    PROCESS_FLAG            VARCHAR2(1)     DEFAULT 'N',  -- N=New, V=Validated, E=Error, P=Processed, I=Interfaced
    ERROR_MESSAGE           VARCHAR2(4000),
    INTERFACE_ID            NUMBER,
    -- Audit Fields
    CREATION_DATE           DATE            DEFAULT SYSDATE,
    CREATED_BY              NUMBER          DEFAULT -1,
    LAST_UPDATE_DATE        DATE            DEFAULT SYSDATE,
    LAST_UPDATED_BY         NUMBER          DEFAULT -1,
    REQUEST_ID              NUMBER,
    -- Constraints
    CONSTRAINT XXAP_INV_HDR_STG_PK PRIMARY KEY (STAGING_ID)
);

-- Create Sequence for Header Staging
CREATE SEQUENCE XXAP_INVOICE_HDR_STG_S
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- Create Index
CREATE INDEX XXAP_INV_HDR_STG_N1 ON XXAP_INVOICE_HDR_STG_WIRA (PROCESS_FLAG) TABLESPACE APPS_TS_TX_IDX;
CREATE INDEX XXAP_INV_HDR_STG_N2 ON XXAP_INVOICE_HDR_STG_WIRA (BATCH_ID) TABLESPACE APPS_TS_TX_IDX;
CREATE INDEX XXAP_INV_HDR_STG_N3 ON XXAP_INVOICE_HDR_STG_WIRA (VENDOR_NUM, VENDOR_SITE_CODE) TABLESPACE APPS_TS_TX_IDX;

-- =============================================================================
-- Table: XXAP_INVOICE_LINES_STG (Invoice Lines Staging)
-- =============================================================================
CREATE TABLE XXAP_INVOICE_LINES_STG_WIRA
(
    LINE_STAGING_ID         NUMBER          NOT NULL,
    STAGING_ID              NUMBER          NOT NULL,  -- FK to Header
    LINE_NUMBER             NUMBER          NOT NULL,
    LINE_TYPE_LOOKUP_CODE   VARCHAR2(25)    DEFAULT 'ITEM',
    AMOUNT                  NUMBER          NOT NULL,
    DESCRIPTION             VARCHAR2(240),
    DIST_CODE_COMBINATION_ID NUMBER,
    DIST_CODE_CONCATENATED  VARCHAR2(250),  -- Segment1.Segment2.Segment3...
    TAX_CODE                VARCHAR2(30),
    TAX_RATE                NUMBER,
    TAX_AMOUNT              NUMBER,
    PO_NUMBER               VARCHAR2(20),
    PO_LINE_NUMBER          NUMBER,
    PO_HEADER_ID            NUMBER,
    PO_LINE_ID              NUMBER,
    PO_LINE_LOCATION_ID     NUMBER,
    PO_DISTRIBUTION_ID      NUMBER,
    QUANTITY_INVOICED       NUMBER,
    UNIT_PRICE              NUMBER,
    -- Processing Status Fields
    PROCESS_FLAG            VARCHAR2(1)     DEFAULT 'N',
    ERROR_MESSAGE           VARCHAR2(4000),
    -- Audit Fields
    CREATION_DATE           DATE            DEFAULT SYSDATE,
    CREATED_BY              NUMBER          DEFAULT -1,
    LAST_UPDATE_DATE        DATE            DEFAULT SYSDATE,
    LAST_UPDATED_BY         NUMBER          DEFAULT -1,
    -- Constraints
    CONSTRAINT XXAP_INV_LINES_STG_PK PRIMARY KEY (LINE_STAGING_ID),
    CONSTRAINT XXAP_INV_LINES_STG_FK1 FOREIGN KEY (STAGING_ID) 
        REFERENCES XXAP_INVOICE_HDR_STG_WIRA (STAGING_ID)
);

-- Create Sequence for Line Staging
CREATE SEQUENCE XXAP_INVOICE_LINES_STG_S
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- Create Index
CREATE INDEX XXAP_INV_LINES_STG_N1 ON XXAP_INVOICE_LINES_STG_WIRA (STAGING_ID) TABLESPACE APPS_TS_TX_IDX;
CREATE INDEX XXAP_INV_LINES_STG_N2 ON XXAP_INVOICE_LINES_STG_WIRA (PROCESS_FLAG) TABLESPACE APPS_TS_TX_IDX;

-- =============================================================================
-- Grant Privileges
-- =============================================================================
GRANT ALL ON XXAP_INVOICE_HDR_STG_WIRA TO APPS;
GRANT ALL ON XXAP_INVOICE_LINES_STG_WIRA TO APPS;
GRANT ALL ON XXAP_INVOICE_HDR_STG_S TO APPS;
GRANT ALL ON XXAP_INVOICE_LINES_STG_S TO APPS;

-- Create Synonyms
CREATE OR REPLACE SYNONYM APPS.XXAP_INVOICE_HDR_STG FOR XXAP_INVOICE_HDR_STG_WIRA;
CREATE OR REPLACE SYNONYM APPS.XXAP_INVOICE_LINES_STG FOR XXAP_INVOICE_LINES_STG_WIRA;
CREATE OR REPLACE SYNONYM APPS.XXAP_INVOICE_HDR_STG_S FOR XXAP.XXAP_INVOICE_HDR_STG_S;
CREATE OR REPLACE SYNONYM APPS.XXAP_INVOICE_LINES_STG_S FOR XXAP.XXAP_INVOICE_LINES_STG_S;

-- =============================================================================
-- Comments
-- =============================================================================
COMMENT ON TABLE XXAP_INVOICE_HDR_STG IS 'Staging table for AP Invoice Headers - Interface from external systems';
COMMENT ON COLUMN XXAP_INVOICE_HDR_STG.PROCESS_FLAG IS 'N=New, V=Validated, E=Error, P=Processed, I=Interfaced';
COMMENT ON TABLE XXAP_INVOICE_LINES_STG IS 'Staging table for AP Invoice Lines - Interface from external systems';

COMMIT;
/
