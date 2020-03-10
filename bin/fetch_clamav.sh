#!/bin/bash
#
#   Mailcleaner - SMTP Antivirus/Antispam Gateway
#   Copyright (C) 2004-2014 Olivier Diserens <olivier@diserens.ch>
#   Copyright (C) 2015-2017 Mentor Reka <reka.mentor@gmail.com>
#   Copyright (C) 2015-2017 Florian Billebault <florian.billebault@gmail.com>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#   @Author: Florian Billebault & Mentor Reka
#   @Date: 20151215
#   This script will fetch the actual ruleset
#
#   Usage:
#           fetch_clamav.sh [-r]

usage()
{
  cat << EOF
usage: $0 options

This script will fetch the latest antivirus definitions for the ClamAV daemon

OPTIONS:
  -r   randomize start of the script, for automated process
EOF
}

randomize=false

while getopts ":r" OPTION
do
  case $OPTION in
    r)
       randomize=true
       ;;
    ?)
       usage
       exit
       ;;
  esac
done


CONFFILE=/etc/mailcleaner.conf
SRCDIR=`grep 'SRCDIR' $CONFFILE | cut -d ' ' -f3`
if [ "$SRCDIR" = "" ]; then 
  SRCDIR="/opt/mailcleaner"
fi
VARDIR=`grep 'VARDIR' $CONFFILE | cut -d ' ' -f3`
if [ "$VARDIR" = "" ]; then
  VARDIR="/var/mailcleaner"
fi

. $SRCDIR/lib/lib_utils.sh
FILE_NAME=$(basename -- "$0")
FILE_NAME="${FILE_NAME%.*}"
ret=$(createLockFile "$FILE_NAME")
if [[ "$ret" -eq "1" ]]; then
        exit 0
fi

. $SRCDIR/lib/updates/download_files.sh

ret=$(downloadDatas "$VARDIR/spool/clamav/" "clamav3" $randomize "clamav" "\|main.cvd\|bytecode.cvd\|daily.cvd\|mirrors.dat" "noexit")

# Creating a test file, the content doesnt matter
testfile=/tmp/scan-test.txt
if [ ! -e ${testfile} ]; then
        echo "Test" > ${testfile}
fi

# Getting to the ClamAV databases
cd /var/mailcleaner/spool/clamav
# Foreach file
for file in $(ls | grep -v "dbs.md5"); do
#        echo "Checking ${file}"
        # test if it is malformed
        MALFORMEDFILE=`/opt/clamav/bin/clamscan -d ${file} ${testfile} 2>&1 > /dev/null |grep Malfor |grep -v ERROR | awk {'print $5'} |sed 's/:$//'`

        # If the file is malformed, remove it
        if [ ! -z "${MALFORMEDFILE}" ] ; then
                rm $file
		# rm /var/mailcleaner/tmp/fetch_files/var/mailcleaner/spool/clamav/$file
                echo "["`date "+%Y/%m/%d %H:%M:%S"`"] Malformed Database $file removed" >> /var/mailcleaner/log/mailcleaner/downloadDatas.log
                MALFORMEDFILE=''
        fi
done
cd -

## restart clamd daemon
if [[ "$ret" -eq "1" ]]; then
	kill -USR2 `cat $VARDIR/run/clamav/clamd.pid 2>/dev/null` > /dev/null 2>&1 
	log "Database reloaded"
fi

removeLockFile "$FILE_NAME"

exit 0
