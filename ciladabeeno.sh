#!/bin/bash

pastebeenResultsURL=$1
path=$2
cookie=$3

if [[ $# -lt 3 ]]; then
    echo "[!] Mandatory arguments not passed. Exiting.."
    echo "Usage: $0 <Pastebeen URL> <Output path> <Cookie>"
    exit
fi

results=$(curl -s $pastebeenResultsURL | egrep -i "\"\/c\b.*\"" -B10 | egrep -io "(pastebin|gist|\b[A-Za-z0-9]{32}\b)" | paste -d: - -)
eval set -- $results

echo "[+] Started parsing.."
echo "[+] Saving output to $path"
echo ""

for result in "$@"
    do
        resultSource=$(echo $result | awk -F: '{print $1}')
        resultID=$(echo $result | awk -F: '{print $2}')

        pastebeenResult="https://pastebeen.com/c/$resultID"
        echo "[+] Pastebeen result: $resultID"

        pastebeenResultRaw="$pastebeenResult/r"

        echo "[+] Checking result source"

        if [[ $resultSource == "Pastebin" ]]; then
            echo "[+] Extracting Pastebin URL from Pastebeen result"
            sourceURL=$(curl -s $pastebeenResult | egrep -io "https:\/\/pastebin\.com\/.{8}")
            echo "[+] Pastebin URL: $sourceURL"
            
            sourceRawURL=`echo $sourceURL | sed 's/https:\/\/pastebin\.com\//https:\/\/pastebin\.com\/raw\//g'`
            
            echo "[+] Checking result availability on its source"
            httpCode=`curl -ILs $sourceURL | grep "^HTTP\/"`
            
            if [[ $httpCode =~ "200" ]]; then
                echo "[+] $sourceURL is live! Downloading.."
                pasteID=`echo $sourceURL | sed 's/pastebin\.com\///g'`
                wget -q --show-progress $sourceRawURL -P $path/pastebin/$pasteID.txt
            elif [[ $httpCode =~ "404" ]]; then
                echo "[+] $resultID is only available on Pastebeen. Dumping to onlyOnPastebeen.txt file.."
                echo $pastebeenResult >> $path/onlyOnPastebeen.txt

                echo "[+] Trying to recover raw data from Pastebeen"
                curl -s -XGET $pastebeenResultRaw -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:75.0) Gecko/20100101 Firefox/75.0" -H "Cookie: access_token_cookie=$cookie" > $path/$resultID.txt
            else
                echo "[!] HTTP code not handled. Moving to the next result.."
            fi
        elif [[ $resultSource == "Gist" ]]; then
            echo "[+] Extracting Gist URL from Pastebeen result"
            sourceURL=$(curl -s $pastebeenResult | ack -io "(http|https)://([\w_-]+(?:(?:\.[\w_-]+)+))([\w.,@?^=%&:/~+#-]*[\w@?^=%&/~+#-])?" | grep -i githubusercontent)

            echo "[+] Checking result availability on its source"
            httpCode=`curl -ILs $sourceURL | grep "^HTTP\/"`
            
            if [[ $httpCode =~ "200" ]]; then
                echo "[+] $sourceURL is live! Downloading.."
                fileName=`echo $sourceURL | egrep -o "[^/]+(?=/$|$)"`
                wget -q --show-progress $sourceURL -P $path/gist/$fileName
            elif [[ $httpCode =~ "404" ]]; then
                echo "[+] $resultID is only available on Pastebeen. Dumping to onlyOnPastebeen.txt file.."
                echo $pastebeenResult >> $path/onlyOnPastebeen.txt

                echo "[+] Trying to recover raw data from Pastebeen"
                curl -s -XGET $pastebeenResultRaw -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:75.0) Gecko/20100101 Firefox/75.0" -H "Cookie: access_token_cookie=$cookie" > $path/$resultID.txt
            else
                echo "[!] HTTP code not handled. Moving to the next result.."
            fi
        fi
        echo ""
    done