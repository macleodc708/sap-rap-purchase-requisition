"! <p class="shorttext synchronized">Virtual Elements: Status Text and Criticality</p>
"! Berechnet Statustext und Farbe (Kritikalität) für die Fiori-Oberfläche,
"! sowohl für aktive Daten als auch für Entwürfe.
CLASS zcl_purreq_virt_550 DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read.
ENDCLASS.



CLASS zcl_purreq_virt_550 IMPLEMENTATION.

  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    " Für die Berechnung wird immer der Status benötigt
    INSERT `STATUS` INTO TABLE et_requested_orig_elements.
  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~calculate.
    DATA requisitions TYPE STANDARD TABLE OF zc_purreq_550 WITH DEFAULT KEY.
    requisitions = CORRESPONDING #( it_original_data ).

    LOOP AT requisitions ASSIGNING FIELD-SYMBOL(<req>).
      <req>-StatusText = SWITCH #( <req>-Status
                                   WHEN zbp_r_purreq_550=>status-new       THEN 'New'
                                   WHEN zbp_r_purreq_550=>status-submitted THEN 'Submitted'
                                   WHEN zbp_r_purreq_550=>status-approved  THEN 'Approved'
                                   WHEN zbp_r_purreq_550=>status-rejected  THEN 'Rejected'
                                   ELSE '' ).
      " 0 = neutral, 1 = rot, 2 = gelb, 3 = grün
      <req>-StatusCriticality = SWITCH #( <req>-Status
                                          WHEN zbp_r_purreq_550=>status-submitted THEN 2
                                          WHEN zbp_r_purreq_550=>status-approved  THEN 3
                                          WHEN zbp_r_purreq_550=>status-rejected  THEN 1
                                          ELSE 0 ).
    ENDLOOP.

    ct_calculated_data = CORRESPONDING #( requisitions ).
  ENDMETHOD.

ENDCLASS.
