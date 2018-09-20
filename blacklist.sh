#!/bin/bash
exec >> ./mediabackup.log
exec 2>/dev/null

curl -X GET http://192.111.151.92:8989/api/queue --header "X-Api-Key:65d21fe7623b466898588081daf73396" 2>/dev/null > ./sonarrqueue.json
curl -X GET http://192.111.151.92:7878/api/queue --header "X-Api-Key:41b68bcb4b0d4698a6f9cd35309def16" 2>/dev/null > ./radarrqueue.json

sonarrCount=$(grep -c "Warning" sonarrqueue.json)
radarrCount=$(grep -c "Warning" radarrqueue.json)
echo "$sonarrCount items blacklisted from Sonarr"
echo "$radarrCount items blacklisted from Radarr"

while [ "$sonarrCount" -gt 0 ];
do
	sed -i '1,/Warning/d' ./sonarrqueue.json
	grep "\"id\"\:" sonarrqueue.json -m 1 | cut -c 11-  >> sonarrid.txt
	sonarrCount=$((sonarrCount-1))
done

while [ "$radarrCount" -gt 0 ];
do
	sed -i '1,/Warning/d' ./radarrqueue.json
	grep "\"id\"\:" radarrqueue.json -m 1 | cut -c 11-  >> radarrid.txt
	radarrCount=$((radarrCount-1))
done

sed -i '/^\s*$/d' ./sonarrid.txt
sed -i '/^\s*$/d' ./radarrid.txt

while read s; do
	curl -X DELETE http://192.111.151.92:8989/api/queue/"$s"?blacklist=true --header "X-Api-Key:65d21fe7623b466898588081daf73396" 2>/dev/null
done <./sonarrid.txt

while read r; do
	curl -X DELETE http://192.111.151.92:7878/api/queue/"$r"?blacklist=true --header "X-Api-Key:41b68bcb4b0d4698a6f9cd35309def16" 2>/dev/null
done <./radarrid.txt

rm ./sonarrqueue.json
rm ./radarrqueue.json
rm ./sonarrid.txt
rm ./radarrid.txt

exit 0