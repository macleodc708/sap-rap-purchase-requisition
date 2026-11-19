"! Handler für den Kopf der Bestellanforderung
CLASS lhc_purreq DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR PurReq RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR PurReq RESULT result.

    METHODS setInitialValues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR PurReq~setInitialValues.

    METHODS setReqID FOR DETERMINE ON SAVE
      IMPORTING keys FOR PurReq~setReqID.

    METHODS validateNeededBy FOR VALIDATE ON SAVE
      IMPORTING keys FOR PurReq~validateNeededBy.

    METHODS recalcTotal FOR MODIFY
      IMPORTING keys FOR ACTION PurReq~recalcTotal.

    METHODS submit FOR MODIFY
      IMPORTING keys FOR ACTION PurReq~submit RESULT result.

    METHODS withdraw FOR MODIFY
      IMPORTING keys FOR ACTION PurReq~withdraw RESULT result.

    METHODS approve FOR MODIFY
      IMPORTING keys FOR ACTION PurReq~approve RESULT result.

    METHODS reject FOR MODIFY
      IMPORTING keys FOR ACTION PurReq~reject RESULT result.
ENDCLASS.


CLASS lhc_purreq IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Demo: alle Operationen erlaubt. Produktiv würde hier über
    " AUTHORITY-CHECK (z. B. Berechtigung je Kostenstelle) entschieden.
    result = VALUE #( %create          = if_abap_behv=>auth-allowed
                      %update          = if_abap_behv=>auth-allowed
                      %delete          = if_abap_behv=>auth-allowed
                      %action-submit   = if_abap_behv=>auth-allowed
                      %action-withdraw = if_abap_behv=>auth-allowed
                      %action-approve  = if_abap_behv=>auth-allowed
                      %action-reject   = if_abap_behv=>auth-allowed
                      %action-Edit     = if_abap_behv=>auth-allowed ).
  ENDMETHOD.


  METHOD get_instance_features.
    " Welche Knöpfe sind je Status aktiv? (Steuert die Fiori-Oberfläche)
    READ ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY PurReq
        FIELDS ( Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requisitions)
      FAILED failed.

    result = VALUE #( FOR req IN requisitions
      LET editable  = xsdbool( req-Status = zbp_r_purreq_550=>status-new
                            OR req-Status = zbp_r_purreq_550=>status-rejected
                            OR req-Status IS INITIAL )
          is_active = xsdbool( req-%is_draft = if_abap_behv=>mk-off )
          pending   = xsdbool( req-Status = zbp_r_purreq_550=>status-submitted AND is_active = abap_true )
      IN ( %tky             = req-%tky
           %update          = COND #( WHEN editable = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
           %action-Edit     = COND #( WHEN editable = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
           %delete          = COND #( WHEN req-Status = zbp_r_purreq_550=>status-new OR req-Status IS INITIAL
                                      THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
           %assoc-_Item     = COND #( WHEN editable = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
           %action-submit   = COND #( WHEN editable = abap_true AND is_active = abap_true
                                      THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
           %action-withdraw = COND #( WHEN pending = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
           %action-approve  = COND #( WHEN pending = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
           %action-reject   = COND #( WHEN pending = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.


  METHOD setInitialValues.
    " Neue Anforderung: Status "Neu", Währung EUR
    READ ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY PurReq
        FIELDS ( Status CurrencyCode )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requisitions).

    DELETE requisitions WHERE Status IS NOT INITIAL.
    CHECK requisitions IS NOT INITIAL.

    MODIFY ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY PurReq
        UPDATE FIELDS ( Status CurrencyCode TotalAmount )
        WITH VALUE #( FOR req IN requisitions
                      ( %tky         = req-%tky
                        Status       = zbp_r_purreq_550=>status-new
                        CurrencyCode = COND #( WHEN req-CurrencyCode IS INITIAL THEN 'EUR' ELSE req-CurrencyCode )
                        TotalAmount  = 0 ) ).
  ENDMETHOD.


  METHOD setReqID.
    " BANF-Nummer beim ersten Speichern vergeben (fortlaufend ab 10000001)
    READ ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY PurReq
        FIELDS ( ReqID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requisitions).

    DELETE requisitions WHERE ReqID IS NOT INITIAL.
    CHECK requisitions IS NOT INITIAL.

    SELECT SINGLE FROM zpr_req_550 FIELDS MAX( req_id ) INTO @DATA(max_req_id).
    DATA(last_number) = COND i( WHEN max_req_id IS INITIAL THEN zbp_r_purreq_550=>number_range_start
                                ELSE CONV i( max_req_id ) ).

    MODIFY ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY PurReq
        UPDATE FIELDS ( ReqID )
        WITH VALUE #( FOR req IN requisitions INDEX INTO i
                      ( %tky  = req-%tky
                        ReqID = |{ last_number + i }| ) ).
  ENDMETHOD.


  METHOD validateNeededBy.
    " "Benötigt bis" darf nicht in der Vergangenheit liegen
    READ ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY PurReq
        FIELDS ( NeededBy )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requisitions).

    DATA(today) = cl_abap_context_info=>get_system_date( ).

    LOOP AT requisitions INTO DATA(req).
      APPEND VALUE #( %tky        = req-%tky
                      %state_area = 'VALIDATE_NEEDED_BY' ) TO reported-purreq.

      IF req-NeededBy IS NOT INITIAL AND req-NeededBy < today.
        APPEND VALUE #( %tky = req-%tky ) TO failed-purreq.
        APPEND VALUE #( %tky              = req-%tky
                        %state_area       = 'VALIDATE_NEEDED_BY'
                        %msg              = new_message_with_text(
                                              severity = if_abap_behv_message=>severity-error
                                              text     = 'The "needed by" date must not be in the past.' )
                        %element-NeededBy = if_abap_behv=>mk-on ) TO reported-purreq.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD recalcTotal.
    " Gesamtwert = Summe der Nettowerte aller Positionen
    READ ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY PurReq BY \_Item
        FIELDS ( NetAmount )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items)
      LINK DATA(links).

    DATA updates TYPE TABLE FOR UPDATE zr_purreq_550\\PurReq.

    DATA total TYPE zr_purreq_550-TotalAmount.

    LOOP AT keys INTO DATA(key).
      CLEAR total.
      LOOP AT links INTO DATA(link) WHERE source-ReqUUID = key-ReqUUID.
        total = total + VALUE #( items[ ItemUUID = link-target-ItemUUID ]-NetAmount OPTIONAL ).
      ENDLOOP.
      APPEND VALUE #( %tky = key-%tky TotalAmount = total ) TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY PurReq
        UPDATE FIELDS ( TotalAmount )
        WITH updates.
  ENDMETHOD.


  METHOD submit.
    " Einreichen: bis zur Wertgrenze automatisch freigeben, sonst "Zur Freigabe"
    READ ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY PurReq
        FIELDS ( Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requisitions)
      ENTITY PurReq BY \_Item
        FIELDS ( NetAmount )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items)
      LINK DATA(links).

    DATA updates TYPE TABLE FOR UPDATE zr_purreq_550\\PurReq.
    DATA now TYPE timestampl.
    GET TIME STAMP FIELD now.

    DATA total TYPE zr_purreq_550-TotalAmount.

    LOOP AT requisitions INTO DATA(req).
      DATA(item_count) = 0.
      CLEAR total.
      LOOP AT links INTO DATA(link) WHERE source-ReqUUID = req-ReqUUID.
        item_count = item_count + 1.
        total = total + VALUE #( items[ ItemUUID = link-target-ItemUUID ]-NetAmount OPTIONAL ).
      ENDLOOP.

      IF item_count = 0.
        APPEND VALUE #( %tky = req-%tky ) TO failed-purreq.
        APPEND VALUE #( %tky = req-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Add at least one item before submitting.' ) ) TO reported-purreq.
        CONTINUE.
      ENDIF.

      IF total <= zbp_r_purreq_550=>auto_approval_limit.
        APPEND VALUE #( %tky            = req-%tky
                        Status          = zbp_r_purreq_550=>status-approved
                        TotalAmount     = total
                        DecidedBy       = 'SYSTEM'
                        DecidedAt       = now
                        RejectionReason = '' ) TO updates.
        APPEND VALUE #( %tky = req-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-success
                                 text     = 'Approved automatically (total up to 1,000.00).' ) ) TO reported-purreq.
      ELSE.
        APPEND VALUE #( %tky            = req-%tky
                        Status          = zbp_r_purreq_550=>status-submitted
                        TotalAmount     = total
                        DecidedBy       = ''
                        DecidedAt       = 0
                        RejectionReason = '' ) TO updates.
        APPEND VALUE #( %tky = req-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-success
                                 text     = 'Submitted for approval.' ) ) TO reported-purreq.
      ENDIF.
    ENDLOOP.

    MODIFY ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY PurReq
        UPDATE FIELDS ( Status TotalAmount DecidedBy DecidedAt RejectionReason )
        WITH updates.

    READ ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY PurReq
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(updated).
    result = VALUE #( FOR u IN updated ( %tky = u-%tky %param = u ) ).
  ENDMETHOD.


  METHOD withdraw.
    " Zurückziehen: eingereichte Anforderung wieder auf "Neu" setzen
    MODIFY ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY PurReq
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = zbp_r_purreq_550=>status-new ) ).

    READ ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY PurReq
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(updated).
    result = VALUE #( FOR u IN updated ( %tky = u-%tky %param = u ) ).
  ENDMETHOD.


  METHOD approve.
    " Freigeben (mit Vier-Augen-Prinzip)
    READ ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY PurReq
        FIELDS ( Status LocalCreatedBy )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requisitions).

    DATA(user) = cl_abap_context_info=>get_user_technical_name( ).
    DATA updates TYPE TABLE FOR UPDATE zr_purreq_550\\PurReq.
    DATA now TYPE timestampl.
    GET TIME STAMP FIELD now.

    LOOP AT requisitions INTO DATA(req).
      IF zbp_r_purreq_550=>four_eyes_check_active = abap_true AND req-LocalCreatedBy = user.
        APPEND VALUE #( %tky = req-%tky ) TO failed-purreq.
        APPEND VALUE #( %tky = req-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Segregation of duties: you cannot approve your own requisition.' ) ) TO reported-purreq.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( %tky      = req-%tky
                      Status    = zbp_r_purreq_550=>status-approved
                      DecidedBy = user
                      DecidedAt = now ) TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY PurReq
        UPDATE FIELDS ( Status DecidedBy DecidedAt )
        WITH updates.

    READ ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY PurReq
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(updated).
    result = VALUE #( FOR u IN updated ( %tky = u-%tky %param = u ) ).
  ENDMETHOD.


  METHOD reject.
    " Ablehnen: Begründung ist Pflicht (Parameter-Dialog in Fiori)
    READ ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY PurReq
        FIELDS ( Status LocalCreatedBy )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requisitions).

    DATA(user) = cl_abap_context_info=>get_user_technical_name( ).
    DATA updates TYPE TABLE FOR UPDATE zr_purreq_550\\PurReq.
    DATA now TYPE timestampl.
    GET TIME STAMP FIELD now.

    LOOP AT requisitions INTO DATA(req).
      DATA(reason) = VALUE #( keys[ KEY id %tky = req-%tky ]-%param-RejectionReason OPTIONAL ).

      IF reason IS INITIAL.
        APPEND VALUE #( %tky = req-%tky ) TO failed-purreq.
        APPEND VALUE #( %tky = req-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Please enter a reason for the rejection.' ) ) TO reported-purreq.
        CONTINUE.
      ENDIF.

      IF zbp_r_purreq_550=>four_eyes_check_active = abap_true AND req-LocalCreatedBy = user.
        APPEND VALUE #( %tky = req-%tky ) TO failed-purreq.
        APPEND VALUE #( %tky = req-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Segregation of duties: you cannot reject your own requisition.' ) ) TO reported-purreq.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky            = req-%tky
                      Status          = zbp_r_purreq_550=>status-rejected
                      DecidedBy       = user
                      DecidedAt       = now
                      RejectionReason = reason ) TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY PurReq
        UPDATE FIELDS ( Status DecidedBy DecidedAt RejectionReason )
        WITH updates.

    READ ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY PurReq
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(updated).
    result = VALUE #( FOR u IN updated ( %tky = u-%tky %param = u ) ).
  ENDMETHOD.

ENDCLASS.


"! Handler für die Positionen
CLASS lhc_item DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS setItemDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~setItemDefaults.

    METHODS calcNetAmount FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~calcNetAmount.

    METHODS validateQuantity FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~validateQuantity.
ENDCLASS.


CLASS lhc_item IMPLEMENTATION.

  METHOD setItemDefaults.
    " Positionsnummer in 10er-Schritten (10, 20, 30 ...) und Währung vom Kopf
    READ ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY Item BY \_PurReq
        FIELDS ( CurrencyCode )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requisitions)
      LINK DATA(item_to_req).

    READ ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY PurReq BY \_Item
        FIELDS ( ItemNo )
        WITH CORRESPONDING #( requisitions )
      RESULT DATA(all_items)
      LINK DATA(req_to_items).

    DATA updates TYPE TABLE FOR UPDATE zr_purreq_550\\Item.

    LOOP AT requisitions INTO DATA(req).
      " höchste vorhandene Positionsnummer dieser Anforderung
      DATA(max_no) = 0.
      LOOP AT req_to_items INTO DATA(r2i) WHERE source-ReqUUID = req-ReqUUID.
        DATA(existing_no) = VALUE #( all_items[ ItemUUID = r2i-target-ItemUUID ]-ItemNo OPTIONAL ).
        IF existing_no > max_no.
          max_no = existing_no.
        ENDIF.
      ENDLOOP.

      " neue Positionen dieser Anforderung durchnummerieren
      LOOP AT item_to_req INTO DATA(i2r) WHERE target-ReqUUID = req-ReqUUID.
        DATA(current_no) = VALUE #( all_items[ ItemUUID = i2r-source-ItemUUID ]-ItemNo OPTIONAL ).
        IF current_no IS INITIAL.
          max_no = max_no + 10.
          current_no = max_no.
        ENDIF.
        APPEND VALUE #( %tky         = i2r-source-%tky
                        ItemNo       = current_no
                        CurrencyCode = req-CurrencyCode ) TO updates.
      ENDLOOP.
    ENDLOOP.

    MODIFY ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY Item
        UPDATE FIELDS ( ItemNo CurrencyCode )
        WITH updates.
  ENDMETHOD.


  METHOD calcNetAmount.
    " Nettowert = Menge x Preis, danach Gesamtwert am Kopf neu berechnen
    READ ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY Item
        FIELDS ( Quantity UnitPrice )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    MODIFY ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY Item
        UPDATE FIELDS ( NetAmount )
        WITH VALUE #( FOR item IN items
                      ( %tky      = item-%tky
                        NetAmount = item-Quantity * item-UnitPrice ) ).

    READ ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY Item BY \_PurReq
        FIELDS ( ReqUUID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requisitions).

    DATA parents TYPE TABLE FOR ACTION IMPORT zr_purreq_550\\PurReq~recalcTotal.
    LOOP AT requisitions INTO DATA(req).
      IF NOT line_exists( parents[ %tky = req-%tky ] ).
        APPEND VALUE #( %tky = req-%tky ) TO parents.
      ENDIF.
    ENDLOOP.

    MODIFY ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY PurReq
        EXECUTE recalcTotal
        FROM parents.
  ENDMETHOD.


  METHOD validateQuantity.
    " Menge muss größer als null sein
    READ ENTITIES OF zr_purreq_550 IN LOCAL MODE
      ENTITY Item
        FIELDS ( Quantity )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    LOOP AT items INTO DATA(item).
      APPEND VALUE #( %tky        = item-%tky
                      %state_area = 'VALIDATE_QUANTITY' ) TO reported-item.

      IF item-Quantity <= 0.
        APPEND VALUE #( %tky = item-%tky ) TO failed-item.
        APPEND VALUE #( %tky              = item-%tky
                        %state_area       = 'VALIDATE_QUANTITY'
                        %msg              = new_message_with_text(
                                              severity = if_abap_behv_message=>severity-error
                                              text     = 'The quantity must be greater than zero.' )
                        %element-Quantity = if_abap_behv=>mk-on ) TO reported-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
