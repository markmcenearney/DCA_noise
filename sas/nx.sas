*Count aircraft noise events per NMT per month and number above 60, 65, 70 and 75 dBA. ;

%let user=markmcenearney;
libname noise "/home/&user.0/noise";

data n1;
set noise.nmt_events;
month=intnx('MONTH', datepart(max_level_date_time), 0, 'BEGINNING');
run;

proc freq data=n1;
tables month*nmtid / out=f1 norow nocol nocum nopercent;
format month yymmn6.;
title aircraft noise events per nmt per month;
run;

* add zero counts for months where all data are missing (because the corresponding workbook on MWAA's noise portal is corrupt;
proc sql;
create table nmt as 
select distinct nmtid
from f1;

create table month as 
select distinct month
from f1;

create table nmt_month as 
select *
from nmt, month;

create table f2 as
select a.*,
coalesce(b.count, 0) as count
from
nmt_month a
left join f1 b
on 
a.nmtid = b.nmtid and
a.month = b.month
;
quit;

proc sgplot data=f2;
styleattrs datacontrastcolors=(red green blue);
series x=month y=count / group=nmtid;
xaxis grid interval=year valuesformat=year4.;
yaxis min=0;  
title aircraft noise events per nmt per month;
run;

proc tabulate data=noise.nmt_summary(where=(nmtid in (2,4,5,6,7,8) and uptime<95));
class nmtid month;
var uptime;
table month, nmtid*uptime;
title monthly uptimes < 95%;
run;

proc sgplot data=noise.nmt_summary (where=(nmtid in (2,4,5,6,7,8)));
styleattrs datacontrastcolors=(red green blue);
series x=month y=uptime / group=nmtid;
xaxis grid interval=year valuesformat=year4.;
format month yymmn6.;
title monthly uptimes;
run;

%macro nx(x=);

proc freq data=n1(where=(max_level>&x)) noprint;
table month*nmtid / out=f3 norow nocol nocum nopercent;
format month yymmn6.;
title aircraft noise events above &x dBA;
run;

proc freq data=n1(where=(max_level>&x and timepart(start_date_time) not between '07:00't and '22:00't));
table month*nmtid / norow nocol nocum nopercent;
format month yymmn6.;
title nighttime aircraft noise events above &x dBA;
run;

/*
proc sgplot data=f3(rename=(count=nx));
styleattrs datacontrastcolors=(red green blue);
series x=month y=nx / group=nmtid;
xaxis grid interval=year valuesformat=year4.;
yaxis min=0;  
title aircraft noise events above &x dBA;
run;
*/

proc sql;
create table nx_adjusted as
select a.nmtid, a.month, a.count,uptime, round(100/uptime*a.count) as nx_adjusted
from
f3 a,
noise.nmt_summary b
where 
a.nmtid = b.nmtid and
a.month = b.month
order by
a.nmtid, a.month
;

proc tabulate data=nx_adjusted format=6.;
class nmtid month;
var nx_adjusted;
table month, nmtid*nx_adjusted*sum=' ';
title aircraft noise events above &x dBA (adjusted per uptime);
run;

proc sgplot data=nx_adjusted;
styleattrs datacontrastcolors=(red green blue);
series x=month y=nx_adjusted / group=nmtid;
xaxis grid interval=year valuesformat=year4.;
title aircraft noise events above &x dBA (adjusted per uptime);
run;

*compute nx per day for rolling 12 months;
data nx_per_day;
retain n nx_adj_12m .;
set nx_adjusted; 
by nmtid month; 

if first.nmtid then
  do;
    n=0;
    nx_adj_12m = 0;
  end;
else;  

n+1;
nx_adj_12m + nx_adjusted;
nx_adj_lag11 = lag11(nx_adjusted);

if n>11 then
  do;
    ndays = intck('day', intnx('month', month, -11, 'b'), intnx('month', month, 0, 'e')) + 1;  
    nx_per_day = nx_adj_12m / ndays;    
    output;
    nx_adj_12m = nx_adj_12m - nx_adj_lag11; 
  end;
else;
run;

proc tabulate data=nx_per_day(where=(month='1Feb16'd or month>'30Apr22'd)) format=6.;
class nmtid month;
var nx_per_day;
table month, nmtid*nx_per_day*sum=' ';
title nx per day based on rolling 12 months (x = &x);
run;

/*
*check;
title check: nx per day based on rolling 12 months (x = &x);
%let end_month=1Feb16;
proc sql;
select nmtid, "&end_month"d as end_month format=yymmn6., 
round(sum(nx_adjusted)/(intck('day', intnx('month', "&end_month"d , -11, 'b'), intnx('month', "&end_month"d, 0, 'e')) + 1)) as nx_per_day,
intck('day', intnx('month', "&end_month"d , -11, 'b'), intnx('month', "&end_month"d, 0, 'e')) + 1 as ndays  
from
nx_adjusted
where
month between intnx('month', "&end_month"d, -11, 'b') and "&end_month"d
group by 
nmtid
;
quit;

*check;
title check: nx per day based on rolling 12 months (x = &x);
%let end_month=1Apr23;
proc sql;
select nmtid, "&end_month"d as end_month format=yymmn6., 
round(sum(nx_adjusted)/(intck('day', intnx('month', "&end_month"d , -11, 'b'), intnx('month', "&end_month"d, 0, 'e')) + 1)) as nx_per_day,  
intck('day', intnx('month', "&end_month"d , -11, 'b'), intnx('month', "&end_month"d, 0, 'e')) + 1 as ndays  
from
nx_adjusted
where
month between intnx('month', "&end_month"d, -11, 'b') and "&end_month"d
group by 
nmtid
;
quit;
*/

proc sgplot data=nx_per_day;
styleattrs datacontrastcolors=(red green blue);
series x=month y=nx_per_day / group=nmtid;
xaxis grid interval=year valuesformat=year4.;
format month yymmn6.;
title nx per day based on rolling 12 months (x = &x);
run;

*compute nx_base =  nx_per_day based on 12 months ended 29 Feb 2016 ;
*adjust for leap year; 
proc sql;
create table nx_base as
select nmtid, nx_per_day*365/366 as nx_base
from
nx_per_day
where
month = '1Feb16'd
;

*compute nx_dif = nx 12 month sum minus sum for 12 months ended Feb 29, 2016;
proc sql;
create table nx_per_day_dif as
select a.nmtid, a.month, round(a.nx_per_day - nx_base) as nx_per_day_dif
from
nx_per_day a,
nx_base b
where 
a.nmtid = b.nmtid 
;

proc tabulate data=nx_per_day_dif(where=(month='1Feb16'd or month>'30Apr22'd)) format=6.;
class nmtid month;
var nx_per_day_dif;
table month, nmtid*nx_per_day_dif*sum=' ';
title change in nx per day relative to 12 months ended Feb 29, 2016;
title2 x = &x;
run;

proc sgplot data=nx_per_day_dif;
styleattrs datacontrastcolors=(red green blue);
series x=month y=nx_per_day_dif/ group=nmtid;
xaxis grid interval=year valuesformat=year4.;
format month yymmn6.;
title change in nx per day relative to 12 months ended Feb 29, 2016;
title2 x = &x;
run;

%mend;

%nx(x=60);
%nx(x=65);
%nx(x=70);
%nx(x=75);
