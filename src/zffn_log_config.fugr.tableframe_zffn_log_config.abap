*---------------------------------------------------------------------*
*    program for:   TABLEFRAME_ZFFN_LOG_CONFIG
*   generation date: 2022-02-22 at 10:43:25
*   view maintenance generator version: #001407#
*---------------------------------------------------------------------*
FUNCTION TABLEFRAME_ZFFN_LOG_CONFIG    .

  PERFORM TABLEFRAME TABLES X_HEADER X_NAMTAB DBA_SELLIST DPL_SELLIST
                            EXCL_CUA_FUNCT
                     USING  CORR_NUMBER VIEW_ACTION VIEW_NAME.

ENDFUNCTION.
