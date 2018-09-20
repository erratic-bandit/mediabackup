#!/bin/bash
#version 1.8
startTime=$(date)
exec >> ./mediabackup.log
exec 2>&1

#backs up the log to log.old if log has at least 200 lines
if [[ $(wc -l ./mediabackup.log | awk '{ print $1}') -ge 200 ]]; then
	cat ./mediabackup.log >> ./mediabackup.log.old && echo "Log backed up at $startTime:" > ./mediabackup.log
fi

#VARIABLES
#largest movie and tv folder on driveA
movie=$(du /home/jdh/driveA/movies/ | sort -nr| head -n 2 | tail -n 1 | grep -o "\\/.*" | tr -d '/' | cut -c 20-)
movieSize=$(du -k /home/jdh/driveA/movies/ | sort -nr | head -n 2 | tail -n 1| awk '{ print $1}')
tv=$(du /home/jdh/driveA/tv/ | sort -nr | head -n 2 | tail -n 1 | grep -o "\\/.*" | tr -d '/' | cut -c 16-)
tvSize=$(du -k /home/jdh/driveA/tv/ | sort -nr| head -n 2 | tail -n 1 | awk '{ print $1}')
music=$(du /home/jdh/driveA/music/ | sort -nr| head -n 2 | tail -n 1 | grep -o "\\/.*" | tr -d '/' | cut -c 19-)
musicSize=$(du -k /home/jdh/driveA/music/ | sort -nr | head -n 2 | tail -n 1 | awk '{ print $1}')
#percentage used on each storage drive
freespaceA=$(df -k /home/jdh/driveA | awk '{ print $4}' | tail -n 1)
freespaceB=$(df -k /home/jdh/driveB | awk '{ print $4}' | tail -n 1)
freespaceC=$(df -k /home/jdh/driveC | awk '{ print $4}' | tail -n 1)
freespaceD=$(df -k /home/jdh/driveD | awk '{ print $4}' | tail -n 1)
totalFree=$(( freespaceA + freespaceB + freespaceC + freespaceD ))
#sets base status
status1="Last scan was $startTime"
status2=$(head -n 2 ./mediabackup.status | tail -n 1)
status3="Total free space is $totalFree k"
#thresholds
primaryThreshold=200000000
if [[ $movieSize -gt $tvSize ]]; then
	secondaryThreshold=$movieSize
else
	secondaryThreshold=$tvSize
fi
#collects sabnzbd information
sabPause=$(curl "http://192.111.151.92:8080/sabnzbd/api?mode=queue&output=json&apikey=8ad731a970e52d863d520206d4f318d9" 2>/dev/null | awk '{ print $8}')

#selects next free drive
if [ "$freespaceB" -gt "$secondaryThreshold" ]; then
	nextFree=driveB
elif [ "$freespaceC" -gt "$secondaryThreshold" ]; then
	nextFree=driveC
elif [ "$freespaceD" -gt "$secondaryThreshold" ]; then
	nextFree=driveD
else
	echo "!!!!!!!!ERROR!!!!!!!!"
	echo "NOT ENOUGH FREE SPACE"
	echo "!!!!!!!!!!!!!!!!!!!!!"
	echo "!!!!!!!!ERROR!!!!!!!!" > ./mediabackup.status
	echo "NOT ENOUGH FREE SPACE" >> ./mediabackup.status
	echo "!!!!!!!!!!!!!!!!!!!!!" >> ./mediabackup.status
	exit 1
fi
#FORMULAS
#moves the largest Movie and creates symlink
moveMovie ()
{
	cp -rf /home/jdh/driveA/movies/"$movie" /home/jdh/"$nextFree"/movies/"$movie" && \
	rm -rf /home/jdh/driveA/movies/"$movie" && \
	ln -sf /home/jdh/"$nextFree"/movies/"$movie" /home/jdh/driveA/movies/ && \
	echo "$movie moved to $nextFree"
}
#moves the largest TV show and creates symlink
moveTV ()
{
	cp -rf /home/jdh/driveA/tv/"$tv" /home/jdh/"$nextFree"/tv/"$tv" && \
	rm -rf /home/jdh/driveA/tv/"$tv" && \
	ln -sf /home/jdh/"$nextFree"/tv/"$tv" /home/jdh/driveA/tv/ && \
	echo "$tv moved to $nextFree"
}
#moves the largest movie and creates symlink
moveMusic ()
{
	cp -rf /home/jdh/driveA/music/"$music" /home/jdh/"$nextFree"/music/"$music" && \
	rm -rf /home/jdh/driveA/music/"$music" && \
	ln -sf /home/jdh/"$nextFree"/music/"$movie" /home/jdh/driveA/movies/ && \
	echo "$music moved to $nextFree"
}
#checks if SABnzbd is paused and resumes
resumeSab ()
{
	if [ "$sabPause" = "true," ]; then
		curl "http://192.111.151.92:8080/sabnzbd/api?mode=resume&apikey=8ad731a970e52d863d520206d4f318d9" 2>/dev/null
		echo "SABnzdb resumed"
	else
		echo "SABnzdb running"
	fi
}
logReport ()
{
	echo "driveA free space was $freespaceA"
	echo "driveB free space was $freespaceB"
	echo "driveC free space was $freespaceC"
	echo "driveD free space was $freespaceD"
	if [ "$movieSize" -gt "$tvSize" ] && [ "$movieSize" -gt "$musicSize" ]; then
		echo "largest file on drive-$movieSize"
	elif [ "$tvSize" -gt "$musicSize" ]; then
		echo "largest file on drive-$tvSize"
	else
		echo "largest file on drive-$musicSize"
	fi
	echo "Finished at $endTime"
	echo "MOVEMENT COMPLETED"
}
statusReport ()
{
	echo "$status1" > ./mediabackup.status
	echo "$status2" >> ./mediabackup.status
	echo "$status3" >> ./mediabackup.status
}

#action
if [ "$freespaceA" -lt $primaryThreshold ]; then
	echo "---BEGIN REPORT---"
	echo "Starting at $startTime"
	if [ "$movieSize" -gt "$tvSize" ] && [ "$movieSize" -gt "$musicSize" ]; then
		echo "Moving $movie to $nextFree ..."
		moveMovie
		endTime=$(date)
		status2="Last move was $movie at $endTime"
	elif [ "$tvSize" -gt "$musicSize" ]; then
		echo "Moving $tv to $nextFree ..."
		moveTV
		endTime=$(date)
		status2="Last move was $tv at $endTime"
	else
		echo "Moving $music to $nextFree ..."
		moveMusic
		endTime=$(date)
		status2="Last move was $music at $endTime"
	fi
	logReport
	resumeSab
	statusReport
	echo -e "---END REPORT---\\n"
	sleep 30
	exit 0
else
	sh ./blacklist.sh
	endTime=$(date)
	if [ "$movieSize" -gt "$tvSize" ] && [ "$movieSize" -gt "$musicSize" ]; then
		echo "largest file on drive-$movieSize k"
	elif [ "$tvSize" -gt "$musicSize" ]; then
		echo "largest file on drive-$tvSize k"
	else
		echo "largest file on drive-$musicSize k"
	fi
	echo -e "Scanned at $endTime , driveA has $freespaceA k free, movement not needed\\n"
	statusReport
	sleep 900
	exit 0
fi

echo "UNKOWN ERROR"
echo "UNKOWN ERROR - CHECK LOGS" > ./mediabackup.status
exit 1