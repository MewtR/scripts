#!/usr/bin/sh

if [ $# -ne 1 ]; then
    printf "Pass in the path to the certificate\n" >&2
    exit 1
fi

PATHTOFILE=$1
FILE=$(basename $PATHTOFILE)
adb root

# The following doesn't work on Android 14
#adb remount
#adb push $PATHTOFILE /system/etc/security/cacerts
#adb shell chmod 664 /system/etc/security/cacerts/$FILE
#adb reboot

DESTINATION_DIRECTORY=/data/local/tmp
INSTALL_SCRIPT=install_system_cert.sh
INSTALL_SCRIPT_PATH=$DESTINATION_DIRECTORY/install_system_cert.sh

if [ -f $INSTALL_SCRIPT ]; then
    rm $INSTALL_SCRIPT
fi

touch $INSTALL_SCRIPT
adb push $PATHTOFILE $DESTINATION_DIRECTORY

printf "#!/bin/sh\n" >> $INSTALL_SCRIPT
printf "\n" >> $INSTALL_SCRIPT

# Procedure to install on Android 14 hopefully
# taken from here: https://httptoolkit.com/blog/android-14-install-system-ca-certificate/

## Not sure why these first three commands are necessary
## Can't we just use /system/etc/security/cacerts directly?
## Why do we need to mount a tmpfs on /system/etc/security/cacerts?
## So it turns out, we're just doing this to be able to write our certificate
## to the directory. Presumably, 'adb remount' should work as well

printf "# Create a separate temp directory, to hold the current certificates\n" >> $INSTALL_SCRIPT
printf "# Otherwise, when we add the mount we can't read the current certs anymore.\n" >> $INSTALL_SCRIPT
printf "mkdir -p -m 700 /data/local/tmp/tmp-ca-copy\n" >> $INSTALL_SCRIPT
printf "\n\n" >> $INSTALL_SCRIPT

printf "# Copy out the existing certificates\n" >> $INSTALL_SCRIPT
printf "cp /apex/com.android.conscrypt/cacerts/* /data/local/tmp/tmp-ca-copy/\n" >> $INSTALL_SCRIPT
printf "\n\n" >> $INSTALL_SCRIPT

printf "# Create the in-memory mount on top of the system certs folder\n" >> $INSTALL_SCRIPT
printf "mount -t tmpfs tmpfs /system/etc/security/cacerts\n" >> $INSTALL_SCRIPT

printf "# Copy the existing certs back into the tmpfs, so we keep trusting them\n" >> $INSTALL_SCRIPT
printf "mv /data/local/tmp/tmp-ca-copy/* /system/etc/security/cacerts/\n" >> $INSTALL_SCRIPT

printf "# Copy our new cert in, so we trust that too\n" >> $INSTALL_SCRIPT
printf "mv $DESTINATION_DIRECTORY/$FILE /system/etc/security/cacerts/\n" >> $INSTALL_SCRIPT
printf "\n\n" >> $INSTALL_SCRIPT

printf "# Update the perms & selinux context labels\n" >> $INSTALL_SCRIPT
## The following three commands won't work even if you're root because /system is mounted as read only by default
## So this is probably what the tmpfs on top of /system/etc/security/cacerts/ was for. To have something writable
## as tim wrote in his blog post. This is why the 'adb remount' command is useful for the previous way of installing the certs
printf "chown root:root /system/etc/security/cacerts/*\n" >> $INSTALL_SCRIPT
printf "chmod 644 /system/etc/security/cacerts/*\n" >> $INSTALL_SCRIPT
printf "chcon u:object_r:system_file:s0 /system/etc/security/cacerts/*\n" >> $INSTALL_SCRIPT
printf "\n\n" >> $INSTALL_SCRIPT

printf "# Deal with the APEX overrides, which need injecting into each namespace:\n" >> $INSTALL_SCRIPT

printf "# First we get the Zygote process(es), which launch each app\n" >> $INSTALL_SCRIPT
printf "ZYGOTE_PID=\$(pidof zygote || true)\n" >> $INSTALL_SCRIPT
printf "ZYGOTE64_PID=\$(pidof zygote64 || true)\n" >> $INSTALL_SCRIPT
printf "# N.b. some devices appear to have both!\n" >> $INSTALL_SCRIPT
printf "\n\n" >> $INSTALL_SCRIPT

printf "# Apps inherit the Zygote's mounts at startup, so we inject here to ensure\n" >> $INSTALL_SCRIPT
printf "# all newly started apps will see these certs straight away:\n" >> $INSTALL_SCRIPT
printf "for Z_PID in \"\$ZYGOTE_PID\" \"\$ZYGOTE64_PID\"; do\n" >> $INSTALL_SCRIPT
printf "    if [ -n \"\$Z_PID\" ]; then\n" >> $INSTALL_SCRIPT
printf "        printf \"nsentering for the following pid, these are zygotes: \${Z_PID}\\\n\" \n" >> $INSTALL_SCRIPT

# --bind basically just makes the contents of /system/etc/security/cacerts appear in /apex/com.android.conscrypt/cacerts
printf "        nsenter -t \${Z_PID} -m -- /bin/mount --bind /system/etc/security/cacerts /apex/com.android.conscrypt/cacerts\n" >> $INSTALL_SCRIPT

# Following also works but I prefer the previous version
#printf "        nsenter --mount=/proc/\${Z_PID}/ns/mnt -- /bin/mount --bind /system/etc/security/cacerts /apex/com.android.conscrypt/cacerts\n" >> $INSTALL_SCRIPT

printf "    fi\n" >> $INSTALL_SCRIPT
printf "done\n" >> $INSTALL_SCRIPT
printf "\n\n" >> $INSTALL_SCRIPT

printf "# Then we inject the mount into all already running apps, so they\n" >> $INSTALL_SCRIPT
printf "# too see these CA certs immediately:\n" >> $INSTALL_SCRIPT

printf "# Get the PID of every process whose parent is one of the Zygotes:\n" >> $INSTALL_SCRIPT
printf "APP_PIDS=\$(printf \"\$ZYGOTE_PID \$ZYGOTE64_PID\" | xargs -n1 ps -o 'PID' -P | grep -v PID)\n" >> $INSTALL_SCRIPT
printf "\n\n" >> $INSTALL_SCRIPT

printf "# Inject into the mount namespace of each of those apps:\n" >> $INSTALL_SCRIPT
printf "for PID in \$APP_PIDS; do\n" >> $INSTALL_SCRIPT
printf "    echo \"Now we\'re doing a non zygote: \${PID}\"  \n" >> $INSTALL_SCRIPT
printf "    nsenter -t \$PID -m -- /bin/mount --bind /system/etc/security/cacerts /apex/com.android.conscrypt/cacerts &\n" >> $INSTALL_SCRIPT
printf "done\n" >> $INSTALL_SCRIPT
printf "wait # Launched in parallel - wait for completion here\n" >> $INSTALL_SCRIPT

# Auto unmount to avoid no more space left on device error. To be commented out after testing
# Actually it still works even if you leave this in
#printf "umount /system/etc/security/cacerts/\n" >> $INSTALL_SCRIPT
printf "\n\n" >> $INSTALL_SCRIPT

printf "printf \"System certificate injected\"\n" >> $INSTALL_SCRIPT

adb push $INSTALL_SCRIPT $INSTALL_SCRIPT_PATH
adb shell exec /system/bin/sh $INSTALL_SCRIPT_PATH

# Clean up
rm $INSTALL_SCRIPT
adb shell rm $INSTALL_SCRIPT_PATH
adb shell rm $DESTINATION_DIRECTORY/$FILE

printf "Will it wait?\n"
