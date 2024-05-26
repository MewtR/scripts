#!/usr/bin/zsh

ORG=revanced

CLI="revanced-cli"
INTEGRATIONS="revanced-integrations"
PATCHES="revanced-patches"
#PATCHER="revanced-patcher"

REPOS=($CLI $INTEGRATIONS $PATCHES) #$PATCHER)

INDEX=0
REPOS_LENGTH=${#REPOS[@]}

for REPO in $REPOS
do
    if [[ $INDEX -eq ($REPOS_LENGTH - 1) ]]; then
        FILTER+=".name == \"${REPO}\" "
    else
        FILTER+=".name == \"${REPO}\" or "
    fi
    INDEX=$(( INDEX + 1 ))
done

URLS=$(curl -s https://api.github.com/orgs/${ORG}/repos | jq -r '.[] | {name, ssh_url} | select('${FILTER}') | .ssh_url ' ) #| tr '\n' ' ')

IFS=$'\n' read -r -d '' -A lines <<< $URLS
for URL in $lines
do
    printf "Cloning %s\n\n" $URL
    git clone --depth=1 $URL
done

