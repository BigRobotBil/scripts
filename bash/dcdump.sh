#!/bin/bash
# slight modifications by Zeek, however all real credit is to darcagn
# link to original: https://dcemulation.org/dumpcast/site/dcdump.txt
# (if the link dies, the original script is preserved at the bottom)
# Primary changes from the original script are:
#   - Remove generating `postinfo.txt`
#   - Create a folder with the extract application name from the index.html
#   - Leave index.html within the folder for reference
#   - Move everything in there once downloads are done/carrying on normally with the script

echo "Dreamcast Dumping Script by darcagn"
echo "   for use with httpd-ack gd-rom dumper software"
echo "   => http://dumpcast.dcemulation.org/\n"

if [ -z "$1" ];
    then
        echo "usage: dcdump.sh [dreamcast's IP address]"
        echo "IP of Dreamcast not specified. Quitting.\n "
        exit
fi

if [[ "$(ls -A tmp)" ]]; then
    read -p "tmp dir has files in it, clear out and proceed? y/n " yn
    if [[ "$yn" == [Yy]* ]]; then
        rm -r tmp
    else
        exit
    fi
fi

mkdir -p tmp

cd tmp

# iterate over all links, except for the ones specified
echo "Beginning to download files from httpd-ack...\n"
wget -r -w 1 -nH -R dc_bios*,dc_flash*,syscalls*,httpd-ack* $1

echo "Required disc access complete, spinning down disc..."
wget -q -t 1 -O /dev/null $1/cdrom_spin_down

# The index.html always has the same structure, so we just need to hunt for the Title line
# This'll match the Title line, and set the capture group to be whatever's in the title section.
# The \1 is just the first captured item (we're only doing one thing) and the p on the end is to print it, 
# which we'll capture in a variable. finally replace everything illegal (anything not a character or number) with underscores
appName=$(sed -n 's/.*<td>Title<\/td><td colspan=3>\(.*\)<\/td>.*/\1/p' index.html | sed -e 's/[^A-Za-z0-9._-]/_/g')

echo "Creating folder"
mkdir -p $appName
echo "Moving data"
mv disc.gdi $appName
mv track* $appName
mv index.html $appName

echo "Moving to $appName folder"
cd $appName

echo "Renaming downloaded tracks to their correct filenames..."
for i in track*
    do mv "$i" "`echo $i | sed s/.ipbintoc.*$//`"
done

echo "GDI info...\n"

echo "\nCalculating filesizes and hashes... This may take a while, please be patient.\n" 

filesize="size "`ls -nl disc.gdi | awk '{print $5}'`
    printf "\t$filesize\t"
crc32="crc "`crc32 disc.gdi`
    printf "$crc32 "
md5="md5 "`openssl md5 disc.gdi | awk -F"=" '{ print $2 }' | sed 's/ //g'`
    printf "$md5 "
sha1="sha1"`openssl sha1 disc.gdi | awk -F"=" '{ print $2 }'`
    printf "%s\n" "$sha1"

for track in track*
do
filesize="size "`ls -nl $track | awk '{print $5}'`
    printf "\t$filesize\t"
crc32="crc "`crc32 $track`
    printf "$crc32 "
md5="md5 "`openssl md5 $track | awk -F"=" '{ print $2 }' | sed 's/ //g'`
    printf "$md5 "
sha1="sha1"`openssl sha1 $track | awk -F"=" '{ print $2 }'`
    printf "%s\n" "$sha1"
done

# move up out of the application folder
cd ..
# move the application folder out of temp
mv $appName ..
# begin anew
cd ..

echo "Done processing for $appName!"

# original script
# "Dreamcast Dumping Script by darcagn"
#echo "   for use with httpd-ack gd-rom dumper software"
#echo "   => http://dumpcast.dcemulation.org/\n"
#
#if [ -z "$1" ];
#	then
#		echo "usage: dcdump.sh [dreamcast's IP address]"
#		echo "IP of Dreamcast not specified. Quitting.\n "
#		exit
#fi
#
#echo "Beginning to download files from httpd-ack...\n"
#wget -r -w 1 -nH -R dc_bios*,dc_flash*,syscalls*,httpd-ack* $1
#
#echo "Required disc access complete, spinning down disc..."
#wget -q -t 1 -O /dev/null $1/cdrom_spin_down
#
#echo "Renaming downloaded tracks to their correct filenames..."
#for i in track*
#	do mv "$i" "`echo $i | sed s/.ipbintoc.*$//`"
#done
#
#echo "Generating dump information...\n"
#
#echo "[b][u]Disc Information[/u]:[/b]" > postinfo.txt
#cat index.html \
#	| head -16 | tail -10 \
#	| sed 's/<tr><td>/[b]/g' \
#	| sed 's/<\/td><td colspan=3>/:[\/b] /g' \
#	| sed 's/<\/td><\/tr>//g' >> postinfo.txt
#
#echo "GDI info...\n"
#
#printf "\nringcode:[code]<<write in ringcode here>>[/code]\n\ngdi information:[code]" >> postinfo.txt
#cat disc.gdi | tr -d "\r" | tee -a postinfo.txt
#echo "[/code]\n" >> postinfo.txt
#printf "file information:[quote]" >> postinfo.txt
#
#echo "\nCalculating filesizes and hashes... This may take a while, please be patient.\n" 
#
#printf "disc.gdi " | tee -a postinfo.txt
#filesize="size "`ls -nl disc.gdi | awk '{print $5}'`
#	printf "\t$filesize\t"
#	printf "[color=red]%s[/color] " "$filesize" >> postinfo.txt
#crc32="crc "`crc32 disc.gdi`
#	printf "$crc32 "
#	printf "[color=green]%s[/color] " "$crc32" >> postinfo.txt
#md5="md5 "`openssl md5 disc.gdi | awk -F"=" '{ print $2 }' | sed 's/ //g'`
#	printf "$md5 "
#	printf "[color=blue]%s[/color] " "$md5" >> postinfo.txt
#sha1="sha1"`openssl sha1 disc.gdi | awk -F"=" '{ print $2 }'`
#	printf "%s\n" "$sha1"
#	printf "[color=red]%s[/color]\n" "$sha1" >> postinfo.txt
#
#for track in track*
#do
#printf "$track " | tee -a postinfo.txt
#filesize="size "`ls -nl $track | awk '{print $5}'`
#	printf "\t$filesize\t"
#	printf "[color=red]%s[/color] " "$filesize" >> postinfo.txt
#crc32="crc "`crc32 $track`
#	printf "$crc32 "
#	printf "[color=green]%s[/color] " "$crc32" >> postinfo.txt
#md5="md5 "`openssl md5 $track | awk -F"=" '{ print $2 }' | sed 's/ //g'`
#	printf "$md5 "
#	printf "[color=blue]%s[/color] " "$md5" >> postinfo.txt
#sha1="sha1"`openssl sha1 $track | awk -F"=" '{ print $2 }'`
#	printf "%s\n" "$sha1"
#	printf "[color=red]%s[/color]\n" "$sha1" >> postinfo.txt
#done
#
#echo "[/quote]\n" >> postinfo.txt
#echo "\npostinfo.txt generated... all done!"
