%let user=markmcenearney;
libname noise "/home/&user.0/noise";

data n1;
set noise.nmt_events;
month=intnx('MONTH', datepart(max_level_date_time), 0, 'BEGINNING');
run;

proc sort data=n1;
by nmtid month;
run;

proc univariate data=n1 noprint;
var max_level;
class operation_type;
output out=s1 n=n mean=mean std=std;
by nmtid month;
run;

proc sort data=s1;
by operation_type;
run;

proc sgplot data=s1;
  styleattrs datacontrastcolors=(red green blue);
  series x=month y=mean / group=nmtid;
  xaxis grid interval=year valuesformat=year4.;
by operation_type;
title max_level;
run;

proc univariate data=n1(where=(hour(timepart(max_level_date_time)) not between 6 and 21)) noprint;
var max_level;
class operation_type;
output out=s2 n=n mean=mean std=std;
by nmtid month;
run;

proc sort data=s2;
by operation_type;
run;

proc sgplot data=s2;
  styleattrs datacontrastcolors=(red green blue);
  series x=month y=mean / group=nmtid;
  xaxis grid interval=year valuesformat=year4.;
by operation_type;
title max_level between 10PM and 6 AM;
run;

