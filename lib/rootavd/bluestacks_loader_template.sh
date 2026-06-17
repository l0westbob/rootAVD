# shellcheck shell=bash
# The generated BlueStacks loader is intentionally assembled as shell text.
# Keep template diagnostics local here; snapshot tests guard output drift.
# shellcheck disable=SC1078,SC1079,SC2004,SC2027,SC2034,SC2140

random() {
	VALUE=$1; TYPE=$2; PICK="$3"; PICKC="$4"
	TMPR=""
	HEX="0123456789abcdef"; HEXC=16
	CHAR="qwertyuiopasdfghjklzxcvbnm"; CHARC=26
	NUM="0123456789"; NUMC=10
	list_pick=$HEX; C=$HEXC
	[ "$TYPE" == "char" ] &&  list_pick=$CHAR && C=$CHARC
	[ "$TYPE" == "number" ] && list_pick=$NUM && C=$NUMC
	[ "$TYPE" == "custom" ] && list_pick="$PICK" && C=$PICKC
	while [ "$VALUE" -gt 0 ]; do
		random_pick=$((RANDOM % C))
		echo -n "${list_pick:$random_pick:1}"
		VALUE=$((VALUE - 1))
	done
}

random_str() {
	random_length=$(random 1 custom 56789 5)
	random "$random_length" custom "qwertyuiopasdfghjklzxcvbnm0123456789QWERTYUIOPASDFGHJKLZXCVBNM" 63 | base64 | sed "s/=//g"
}
magisk_loader() {
	magisk_overlay=$(random_str)
	magisk_postfsdata=$(random_str)
	magisk_service=$(random_str)
	magisk_daemon=$(random_str)
	magisk_boot_complete=$(random_str)
	magisk_loadpolicy=$(random_str)
	dev_random=$(random_str)
    #system-as-root, /sbin is removal
    MAGISKTMP="/dev/$dev_random"
    mount_sbin="mkdir -p \"$MAGISKTMP\"
mnt_tmpfs \"$MAGISKTMP\"
chmod 755 \"$MAGISKTMP\""
     umount_sbin="umount /sbin"


# apply multiple sepolicy at same time

LOAD_MODULES_POLICY="rm -rf \"\$MAGISKTMP/.magisk/sepolicy.rules\"
for module in \$(ls /data/adb/modules); do
              if ! [ -f \"/data/adb/modules/\$module/disable\" ] && [ -f \"/data/adb/modules/\$module/sepolicy.rule\" ]; then
                  echo \"## * module sepolicy: \$module\" >>\"\$MAGISKTMP/.magisk/sepolicy.rules\"
                  cat  \"/data/adb/modules/\$module/sepolicy.rule\" >>\"\$MAGISKTMP/.magisk/sepolicy.rules\"
                  echo \"\" >>\"\$MAGISKTMP/.magisk/sepolicy.rules\"

              fi
          done
\$MAGISKTMP/magiskpolicy --live --apply \"\$MAGISKTMP/.magisk/sepolicy.rules\""

ADDITIONAL_SCRIPT="( # addition script
rm -rf /data/adb/post-fs-data.d/fix_mirror_mount.sh
rm -rf /data/adb/service.d/fix_modules_not_show.sh


# additional script to deal with bullshit faulty design of emulator
# that close built-in root will remove magisk's /system/bin/su

echo \"
export PATH=\\\"\$MAGISKTMP:\\\$PATH\\\"
if [ -f \\\"/system/bin/magisk\\\" ]; then
    umount -l /system/bin/su
    rm -rf /system/bin/su
    ln -fs ./magisk /system/bin/su
    mount -o ro,remount /system/bin
    umount -l /system/bin/magisk
    mount --bind \\\"\$MAGISKTMP/magisk\\\" /system/bin/magisk
fi\" >\$MAGISKTMP/emu/magisksu_survival.sh

# additional script to deal with bullshit faulty design of Bluestacks
# that /system is a bind mountpoint

echo \"
SCRIPT=\\\"\\\$0\\\"
MAGISKTMP=\\\$(magisk --path) || MAGISKTMP=/sbin
( #fix bluestacks
MIRROR_SYSTEM=\\\"\\\$MAGISKTMP/.magisk/mirror/system\\\"
test ! -d \\\"\\\$MIRROR_SYSTEM/android/system\\\" && exit
test \\\"\\\$(cd /system; ls)\\\" == \\\"\\\$(cd \\\"\\\$MIRROR_SYSTEM\\\"; ls)\\\" && exit
mount --bind \\\"\\\$MIRROR_SYSTEM/android/system\\\" \\\"\\\$MIRROR_SYSTEM\\\" )
( #fix mount data mirror
function cmdline() {
	awk -F\\\"\\\${1}=\\\" '{print \\\$2}' < /proc/cmdline | cut -d' ' -f1 2> /dev/null
}

# additional script to deal with bullshit faulty design of Android-x86
# that data is a bind mount from $SRC/data on ext4 partition


SRC=\\\"\\\$(cmdline SRC)\\\"
test -z \\\"\\\$SRC\\\" && exit
LIST_TEST=\\\"
/data
/data/adb
/data/adb/magisk
/data/adb/modules
\\\"
count=0
for folder in \\\$LIST_TEST; do
test \\\"\\\$(ls -A \\\$MAGISKTMP/.magisk/mirror/\\\$folder 2>/dev/null)\\\" == \\\"\\\$(ls -A \\\$folder 2>/dev/null)\\\" && count=\\\$((\\\$count + 1))
done
test \\\"\\\$count\\\" == 4 && exit
count=0
for folder in \\\$LIST_TEST; do
test \\\"\\\$(ls -A \\\$MAGISKTMP/.magisk/mirror/data/\\\$SRC/\\\$folder 2>/dev/null)\\\" == \\\"\\\$(ls -A \\\$folder 2>/dev/null)\\\" && count=\\\$((\\\$count + 1))
done
if [ \\\"\\\$count\\\" == 4 ]; then
mount --bind \\\"\\\$MAGISKTMP/.magisk/mirror/data/\\\$SRC/data\\\" \\\"\\\$MAGISKTMP/.magisk/mirror/data\\\"
fi )
rm -rf \\\"\\\$SCRIPT\\\"
\" >/data/adb/post-fs-data.d/fix_mirror_mount.sh
echo \"
SCRIPT=\\\"\\\$0\\\"
MAGISKTMP=\\\$(magisk --path) || MAGISKTMP=/sbin
CHECK=\\\"/data/adb/modules/.mk_\\\$RANDOM\\\$RANDOM\\\"
touch \\\"\\\$CHECK\\\"
test \\\"\\\$(ls -A \\\$MAGISKTMP/.magisk/modules 2>/dev/null)\\\" != \\\"\\\$(ls -A /data/adb/modules 2>/dev/null)\\\" && mount --bind \\\$MAGISKTMP/.magisk/mirror/data/adb/modules \\\$MAGISKTMP/.magisk/modules
rm -rf \\\"\\\$CHECK\\\"
rm -rf \\\"\\\$SCRIPT\\\"\" >/data/adb/service.d/fix_modules_not_show.sh
chmod 755 /data/adb/service.d/fix_modules_not_show.sh
chmod 755 /data/adb/post-fs-data.d/fix_mirror_mount.sh; )"


EXPORT_PATH="export PATH /sbin:/system/bin:/system/xbin:/vendor/bin:/apex/com.android.runtime/bin:/apex/com.android.art/bin"


magiskloader="

         on early-init
             $EXPORT_PATH


          on post-fs-data
$RM_RUSTY_MAGISK
              start logd
              start adbd
              rm /dev/.magisk_unblock
              exec u:r:su:s0 root root -- $MAGISKBASE/busybox sh -o standalone $MAGISKBASE/overlay.sh
              exec u:r:magisk:s0 root root -- $MAGISKTMP/magisk --daemon
              start $magisk_postfsdata
              # wait all magisk post-fs-data jobs are completed or 40s  has passed
              wait /dev/.magisk_unblock 40
              rm /dev/.magisk_unblock

          service $magisk_postfsdata $MAGISKTMP/magisk --post-fs-data
              user root
              seclabel u:r:magisk:s0
              oneshot

          service $magisk_service $MAGISKTMP/magisk --service
              class late_start
              user root
              seclabel u:r:magisk:s0
              oneshot

          on property:sys.boot_completed=1
              $umount_sbin
              start $magisk_boot_complete
# remove magisk service traces from some detection
# although detect modified init.rc is not always correct
              exec u:r:magisk:s0 root root -- $MAGISKTMP/magisk resetprop --delete init.svc.$magisk_postfsdata
              exec u:r:magisk:s0 root root -- $MAGISKTMP/magisk resetprop --delete init.svc.$magisk_service
              exec u:r:magisk:s0 root root -- $MAGISKTMP/magisk resetprop --delete init.svc.$magisk_boot_complete
              exec u:r:magisk:s0 root root -- $MAGISKTMP/magisk resetprop --delete init.svc_debug_pid.$magisk_postfsdata
              exec u:r:magisk:s0 root root -- $MAGISKTMP/magisk resetprop --delete init.svc_debug_pid.$magisk_service
              exec u:r:magisk:s0 root root -- $MAGISKTMP/magisk resetprop --delete init.svc_debug_pid.$magisk_boot_complete
              exec u:r:magisk:s0 root root -- $MAGISKTMP/busybox sh -o standalone $MAGISKTMP/emu/magisksu_survival.sh
          service $magisk_boot_complete $MAGISKTMP/magisk --boot-complete
              user root
              seclabel u:r:magisk:s0
              oneshot"


overlay_loader="#!$MAGISKBASE/busybox sh

export PATH=/sbin:/system/bin:/system/xbin


mnt_tmpfs(){ (
# MOUNT TMPFS ON A DIRECTORY
MOUNTPOINT=\"\$1\"
mkdir -p \"\$MOUNTPOINT\"
mount -t tmpfs -o \"mode=0755\" tmpfs \"\$MOUNTPOINT\" 2>/dev/null
) }



mnt_bind(){ (
# SHORTCUT BY BIND MOUNT
FROM=\"\$1\"; TO=\"\$2\"
if [ -L \"\$FROM\" ]; then
SOFTLN=\"\$(readlink \"\$FROM\")\"
ln -s \"\$SOFTLN\" \"\$TO\"
elif [ -d \"\$FROM\" ]; then
mkdir -p \"\$TO\" 2>/dev/null
mount --bind \"\$FROM\" \"\$TO\"
else
echo -n 2>/dev/null >\"\$TO\"
mount --bind \"\$FROM\" \"\$TO\"
fi
) }

clone(){ (
FROM=\"\$1\"; TO=\"\$2\"; IFS=\$\"
\"
[ -d \"\$TO\" ] || exit 1;
( cd \"\$FROM\" && find * -prune ) | while read obj; do
( if [ -d \"\$FROM/\$obj\" ]; then
mnt_tmpfs \"\$TO/\$obj\"
else
mnt_bind \"\$FROM/\$obj\" \"\$TO/\$obj\" 2>/dev/null
fi ) &
sleep 0.05
done
) }

overlay(){ (
# RE-OVERLAY A DIRECTORY
FOLDER=\"\$1\";
TMPFOLDER=\"/dev/vm-overlay\"
#_____
PAYDIR=\"\${TMPFOLDER}_\${RANDOM}_\$(date | base64)\"
mkdir -p \"\$PAYDIR\"
mnt_tmpfs \"\$PAYDIR\"
#_________
clone \"\$FOLDER\" \"\$PAYDIR\"
mount --move \"\$PAYDIR\" \"\$FOLDER\"
rm -rf \"\$PAYDIR\"
#______________
) }

exit_magisk(){
umount -l $MAGISKTMP
echo -n >/dev/.magisk_unblock
}


API=\$(getprop ro.build.version.sdk)
  ABI=\$(getprop ro.product.cpu.abi)
  if [ \"\$ABI\" = \"x86\" ]; then
    ARCH=x86
    ABI32=x86
    IS64BIT=false
  elif [ \"\$ABI\" = \"arm64-v8a\" ]; then
    ARCH=arm64
    ABI32=armeabi-v7a
    IS64BIT=true
  elif [ \"\$ABI\" = \"x86_64\" ]; then
    ARCH=x64
    ABI32=x86
    IS64BIT=true
  else
    ARCH=arm
    ABI=armeabi-v7a
    ABI32=armeabi-v7a
    IS64BIT=false
  fi

magisk_name=\"magisk32\"
[ \"\$IS64BIT\" == true ] && magisk_name=\"magisk64\"

# umount previous /sbin tmpfs overlay

count=0
( magisk --stop ) &

# force umount /sbin tmpfs

until ! mount | grep -q \" /sbin \"; do
[ \"\$count\" -gt \"10\" ] && break
umount -l /sbin 2>/dev/null
sleep 0.1
count=\$((\$count + 1))
test ! -d /sbin && break
done

# mount magisk tmpfs path

$mount_sbin

MAGISKTMP=$MAGISKTMP
chmod 755 \"\$MAGISKTMP\"
set -x
mkdir -p \$MAGISKTMP/.magisk
mkdir -p \$MAGISKTMP/emu
exec 2>>\$MAGISKTMP/emu/record_logs.txt
exec >>\$MAGISKTMP/emu/record_logs.txt

cd $MAGISKBASE

test ! -f \"./\$magisk_name\" && { echo -n >/dev/.overlay_unblock; exit_magisk; exit 0; }


MAGISKBIN=/data/adb/magisk
mkdir /data/unencrypted
for mdir in modules post-fs-data.d service.d magisk; do
test ! -d /data/adb/\$mdir && rm -rf /data/adb/\$mdir
mkdir /data/adb/\$mdir 2>/dev/null
done
for file in magisk32 magisk64 magiskinit; do
  cp -af ./\$file \$MAGISKTMP/\$file 2>/dev/null
  chmod 755 \$MAGISKTMP/\$file
  cp -af ./\$file \$MAGISKBIN/\$file 2>/dev/null
  chmod 755 \$MAGISKBIN/\$file
done
cp -af ./magiskboot \$MAGISKBIN/magiskboot
cp -af ./busybox \$MAGISKBIN/busybox
cp -af ./busybox \$MAGISKTMP
chmod 755 \$MAGISKTMP/busybox
\$MAGISKTMP/busybox --install -s \$MAGISKTMP
cp -af ./assets/* \$MAGISKBIN

# create symlink / applet

ln -s ./\$magisk_name \$MAGISKTMP/magisk 2>/dev/null
ln -s ./magisk \$MAGISKTMP/su 2>/dev/null
ln -s ./magisk \$MAGISKTMP/resetprop 2>/dev/null
ln -s ./magisk \$MAGISKTMP/magiskhide 2>/dev/null
ln -s ./magiskinit \$MAGISKTMP/magiskpolicy 2>/dev/null

mkdir -p \$MAGISKTMP/.magisk/mirror
mkdir \$MAGISKTMP/.magisk/block

touch \$MAGISKTMP/.magisk/config

cd \$MAGISKTMP
# SELinux stuffs
ln -sf ./magiskinit magiskpolicy
if [ -f /vendor/etc/selinux/precompiled_sepolicy ]; then
  ./magiskpolicy --load /vendor/etc/selinux/precompiled_sepolicy --live --magisk 2>&1
elif [ -f /sepolicy ]; then
  ./magiskpolicy --load /sepolicy --live --magisk 2>&1
else
  ./magiskpolicy --live --magisk 2>&1
fi

#remount system read-only to fix Magisk fail to mount mirror

${remove_backup:-}
mount -o ro,remount /
mount -o ro,remount /system
mount -o ro,remount /vendor
mount -o ro,remount /product
mount -o ro,remount /system_ext

restorecon -R /data/adb/magisk

$ADDITIONAL_SCRIPT
$LOAD_MODULES_POLICY

[ ! -f \"\$MAGISKTMP/magisk\" ] && exit_magisk
# test ! \"\$(pidof magiskd)\" && exit_magisk

[ -d "/oem/.overlay" ] && umount -l /oem
umount -l /system/etc/init
umount -l /init.rc
umount -l /system/etc/init/hw/init.rc
"
}
