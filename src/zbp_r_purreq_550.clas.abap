"! <p class="shorttext synchronized">Behavior Implementation for ZR_PURREQ_550</p>
"! Bestellanforderung mit Freigabeprozess (RAP, managed, mit Draft).
"! Die eigentliche Logik steckt in den lokalen Klassen (Local Types).
CLASS zbp_r_purreq_550 DEFINITION PUBLIC ABSTRACT FINAL FOR BEHAVIOR OF zr_purreq_550.
  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF status,
        new       TYPE c LENGTH 1 VALUE 'N',
        submitted TYPE c LENGTH 1 VALUE 'S',
        approved  TYPE c LENGTH 1 VALUE 'A',
        rejected  TYPE c LENGTH 1 VALUE 'R',
      END OF status.

    "! Bis zu diesem Gesamtwert wird beim Einreichen automatisch freigegeben
    CONSTANTS auto_approval_limit TYPE p LENGTH 8 DECIMALS 2 VALUE '1000.00'.

    "! Vier-Augen-Prinzip: Niemand darf die eigene Anforderung entscheiden.
    "! Im gemeinsamen Trial-System mit nur einem Benutzer abgeschaltet,
    "! damit der Freigabeprozess vorgeführt werden kann.
    CONSTANTS four_eyes_check_active TYPE abap_bool VALUE abap_false.

    "! Erste vergebene BANF-Nummer minus 1
    CONSTANTS number_range_start TYPE i VALUE 10000000.
ENDCLASS.



CLASS zbp_r_purreq_550 IMPLEMENTATION.
ENDCLASS.
