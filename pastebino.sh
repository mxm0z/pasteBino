#!/bin/bash

pastebeenResultsURL=$1
email=$2
pass=$3
defaultPath=$(pwd)
path=${4:-$defaultPath}

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <Pastebeen results URL> <email> <password> <destination folder [optional]>"
    exit
fi

urlencode() {
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%s' "$c" | xxd -p -c1 |
                   while read c; do printf '%%%s' "$c"; done ;;
        esac
    done
}

email=$(urlencode $email)
pass=$(urlencode $pass)

echo "[+] Checking directory structure"

[ ! -d $path/pasteBino ] && mkdir $path/{pasteBino,pasteBino/{pastebin,gist,pastebeen,pastebeen/{pastebin,gist}}}

path="$path/pasteBino"

echo "[+] Saving output to $path"

results=$(curl -s $pastebeenResultsURL | egrep -i "\"\/c\b.*\"" -B10 | egrep -io "(pastebin|gist|\b[A-Za-z0-9]{32}\b)" | paste -d: - -)
eval set -- $results

resultNumber=$(echo "$@" | wc -w)
pastebinResultNumber=$(echo "$@" | egrep -oi pastebin | wc -l)
gistResultNumber=$(echo "$@" | egrep -oi gist | wc -l)

# pastebinResults=$(echo "$@" | egrep -oi "pastebin:<REGEX>" | wc -l)
# gistResults=$(echo "$@" | egrep -oi "gist:<REGEX>" | wc -l)
# fileName=`echo $sourceURL | egrep -o "[^/]+(?=/$|$)"`

echo "[+] Started parsing Pastebeen task results.."
echo "[+] Analyzing $resultNumber results"
echo "[+] Pastebin: $pastebinResultNumber | Gist: $gistResultNumber"
echo ""

echo "[+] Logging in on Pastebeen.."

userAgent==$(shuf -n 1 useragents.txt)

cookie=$(curl -s -o /dev/null -D - 'https://pastebeen.com/u/login' -H "User-Agent: $userAgent" --compressed -H 'Content-Type: application/json' -H 'X-Requested-With: XMLHttpRequest' -d "{"email":"$email","password":"$pass"}" | egrep -o "\b\w*\.\w{220}\.\w*\b")

echo "[+] Logged in successfully.."
echo ""

for result in "$@"
    do
        resultSource=$(echo $result | awk -F: '{print $1}')
        resultID=$(echo $result | awk -F: '{print $2}')

        pastebeenResult="https://pastebeen.com/c/$resultID"

        # badges=$(curl -s $pastebeenResult | grep badge | egrep -o "\b((Email|(User|Email) & Pass|Hash|(Google API|CD) Key): [0-9]{1,5}|Spotify|Steam|Uplay|Origin|Spotify|Deezer|Epic|Github|Gitlab|Snapchat|OCS|Netflix|Twitter|Facebook|Minecraft|Fortnite|M3U|Gmail|iCloud|RMCSport|Hotstar|Disney\+|Ebay|Nord VPN|Dropbox|Amazon|Zoom\.us|Paypal|Dominos|JSON|SQL|Base64|XML|HTML|PHP|Javascript|C|C\+\+|Python|Subtitles)\b")

        echo "[+] Result ID: $resultID"
        echo "[+] Result URL: $pastebeenResult"
        # echo "[+] Tags: $badges"

        pastebeenRawResult="$pastebeenResult/r"

        echo "$pastebeenResult:$pastebeenRawResult" >> $path/allPastebeenURLs.txt

        echo "[+] Checking result source"

        if [[ $resultSource == "Pastebin" ]]; then
            echo "[+] Source: Pastebin"

            echo "[+] Extracting Pastebin URL from Pastebeen result"
            sourceURL=$(curl -s $pastebeenResult -H "User-Agent: $userAgent" | egrep -io "https:\/\/pastebin\.com\/.{8}")
            echo "[+] Pastebin URL: $sourceURL"
            echo $sourceURL >> $path/pastebin/allPastebinURLs.txt
            
            sourceRawURL=$(echo $sourceURL | sed 's/pastebin\.com/pastebin\.com\/raw/g')
            
            echo "[+] Checking result availability on Pastebin"
            httpCode=$(curl -ILs $sourceURL | grep "^HTTP\/")
            
            if [[ $httpCode =~ "200" ]]; then
                echo $sourceURL >> $path/pastebin/alivePastebinURLs.txt

                echo "[+] $sourceURL is live on Pastebin! Downloading.."
                wget -q --show-progress $sourceRawURL -P $path/pastebin
            elif [[ $httpCode =~ "404" ]]; then
                echo "[+] $resultID is only available on Pastebeen"

                echo $sourceURL >> $path/pastebin/deadPastebinURLs.txt
                echo $pastebeenResult >> $path/pastebeen/pastebinOnlyOnPastebeen.txt

                echo "[+] Trying to recover Pastebin raw data from Pastebeen"
                curl -s $pastebeenRawResult -H "User-Agent: $userAgent" -H "Cookie: access_token_cookie=$cookie" --progress-bar > $path/pastebeen/pastebin/$resultID.txt

                if [ -f $path/pastebeen/pastebin/$resultID.txt ]; then
                    echo "[+] Recovered to ../pastebeen/pastebin/$resultID.txt"
                else
                    echo "[!] Something went wrong. Exiting.."
                    echo "[!] Saving result with error to $path/errors.txt"
                    echo "$pastebeenResult | $sourceURL" >> $path/resultErrors.txt
                    exit
                fi
                # [ ! -f $path/pastebeen/pastebin/$resultID.txt ] && { echo "[!] Something wrong. Stopping.."; exit }
                # [ -f $path/pastebeen/pastebin/$resultID.txt ] && echo "Recovered to ../pastebeen/pastebin/$resultID.txt" || { echo "[!] Something wrong. Exiting.."; exit }
            else
                echo "[!] HTTP code not handled: $httpCode"
                echo "echo $pastebeenResult | $sourceURL | $httpCode" >> $path/httpErrors.txt
            fi
        elif [[ $resultSource == "Gist" ]]; then
            echo "[+] Source: Gist"

            echo "[+] Extracting Gist URL from Pastebeen result"
            sourceURL=$(curl -s $pastebeenResult | ack -oi "(http|https)://([\w_-]+(?:(?:\.[\w_-]+)+))([\w.,@?^=%&:/~+#-]*[\w@?^=%&/~+#-])?" | egrep -i githubusercontent)
            echo "[+] Gist URL: $sourceURL"
            echo $sourceURL >> $path/gist/allGistURLs.txt

            echo "[+] Checking result availability on Gist"
            httpCode=$(curl -ILs $sourceURL | grep "^HTTP\/")
            
            if [[ $httpCode =~ "200" ]]; then
                echo $sourceURL >> $path/gist/aliveGistURLs.txt

                echo "[+] $sourceURL is live on Gist! Downloading.."
                fileID=$(echo $sourceURL | egrep -oi "\w{40}")
                username=$(echo $sourceURL | grep -o "githubusercontent\.com\/\w*" | sed 's/githubusercontent\.com\///g')
                wget -q --show-progress $sourceURL -P $path/gist/$username/$fileID
            elif [[ $httpCode =~ "404" ]]; then
                echo "[+] $resultID is only available on Pastebeen"

                echo $sourceURL >> $path/gist/deadGistURLs.txt
                echo $pastebeenResult >> $path/pastebeen/gistOnlyOnPastebeen.txt

                echo "[+] Trying to recover Gist raw data from Pastebeen"
                curl -s $pastebeenRawResult -H "User-Agent: $userAgent" -H "Cookie: access_token_cookie=$cookie" --progress-bar > $path/pastebeen/gist/$resultID.txt

                if [ -f $path/pastebeen/gist/$resultID.txt ]; then
                    echo "[+] Recovered to ../pastebeen/gist/$resultID.txt"
                else
                    echo "[!] Something went wrong. Exiting.."
                    echo "[!] Saving result with error to $path/errors.txt"
                    echo "$pastebeenResult | $sourceURL" >> $path/resultErrors.txt
                    exit
                fi
                # [ ! -f $path/pastebeen/gist/$resultID.txt ] && { echo "[!] Something wrong. Stopping.."; exit }
                # [ -f $path/pastebeen/gist/$resultID.txt ] && echo "Recovered to ../pastebeen/gist/$resultID.txt" || { echo "[!] Something wrong. Stopping.."; exit }
                # [ ! -f /etc/resolv.conf ] && echo "$FILE exist." || echo "$FILE does not exist."
            else
                echo "[!] HTTP code not handled: $httpCode"
                echo "echo $pastebeenResult | $sourceURL | $httpCode" >> $path/httpErrors.txt
            fi
        fi
        echo ""
    done
