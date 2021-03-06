*&---------------------------------------------------------------------*
*& Report ZFN_LOG_VIEWER
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT ZFN_LOG_VIEWER.

DATA: _LOG TYPE ZFN_LOG.

INCLUDE ZFN_MACROS.

SELECTION-SCREEN BEGIN OF BLOCK B1 WITH FRAME TITLE TEXT-T00.

SELECT-OPTIONS: S_FM FOR _LOG-FNAME NO INTERVALS NO-EXTENSION.
SELECT-OPTIONS: S_GUID FOR _LOG-GUID.
SELECT-OPTIONS: S_CF1 FOR _LOG-CUST_FIELD1.
SELECT-OPTIONS: S_CF2 FOR _LOG-CUST_FIELD2.
SELECT-OPTIONS: S_CF3 FOR _LOG-CUST_FIELD3.
SELECT-OPTIONS: S_STATUS FOR _LOG-STATUS NO INTERVALS.
SELECTION-SCREEN END OF BLOCK B1.

SELECTION-SCREEN BEGIN OF BLOCK B2 WITH FRAME TITLE TEXT-T01.
SELECTION-SCREEN BEGIN OF LINE .
SELECTION-SCREEN COMMENT 1(20) TEXT-T02 FOR FIELD P_DSTART.
PARAMETERS: P_DSTART TYPE EDIDC-UPDDAT DEFAULT SY-DATUM.
SELECTION-SCREEN COMMENT 35(20) TEXT-T03 FOR FIELD P_DEND.
PARAMETERS: P_DEND TYPE EDIDC-UPDDAT.
SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN BEGIN OF LINE .
SELECTION-SCREEN COMMENT 1(20) TEXT-T04 FOR FIELD P_TSTART.
PARAMETERS: P_TSTART TYPE EDIDC-UPDTIM DEFAULT '000000'.
SELECTION-SCREEN COMMENT 35(20) TEXT-T05 FOR FIELD P_TEND.
PARAMETERS: P_TEND TYPE EDIDC-UPDTIM DEFAULT '235959'.
SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN END OF BLOCK B2.

* Block: Number Of Hits.
SELECTION-SCREEN BEGIN OF BLOCK NO_OF_HITS WITH FRAME TITLE TEXT-T06.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(20) FOR FIELD PV_NOFHS.
PARAMETERS PV_NOFHS TYPE I DEFAULT 1000 MODIF ID NH2.
SELECTION-SCREEN POSITION 40.
PARAMETERS PC_NHNL AS CHECKBOX USER-COMMAND NH1.
SELECTION-SCREEN COMMENT 47(30) TEXT-T07 FOR FIELD PC_NHNL.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK NO_OF_HITS.

TYPES: TY_TIME_COND TYPE RANGE OF TIMESTAMP.

DATA: GT_LOG TYPE STANDARD TABLE OF ZFN_LOG.
DATA: GR_ALV TYPE REF TO CL_SALV_TABLE.

CLASS LCL_HANDLE_EVENTS DEFINITION.
  PUBLIC SECTION.
    METHODS:
      ON_USER_COMMAND FOR EVENT ADDED_FUNCTION OF CL_SALV_EVENTS
        IMPORTING E_SALV_FUNCTION,

      ON_LINK_CLICK FOR EVENT LINK_CLICK OF CL_SALV_EVENTS_TABLE
        IMPORTING ROW COLUMN.
ENDCLASS.

CLASS LCL_HANDLE_EVENTS IMPLEMENTATION.
  METHOD ON_USER_COMMAND.
    PERFORM HANDLE_USER_COMMAND USING E_SALV_FUNCTION.
  ENDMETHOD.                    "on_user_command
  "on_double_click

  METHOD ON_LINK_CLICK.

    DATA: VALUE TYPE STRING.

    READ TABLE GT_LOG INDEX ROW ASSIGNING FIELD-SYMBOL(<ROW>).
    IF SY-SUBRC = 0.
      ASSIGN COMPONENT COLUMN OF STRUCTURE <ROW> TO FIELD-SYMBOL(<VALUE>).
      IF SY-SUBRC = 0.
        VALUE = <VALUE>.
      ENDIF.
    ENDIF.

    IF COLUMN = 'FNAME'.

      DATA(FM_NAME) = CONV RS38L_FNAM( VALUE ).
      SET PARAMETER ID 'LIB' FIELD FM_NAME.
      CALL TRANSACTION 'SE37' AND SKIP FIRST SCREEN.

    ELSE.

      CL_DEMO_OUTPUT=>DISPLAY_JSON( <VALUE> ).

    ENDIF.

  ENDMETHOD.                    "on_single_click
ENDCLASS.


INITIALIZATION.


START-OF-SELECTION.

  DATA(GR_EVENTS) = NEW LCL_HANDLE_EVENTS( ).

  PERFORM GET_DATA.

  PERFORM DISPLAY.
*&---------------------------------------------------------------------*
*&      Form  GET_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM GET_DATA.


  DATA: S_TS TYPE TY_TIME_COND.

  PERFORM GET_TIME_COND USING P_DSTART
                              P_DEND
                              P_TSTART
                              P_TEND
                              S_TS.

  SELECT * FROM ZFN_LOG
    WHERE GUID        IN @S_GUID
      AND FNAME       IN @S_FM
      AND CUST_FIELD1 IN @S_CF1
      AND CUST_FIELD2 IN @S_CF2
      AND CUST_FIELD3 IN @S_CF3
      AND STATUS      IN @S_STATUS
      AND TIMESTAMP   IN @S_TS
    INTO TABLE @GT_LOG
    UP TO @PV_NOFHS ROWS.

ENDFORM.

FORM GET_TIME_COND USING SDATE  TYPE DATS
                         EDATE  TYPE DATS
                         STIME  TYPE UZEIT
                         ETIME  TYPE UZEIT
                         RESULT TYPE TY_TIME_COND.
  IF SDATE IS INITIAL AND EDATE IS INITIAL.
    RETURN.
  ENDIF.

  DATA(START_DATE) = SDATE.
  DATA(END_DATE) = EDATE.

  IF END_DATE IS INITIAL.
    END_DATE = START_DATE.
  ENDIF.

  IF START_DATE IS INITIAL.
    START_DATE = END_DATE.
  ENDIF.

  DATA(START_TIMESTAMP) = START_DATE && STIME.
  DATA(END_TIMESTAMP)   = END_DATE && ETIME.

  RESULT = VALUE #( SIGN = 'I' OPTION = 'BT' (
      LOW  = START_TIMESTAMP
      HIGH = END_TIMESTAMP
    )
  ).
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  DISPLAY
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM DISPLAY.

  TRY.
      CL_SALV_TABLE=>FACTORY(
        IMPORTING
          R_SALV_TABLE = GR_ALV
        CHANGING
          T_TABLE      = GT_LOG ).
    CATCH CX_SALV_MSG INTO DATA(LR_MSG).
  ENDTRY.

  DATA(LR_COLS) = CAST CL_SALV_COLUMNS( GR_ALV->GET_COLUMNS( ) ).

  LR_COLS->SET_OPTIMIZE( 'X' ).

  GR_ALV->SET_SCREEN_STATUS(
    PFSTATUS      =  'SALV_STANDARD'
    REPORT        =  SY-REPID
    SET_FUNCTIONS = GR_ALV->C_FUNCTIONS_ALL
  ).

  DATA(LR_SELECTIONS) = GR_ALV->GET_SELECTIONS( ).
  LR_SELECTIONS->SET_SELECTION_MODE( 3 ).

  DATA: LR_FUNCTIONS TYPE REF TO CL_SALV_FUNCTIONS.

  IF ZCL_FN_UTILITIES=>GET_DISTINCT_COUNT( TAB_DATA = GT_LOG FIELD_NAME = 'FNAME' ) = 1.
    SELECT SINGLE CUST_NAME1, CUST_NAME2, CUST_NAME3 FROM ZFN_LOG_CONFIG
      INTO @DATA(CONFIG).
  ENDIF.

  IF CONFIG IS INITIAL.
    CONFIG = VALUE #(
      CUST_NAME1 = 'CUST_FIELD1'
      CUST_NAME2 = 'CUST_FIELD2'
      CUST_NAME3 = 'CUST_FIELD3'
    ).
  ENDIF.

  IF SY-LANGU = 'E'.
    PERFORM SET_COLUMN USING ''  LR_COLS 'GUID'        'GUID' .
    PERFORM SET_COLUMN USING 'X' LR_COLS 'FNAME'       'Function Module' .
    PERFORM SET_COLUMN USING ''  LR_COLS 'CUST_FIELD1'  CONFIG-CUST_NAME1.
    PERFORM SET_COLUMN USING ''  LR_COLS 'CUST_FIELD2'  CONFIG-CUST_NAME2.
    PERFORM SET_COLUMN USING ''  LR_COLS 'CUST_FIELD3'  CONFIG-CUST_NAME3.
    PERFORM SET_COLUMN USING ''  LR_COLS 'STATUS'      'Status Code' .
    PERFORM SET_COLUMN USING ''  LR_COLS 'TIMESTAMP'   'Timestamp' .
    PERFORM SET_COLUMN USING ''  LR_COLS 'TIME_COST'   'Time Cost' .
    PERFORM SET_COLUMN USING ''  LR_COLS 'UNAME'       'User' .
    PERFORM SET_COLUMN USING ''  LR_COLS 'MESSAGE'     'Message' .
    PERFORM SET_COLUMN USING 'X' LR_COLS 'IMPORT'      'Import Data' .
    PERFORM SET_COLUMN USING 'X' LR_COLS 'EXPORT'      'Export Data' .
    PERFORM SET_COLUMN USING 'X' LR_COLS 'CHANGE_IN'   'Changing In' .
    PERFORM SET_COLUMN USING 'X' LR_COLS 'CHANGE_OUT'  'Changing Out' .
    PERFORM SET_COLUMN USING 'X' LR_COLS 'TABLE_IN'    'Tables In ' .
    PERFORM SET_COLUMN USING 'X' LR_COLS 'TABLE_OUT'   'Tables Out' .
  ELSE.
    PERFORM SET_COLUMN USING ''  LR_COLS 'GUID'        'GUID' .
    PERFORM SET_COLUMN USING 'X' LR_COLS 'FNAME'       '????????????' .
    PERFORM SET_COLUMN USING ''  LR_COLS 'CUST_FIELD1'  '????????????1'.
    PERFORM SET_COLUMN USING ''  LR_COLS 'CUST_FIELD2'  '????????????2'.
    PERFORM SET_COLUMN USING ''  LR_COLS 'CUST_FIELD3' '????????????3'.
    PERFORM SET_COLUMN USING ''  LR_COLS 'STATUS'      '????????????'.
    PERFORM SET_COLUMN USING ''  LR_COLS 'TIMESTAMP'   '?????????' .
    PERFORM SET_COLUMN USING ''  LR_COLS 'TIME_COST'   '????????????' .
    PERFORM SET_COLUMN USING ''  LR_COLS 'UNAME'       '??????' .
    PERFORM SET_COLUMN USING ''  LR_COLS 'MESSAGE'     '??????' .
    PERFORM SET_COLUMN USING 'X' LR_COLS 'IMPORT'      '????????????' .
    PERFORM SET_COLUMN USING 'X' LR_COLS 'EXPORT'      '????????????' .
    PERFORM SET_COLUMN USING 'X' LR_COLS 'CHANGE_IN'   '????????????' .
    PERFORM SET_COLUMN USING 'X' LR_COLS 'CHANGE_OUT'  '????????????' .
    PERFORM SET_COLUMN USING 'X' LR_COLS 'TABLE_IN'    '?????????' .
    PERFORM SET_COLUMN USING 'X' LR_COLS 'TABLE_OUT'   '?????????' .
  ENDIF.

  DATA(LR_EVENTS) = GR_ALV->GET_EVENT( ).

  SET HANDLER GR_EVENTS->ON_USER_COMMAND FOR LR_EVENTS.

  SET HANDLER GR_EVENTS->ON_LINK_CLICK FOR LR_EVENTS.


  GR_ALV->DISPLAY( ).

ENDFORM.

FORM SET_COLUMN  USING  I_HOTSPOT TYPE XFELD
                        PR_COLS TYPE REF TO CL_SALV_COLUMNS
                        VALUE(FNAME)
                        VALUE(TEXT).

  DATA: LR_COLUMN TYPE REF TO CL_SALV_COLUMN_TABLE.

  TRY.
      LR_COLUMN ?= PR_COLS->GET_COLUMN( FNAME ).
      LR_COLUMN->SET_LONG_TEXT( CONV #( TEXT ) ).
      LR_COLUMN->SET_MEDIUM_TEXT( CONV #( TEXT ) ).
      LR_COLUMN->SET_SHORT_TEXT( CONV #( TEXT ) ).
      IF I_HOTSPOT = ABAP_TRUE.
        LR_COLUMN->SET_CELL_TYPE( IF_SALV_C_CELL_TYPE=>HOTSPOT ).
      ENDIF.
    CATCH CX_SALV_NOT_FOUND.                            "#EC NO_HANDLER
  ENDTRY.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  HANDLE_USER_COMMAND
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_E_SALV_FUNCTION  text
*----------------------------------------------------------------------*
FORM HANDLE_USER_COMMAND  USING  I_UCOMM TYPE SALV_DE_FUNCTION.

  CASE I_UCOMM.
    WHEN 'PROCESS'.
      IF ZCL_FN_UTILITIES=>IS_PRD( ).
        DATA: ANS TYPE C.
        CALL FUNCTION 'POPUP_TO_CONFIRM'
          EXPORTING
            TITLEBAR              = 'Confirm'(m01)
            TEXT_QUESTION         = 'You have called an IDoc test transaction in a client flagged as "Productive".'(m02)
            TEXT_BUTTON_1         = 'OK'
            ICON_BUTTON_1         = 'ICON_CHECKED'
            TEXT_BUTTON_2         = 'CANCEL'
            ICON_BUTTON_2         = 'ICON_CANCEL'
            DISPLAY_CANCEL_BUTTON = ' '
            POPUP_TYPE            = 'ICON_MESSAGE_ERROR'
          IMPORTING
            ANSWER                = ANS.
        IF ANS = 2.
          RETURN.
        ENDIF.
      ENDIF.
      PERFORM PROCESS_SELECTED_ROWS.
    WHEN 'REFRESH'.
      PERFORM GET_DATA.
      GR_ALV->REFRESH( ).
    WHEN OTHERS.
  ENDCASE.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  PROCESS_SELECTED_ROWS
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM PROCESS_SELECTED_ROWS.

  DATA(LR_SELECTIONS) = GR_ALV->GET_SELECTIONS( ).
  DATA(LT_ROWS) = LR_SELECTIONS->GET_SELECTED_ROWS( ).
  DATA:GUID TYPE GUID.
  LOOP AT LT_ROWS ASSIGNING FIELD-SYMBOL(<ROW>).

    READ TABLE GT_LOG INDEX <ROW> ASSIGNING FIELD-SYMBOL(<LOG>).
    IF SY-SUBRC = 0.
      DATA(PASS) = ZCL_FN_UTILITIES=>FM_AUTHORITY_CHECK( <LOG>-FNAME ).
      IF PASS = ABAP_FALSE.
        DATA(MSG) = |You are not authorized to test function module { <LOG>-FNAME }|.
        MESSAGE MSG TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.
    ENDIF.
  ENDLOOP.


  LOOP AT LT_ROWS ASSIGNING <ROW>.

    READ TABLE GT_LOG INDEX <ROW> ASSIGNING <LOG>.
    IF SY-SUBRC = 0.
      GUID = <LOG>-GUID.
      ZCL_FN_UTILITIES=>RE_PROCESS( GUID ).
    ENDIF.

  ENDLOOP.

  MSG = |{ LINES( LT_ROWS ) } records processed|.

  MESSAGE MSG TYPE 'S'.

ENDFORM.
