#!/usr/bin/zsh

ENV=.env
GRADLE_PROPERTIES=gradle.properties
if [ ! -f $ENV ]; then
    printf "You need an .env file with your username and access token\n"
    exit 1
fi


# Following is required for revanced-integrations
export ANDROID_HOME=/opt/android-sdk
# I also had to install the following from the AUR:
# android-sdk-build-tools, android-sdk-cmdline-tools-latest,
# android-sdk-platform-tools and android-platform-33 (33 happens to be
# the version ./gradlew build was complaining about)

BUILD_DIRECTORY=build
if [ ! -d $BUILD_DIRECTORY ]; then
    mkdir $BUILD_DIRECTORY
fi

for DIR in *
do
    if [ -d $DIR ]; then
        printf "Entering %s\n" $DIR
        cd $DIR
        if [ -f gradle.properties ]; then
            CONTENTS=$(cat $GRADLE_PROPERTIES)
            if [[ $CONTENTS == *"gpr.key"* ]]; then
                printf "Personal access token is already there\n"
            else
                AUTH=$(cat ../$ENV)
                printf $AUTH >> $GRADLE_PROPERTIES
            fi
        fi

        if [ -f gradlew ]; then
            ./gradlew build
        fi

        if [[ $DIR == "revanced-cli" ]]; then
            cp build/libs/revanced-cli-*-all.jar ../$BUILD_DIRECTORY
        elif [[ $DIR == "revanced-patches" ]]; then
            cp build/libs/revanced-patches-*.jar ../$BUILD_DIRECTORY
        elif [[ $DIR == "revanced-integrations" ]]; then
            cp app/build/outputs/apk/release/revanced-integrations-*.apk ../$BUILD_DIRECTORY
        fi

        cd ..
    fi
done
