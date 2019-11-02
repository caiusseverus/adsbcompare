#!/bin/bash

cd /var/lib/graphs1090/scatter

starta=$1
durationa=$2
let "dura = $2-1"

cat $(for i in $(eval echo "{0..$dura}"); do date -I --date=$starta+${i}days; done) > /tmp/first

wc -l /tmp/first

startb=$3
durationb=$4
let "durb = $4-1"

cat $(for i in $(eval echo "{0..$durb}"); do date -I --date=$startb+${i}days; done) > /tmp/second

enda=$(date -I --date=$starta+${dura}days)
endb=$(date -I --date=$startb+${durb}days)

wc -l /tmp/second

gnuplot -c /dev/stdin $starta $enda $startb $endb <<"EOF"

set terminal pngcairo enhanced size 1900,900 background rgb 'gray80'
set output '/tmp/compare.png'

set datafile missing "NaN"

set multiplot layout 2,4

set size 0.5,1
set origin 0,0
set xlabel "Aircraft"
set ylabel "Messages"
set grid xtics ytics
set xtics 50
set ytics 100
set pointsize 0.5
set title "Comparison of ".ARG1." to ".ARG2." and ".ARG3." to ".ARG4

set fit prescale
set fit logfile '/tmp/fit'
FIT_LIMIT = 1.e-10
FIT_MAXITER = 100

f(x) = a/20*x**2 - 10*b*x + 3000*abs(c)*x/sqrt(6000*abs(d)+x**2)
a=1
b=1
c=1
d=1
fit f(x) '/tmp/first' using ($4):($2+$3) via a,b,c,d

g(x) = j/20*x**2 - 10*k*x + 3000*abs(l)*x/sqrt(6000*abs(m)+x**2)
j=1
k=1
l=1
m=1
fit g(x) '/tmp/second' using ($4):($2+$3) via j,k,l,m

plot    '/tmp/first' using ($4):($2+$3) with points lt rgb "red" pt 7 title ARG1." to ".ARG2, f(x) lt rgb "black" notitle, \
        '/tmp/second' using ($4):($2+$3) with point lt rgb "blue" pt 7 title ARG3." to ".ARG4,  g(x) lt rgb "black" notitle


unset title

set size 0.5,0.6
set origin 0.5,0
set xlabel "Aircraft"
set ylabel "Range"
set grid xtics ytics
set ytics 50
set xtics 50
set pointsize 0.5
unset title

stats   '/tmp/first' using ($4) name "AircraftA"
stats   '/tmp/first' using ($1/1852) name "RangeA"
stats   '/tmp/second' using ($4) name "AircraftB"
stats   '/tmp/second' using ($1/1852) name "RangeB"

if (RangeA_min < RangeB_min) ymin = RangeA_min-5; else ymin = RangeB_min-5
if (AircraftA_max > AircraftB_max) xmax = AircraftA_max + 10 ; else xmax = AircraftB_max + 10

set xrange [0:xmax]
set yrange [ymin:300]

f(x) = a1*x**2 + b1*x + c1
a1 = 1
b1 = 1
c1 = 1

g(x) = a2*x**2 + b2*x + c2
a2 = 1
b2 = 1
c2 = 1

fit f(x) '/tmp/first' using ($4):($1/1852) via a1,b1,c1
fit g(x) '/tmp/second' using ($4):($1/1852) via a2,b2,c2

plot    '/tmp/first' using ($4):($1/1852) with points lt rgb "red" pt 7 title ARG1." to ".ARG2, f(x) lt rgb "black" notitle, \
        '/tmp/second' using ($4):($1/1852) with points lt rgb "blue" pt 7 title ARG3." to ".ARG4, g(x) lt rgb "black" notitle


set xrange [*:*]
unset yrange
set size 0.1667,0.4
set origin 0.5,0.6
set ylabel "Range"
unset xlabel
unset xtics
set style fill solid 0.5 border -1
set ytics auto


plot    '/tmp/first' using (1):($1/1852) w boxplot lc "red" notitle, \
        '/tmp/second' using (2):($1/1852) w boxplot lc "blue" notitle


set size 0.1667,0.4
set origin 0.6667,0.6
set ylabel "Aircraft"
set style fill solid 0.5 border -1
set ytics auto

plot    '/tmp/first' using (1):($4) w boxplot lc "red" notitle, \
        '/tmp/second' using (2):($4) w boxplot lc "blue" notitle


set size 0.1667,0.4
set origin 0.8334, 0.6
set ylabel "Messages"
set style fill solid 0.5 border -1
set ytics auto

plot    '/tmp/first' u (1):($2+$3) w boxplot lc "red" notitle, \
        '/tmp/second' u (2):($2+$3) w boxplot lc "blue" notitle




EOF

sudo cp /tmp/compare.png /run/dump1090-fa/compare.png
