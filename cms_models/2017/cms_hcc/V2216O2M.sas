 %MACRO V2216O2M(INP=, IND=, OUTDATA=, IDVAR=, KEEPVAR=, SEDITS=,
                 DATE_ASOF=, DATE_ASOF_EDIT=,
                 FMNAME9=V22Y15RC, FMNAME0=V22Y16RC,
                 AGEFMT9=I9AGEY15MCE, SEXFMT9=I9SEXY15MCE,
                 AGEFMT0=I0AGEY16MCE, SEXFMT0=I0SEXY16MCE, DF=1,
                 AGESEXMAC=AGESEXV2, EDITMAC9=V22I9ED1,
                 EDITMAC0=V22I0ED1, LABELMAC=V22H79L1,
                 HIERMAC=V22H79H1, SCOREMAC=SCOREVAR);

%**********************************************************************
 * Score variables are created using coefficients from 9 final models:
 * 1) Community NonDual Aged
 * 2) Community NonDual Disabled
 * 3) Community Full Benefit Dual Aged
 * 4) Community Full Benefit Dual Disabled
 * 5) Community Partial Benefit Dual Aged
 * 6) Community Partial Benefit Dual Disabled
 * 7) Long Term Institutional
 * 8) New Enrollees
 * 9) SNP New Enrollees
 *
 * Assumptions about input files:
 *   - both files are sorted by person ID
 *   - person level file has the following variables:
 *     :&IDVAR   - person ID variable (it is a macro parameter)
 *     :DOB      - date of birth
 *     :SEX      - sex
 *     :OREC     - original reason for entitlement
 *     :LTIMCAID - Medicaid dummy variable for LTI
 *     :NEMCAID  - Medicaid dummy variable for new enrollees
 *
 *   - diagnosis level file has the following variables:
 *     :&IDVAR  - person ID variable (it is a macro parameter)
 *     :DIAG    - diagnosis
 *     :DIAG_TYPE - '9' for ICD9, '0' for ICD10
 *
 * Parameters:
 * INP            - input person dataset
 * IND            - input diagnosis dataset
 * OUTDATA        - output dataset
 * IDVAR          - name of person id variable (HICNO for Medicare data)
 * KEEPVAR        - variables to keep in the output file
 * SEDITS         - a switch that controls whether to perform MCE edits
 *                  on ICD9 and ICD10. 1-YES, 0-NO
 * DATE_ASOF      - reference date to calculate age. Set to February 1
 *                  of the payment year for consistency with CMS.
 * DATE_ASOF_EDIT - reference date to calculate age used for
 *                  validation of diagnoses (MCE edits)
 * FMNAME9        - format name (crosswalk ICD9 to V22 CCs)
 * FMNAME0        - format name (crosswalk ICD10 to V22 CCs)
 * AGEFMT9        - format name (crosswalk ICD9 to acceptable age range
 *                  in case MCE edits on diags are to be performed)
 * AGEFMT0        - format name (crosswalk ICD10 to acceptable age range
 *                  in case MCE edits on diags are to be performed)
 * SEXFMT9        - format name (crosswalk ICD9 to acceptable sex in
 *                  case MCE edits on diags are to be performed)
 * SEXFMT0        - format name (crosswalk ICD10 to acceptable sex in
 *                  case MCE edits on diags are to be performed)
 * DF             - normalization factor.
 *                  Default=1
 * AGESEXMAC      - external macro name: create age/sex,
 *                  originally disabled, disabled vars
 * EDITMAC9       - external macro name: perform edits to ICD9
 * EDITMAC0       - external macro name: perform edits to ICD10
 * LABELMAC       - external macro name: assign labels to HCCs
 * HIERMAC        - external macro name: set HCC=0 according to
 *                  hierarchies
 * SCOREMAC       - external macro name: calculate a score variable
 *
 **********************************************************************;

 %**********************************************************************
 * step1: include external macros
 **********************************************************************;
 %IF "&AGESEXMAC" ne "" %THEN %DO;
     %INCLUDE IN0(&AGESEXMAC) /SOURCE2; %* create demographic variables;
 %END;
 %IF "&EDITMAC9" ne "" %THEN %DO;
     %INCLUDE IN0(&EDITMAC9)   /SOURCE2; %* perform edits on ICD9;
 %END;
 %IF "&EDITMAC0" ne "" %THEN %DO;
     %INCLUDE IN0(&EDITMAC0)   /SOURCE2; %* perform edits on ICD10;
 %END;
 %IF "&LABELMAC" ne "" %THEN %DO;
     %INCLUDE IN0(&LABELMAC)  /SOURCE2; %* hcc labels;
 %END;
 %IF "&HIERMAC" ne "" %THEN %DO;
     %INCLUDE IN0(&HIERMAC)   /SOURCE2; %* hierarchies;
 %END;
 %IF "&SCOREMAC" ne "" %THEN %DO;
     %INCLUDE IN0(&SCOREMAC)  /SOURCE2; %* calculate score variable;
 %END;

 %**********************************************************************
 * step2: define internal macro variables
 **********************************************************************;

 %LET N_CC=201; %*max # of HCCs;

 %* age/sex variables for Community Aged regression;
 %LET AGESEXVA=                                    F65_69
                F70_74 F75_79 F80_84 F85_89 F90_94 F95_GT
                                                   M65_69
                M70_74 M75_79 M80_84 M85_89 M90_94 M95_GT;

 %* age/sex variables for Community Disabled regression;
 %LET AGESEXVD= F0_34  F35_44 F45_54 F55_59 F60_64
                M0_34  M35_44 M45_54 M55_59 M60_64;


 %* diagnostic categories necessary to create interaction variables;
 %LET DIAG_CAT= CANCER  DIABETES  CHF CARD_RESP_FAIL
                gCopdCF  RENAL  SEPSIS PRESSURE_ULCER
                gSubstanceAbuse
                gPsychiatric;


 %*orig disabled interactions for Community Aged regressions;
 %LET ORIG_INT =%STR(OriginallyDisabled_Female OriginallyDisabled_Male);

 %*interaction variables for Community Aged regressions;
 %LET INTERRACC_VARSA=%STR(HCC47_gCancer
           HCC85_gDiabetesMellit
           HCC85_gCopdCF
           HCC85_gRenal
           gRespDepandArre_gCopdCF
           HCC85_HCC96
           );

 %*interaction variables for Community Disabled regressions;
  %LET INTERRACC_VARSD=%STR(HCC47_gCancer
           HCC85_gDiabetesMellit
           HCC85_gCopdCF
           HCC85_gRenal
           gRespDepandArre_gCopdCF
           HCC85_HCC96
           gSubstanceAbuse_gPsychiatric
           );


 %*variables for Community Aged regressions ;
 %LET COMM_REGA= &AGESEXVA
                 &orig_int
                 &HCCV22_list79
                 &INTERRACC_VARSA ;


 %*variables for Community Disabled regressions ;
 %LET COMM_REGD= &AGESEXVD
                 &HCCV22_list79
                 &INTERRACC_VARSD;


 %* age/sex variables for Insititutional regression;
 %LET AGESEXV=  F0_34  F35_44 F45_54 F55_59 F60_64 F65_69
                F70_74 F75_79 F80_84 F85_89 F90_94 F95_GT
                M0_34  M35_44 M45_54 M55_59 M60_64 M65_69
                M70_74 M75_79 M80_84 M85_89 M90_94 M95_GT;


 %*interaction variables for Institutional regression;
 %LET INTERRACI_VARS = %STR(DISABLED_HCC85       DISABLED_PRESSURE_ULCER
                            DISABLED_HCC161      DISABLED_HCC39
                            DISABLED_HCC77       DISABLED_HCC6
                            CHF_gCopdCF
                            gCopdCF_CARD_RESP_FAIL
                            SEPSIS_PRESSURE_ULCER
                            SEPSIS_ARTIF_OPENINGS
                            ART_OPENINGS_PRESSURE_ULCER
                            DIABETES_CHF
                            gCopdCF_ASP_SPEC_BACT_PNEUM
                            ASP_SPEC_BACT_PNEUM_PRES_ULC
                            SEPSIS_ASP_SPEC_BACT_PNEUM
                            SCHIZOPHRENIA_gCopdCF
                            SCHIZOPHRENIA_CHF
                            SCHIZOPHRENIA_SEIZURES);


 %*variables for Institutional regression;
 %LET INST_REG = %STR(&AGESEXV
                      LTIMCAID  ORIGDS
                      &INTERRACI_VARS
                      &HCCV22_list79);

 %*age/sex variables for non-ORIGDS New Enrollee and SNP New Enrollee
 interactions;
 %LET NE_AGESEXV=
      NEF0_34    NEF35_44   NEF45_54   NEF55_59   NEF60_64
      NEF65      NEF66      NEF67      NEF68      NEF69
      NEF70_74   NEF75_79   NEF80_84
      NEF85_89   NEF90_94   NEF95_GT
      NEM0_34    NEM35_44   NEM45_54   NEM55_59   NEM60_64
      NEM65      NEM66      NEM67      NEM68      NEM69
      NEM70_74   NEM75_79   NEM80_84
      NEM85_89   NEM90_94   NEM95_GT;

 %*age/sex variables for ORIGDS New Enrollee and SNP New Enrollee
 interactions;
 %LET ONE_AGESEXV=
      NEF65      NEF66      NEF67      NEF68      NEF69
      NEF70_74   NEF75_79   NEF80_84
      NEF85_89   NEF90_94   NEF95_GT
      NEM65      NEM66      NEM67      NEM68      NEM69
      NEM70_74   NEM75_79   NEM80_84
      NEM85_89   NEM90_94   NEM95_GT;


 %*variables for New Enrollee and SNP New Enrollee regression;
 %LET NE_REG=%STR(
   NMCAID_NORIGDIS_NEF0_34        NMCAID_NORIGDIS_NEF35_44
   NMCAID_NORIGDIS_NEF45_54       NMCAID_NORIGDIS_NEF55_59
   NMCAID_NORIGDIS_NEF60_64       NMCAID_NORIGDIS_NEF65
   NMCAID_NORIGDIS_NEF66          NMCAID_NORIGDIS_NEF67
   NMCAID_NORIGDIS_NEF68          NMCAID_NORIGDIS_NEF69
   NMCAID_NORIGDIS_NEF70_74       NMCAID_NORIGDIS_NEF75_79
   NMCAID_NORIGDIS_NEF80_84       NMCAID_NORIGDIS_NEF85_89
   NMCAID_NORIGDIS_NEF90_94       NMCAID_NORIGDIS_NEF95_GT

   NMCAID_NORIGDIS_NEM0_34        NMCAID_NORIGDIS_NEM35_44
   NMCAID_NORIGDIS_NEM45_54       NMCAID_NORIGDIS_NEM55_59
   NMCAID_NORIGDIS_NEM60_64       NMCAID_NORIGDIS_NEM65
   NMCAID_NORIGDIS_NEM66          NMCAID_NORIGDIS_NEM67
   NMCAID_NORIGDIS_NEM68          NMCAID_NORIGDIS_NEM69
   NMCAID_NORIGDIS_NEM70_74       NMCAID_NORIGDIS_NEM75_79
   NMCAID_NORIGDIS_NEM80_84       NMCAID_NORIGDIS_NEM85_89
   NMCAID_NORIGDIS_NEM90_94       NMCAID_NORIGDIS_NEM95_GT

   MCAID_NORIGDIS_NEF0_34         MCAID_NORIGDIS_NEF35_44
   MCAID_NORIGDIS_NEF45_54        MCAID_NORIGDIS_NEF55_59
   MCAID_NORIGDIS_NEF60_64        MCAID_NORIGDIS_NEF65
   MCAID_NORIGDIS_NEF66           MCAID_NORIGDIS_NEF67
   MCAID_NORIGDIS_NEF68           MCAID_NORIGDIS_NEF69
   MCAID_NORIGDIS_NEF70_74        MCAID_NORIGDIS_NEF75_79
   MCAID_NORIGDIS_NEF80_84        MCAID_NORIGDIS_NEF85_89
   MCAID_NORIGDIS_NEF90_94        MCAID_NORIGDIS_NEF95_GT

   MCAID_NORIGDIS_NEM0_34         MCAID_NORIGDIS_NEM35_44
   MCAID_NORIGDIS_NEM45_54        MCAID_NORIGDIS_NEM55_59
   MCAID_NORIGDIS_NEM60_64        MCAID_NORIGDIS_NEM65
   MCAID_NORIGDIS_NEM66           MCAID_NORIGDIS_NEM67
   MCAID_NORIGDIS_NEM68           MCAID_NORIGDIS_NEM69
   MCAID_NORIGDIS_NEM70_74        MCAID_NORIGDIS_NEM75_79
   MCAID_NORIGDIS_NEM80_84        MCAID_NORIGDIS_NEM85_89
   MCAID_NORIGDIS_NEM90_94        MCAID_NORIGDIS_NEM95_GT

   NMCAID_ORIGDIS_NEF65           NMCAID_ORIGDIS_NEF66
   NMCAID_ORIGDIS_NEF67           NMCAID_ORIGDIS_NEF68
   NMCAID_ORIGDIS_NEF69           NMCAID_ORIGDIS_NEF70_74
   NMCAID_ORIGDIS_NEF75_79        NMCAID_ORIGDIS_NEF80_84
   NMCAID_ORIGDIS_NEF85_89        NMCAID_ORIGDIS_NEF90_94
   NMCAID_ORIGDIS_NEF95_GT

   NMCAID_ORIGDIS_NEM65           NMCAID_ORIGDIS_NEM66
   NMCAID_ORIGDIS_NEM67           NMCAID_ORIGDIS_NEM68
   NMCAID_ORIGDIS_NEM69           NMCAID_ORIGDIS_NEM70_74
   NMCAID_ORIGDIS_NEM75_79        NMCAID_ORIGDIS_NEM80_84
   NMCAID_ORIGDIS_NEM85_89        NMCAID_ORIGDIS_NEM90_94
   NMCAID_ORIGDIS_NEM95_GT

   MCAID_ORIGDIS_NEF65            MCAID_ORIGDIS_NEF66
   MCAID_ORIGDIS_NEF67            MCAID_ORIGDIS_NEF68
   MCAID_ORIGDIS_NEF69            MCAID_ORIGDIS_NEF70_74
   MCAID_ORIGDIS_NEF75_79         MCAID_ORIGDIS_NEF80_84
   MCAID_ORIGDIS_NEF85_89         MCAID_ORIGDIS_NEF90_94
   MCAID_ORIGDIS_NEF95_GT

   MCAID_ORIGDIS_NEM65            MCAID_ORIGDIS_NEM66
   MCAID_ORIGDIS_NEM67            MCAID_ORIGDIS_NEM68
   MCAID_ORIGDIS_NEM69            MCAID_ORIGDIS_NEM70_74
   MCAID_ORIGDIS_NEM75_79         MCAID_ORIGDIS_NEM80_84
   MCAID_ORIGDIS_NEM85_89         MCAID_ORIGDIS_NEM90_94
   MCAID_ORIGDIS_NEM95_GT);

 %*macro to create New Enrollee and SNP New Enrollee regression
 variables;
 %MACRO INTER(PVAR=, RLIST=);
    %LOCAL I;
    %LET I=1;
    %DO %UNTIL(%SCAN(&RLIST,&I)=);
       &PVAR._%SCAN(&RLIST,&I) = &PVAR * %SCAN(&RLIST,&I);
       %LET I=%EVAL(&I+1);
    %END;
 %MEND INTER;


 %**********************************************************************
 * step3: merge person and diagnosis files outputting one record
 *        per person with score and HCC variables for each input person
 *        level record
 ***********************************************************************;

 DATA &OUTDATA(KEEP=&KEEPVAR );
   %****************************************************
    * step3.1: declaration section
    ****************************************************;

    %IF "&LABELMAC" ne "" %THEN %&LABELMAC;  *HCC labels;

   %* length of new variables (length for other age/sex vars is set in
      &AGESEXMAC macro);
    LENGTH CC $4.
           AGEF
           OriginallyDisabled_Female
           OriginallyDisabled_Male
           &NE_REG
           CC1-CC&N_CC
           HCC1-HCC&N_CC
           &DIAG_CAT
           &INTERRACC_VARSA
           &INTERRACC_VARSD
           &INTERRACI_VARS
           AGEF_EDIT
           3.;

    %*retain cc vars;
    RETAIN CC1-CC&N_CC 0  AGEF AGEF_EDIT;
    %*arrays;
    ARRAY C(&N_CC)  CC1-CC&N_CC;
    ARRAY HCC(&N_CC) HCC1-HCC&N_CC;
    %*interaction vars;
    ARRAY RV &INTERRACC_VARSA &INTERRACC_VARSD
          &INTERRACI_VARS &DIAG_CAT;

    %***************************************************
    * step3.2: to bring in regression coefficients
    ****************************************************;
    IF _N_ = 1 THEN SET INCOEF.HCCCOEFN;
    %***************************************************
    * step3.3: merge
    ****************************************************;
    MERGE &INP(IN=IN1)
          &IND(IN=IN2);
    BY &IDVAR;

    IF IN1 THEN DO;

    %*******************************************************
    * step3.4: for the first record for a person set CC to 0
    ********************************************************;

       IF FIRST.&IDVAR THEN DO;
          %*set ccs to 0;
           DO I=1 TO &N_CC;
            C(I)=0;
           END;
           %* age;
           AGEF =FLOOR((INTCK(
                'MONTH',DOB,&DATE_ASOF)-(DAY(&DATE_ASOF)<DAY(DOB)))/12);
           %IF "&DATE_ASOF_EDIT" ne "" %THEN
           AGEF_EDIT =FLOOR((INTCK('MONTH',DOB,&DATE_ASOF_EDIT)
                -(DAY(&DATE_ASOF_EDIT)<DAY(DOB)))/12);
           %ELSE AGEF_EDIT=AGEF;
           ;
       END;

    %***************************************************
    * step3.5 if there are any diagnoses for a person
    *         then do the following:
    *         - perform diag edits using macro &EDITMAC9 if ICD9 or
    *           &EDITMAC0 if ICD10
    *         - create CC using corresponding formats for ICD9
    *           or ICD10
    *         - assign additional CC using provided additional formats
    ****************************************************;
       IF IN1 & IN2 THEN DO;
          %*initialize;
          CC="9999";

          IF DIAG_TYPE = "9" THEN DO;
             %IF "&EDITMAC9" NE "" %THEN
                  %&EDITMAC9(AGE=AGEF_EDIT,SEX=SEX,ICD9=DIAG);
             IF CC NE "-1.0" AND CC NE "9999" THEN DO;
                IND=INPUT(CC,4.);
                IF 1 <= IND <= &N_CC THEN C(IND)=1;
             END;
             ELSE IF CC="9999" THEN DO;
                ** primary assignment **;
                IND = INPUT(LEFT(PUT(DIAG,$I9&FMNAME9..)),4.);
                IF 1 <= IND <= &N_CC THEN C(IND)=1;
                ** duplicate assignment **;
                IND = INPUT(LEFT(PUT(DIAG,$I9DUP&FMNAME9..)),4.);
                IF 1 <= IND <= &N_CC THEN C(IND)=1;
             END;
          END;

          ELSE IF DIAG_TYPE = "0" THEN DO;
              %IF "&EDITMAC0" NE "" %THEN
                   %&EDITMAC0(AGE=AGEF_EDIT,SEX=SEX,ICD10=DIAG);
              IF CC NE "-1.0" AND CC NE "9999" THEN DO;
                 IND=INPUT(CC,4.);
                 IF 1 <= IND <= &N_CC THEN C(IND)=1;
              END;
              ELSE IF CC="9999" THEN DO;
                 ** primary assignment **;
                 IND = INPUT(LEFT(PUT(DIAG,$I0&FMNAME0..)),4.);
                 IF 1 <= IND <= &N_CC THEN C(IND)=1;
                 ** duplicate assignment **;
                 IND = INPUT(LEFT(PUT(DIAG,$I0DUP&FMNAME0..)),4.);
                 IF 1 <= IND <= &N_CC THEN C(IND)=1;
                 ** secondary assignment **;
                 IND = INPUT(LEFT(PUT(DIAG,$I0SEC&FMNAME0..)),4.);
                 IF 1 <= IND <= &N_CC THEN C(IND)=1;
              END;
          END;
       END; %*CC creation;

    %*************************************************************
    * step3.6 for the last record for a person do the
    *         following:
    *         - create demographic variables needed (macro &AGESEXMAC)
    *         - create HCC using hierarchies (macro &HIERMAC)
    *         - create HCC interaction variables
    *         - create HCC and DISABL interaction variables
    *         - set HCCs and interaction vars to zero if there
    *           are no diagnoses for a person
    *         - create scores for 6 community models
    *         - create score for institutional model
    *         - create score for new enrollee model
    *         - create score for SNP new enrollee model
    **************************************************************;
       IF LAST.&IDVAR THEN DO;

           %****************************
           * demographic vars
           *****************************;
           %*create age/sex cells, originally disabled, disabled vars;
           %IF "&AGESEXMAC" ne "" %THEN
           %&AGESEXMAC(AGEF=AGEF, SEX=SEX, OREC=OREC);

           %*interaction;
           OriginallyDisabled_Female= ORIGDS*(SEX='2');
           OriginallyDisabled_Male  = ORIGDS*(SEX='1');

           %* NE interactions;
           NE_ORIGDS       = (AGEF>=65)*(OREC='1');
           NMCAID_NORIGDIS = (NEMCAID <=0 and NE_ORIGDS <=0);
           MCAID_NORIGDIS  = (NEMCAID > 0 and NE_ORIGDS <=0);
           NMCAID_ORIGDIS  = (NEMCAID <=0 and NE_ORIGDS > 0);
           MCAID_ORIGDIS   = (NEMCAID > 0 and NE_ORIGDS > 0);

           %INTER(PVAR =  NMCAID_NORIGDIS,  RLIST = &NE_AGESEXV );
           %INTER(PVAR =  MCAID_NORIGDIS,   RLIST = &NE_AGESEXV );
           %INTER(PVAR =  NMCAID_ORIGDIS,   RLIST = &ONE_AGESEXV);
           %INTER(PVAR =  MCAID_ORIGDIS,    RLIST = &ONE_AGESEXV);

           IF IN1 & IN2 THEN DO;
            %**********************
            * hierarchies
            **********************;
            %IF "&HIERMAC" ne "" %THEN %&HIERMAC;
            %************************
            * interaction variables
            *************************;
            %*diagnostic categories;
            CANCER         = MAX(HCC8, HCC9, HCC10, HCC11, HCC12);
            DIABETES       = MAX(HCC17, HCC18, HCC19);
            CARD_RESP_FAIL = MAX(HCC82, HCC83, HCC84);
            CHF            = HCC85;
            gCopdCF        = MAX(HCC110, HCC111, HCC112);
            RENAL          = MAX(HCC134, HCC135, HCC136, HCC137);
            SEPSIS         = HCC2;
            gSubstanceAbuse= MAX(HCC54, HCC55);
            gPsychiatric   = MAX(HCC57, HCC58);
            %*community models interactions ;
            HCC47_gCancer                = HCC47*Cancer;
            HCC85_gDiabetesMellit        = HCC85*Diabetes;
            HCC85_gCopdCF                = HCC85*gCopdCF;
            HCC85_gRenal                 = HCC85*Renal;
            gRespDepandArre_gCopdCF      = Card_Resp_Fail*gCopdCF;
            HCC85_HCC96                  = HCC85*HCC96;
            gSubstanceAbuse_gPsychiatric = gSubstanceAbuse*gPsychiatric;

            %*institutional model;
            PRESSURE_ULCER = MAX(HCC157, HCC158); /*10/19/2012*/;
            CHF_gCopdCF                  = CHF*gCopdCF;
            gCopdCF_CARD_RESP_FAIL       = gCopdCF*CARD_RESP_FAIL;
            SEPSIS_PRESSURE_ULCER        = SEPSIS*PRESSURE_ULCER;
            SEPSIS_ARTIF_OPENINGS        = SEPSIS*(HCC188);
            ART_OPENINGS_PRESSURE_ULCER  = (HCC188)*PRESSURE_ULCER;
            DIABETES_CHF                 = DIABETES*CHF;
            gCopdCF_ASP_SPEC_BACT_PNEUM  = gCopdCF*(HCC114);
            ASP_SPEC_BACT_PNEUM_PRES_ULC = (HCC114)*PRESSURE_ULCER;
            SEPSIS_ASP_SPEC_BACT_PNEUM   = SEPSIS*(HCC114);
            SCHIZOPHRENIA_gCopdCF        = (HCC57)*gCopdCF;
            SCHIZOPHRENIA_CHF            = (HCC57)*CHF;
            SCHIZOPHRENIA_SEIZURES       = (HCC57)*(HCC79);

            DISABLED_HCC85          = DISABL*(HCC85);
            DISABLED_PRESSURE_ULCER = DISABL*PRESSURE_ULCER;
            DISABLED_HCC161         = DISABL*(HCC161);
            DISABLED_HCC39          = DISABL*(HCC39);
            DISABLED_HCC77          = DISABL*(HCC77);
            DISABLED_HCC6           = DISABL*(HCC6);

           END; *there are some diagnoses for a person;
           ELSE DO;
              DO I=1 TO &N_CC;
                 HCC(I)=0;
              END;
              DO OVER RV;
                 RV=0;
              END;
           END;

           %*score calculation;

           /***************************/
           /*    community models     */
           /***************************/;

        %IF "&SCOREMAC" ne "" %THEN %DO;
     %&SCOREMAC(PVAR=SCORE_COMMUNITY_NA,  RLIST=&COMM_REGA, CPREF=CNA_);
     %&SCOREMAC(PVAR=SCORE_COMMUNITY_ND,  RLIST=&COMM_REGD, CPREF=CND_);
     %&SCOREMAC(PVAR=SCORE_COMMUNITY_FBA, RLIST=&COMM_REGA, CPREF=CFA_);
     %&SCOREMAC(PVAR=SCORE_COMMUNITY_FBD, RLIST=&COMM_REGD, CPREF=CFD_);
     %&SCOREMAC(PVAR=SCORE_COMMUNITY_PBA, RLIST=&COMM_REGA, CPREF=CPA_);
     %&SCOREMAC(PVAR=SCORE_COMMUNITY_PBD, RLIST=&COMM_REGD, CPREF=CPD_);

           /***************************/
           /*   institutional model   */
           /***************************/;

     %&SCOREMAC(PVAR=SCORE_INSTITUTIONAL, RLIST=&INST_REG, CPREF=INS_);

           /***************************/
           /*   new enrollees model   */
           /***************************/;

     %&SCOREMAC(PVAR=SCORE_NEW_ENROLLEE, RLIST=&NE_REG, CPREF=NE_);

           /***************************/
           /* SNP new enrollees model */
           /***************************/;

     %SCOREVAR(PVAR=SCORE_SNP_NEW_ENROLLEE, RLIST=&NE_REG, CPREF=SNPNE_);
        %END;

           /****************************/
           /*   normalize the scores   */
           /***************************/;
          SCORE_COMMUNITY_NA     = SCORE_COMMUNITY_NA    *&DF;
          SCORE_COMMUNITY_ND     = SCORE_COMMUNITY_ND    *&DF;
          SCORE_COMMUNITY_FBA    = SCORE_COMMUNITY_FBA   *&DF;
          SCORE_COMMUNITY_FBD    = SCORE_COMMUNITY_FBD   *&DF;
          SCORE_COMMUNITY_PBA    = SCORE_COMMUNITY_PBA   *&DF;
          SCORE_COMMUNITY_PBD    = SCORE_COMMUNITY_PBD   *&DF;
          SCORE_INSTITUTIONAL    = SCORE_INSTITUTIONAL   *&DF;
          SCORE_NEW_ENROLLEE     = SCORE_NEW_ENROLLEE    *&DF;
          SCORE_SNP_NEW_ENROLLEE = SCORE_SNP_NEW_ENROLLEE*&DF;

          OUTPUT &OUTDATA;
       END; %*last record for a person;
     END; %*there is a person record;
 RUN;

 %**********************************************************************
 * step4: data checks and proc contents
 ***********************************************************************;
 PROC PRINT U DATA=&OUTDATA(OBS=46);
     TITLE '*** V2216O2M output file ***';
 RUN ;
 PROC CONTENTS DATA=&OUTDATA;
 RUN;

 %MEND V2216O2M;
