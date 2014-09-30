# not done

for d in "$@"
do
  if [ -d "$d" ]; then 
      # It's a directory!
      # Directory command goes here.
      cd "$d"
      echo " " >> enfused.log
      echo "JOB STARTED" >> enfused.log
      echo "Entering directory $d" >> enfused.log
      textFileCount=$(ls HDR*.txt | wc -l)
      shFileCount=$(ls HDR*.sh | wc -l)
      if [ "$shFileCount" -gt "0" ]; then
        export PATH=$PATH:/usr/local/bin
        echo "`ls HDR*.sh | /usr/local/bin/parallel ./{} 2>&1`" >> enfused.log
      fi
      if [ "$textFileCount" -gt "0" ]; then
         echo "`ls HDR*.txt | sort -n | /usr/local/bin/parallel /bin/cat {} \| /usr/local/bin/parallel -I xxx echo /usr/local/bin/enfusexxx -o {.}.JPG \| sh  2>&1`" >> enfused.log
      fi
      if [ "$textFileCount" -eq "0" ] && [ "$shFileCount" -eq "0" ]; then 
         echo "`ls IMG*.JPG | sort -n | /usr/local/bin/parallel -j4 -N9 'outputName=$(echo "{1/.}" | sed -e "s/IMG_/HDR_/g" ); /usr/local/bin/enfuse {} -o $outputName.JPG; ' 2>&1`" >> enfused.1920.log
      fi
      enfusedFileCount=$(ls HDR_*.JPG | wc -l)
      if [ "$enfusedFileCount" -gt "0" ]; then
        echo "`ls HDR_*.JPG | /usr/local/bin/parallel '/bin/mv {} {.}.full.JPG'  2>&1`" >> enfused.log
        mkdir "enfused"
        mv HDR*.full.JPG enfused/
        open enfused
      fi
  else
    filename=$(basename "$d")
    extension="${filename##*.}"
    filename="${filename%.*}"
    [[ "$extension" == "JPG" ]] && { looseJpgFiles="$looseJpgFiles$d
"; }
    [[ "$extension" == "jpg" ]] && { looseJpgFiles="$looseJpgFiles$d
"; }
  fi
done
if [ $(echo "$looseJpgFiles" | wc -l) -gt "1" ]; then
         firstFile=$(echo "$looseJpgFiles" | head -n 1)
         dirName=$(dirname "$firstFile")
         cd "$dirName"
	 echo " " >> enfused.log
         echo "JOB STARTED" >> enfused.log
         looseJpgFiles="$(echo "$looseJpgFiles" | sed -e '/^$/d' | sort )"
         echo "`echo "$looseJpgFiles" | /usr/local/bin/parallel -j4 -N9 'outputName=$(echo "{1/.}" | sed -e "s/IMG_/HDR_/g" ); /usr/local/bin/enfuse {} -o $outputName.JPG; ' 2>&1`" >> enfused.log
         echo "`ls HDR_*.JPG | /usr/local/bin/parallel '/bin/mv {} {.}.full.JPG'  2>&1`" >> enfused.log
         mkdir "enfused"
         mv HDR*.full.JPG enfused/
         open enfused
fi
echo "JOB DONE" >> enfused.log
echo " " >> enfused.log