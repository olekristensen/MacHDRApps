for d in "$@"
do
  if [ -d "$d" ]; then 
      # It's a directory!
      # Directory command goes here.
      cd "$d"
      echo " " >> enfused.timelapse.1920.log
      echo "JOB STARTED" >> enfused.timelapse.1920.log
      textFileCount=$(ls HDR*.txt | wc -l)
      shFileCount=$(ls HDR*.sh | wc -l)
      if [ "$shFileCount" -gt "0" ]; then
	export PATH=$PATH:/usr/local/bin
	echo "`ls HDR*.sh | /usr/local/bin/parallel ./{} 2>&1`" >> enfused.timelapse.1920.log
      fi
      if [ "$textFileCount" -gt "0" ]; then
	echo "`ls HDR*.txt | sort -n | /usr/local/bin/parallel /bin/cat {} \| /usr/local/bin/parallel -I xxx echo /usr/local/bin/enfusexxx -o {.}.JPG \| sh  2>&1`" >> enfused.timelapse.1920.log
      fi
      if [ "$textFileCount" -eq "0" ] && [ "$shFileCount" -eq "0" ]; then 
         echo "`ls IMG*.JPG | sort -n | /usr/local/bin/parallel -j4 -N9 'outputName=$(echo "{1/.}" | sed -e "s/IMG_/HDR_/g" ); /usr/local/bin/enfuse {} -o $outputName.JPG; ' 2>&1`" >> enfused.timelapse.1920.log
      fi
      enfusedFileCount=$(ls HDR_*.JPG | wc -l)
      if [ "$enfusedFileCount" -gt "0" ]; then
	 echo "`ls HDR_*.JPG | /usr/local/bin/parallel '/bin/mv {} {.}.full.JPG'  2>&1`" >> enfused.timelapse.1920.log
	 mkdir "enfused"
	 mv HDR*.full.JPG enfused/
         echo "`ls enfused/HDR*.full.JPG | /usr/bin/sed -e 's/.full//g' | /usr/local/bin/parallel '/usr/local/bin/convert {.}.full.JPG -scale 1920x {.}.1920.JPG'  2>&1`" >> enfused.timelapse.1920.log
	 echo "`/usr/local/bin/ffmpeg -y -r 25 -pattern_type glob -i 'enfused/*.1920.JPG' -c:v libx264 enfused.timelapse.1920.mp4  2>&1`" >> enfused.timelapse.1920.log
         open "enfused.timelapse.1920.mp4"
      fi
  fi
done
echo "JOB DONE" >> enfused.timelapse.1920.log
echo " " >> enfused.timelapse.1920.log