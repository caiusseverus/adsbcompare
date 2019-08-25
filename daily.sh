#!/bin/bash

rm /tmp/day
rm /tmp/week
rm /tmp/month
rm /tmp/year
rm /tmp/old

for i in $(ls -1 /var/lib/graphs1090/scatter/ | tail -n 1); do

        cat /var/lib/graphs1090/scatter/$i >> /tmp/day

done

for i in $(ls -1 /var/lib/graphs1090/scatter/ | tail -n 8 | head -n 7); do

        cat /var/lib/graphs1090/scatter/$i >> /tmp/week

done

for i in $(ls -1 /var/lib/graphs1090/scatter/ | tail -n 38 | head -n 30); do

        cat /var/lib/graphs1090/scatter/$i >> /tmp/month

done

for i in $(ls -1 /var/lib/graphs1090/scatter/ | tail -n 403 | head -n 365); do

        cat /var/lib/graphs1090/scatter/$i >> /tmp/year

done

for i in $(ls -1 /var/lib/graphs1090/scatter/ | tail -n 37 | head -n 30); do

        cat /var/lib/graphs1090/scatter/$i >> /tmp/old

done


gnuplot -c /dev/stdin <<"EOF"


set terminal pngcairo enhanced size 1900,900 background rgb 'gray15'
set output '/tmp/daily.png'


set datafile missing "NaN"


date = system ('date -I')

set multiplot layout 3,2 title 'Created '.date


set size 0.5,0.33
set origin 0.5,0.66
set xtics ("Year" 1, "Month" 2, "Week" 3, "Day" 4)
set title "Range"
set style fill solid 0.5 border -1
set style boxplot nooutliers
set pointsize 0.5

stats '/tmp/year' u ($1/1852) name "Y" noout
stats '/tmp/month' u ($1/1852) name "M" noout
stats '/tmp/week' u ($1/1852) name "W" noout
stats '/tmp/day' u ($1/1852) name "D" noout

ub = ceil((Y_median + (Y_up_quartile - Y_lo_quartile) * 1.5) / 10) * 10 + 10
lb = floor((Y_median - (Y_up_quartile - Y_lo_quartile) * 1.5) / 10) * 10 - 10

set yrange [lb:ub]

Ymax = Y_up_quartile + ((Y_up_quartile - Y_lo_quartile) * 1.5)
Ymin = Y_lo_quartile - ((Y_up_quartile - Y_lo_quartile) * 1.5)
Mmax = M_up_quartile + ((M_up_quartile - M_lo_quartile) * 1.5)
Mmin = M_lo_quartile - ((M_up_quartile - M_lo_quartile) * 1.5)
Wmax = W_up_quartile + ((W_up_quartile - W_lo_quartile) * 1.5)
Wmin = W_lo_quartile - ((W_up_quartile - W_lo_quartile) * 1.5)
Dmax = D_up_quartile + ((D_up_quartile - D_lo_quartile) * 1.5)
if (D_min > (D_lo_quartile - ((D_up_quartile - D_lo_quartile) * 1.5))) {Dmin = D_min} ; else {Dmin = (D_lo_quartile - ((D_up_quartile - D_lo_quartile) * 1.5))}



set label 1 sprintf("%3.2f",Ymax) right at 0.725,Ymax font ",8"
set label 2 sprintf("%3.2f",Y_up_quartile) right at 0.725,Y_up_quartile font ",8"
set label 3 sprintf("%3.2f",Y_median) right at 0.725,Y_median font ",8"
set label 4 sprintf("%3.2f",Y_lo_quartile) right at 0.725,Y_lo_quartile font ",8"
set label 5 sprintf("%3.2f",Ymin) right at 0.725,Ymin font ",8"

set label 6 sprintf("%3.2f",Mmax) right at 1.725,Mmax font ",8"
set label 7 sprintf("%3.2f",M_up_quartile) right at 1.725,M_up_quartile font ",8"
set label 8 sprintf("%3.2f",M_median) right at 1.725,M_median font ",8"
set label 9 sprintf("%3.2f",M_lo_quartile) right at 1.725,M_lo_quartile font ",8"
set label 10 sprintf("%3.2f",Mmin) right at 1.725,Mmin font ",8"

set label 11 sprintf("%3.2f",Wmax) right at 2.725,Wmax font ",8"
set label 12 sprintf("%3.2f",W_up_quartile) right at 2.725,W_up_quartile font ",8"
set label 13 sprintf("%3.2f",W_median) right at 2.725,W_median font ",8"
set label 14 sprintf("%3.2f",W_lo_quartile) right at 2.725,W_lo_quartile font ",8"
set label 15 sprintf("%3.2f",Wmin) right at 2.725,Wmin font ",8"

set label 16 sprintf("%3.2f",Dmax) right at 3.725,Dmax font ",8"
set label 17 sprintf("%3.2f",D_up_quartile) right at 3.725,D_up_quartile font ",8"
set label 18 sprintf("%3.2f",D_median) right at 3.725,D_median font ",8"
set label 19 sprintf("%3.2f",D_lo_quartile) right at 3.725,D_lo_quartile font ",8"
set label 20 sprintf("%3.2f",Dmin) right at 3.725,Dmin font ",8"


plot    '/tmp/year' u (1):($1/1852) w boxplot lc "blue" notitle, \
        '/tmp/month' u (2):($1/1852) w boxplot lc "blue" notitle, \
        '/tmp/week' u (3):($1/1852) w boxplot lc "blue" notitle, \
        '/tmp/day' u (4):($1/1852) w boxplot lc "blue" notitle

unset for [i=1:20] label i
unset yrange


set size 0.5,0.33
set origin 0.5,0.33
set xtics ("Year" 1, "Month" 2, "Week" 3, "Day" 4)
set title "Messages"
set style fill solid 0.5 border -1
set style boxplot nooutliers
set pointsize 0.5

stats '/tmp/year' u ($2+$3) name "Y" noout
stats '/tmp/month' u ($2+$3) name "M" noout
stats '/tmp/week' u ($2+$3) name "W" noout
stats '/tmp/day' u ($2+$3) name "D" noout

ub = ceil((Y_max / 100) * 100 + 100)
lb = floor((Y_min / 100) * 100 - 100)

set yrange [lb:ub]


Ymax = Y_max
Ymin = Y_min
Mmax = M_max
Mmin = M_min
Wmax = W_max
Wmin = W_min
Dmax = D_max
Dmin = D_min


set label 1 sprintf("%3.0f",Ymax) right at 0.725,Ymax font ",8"
set label 2 sprintf("%3.0f",Y_up_quartile) right at 0.725,Y_up_quartile font ",8"
set label 3 sprintf("%3.0f",Y_median) right at 0.725,Y_median font ",8"
set label 4 sprintf("%3.0f",Y_lo_quartile) right at 0.725,Y_lo_quartile font ",8"
set label 5 sprintf("%3.0f",Ymin) right at 0.725,Ymin font ",8"

set label 6 sprintf("%3.0f",Mmax) right at 1.725,Mmax font ",8"
set label 7 sprintf("%3.0f",M_up_quartile) right at 1.725,M_up_quartile font ",8"
set label 8 sprintf("%3.0f",M_median) right at 1.725,M_median font ",8"
set label 9 sprintf("%3.0f",M_lo_quartile) right at 1.725,M_lo_quartile font ",8"
set label 10 sprintf("%3.0f",Mmin) right at 1.725,Mmin font ",8"

set label 11 sprintf("%3.0f",Wmax) right at 2.725,Wmax font ",8"
set label 12 sprintf("%3.0f",W_up_quartile) right at 2.725,W_up_quartile font ",8"
set label 13 sprintf("%3.0f",W_median) right at 2.725,W_median font ",8"
set label 14 sprintf("%3.0f",W_lo_quartile) right at 2.725,W_lo_quartile font ",8"
set label 15 sprintf("%3.0f",Wmin) right at 2.725,Wmin font ",8"

set label 16 sprintf("%3.0f",Dmax) right at 3.725,Dmax font ",8"
set label 17 sprintf("%3.0f",D_up_quartile) right at 3.725,D_up_quartile font ",8"
set label 18 sprintf("%3.0f",D_median) right at 3.725,D_median font ",8"
set label 19 sprintf("%3.0f",D_lo_quartile) right at 3.725,D_lo_quartile font ",8"
set label 20 sprintf("%3.0f",Dmin) right at 3.725,Dmin font ",8"



plot    '/tmp/year' u (1):($2+$3) w boxplot lc "green" notitle, \
        '/tmp/month' u (2):($2+$3) w boxplot lc "green" notitle, \
        '/tmp/week' u (3):($2+$3) w boxplot lc "green" notitle, \
        '/tmp/day' u (4):($2+$3) w boxplot lc "green" notitle

unset for [i=1:20] label i
unset yrange



set size 0.5,0.33
set origin 0.5,0
set xtics ("Year" 1, "Month" 2, "Week" 3, "Day" 4)
set title "Aircraft"
set style fill solid 0.5 border -1
set style boxplot nooutliers
set pointsize 0.5

stats '/tmp/year' u ($4) name "Y" noout
stats '/tmp/month' u ($4) name "M" noout
stats '/tmp/week' u ($4) name "W" noout
stats '/tmp/day' u ($4) name "D" noout

ub = ceil((Y_max / 10) * 10 + 10)
lb = floor((Y_min / 10) * 10 - 10)

set yrange [lb:ub]


Ymax = Y_max
Ymin = Y_min
Mmax = M_max
Mmin = M_min
Wmax = W_max
Wmin = W_min
Dmax = D_max
Dmin = D_min


set label 1 sprintf("%3.0f",Ymax) right at 0.725,Ymax font ",8"
set label 2 sprintf("%3.0f",Y_up_quartile) right at 0.725,Y_up_quartile font ",8"
set label 3 sprintf("%3.0f",Y_median) right at 0.725,Y_median font ",8"
set label 4 sprintf("%3.0f",Y_lo_quartile) right at 0.725,Y_lo_quartile font ",8"
set label 5 sprintf("%3.0f",Ymin) right at 0.725,Ymin font ",8"

set label 6 sprintf("%3.0f",Mmax) right at 1.725,Mmax font ",8"
set label 7 sprintf("%3.0f",M_up_quartile) right at 1.725,M_up_quartile font ",8"
set label 8 sprintf("%3.0f",M_median) right at 1.725,M_median font ",8"
set label 9 sprintf("%3.0f",M_lo_quartile) right at 1.725,M_lo_quartile font ",8"
set label 10 sprintf("%3.0f",Mmin) right at 1.725,Mmin font ",8"

set label 11 sprintf("%3.0f",Wmax) right at 2.725,Wmax font ",8"
set label 12 sprintf("%3.0f",W_up_quartile) right at 2.725,W_up_quartile font ",8"
set label 13 sprintf("%3.0f",W_median) right at 2.725,W_median font ",8"
set label 14 sprintf("%3.0f",W_lo_quartile) right at 2.725,W_lo_quartile font ",8"
set label 15 sprintf("%3.0f",Wmin) right at 2.725,Wmin font ",8"

set label 16 sprintf("%3.0f",Dmax) right at 3.725,Dmax font ",8"
set label 17 sprintf("%3.0f",D_up_quartile) right at 3.725,D_up_quartile font ",8"
set label 18 sprintf("%3.0f",D_median) right at 3.725,D_median font ",8"
set label 19 sprintf("%3.0f",D_lo_quartile) right at 3.725,D_lo_quartile font ",8"
set label 20 sprintf("%3.0f",Dmin) right at 3.725,Dmin font ",8"



plot    '/tmp/year' u (1):($4) w boxplot lc "red" notitle, \
        '/tmp/month' u (2):($4) w boxplot lc "red" notitle, \
        '/tmp/week' u (3):($4) w boxplot lc "red" notitle, \
        '/tmp/day' u (4):($4) w boxplot lc "red" notitle

unset for [i=1:20] label i
unset yrange
unset xtics

set size 0.5,1
set origin 0,0
set xlabel "Aircraft"
set ylabel "Message rate"
set grid xtics ytics
set xtics 50
set ytics 100

set title "Last week compared with preceding month"

set fit prescale
set fit logfile '/tmp/fit'
FIT_LIMIT = 1.e-10
FIT_MAXITER = 100

f(x) = a/20*x**2 - 10*b*x + 3000*abs(c)*x/sqrt(6000*abs(d)+x**2)
a=1
b=1
c=1
d=1
fit f(x) '/tmp/week' using ($4):($2+$3) via a,b,c,d

stats '/tmp/week' using ($1/1852) name "Range" noout

lb = (Range_mean - Range_stddev*2)
ub = (Range_mean + Range_stddev*2)

set palette rgbformula 34,35,36
set cblabel 'Range nm'
set cbrange [lb:ub]
set colorbox horizontal user origin graph 0.4, graph 0.1 size graph 0.5, graph 0.05
set key off

plot    '/tmp/old' u ($4):($2+$3) with points lt rgb '#001CD2' pt 2 notitle, \
        '/tmp/week' u ($4):($2+$3):($1/1852) with points lt palette pt 7 notitle, f(x) lt rgb "black" title "Week" at end

EOF

sudo cp /tmp/daily.png /run/dump1090-fa/daily.png
