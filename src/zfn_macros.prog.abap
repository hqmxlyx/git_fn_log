*&---------------------------------------------------------------------*
*& 包含               ZFN_MACROS
*&---------------------------------------------------------------------*

DEFINE /ZFN/LOG_INIT.

  DATA: /zfn/comp_tab TYPE cl_abap_structdescr=>component_table,
        /zfn/comp_wa  LIKE LINE OF /zfn/comp_tab.
  DATA: /zfn/struct_type    TYPE REF TO cl_abap_structdescr, "Structure
        /zfn/parameter_data TYPE REF TO data.
  DATA: /zfn/table_structure_type TYPE REF TO cl_abap_structdescr,
        /zfn/table_type TYPE REF TO cl_abap_tabledescr.

  DATA: true_fieldname TYPE string.

  FIELD-SYMBOLS: </zfn/parameter_data>       TYPE any,
                 </zfn/parameter_data_field> TYPE any,
                 </zfn/parameter>            TYPE any.


  DATA: /zfn/callstack TYPE abap_callstack.

  DATA: /zfn/log TYPE ZFN_LOG.

  GET TIME.

  CALL FUNCTION 'SYSTEM_CALLSTACK'
    IMPORTING
      callstack = /zfn/callstack.

  DATA(/zfn/func_name) = VALUE #( /zfn/callstack[ 1 ]-blockname OPTIONAL ).

    SELECT SINGLE * FROM zfn_log_config
      WHERE fname   = @/zfn/func_name
        AND enabled = 'X'
      INTO @DATA(/zfn/config).
  IF sy-subrc = 0.

    SELECT funcname, paramtype, pposition, parameter, structure
      FROM fupararef
      WHERE funcname = @/zfn/func_name
      INTO TABLE @DATA(/zfn/parameters_tab).
    IF sy-subrc = 0.

      SORT /zfn/parameters_tab BY paramtype pposition.

      FIELD-SYMBOLS: </alf/parameters> LIKE LINE OF /zfn/parameters_tab,
                     </alf/comp>       LIKE LINE OF /zfn/comp_tab.

      IF /zfn/config-import = abap_true.
        /zfn/log_get_json 'I' /zfn/log-import.
      ENDIF.

      IF /zfn/config-change = abap_true.
        /zfn/log_get_json 'C' /zfn/log-change_in.
      ENDIF.

      IF /zfn/config-table_in = abap_true.
        /zfn/log_get_table_json /zfn/log-table_in.
      ENDIF.

      DATA: /zfn/start_time TYPE tzntstmpl.

      TRY.
          /zfn/log-guid = cl_system_uuid=>create_uuid_x16_static( ).
        CATCH cx_uuid_error INTO DATA(/zfn/oref).
      ENDTRY.

      GET TIME STAMP FIELD /zfn/start_time.
      GET TIME STAMP FIELD /zfn/log-timestamp.

      /zfn/log = VALUE #( BASE /zfn/log
        fname = /zfn/func_name
        uname = sy-uname
      ).

    ENDIF.
  ENDIF.

END-OF-DEFINITION.

DEFINE /ZFN/LOG_GET_JSON.

  CLEAR /zfn/comp_tab.

  LOOP AT /zfn/parameters_tab ASSIGNING </alf/parameters> WHERE paramtype = &1.
    /zfn/comp_wa-name = </alf/parameters>-parameter.
    /zfn/comp_wa-type ?= cl_abap_datadescr=>describe_by_name( </alf/parameters>-structure ).
    APPEND /zfn/comp_wa TO /zfn/comp_tab.
  ENDLOOP.

  IF /zfn/comp_tab IS NOT INITIAL.
    /zfn/struct_type = cl_abap_structdescr=>create( /zfn/comp_tab ).

    CREATE DATA /zfn/parameter_data TYPE HANDLE /zfn/struct_type.

    ASSIGN /zfn/parameter_data->* TO </zfn/parameter_data>.

    LOOP AT /zfn/comp_tab ASSIGNING </alf/comp>.
      ASSIGN (</alf/comp>-name) TO </zfn/parameter>.
      ASSIGN COMPONENT </alf/comp>-name OF STRUCTURE </zfn/parameter_data> TO </zfn/parameter_data_field>.
      </zfn/parameter_data_field> = </zfn/parameter>.
    ENDLOOP.

    &2 = /ui2/cl_json=>serialize( data = </zfn/parameter_data> ).
  ENDIF.

END-OF-DEFINITION.

DEFINE /ZFN/SET_CUSTOM_FIELDS.

  /zfn/log = VALUE #( BASE /zfn/log
    cust_field1 = &1
    cust_field2 = &2
    cust_field3 = &3
  ).

END-OF-DEFINITION.

DEFINE /ZFN/SET_STATUS .

  /zfn/log = VALUE #( BASE /zfn/log
    status  = &1
    message = &2
  ).

END-OF-DEFINITION.

DEFINE /ZFN/SAVE .

  IF /zfn/log-guid IS NOT INITIAL.

    DATA: /zfn/end_time TYPE tzntstmpl.

    IF /zfn/config-export = abap_true.
      /zfn/log_get_json 'E' /zfn/log-export.
    ENDIF.

    IF /zfn/config-table_out = abap_true.
      /zfn/log_get_table_json /zfn/log-table_out.
    ENDIF.

    IF /zfn/config-change = abap_true.
      /zfn/log_get_json 'C' /zfn/log-change_out.
    ENDIF.

    GET TIME.

    GET TIME STAMP FIELD /zfn/end_time.

    /zfn/log-time_cost = cl_abap_tstmp=>subtract( tstmp1 = /zfn/end_time tstmp2 = /zfn/start_time ).

    MODIFY zfn_log FROM @/zfn/log.

    IF /zfn/config-no_commit = abap_false.
      COMMIT WORK.
    ENDIF.

  ENDIF.


END-OF-DEFINITION.

DEFINE /ZFN/LOG_GET_TABLE_JSON.

  CLEAR /zfn/comp_tab.

  LOOP AT /zfn/parameters_tab ASSIGNING </alf/parameters> WHERE paramtype = 'T'.
    /zfn/comp_wa-name = </alf/parameters>-parameter.
    /zfn/table_structure_type = CAST cl_abap_structdescr( cl_abap_datadescr=>describe_by_name( </alf/parameters>-structure ) ).
    /zfn/table_type = CAST cl_abap_tabledescr( cl_abap_tabledescr=>create( /zfn/table_structure_type ) ).
    /zfn/comp_wa-type ?= /zfn/table_type.
    APPEND /zfn/comp_wa TO /zfn/comp_tab.
  ENDLOOP.

  IF /zfn/comp_tab IS NOT INITIAL.
    /zfn/struct_type = cl_abap_structdescr=>create( /zfn/comp_tab ).

    CREATE DATA /zfn/parameter_data TYPE HANDLE /zfn/struct_type.

    ASSIGN /zfn/parameter_data->* TO </zfn/parameter_data>.

    LOOP AT /zfn/comp_tab ASSIGNING </alf/comp>.
      true_fieldname = </alf/comp>-name && '[]'.
      ASSIGN (true_fieldname) TO </zfn/parameter>.
      ASSIGN COMPONENT </alf/comp>-name OF STRUCTURE </zfn/parameter_data> TO </zfn/parameter_data_field>.
      </zfn/parameter_data_field> = </zfn/parameter>.
    ENDLOOP.

    &1 = /ui2/cl_json=>serialize( data = </zfn/parameter_data> ).
  ENDIF.

END-OF-DEFINITION.
