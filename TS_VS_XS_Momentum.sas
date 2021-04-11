PROC IMPORT OUT= WORK.SPOT
            DATAFILE= "C:\Users\30970\Downloads\JBAZ_TS_VS_XS\SPOT.xlsx"
            DBMS=EXCEL REPLACE ;
GETNAMES=YES;
MIXED=NO;
SCANTEXT=YES;
USEDATE=YES;
SCANTIME=YES;
RUN;
PROC IMPORT OUT= WORK.FWD
            DATAFILE= "C:\Users\30970\Downloads\JBAZ_TS_VS_XS\FWD.xlsx"
            DBMS=EXCEL REPLACE ;
GETNAMES=YES;
MIXED=NO;
SCANTEXT=YES;
USEDATE=YES;
SCANTIME=YES;
RUN;
PROC IMPORT OUT= WORK.CPI
            DATAFILE= "C:\Users\30970\Downloads\JBAZ_TS_VS_XS\CPI.xlsx"
            DBMS=EXCEL REPLACE ;
GETNAMES=YES;
MIXED=NO;
SCANTEXT=YES;
USEDATE=YES;
SCANTIME=YES;
RUN;

PROC SORT DATA=WORK.SPOT;
  BY NAME;
RUN; 

proc transpose data=SPOT out=SPOT_NEW;
  by NAME;
/*  var _004 _005 _006 _007 _008 _009 _010 _011 _012 _013 _014 _015 _016;*/
/*  id var1;*/
run;

DATA WORK.SPOT_NEW;
	SET WORK.SPOT_NEW;
	IF MISSING(COL1)=1 THEN DELETE;
	DROP _NAME_;
RUN;

DATA WORK.SPOT_NEW;
	SET WORK.SPOT_NEW;
	YEAR=YEAR(NAME);
	QUARTER=QTR(NAME);
	CUR=_LABEL_;
	format YEAR BEST12. QUARTER BEST12.;
RUN;


PROC SORT DATA=WORK.FWD;
  BY NAME;
RUN; 

proc transpose data=FWD out=FWD_NEW;
  by NAME;
/*  var _004 _005 _006 _007 _008 _009 _010 _011 _012 _013 _014 _015 _016;*/
/*  id var1;*/
run;

DATA WORK.FWD_NEW;
	SET WORK.FWD_NEW;
	IF MISSING(COL1)=1 THEN DELETE;
	DROP _NAME_;
RUN;
DATA WORK.FWD_NEW;
	SET WORK.FWD_NEW;
	YEAR=YEAR(NAME);
	QUARTER=QTR(NAME);
	CUR=substr(_LABEL_,2,lengthn(_LABEL_));
	format YEAR BEST12. QUARTER BEST12.;
RUN;

PROC SORT DATA=WORK.CPI;
  BY YEAR QUARTER;
RUN; 

proc transpose data=CPI out=CPI_NEW;
  by YEAR QUARTER;
/*  var _004 _005 _006 _007 _008 _009 _010 _011 _012 _013 _014 _015 _016;*/
/*  id var1;*/
run;

DATA WORK.CPI_NEW;
	SET WORK.CPI_NEW;
	IF MISSING(COL1)=1 THEN DELETE;
	CUR=substr(_LABEL_,2,lengthn(_LABEL_));
	DROP _NAME_;
RUN;



/*ASSIGNING NEXT DAY VALUES
see pg 13 in paper, FX positions are closed after 252 days */

PROC SORT DATA=SPOT_NEW;
  BY CUR NAME;
RUN;

DATA SPOT_NEW;
	SET SPOT_NEW end=finished;
  	if not finished then do;
	pt = _N_ + 252;
  	set SPOT_NEW (keep=COL1 rename= (COL1 = SPOT1)) point=pt;
 	end;
  	else SPOT1 = .;
RUN;
DATA SPOT_NEW;
	SET SPOT_NEW;
	RET=LOG(SPOT1/COL1);
	RET2=RET*RET;
RUN;
 

/*proc expand data=COMPACTDATA1 out=COMPACTDATA3 method=none;*/
/*   BY CUR ;*/
/*   id NAME;*/
/*   convert SPOT = SPOT_lag1  / transformout=(lag 1);*/
/*   convert SPOT = SPOT_movave / transformout=(movave 10);*/
/*run;*/


/*DATA COMPACTDATA3;*/
/*	SET COMPACTDATA1;*/
/*	BY CUR;*/
/*/*	IF NAME="24JAN1991"d THEN */*/
/*	SPOT_EWMA=LEAD(RET2);*/
/*RUN;*/


/***************************************************/
/**********************EWMA*************************/
/*ORDER 8 FOR SHORT POSN [8,16,32] & LONG POSN [24,48,96]

/*FOR SHORT POSITION */

%let ewmaOrder=8;
%let ewmaFraction=%sysevalf(1/&ewmaOrder);  /*CODE URL: https://communities.sas.com/t5/General-SAS-Programming/Proc-Expand-Exponential-Moving-Average-question/td-p/139327 */
proc expand data=SPOT_NEW out=COMPACTDATA3;
by CUR;
convert RET2=S8 / transformout=( ewma &ewmaFraction );
run;
quit;
data COMPACTDATA3;
set COMPACTDATA3;
BY CUR NAME;
if TIME < (&ewmaOrder+1) then S8=.;
run;
/*proc expand data=COMPACTDATA3 out=COMPACTDATA3;*/
/*convert RET2=EMA/ transformout=( ewma 0.125); /*SMOOTHING NUMBER=1-(7/8); http://www.okstate.edu/sas/v7/sashtml/books/ets/chap11/sect26.htm */*/
/*run; */


%let ewmaOrder=16;
%let ewmaFraction=%sysevalf(1/&ewmaOrder);
proc expand data=COMPACTDATA3 out=COMPACTDATA3;
by CUR;
convert RET2=S16 / transformout=( ewma &ewmaFraction );
run;
quit;
data COMPACTDATA3;
set COMPACTDATA3;
if TIME < (&ewmaOrder+1) then S16=.;
run;

%let ewmaOrder=32;
%let ewmaFraction=%sysevalf(1/&ewmaOrder);
proc expand data=COMPACTDATA3 out=COMPACTDATA3;
by CUR;
convert RET2=S32 / transformout=( ewma &ewmaFraction );
run;
quit;
data COMPACTDATA3;
set COMPACTDATA3;
if TIME < (&ewmaOrder+1) then S32=.;
run;

/*FOR LONG POSITION */

%let ewmaOrder=24;
%let ewmaFraction=%sysevalf(1/&ewmaOrder);
proc expand data=COMPACTDATA3 out=COMPACTDATA3;
by CUR;
convert RET2=L24 / transformout=( ewma &ewmaFraction );
run;
quit;
data COMPACTDATA3;
set COMPACTDATA3;
if TIME < (&ewmaOrder+1) then L24=.;
run;
/*proc expand data=COMPACTDATA3 out=COMPACTDATA3;*/
/*convert RET2=EMA/ transformout=(ewma 0.125); /*SMOOTHING NUMBER=1-(7/8); http://www.okstate.edu/sas/v7/sashtml/books/ets/chap11/sect26.htm */*/
/*run; */


%let ewmaOrder=48;
%let ewmaFraction=%sysevalf(1/&ewmaOrder);
proc expand data=COMPACTDATA3 out=COMPACTDATA3;
by CUR;
convert RET2=L48 / transformout=( ewma &ewmaFraction );
run;
quit;
data COMPACTDATA3;
set COMPACTDATA3;
if TIME < (&ewmaOrder+1) then L48=.;
run;

%let ewmaOrder=96;
%let ewmaFraction=%sysevalf(1/&ewmaOrder);
proc expand data=COMPACTDATA3 out=COMPACTDATA3;
by CUR;
convert RET2=L96 / transformout=( ewma &ewmaFraction );
run;
quit;
data COMPACTDATA3;
set COMPACTDATA3;
if TIME < (&ewmaOrder+1) then L96=.;
run;



DATA COMPACTDATA3;
	SET COMPACTDATA3;
	X1=S8-L24;
	X2=S16-L48;
	X3=S32-L96;
RUN;

PROC EXPAND DATA=COMPACTDATA3 OUT=COMPACTDATA3;
BY CUR;
ID NAME;
CONVERT COL1=MOVSTD63 / TRANSFORMOUT=(MOVSTD 63); /* 63 DAY ROLLING STANDARD DEVIATION */
RUN;

DATA COMPACTDATA3;
	SET COMPACTDATA3;
	Y1=X1/MOVSTD63;
	Y2=X2/MOVSTD63;
	Y3=X3/MOVSTD63;
RUN;

PROC EXPAND DATA=COMPACTDATA3 OUT=COMPACTDATA3;
BY CUR;
ID NAME;
CONVERT Y1=STD1 / TRANSFORMOUT=(MOVSTD 252); /* 252 DAY ROLLING STANDARD DEVIATION OF Y */
CONVERT Y2=STD2 / TRANSFORMOUT=(MOVSTD 252);
CONVERT Y3=STD3 / TRANSFORMOUT=(MOVSTD 252);
RUN;

DATA COMPACTDATA3;
	SET COMPACTDATA3;
	IF STD1=0 THEN STD1=.;
	IF STD2=0 THEN STD2=.;
	IF STD3=0 THEN STD3=.;
RUN;

DATA COMPACTDATA3;
	SET COMPACTDATA3;
	Z1=Y1/STD1;
	Z2=Y2/STD2;
	Z3=Y3/STD3;
RUN;
/*MOMENTUM SIGNAL */

DATA COMPACTDATA3;
	SET COMPACTDATA3;
	U1=(Z1*EXP(-Z1*Z1/4))/0.89;
	U2=(Z2*EXP(-Z2*Z2/4))/0.89;
	U3=(Z3*EXP(-Z3*Z3/4))/0.89;
	MOM=(1/3)*(U1+U2+U3);
RUN;

/*CREATING DATASET FOR MOMENTUM STRATEGY */
DATA COMPACTDATA3D;
	SET COMPACTDATA3;
	IF CUR="CZK" THEN IF NAME<"02MAY2000"d THEN DELETE;
	IF CUR="PLN" THEN IF NAME<"02MAY2000"d THEN DELETE;
	IF CUR="THB" THEN IF NAME<"02MAY2000"d THEN DELETE;
	IF CUR="HUF" THEN IF NAME<"02MAY2000"d THEN DELETE;
	IF CUR="INR" THEN IF NAME<"02MAY2000"d THEN DELETE;
	IF CUR="KRW" THEN IF NAME<"02MAY2000"d THEN DELETE;
	IF CUR="MXN" THEN IF NAME<"02MAY2000"d THEN DELETE;
	IF CUR="PHP" THEN IF NAME<"02MAY2000"d THEN DELETE;
	IF CUR="TRY" THEN IF NAME<"02MAY2000"d THEN DELETE;
	IF CUR="TWD" THEN IF NAME<"02MAY2000"d THEN DELETE;
RUN; 

/* SIGNAL */

DATA ASH.COMPACTDATA3_NEW;
	SET COMPACTDATA3D;
RUN;



/*Ranking */
PROC SORT DATA=CompactData3D OUT=CompactData4;
  BY NAME;
RUN;
DATA COMPACTDATA4;
	SET COMPACTDATA4;
	IF MISSING(MOM)=1 THEN DELETE;
RUN;

proc rank data=CompactData4 out=Ranks_MOM_LOW;
  by NAME;
  var MOM;
  ranks LOW;
run;
proc rank data=CompactData4 DESCENDING out=Ranks_MOM_HIGH;
  by NAME;
  var MOM;
  ranks HIGH;
run;
proc sql;
  create table CompactData5 as
  select distinct a.*,b.HIGH
  from Ranks_MOM_LOW as a, Ranks_MOM_HIGH as b
  where a.NAME=b.NAME and a.YEAR=b.YEAR and a.QUARTER=b.QUARTER and a.CUR=b.CUR
  order by a.NAME,a.YEAR, a.QUARTER,a.CUR;
quit;

/*X-SECTION ANALYSIS */

DATA COMPACTDATA5;
	SET COMPACTDATA5;
	IF HIGH<4 THEN LONG=1;
	IF LOW<4 THEN LONG=0;
RUN;

DATA CROSS_PORT;
	SET COMPACTDATA5;
	IF MISSING(LONG)=1 THEN DELETE;
	IF LONG=1 THEN WT=(1/3);
	IF LONG=0 THEN WT=-(1/3);
	DROP STD1 STD2 STD3 MOVSTD63 L96 L48 L24 S32 S16 S8 X1 X2 X3 Y1 Y2 Y3 Z1 Z2 Z3 U1 U2 U3;
RUN;

data CROSS_PORT;
  set CROSS_PORT;
  by NAME;
  Retain SumRET;
  SumRET = sum(SumRET, WT*RET);
  if first.NAME=1 then SumRET=WT*RET;
run;

DATA CROSS_PORT1;
	SET CROSS_PORT;
	BY NAME;
	IF LAST.NAME=1 THEN RET1=SumRET;
	KEEP NAME RET1;
	IF MISSING(RET1)=1 THEN DELETE;
RUN;

*TIME-SERIES ANALYSIS */
/*Ranking */


DATA COMPACTDATA1_T;
	SET COMPACTDATA5;
	IF MOM>0 THEN LONG=1;
	IF MOM<0 THEN LONG=0;
RUN;

/*TO FIND OUT NUMBER OF ITEMS IN EACH DISTINCT NAME */
proc sql;
  create table COMPACTDATA1_TB as
  select distinct *,max(LOW)as MAXR
  from COMPACTDATA1_T
  group by NAME,YEAR,QUARTER
  order by NAME,YEAR,QUARTER;
RUN; 

DATA CROSS_PORT_MOM_T;
	SET COMPACTDATA1_TB;
	IF MISSING(LONG)=1 THEN DELETE;
	IF LONG=1 THEN WT=(1/MAXR);
	IF LONG=0 THEN WT=-(1/MAXR);
RUN;

data CROSS_PORT_MOM_T;
  set CROSS_PORT_MOM_T;
  by NAME;
  Retain SumRET;
  SumRET = sum(SumRET, WT*RET);
  if first.NAME=1 then SumRET=WT*RET;
run;

DATA CROSS_PORT_MOM_T1;
	SET CROSS_PORT_MOM_T;
	BY NAME;
	IF LAST.NAME=1 THEN RET1=SumRET;
	KEEP NAME RET1;
	IF MISSING(RET1)=1 THEN DELETE;
RUN;
