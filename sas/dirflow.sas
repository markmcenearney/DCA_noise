*analyze dir flow and weather;
*source of weather data is https://mesonet.agron.iastate.edu/request/download.phtml?network=VA_ASOS;
*weather obs are hourly + specials thru April 2016 and every 5 minutes thereafter;

%let start=1Mar15;
%let end=30Jun23;
%let user=markmcenearney;

libname noise "/home/&user.0/noise";
libname weather "/home/&user.0/weather";
filename weather "/home/&user.0/weather/asos.txt" termstr=lf;

data w1 (keep=weather_dt weather_date year month hour wind_dir wind_speed sky1 sky1_level);

%let _EFIERR_ = 0; /* set the ERROR detection macro variable */
infile weather delimiter = ',' MISSOVER DSD firstobs=2 ;
* station,datetime,tmpf,relh,drct,sknt,gust,skyc1,skyl1;

informat station $3. ;
informat _datetime $20. ;
informat _tmpf $6. ;
informat _relh $6. ;
informat _drct $7. ;
informat _sknt $7. ;
informat _gust $5.;
informat _skyc1 $3. ;
informat _skyl1 $7. ;
 
format station $3. ;
format _datetime $40. ;
format _tmpf $6. ;
format _relh $6. ;
format _drct $7. ;
format _sknt $7. ;
format _gust $5.;
format _skyc1 $3. ;
format _skyl1 $7. ;
input
station $
_datetime $
_tmpf $
_relh $
_drct $
_sknt $
_gust $
_skyc1 $
_skyl1 $

;

if _ERROR_ then call symputx('_EFIERR_',1);  /* set ERROR detection macro variable */

weather_dt=dhms(input(substr(_datetime,1,10),yymmdd10.), 0,0,input(substr(_datetime,12,5),time5.));
weather_date=datepart(weather_dt);
if "&start"d<=weather_date and weather_date<="&end"d;
year=year(weather_date);
month=intnx('MONTH', weather_date, 0, 'BEGINNING');
hour=hour(timepart(weather_dt));

if _drct='M' then 
  wind_dir = .;
else wind_dir=input(_drct,7.);
 
if _sknt='M' then
  wind_speed = .;
else wind_speed=input(_sknt,7.);
 
if wind_dir=. or wind_speed=. then delete;

sky1=_skyc1;

if _skyl1='M' then
  sky1_level=.;
else sky1_level=input(_skyl1,7.);

output;

format month yymmn6. weather_date yymmdd8.;
run;

/* tbd check duplicates before deleting to see if data are the same */
proc sort nodupkey data=w1; by weather_dt; run;
  
proc freq data=w1;
tables month;
title DCA weather obs per month;
title2 note increase in 201605 when weather data became available every 5 minutes;
run;

/*
proc freq data=w1(where=(weather_date between '16Apr16'd and '31May16'd));
tables weather_date;
run;
*/

data w2(keep=weather_dt year wind_dir wind_speed sky1 sky1_level measurement_duration);

retain
weather_dt .
wind_dir .
wind_speed .
sky1 'xxx'
sky1_level .
;

set w1(rename=(weather_dt=_weather_dt wind_dir=_wind_dir wind_speed=_wind_speed sky1=_sky1 sky1_level=_sky1_level));
by _weather_dt;

if _n_>1 then
  do;
    measurement_duration=(_weather_dt-weather_dt)/60; /* convert seconds to minutes */
    *if measurement_duration<=60 then output; *exclude weather obs more than 60 minutes old;
  end;
else;

weather_dt=_weather_dt;
wind_dir=_wind_dir;
wind_speed=_wind_speed;
sky1=_sky1;
sky1_level=_sky1_level;
run;

title distribution of elapsed time between weather obs in minutes;
proc freq data=w2; tables measurement_duration; run;

title wind direction since &start;
title2 weighted by measurement_duration except where duration > 60 minutes;
proc freq data=w2(where=(measurement_duration<=60));
tables wind_dir;
weight measurement_duration;
run;

data weather.weather_class;
length weather_class $ 25 wind_dir_class $ 1;
set w2(where=(measurement_duration<=60));
* file "/home/markmcenearney0/noise/wind_rose_data.txt";

if wind_dir >= (-4 +360 - 45) or wind_dir<=(-4 + 45) then
  wind_dir_class="N";
else if (-4 + 90 - 45) < wind_dir and wind_dir < (-4 + 90 + 45) then   
  wind_dir_class="E";
else if (-4 + 180 - 45) <= wind_dir and wind_dir <= (-4 + 180 + 45) then   
  wind_dir_class="S";
else wind_dir_class='W';  
  
if sky1='OVC' and sky1_level<= 1000 then
  weather_class='Low cloud ceiling';
else if wind_speed < 4 then
   weather_class = "Calm 0-3";
else if wind_speed<6 then
  if wind_dir=999 then
    weather_class='Variable 4-5';
  else if wind_dir_class='S' then
    weather_class='Southerly 4-5';
  else if wind_dir_class = 'N' then
    weather_class='Northerly 4-5';
  else weather_class='Crosswind 4-5';  
else if wind_speed < 11 then
  if wind_dir=999 then
    weather_class='Variable 6-10';
  else if wind_dir_class='S' then
    weather_class='Southerly 6-10';
  else if wind_dir_class='N' then
    weather_class='Northerly 6-10';
  else weather_class='Crosswind 6-10';
else if wind_dir=999 then
  weather_class='Variable above 10';
else if wind_dir_class='S' then
  weather_class='Southerly above 10';
else if wind_dir_class='N' then
  weather_class='Northerly above 10';
else weather_class='Crosswind above 10';

if weather_class in ('Low cloud ceiling','Variable 4-5','Variable 6-10', 'Variable above 10', 'Northerly 4-5','Northerly 6-10' 'Northerly above 10') then
  potential_south_flow=0;
else potential_south_flow=1;  
output;

run;

title wind direction since &start;
title2 weighted by measurement_duration except where duration > 60 minutes;
proc freq data=weather.weather_class(where=(weather_class = ''));
tables wind_dir_class;
weight measurement_duration;
run;

title wind and cloud ceiling conditions since &start;
title2 weighted by measurement_duration except where duration > 60 minutes;
proc freq data=weather.weather_class;
tables weather_class / out=f1 nocol nocum norow;
weight measurement_duration;
run;

data w3;
set weather.weather_class;
format weather_dt datetime19.;
run;

proc sort data=w3; by weather_dt; run;

*generate per minute weather obs for merging with operations data;

data w4;
set w3;
by weather_dt;

lag_weather_dt=lag(weather_dt);

if _n_>1 and weather_dt-lag_weather_dt<=3600 then
  do;
    end=weather_dt;
    do weather_dt=lag_weather_dt+60 to end by 60;
      output;
    end;  
  end;
else;

drop end;
run;

data f1;
set noise.nmt_events (where=(nmtid in (7,8) and datepart(start_date_time) between "&start"d and "&end"d));
weather_dt = round(start_date_time,hms(0,1,00)); * round to nearest minute;
month=intnx('MONTH', datepart(start_date_time), 0, 'BEGINNING');

if nmtid=7 then
  if operation_type='D' then
    dir_flow='N';
  else dir_flow='S';
else if operation_type='D' then
  dir_flow='S';
else dir_flow='N';

format start_date_time weather_dt datetime19.;
run;

proc sort data=f1; by weather_dt; run;

data fw1 nomatch;
merge w4(in=in_w4) f1(in=in_f1);
by weather_dt;
if in_f1 then
  if in_w4 then
    output fw1;
  else output nomatch;
else;
run;

proc sort data=fw1; by year; run;

proc freq data=fw1;
tables dir_flow*weather_class / nocol norow nocum nopercent;
title north and south flow ops per weather class since &start;
run;

proc freq data=fw1;
tables dir_flow*weather_class / nocol norow nocum nopercent;
title north and south flow ops per weather class;
by year;
run;

/*
proc freq data=fw1(where=(datepart(weather_dt) between "&end_minus12months"d and "&end"d));
tables dir_flow*weather_class / out=f1 nocol norow nocum nopercent;
title north and south flow ops per weather class in 12 months ending &end;
run;
*/

/*
title percent north in months &start to &end;
proc sql;
SELECT 
    (SELECT COUNT(*) FROM nw1 WHERE dir_flow = 'N' and datepart(weather_dt) between &start and &end) * 100.0 / COUNT(*) AS percent_north
FROM nw1 
where datepart(weather_dt) between &start and &end;

title possible percent south in months &start to &end;
proc sql;
SELECT 
    (SELECT COUNT(*) FROM nw1 WHERE potential_south_flow=1 and datepart(weather_dt) between &start and &end) * 100.0 / COUNT(*) AS possible_percent_south
FROM nw1 
where datepart(weather_dt) between &start and &end;

title percent north in months &end_minus12months to &end;
proc sql;
SELECT 
    (SELECT COUNT(*) FROM nw1 WHERE dir_flow = 'N' and datepart(weather_dt) between &end_minus12months and &end) * 100.0 / COUNT(*) AS percent_north
FROM nw1 
where datepart(weather_dt) between &end_minus12months and &end ;

title possible percent south in months &end_minus12months to &end;
proc sql;
SELECT 
    (SELECT COUNT(*) FROM nw1 WHERE potential_south_flow=1 and datepart(weather_dt) between &end_minus12months and &end) * 100.0 / COUNT(*) AS possible_percent_south
FROM nw1 
where datepart(weather_dt) between &end_minus12months and &end;

*/

data windrose;
set weather.weather_class;
length compass_label $3. speed_label $12.;
select;
  when (wind_dir >= 337.5 or wind_dir < 22.5) compass_label = 'N';
  when (wind_dir >= 22.5 and wind_dir < 67.5) compass_label = 'NE';
  when (wind_dir >= 67.5 and wind_dir < 112.5) compass_label = 'E';
  when (wind_dir >= 112.5 and wind_dir < 157.5) compass_label = 'SE';
  when (wind_dir >= 157.5 and wind_dir < 202.5) compass_label = 'S';
  when (wind_dir >= 202.5 and wind_dir < 247.5) compass_label = 'SW';
  when (wind_dir >= 247.5 and wind_dir < 292.5) compass_label = 'W';
  when (wind_dir >= 292.5 and wind_dir < 337.5) compass_label = 'NW';
end;

if wind_speed < 4 then
  speed_label='0-3';
else if wind_speed < 7 then
  speed_label='4-5';
else if wind_speed < 10 then
  speed_label='6-9';
else speed_label='10-50';  

run;

title wind direction and speed since &start;
title2 weighted by measurement_duration except where duration > 60 minutes;
proc freq data=windrose(rename=(compass_label=direction speed_label=speed));
tables direction*speed / out=wr1 norow nocol nocum;
weight measurement_duration;
run;

title wind direction and speed since &start;
title2;
proc gradar data=wr1;
    chart direction / sumvar=percent
    windrose
    speed=speed
    noframe;
run;    
quit;

data coverage; *hourly weather coverage;
retain last_dt .;
set w4;
by weather_dt;

if last_dt ^=. then
  do;
    if weather_dt-last_dt <= 3600 then
      do;
        coverage_in_hours=(weather_dt-last_dt)/3600; /* convert seconds to hours */
        output;
      end;
    else;
  end;
else;
last_dt=weather_dt;
run;

/*
title hourly or more frequent weather data coverage (percent); 
proc sql;
select
month format=yymmn6.,
sum(coverage_in_hours)/day(intnx('month', month, 0, 'end'))/24*100 as weather_coverage
from
coverage
group by 
month
;
quit;
*/
