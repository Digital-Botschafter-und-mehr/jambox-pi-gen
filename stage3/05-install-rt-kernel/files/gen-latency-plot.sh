#!/bin/bash
MODEL=$(tr -d '\0' </proc/device-tree/model)
[[ "$MODEL" =~ "Pi 4" ]] && PIMODEL=RPi4
[[ "$MODEL" =~ "Pi 3" ]] && PIMODEL=RPi3
[[ "$MODEL" =~ "Pi 2" ]] && PIMODEL=RPi2
[[ -z "$PIMODEL" ]] && PIMODEL=PiUnk
KERNEL=`uname -r`
OUTPUTFILE=output_${PIMODEL}_${KERNEL}
PLOTFILE=plot_${PIMODEL}_${KERNEL}.png
CYCLICTEST_CMD="./cyclictest -l100000000 -m -Sp91 -i200 -h400 -q >$OUTPUTFILE"

if ! [ -x "$(command -v gnuplot)" ]; then
  sudo apt -y install gnuplot
fi

if ! [ -d "$HOME/rt-tests" ]; then
  git clone --depth 1 --branch stable/v1.0 https://git.kernel.org/pub/scm/utils/rt-tests/rt-tests.git $HOME/rt-tests/ 
fi

cd $HOME/rt-tests

if [[ ! -f $OUTPUTFILE ]]; then
  [[ ! -f ./cyclictest ]] && make
  echo `date`: begin cyclicttest - this will take 5+ hours
  echo CYCLICTEST_CMD: $CYCLICTEST_CMD
  eval $CYCLICTEST_CMD
  echo `date`: end cyclictest
fi

max=`grep "Max Latencies" $OUTPUTFILE | tr " " "\n" | sort -n | tail -1 | sed s/^0*//`
grep -v -e "^#" -e "^$" $OUTPUTFILE | tr " " "\t" >histogram
cores=`nproc`

for i in `seq 1 $cores`
do
  column=`expr $i + 1`
  cut -f1,$column histogram >histogram$i
done

echo -n -e "set title \"Latency - $PIMODEL - Linux $KERNEL\"\n\
set terminal png\n\
set xlabel \"Latency (us), max $max us\"\n\
set logscale y\n\
set xrange [0:400]\n\
set yrange [0.8:*]\n\
set ylabel \"Number of latency samples\"\n\
set output \"$PLOTFILE\"\n\
plot " >plotcmd

for i in `seq 1 $cores`
do
  if test $i != 1
  then
    echo -n ", " >>plotcmd
  fi
  cpuno=`expr $i - 1`
  if test $cpuno -lt 10
  then
    title=" CPU$cpuno"
   else
    title="CPU$cpuno"
  fi
  echo -n "\"histogram$i\" using 1:2 title \"$title\" with histeps" >>plotcmd
done

gnuplot -persist <plotcmd
gpicview $PLOTFILE &
exit
