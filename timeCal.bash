#!/bin/bash
#-----------------------------------------------------------------
# -- \file timeCal.bash
# -- Description: This is a bash script that will extract the 
# --    ToF and Tdiff spectra from an uncalibrated VANDLE 
# --    histogram using readhis. It will give as final output the 
# --    fully functional timingCal.txt to be used with the 
# --    pixie_ldf_c software. It expects as input the number of 
# --    VANDLE bars you have in the analysis.
# --    
# -- \author S. V. Paulauskas
# -- \date 05 December 2012
# --
# -- This script is distributed as part of a suite to perform
# -- calibrations for VANDLE. It is distributed under the
# -- GPL V 3.0 license. 
# ---------------------------------------------------------------
numBars=$1
hisPath="his/078cu/078cu-timeCal.his"
tofId=3103
diffId=3102
#numBars=48

let dubBars=$numBars*2
let numDiff=$numBars-1
let numTof=$dubBars-1
let tofLines=$dubBars+1
let diffLines=$numBars+1

errorMsg() {
    echo -e "We have some kind of problems fitting the " $1 "."
    echo -e "You should check the fitting script and adjust initial parameters"
}

successMsg() {
    echo -e "FUCK YEAH!!!! We successfully completed the " $1 " fits."
    echo -e "There were " $2 " fits (plus one header line)"
}

#--------- DOING THE TOF PART ----------------
rm -f results-tof.dat test.par test.dat
touch results-tof.dat && echo -e "#Num MaxPos Mu" >> results-tof.dat
for i in `seq 0 $numTof`
do
    readhis $hisPath --id $tofId --gy $i,$i > test.dat
    gnuplot timingCal.gp 2>&1>/dev/null && j=`cat test.par`
    echo $i $j >> results-tof.dat
done

#--------- DOING THE DIFF PART ---------------
rm -f test.par test.dat results-diff.dat
touch results-diff.dat && echo -e "#Num MaxPos Mu" >> results-diff.dat
for i in `seq 0 $numDiff`
do
    readhis $hisPath --id $diffId --gy $i,$i > test.dat
    gnuplot timingCal.gp 2>&1>/dev/null && j=`cat test.par`
    echo $i $j >> results-diff.dat
done

#---------- CHECK THE NUMBER OF TOF LINES -----------------------
numFits=`awk '{nlines++} END {print nlines}' results-tof.dat`
if (( $numFits != $tofLines ))
then
    errorMsg "TOF"
else
    successMsg "tof" $numFits
fi

#---------- CHECK THE NUMBER OF DIFF LINES ------------------------
numFits=`awk '{nlines++} END {print nlines}' results-diff.dat`
if (( $numFits != $diffLines ))
then
    errorMsg "DIFF"
else
    successMsg "diff" $numFits
fi

#---------------- CALCULATE THE NEW LINES FOR THE CORRECTION -------------
awk '{if (NR > 1) print int($1*0.5), (203.366-$3)*0.5}' results-tof.dat > results-tof.tmp
awk '{if (NR > 1) print $1, (200.0-$3)*0.5}' results-diff.dat > results-diff.tmp

#----------- UPDATE THE TIMING CAL FILE -------------------
while read LINE
do
    barNum=`echo $LINE | awk '{print $1}'`
    cal0=`echo $LINE | awk '{print $2}'`
    read LINE
    cal1=`echo $LINE | awk '{print $2}'`

    newLine=`awk -v bar=$barNum -v tofCal0=$cal0 -v tofCal1=$cal1 '{if($1==bar && $2 =="small")print $1,$2,$3,$4,$5,$6, tofCal0, tofCal1}' timingCal.txt`
    awk -v bar=$barNum -v line="$newLine" '{if($1==bar && $2 =="small") sub($0,line); print}' timingCal.txt > vandleCal.tmp
    mv vandleCal.tmp timingCal.txt
done < results-tof.tmp

while read LINE
do
    set -- $LINE
    barNum=$1
    cal=$2
    
    newLine=`awk -v bar=$barNum -v diffCal0=$cal '{if($1==bar && $2 =="small")print $1,$2,$3,$4,$5,diffCal0,$7,$8}' timingCal.txt`
    awk -v bar=$barNum -v line="$newLine" '{if($1==bar && $2 =="small") sub($0,line); print}' timingCal.txt > vandleCal.tmp
    mv vandleCal.tmp timingCal.txt
done < results-diff.tmp
echo "Finished constructing the timingCal.txt."

echo "Removing the temporary files"
rm -f results-diff.tmp results-tof.tmp test.dat test.par
