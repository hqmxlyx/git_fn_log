*---------------------------------------------------------------------*
*    view related data declarations
*   generation date: 2022-02-22 at 10:43:25
*   view maintenance generator version: #001407#
*---------------------------------------------------------------------*
*...processing: ZFN_LOG_CONFIG..................................*
DATA:  BEGIN OF STATUS_ZFN_LOG_CONFIG                .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZFN_LOG_CONFIG                .
CONTROLS: TCTRL_ZFN_LOG_CONFIG
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZFN_LOG_CONFIG                .
TABLES: ZFN_LOG_CONFIG                 .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
