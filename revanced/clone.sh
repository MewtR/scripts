#!/usr/bin/sh

ORG=revanced

CLI="revanced-cli"
INTEGRATIONS="revanced-integrations"
PATCHES="revanced-patches"
#PATCHER="revanced-patcher"

REPOS="$CLI $INTEGRATIONS $PATCHES" #$PATCHER"

printf "%s\n" $REPOS
INDEX=0
REPOS_LENGTH=$(wc -w <<< $REPOS)

printf "%s\n" "$REPOS_LENGTH"
for REPO in $REPOS
do
    if [ $INDEX -eq $((REPOS_LENGTH - 1)) ]; then
        FILTER+=".name == \"$REPO\" "
    else
        FILTER+=".name == \"$REPO\" or "
    fi
    INDEX=$(( INDEX + 1 ))
done

printf "%s\n" "$FILTER"

URLS=$(curl -s https://api.github.com/orgs/$ORG/repos | jq -r ".[] | {name, ssh_url} | select($FILTER) | .ssh_url " )

printf "%s\n" "$URLS"

for URL in $URLS
do
    printf "Cloning %s\n\n" $URL
    git clone --depth=1 $URL
done
