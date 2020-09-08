#!/bin/bash

startDate=$1 # 01-01-2018
endDate=$2 # 17-06-2020
regex=$3 # \b(fdkos|ofsdkfosk)\b ----URL encoding----> %5Cb(fdkos%7Cofsdkfosk)%5Cb
email=$4
pass=$5

if [[ $# -lt 5 ]]; then
    echo "Usage: $0 <start date> <end date> <regex> <email> <password>"
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

regex=$(urlencode $regex)
email=$(urlencode $email)
pass=$(urlencode $pass)

scheduleURL="https://pastebeen.com/search/manual?s=$regex&f=$startDate&t=$endDate&n=true&r=true"

cookie=$(curl -s -o /dev/null -D - 'https://pastebeen.com/u/login' -H "User-Agent: $userAgent" --compressed -H 'Content-Type: application/json' -H 'X-Requested-With: XMLHttpRequest' -d "{"email":"$email","password":"$pass"}" | egrep -o "\b\w*\.\w{220}\.\w*\b")

# Schedule task
# https://pastebeen.com/search/manual?s=%5Cb(fdkos%7Cofsdkfosk)%5Cb&f=01-01-2018&t=17-06-2020&n=true&r=true

curl $scheduleURL -H 'x-requested-with: XMLHttpRequest' -H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.97 Safari/537.36' -H 'referer: https://pastebeen.com/simple_search' -H "cookie: access_token_cookie=$cookie" --compressed

echo "[+] Task scheduled. Ight imma head out.."  