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
PROC IMPORT OUT= WORK.CPI_USD
            DATAFILE= "C:\Users\30970\Downloads\JBAZ_TS_VS_XS\CPI_USD.xlsx"
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

proc sql;
  create table CompactData as
  select distinct a.NAME,a.YEAR,a.QUARTER,a.CUR,a.COL1 as SPOT,b.COL1 as FWD
  from SPOT_NEW as a, FWD_NEW as b
  where a.NAME=b.NAME and a.YEAR=b.YEAR and a.QUARTER=b.QUARTER and a.CUR=b.CUR
  order by a.NAME,a.YEAR, a.QUARTER,a.CUR;
quit;

proc sql;
  create table CompactData1 as
  select distinct a.NAME,a.YEAR,a.QUARTER,a.CUR,a.COL1 as SPOT,b.COL1 as FWD
  from SPOT_NEW as a, FWD_NEW as b
  where a.NAME=b.NAME and a.YEAR=b.YEAR and a.QUARTER=b.QUARTER and a.CUR=b.CUR
  order by a.CUR,a.NAME;
quit;

/*ASSIGNING NEXT DAY VALUES
see pg 13 in paper, FX positions are closed after 252 days */
DATA COMPACTDATA1;
	SET COMPACTDATA1 end=finished;
  	if not finished then do;
	pt = _N_ + 252;
  	set COMPACTDATA1 (keep=FWD rename= (FWD = FWD1)) point=pt;
 	end;
  	else FWD1 = .;
RUN;
DATA COMPACTDATA1;
	SET COMPACTDATA1 end=finished;
  	if not finished then do;
	pt = _N_ + 252;
  	set COMPACTDATA1 (keep=SPOT rename= (SPOT = SPOT1)) point=pt;
 	end;
  	else SPOT1 = .;
RUN;

DATA COMPACTDATA1;
	SET COMPACTDATA1;
	BY CUR;
	IF NAME<="31Dec2015"d;
RUN; 


proc sql;
  create table CompactData2 as
  select distinct a.*,b.FWD1,b.SPOT1
  from CompactData as a, CompactData1 as b
  where a.NAME=b.NAME and a.YEAR=b.YEAR and a.QUARTER=b.QUARTER and a.CUR=b.CUR
  order by a.NAME,a.YEAR, a.QUARTER,a.CUR;
quit;

/*ESTIMATION OF CARRY */
DATA COMPACTDATA2;
	SET COMPACTDATA2;
	CARRY=4*((SPOT/FWD)-1);
RUN;
/*ESTIMATION OF VALUE */
proc sql;
  create table CompactData3 as
  select distinct a.*,b.COL1 as CPI
  from CompactData2 as a, CPI_NEW as b
  where a.YEAR=b.YEAR and a.QUARTER=b.QUARTER and a.CUR=b.CUR
  order by a.NAME,a.YEAR, a.QUARTER,a.CUR;
quit;
proc sql;
  create table CompactData3 as
  select distinct a.*,b.CPI_USD
  from CompactData3 as a, CPI_USD as b
  where a.YEAR=b.YEAR and a.QUARTER=b.QUARTER
  order by a.NAME,a.YEAR, a.QUARTER,a.CUR;
quit;

DATA COMPACTDATA3;
	SET COMPACTDATA3;
	SPOTR=LOG(SPOT*(CPI/CPI_USD));
run;
proc sql;
  create table COMPACTDATA4 as
  select distinct YEAR,CUR,mean(SPOTR) as M_SPOTR
  from COMPACTDATA3
  group by YEAR,CUR
  order by YEAR,CUR;
quit;

proc sql;
  create table COMPACTDATA5 as
  select distinct a.*,b.M_SPOTR
  from COMPACTDATA3 as a,COMPACTDATA4 as B
  where a.YEAR=b.YEAR and a.CUR=b.CUR
  order by a.NAME,a.YEAR, a.QUARTER,a.CUR;
quit;

DATA COMPACTDATA5;
	SET COMPACTDATA5;
	VALUE=SPOTR-M_SPOTR;
RUN;

/****************************/
/*****X-section analysis*****/
/*Ranking-CARRY*/
proc rank data=CompactData2 out=Ranks_CARRY_LOW;
  by NAME;
  var CARRY;
  ranks LOW;
run;
proc rank data=CompactData2 DESCENDING out=Ranks_CARRY_HIGH;
  by NAME;
  var CARRY;
  ranks HIGH;
run;
/*Ranking-VALUE*/
proc rank data=CompactData5 out=Ranks_VALUE_LOW;
  by NAME;
  var VALUE;
  ranks LOW;
run;
proc rank data=CompactData5 DESCENDING out=Ranks_VALUE_HIGH;
  by NAME;
  var VALUE;
  ranks HIGH;
run;
/*CARRY*/
proc sql;
  create table CompactData1 as
  select distinct a.*,b.HIGH
  from Ranks_CARRY_LOW as a, Ranks_CARRY_HIGH as b
  where a.NAME=b.NAME and a.YEAR=b.YEAR and a.QUARTER=b.QUARTER and a.CUR=b.CUR
  order by a.NAME,a.YEAR, a.QUARTER,a.CUR;
quit;

DATA COMPACTDATA1;
	SET COMPACTDATA1;
	IF HIGH<4 THEN LONG=1;
	IF LOW<4 THEN LONG=0;
RUN;

DATA CROSS_PORT;
	SET COMPACTDATA1;
	IF MISSING(LONG)=1 THEN DELETE;
	IF LONG=1 THEN WT=(1/3);
	IF LONG=0 THEN WT=-(1/3);
RUN;

DATA CROSS_PORT;
	SET CROSS_PORT;
	RET=LOG(SPOT1/SPOT);
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

/*VALUE*/
proc sql;
  create table CompactData5 as
  select distinct a.*,b.HIGH
  from Ranks_VALUE_LOW as a, Ranks_VALUE_HIGH as b
  where a.NAME=b.NAME and a.YEAR=b.YEAR and a.QUARTER=b.QUARTER and a.CUR=b.CUR
  order by a.NAME,a.YEAR, a.QUARTER,a.CUR;
quit;

DATA COMPACTDATA5;
	SET COMPACTDATA5;
	IF HIGH<4 THEN LONG=1;
	IF LOW<4 THEN LONG=0;
RUN;

DATA CROSS_PORT_VALUE;
	SET COMPACTDATA5;
	IF MISSING(LONG)=1 THEN DELETE;
	IF LONG=1 THEN WT=(1/3);
	IF LONG=0 THEN WT=-(1/3);
RUN;

DATA CROSS_PORT_VALUE;
	SET CROSS_PORT_VALUE;
	RET=LOG(SPOT1/SPOT);
RUN;

data CROSS_PORT_VALUE;
  set CROSS_PORT_VALUE;
  by NAME;
  Retain SumRET;
  SumRET = sum(SumRET, WT*RET);
  if first.NAME=1 then SumRET=WT*RET;
run;

DATA CROSS_PORT_VALUE1;
	SET CROSS_PORT_VALUE;
	BY NAME;
	IF LAST.NAME=1 THEN RET1=SumRET;
	KEEP NAME RET1;
	IF MISSING(RET1)=1 THEN DELETE;
RUN;

/***************************/
/*****T-series analysis*****/

/*CARRY*/
DATA COMPACTDATA1_T;
	SET COMPACTDATA1;
	IF CARRY>0 THEN LONG=1;
	IF CARRY<0 THEN LONG=0;
RUN;

/*TO FIND OUT NUMBER OF ITEMS IN EACH DISTINCT NAME */
proc sql;
  create table COMPACTDATA1_TB as
  select distinct *,max(LOW)as MAXR
  from COMPACTDATA1_T
  group by NAME,YEAR,QUARTER
  order by NAME,YEAR,QUARTER;
RUN; 

DATA CROSS_PORT_CARRY_T;
	SET COMPACTDATA1_TB;
	IF MISSING(LONG)=1 THEN DELETE;
	IF LONG=1 THEN WT=(1/MAXR);
	IF LONG=0 THEN WT=-(1/MAXR);
RUN;

DATA CROSS_PORT_CARRY_T;
	SET CROSS_PORT_CARRY_T;
	RET=LOG(SPOT1/SPOT);
RUN;

data CROSS_PORT_CARRY_T;
  set CROSS_PORT_CARRY_T;
  by NAME;
  Retain SumRET;
  SumRET = sum(SumRET, WT*RET);
  if first.NAME=1 then SumRET=WT*RET;
run;

DATA CROSS_PORT_CARRY_T1;
	SET CROSS_PORT_CARRY_T;
	BY NAME;
	IF LAST.NAME=1 THEN RET1=SumRET;
	KEEP NAME RET1;
	IF MISSING(RET1)=1 THEN DELETE;
RUN;

/*VALUE*/
DATA COMPACTDATA5_T;
	SET COMPACTDATA5;
	IF VALUE>0 THEN LONG=1;
	IF VALUE<0 THEN LONG=0;
RUN;

/*TO FIND OUT NUMBER OF ITEMS IN EACH DISTINCT NAME */
proc sql;
  create table COMPACTDATA5_TB as
  select distinct *,max(LOW)as MAXR
  from COMPACTDATA5_T
  group by NAME,YEAR,QUARTER
  order by NAME,YEAR,QUARTER;
RUN; 

DATA CROSS_PORT_VALUE_T;
	SET COMPACTDATA5_TB;
	IF MISSING(LONG)=1 THEN DELETE;
	IF LONG=1 THEN WT=(1/MAXR);
	IF LONG=0 THEN WT=-(1/MAXR);
RUN;

DATA CROSS_PORT_VALUE_T;
	SET CROSS_PORT_VALUE_T;
	RET=LOG(SPOT1/SPOT);
RUN;

data CROSS_PORT_VALUE_T;
  set CROSS_PORT_VALUE_T;
  by NAME;
  Retain SumRET;
  SumRET = sum(SumRET, WT*RET);
  if first.NAME=1 then SumRET=WT*RET;
run;

DATA CROSS_PORT_VALUE_T1;
	SET CROSS_PORT_VALUE_T;
	BY NAME;
	IF LAST.NAME=1 THEN RET1=SumRET;
	KEEP NAME RET1;
	IF MISSING(RET1)=1 THEN DELETE;
RUN;
