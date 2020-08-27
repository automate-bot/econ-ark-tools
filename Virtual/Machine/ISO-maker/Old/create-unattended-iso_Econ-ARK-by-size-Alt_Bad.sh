

echo 'hi'
exit

if [ "$#" -ne 1 ]; then
    echo "Wrong number of arguments:"
    echo "usage: ${0##*/} MIN|MAX"
    exit 1
else
    if ( [ ! "$1" == "MIN" ] && [ ! "$1" == "MAX" ] ); then
	echo "usage: ${0##*/} MIN|MAX"
	exit 2
    fi
fi

size="$1"

pathToScript=$(dirname `realpath "$0"`)
# pathToScript=/home/econ-ark/GitHub/econ-ark/econ-ark-tools/Virtual/Machine/ISO-maker/
online=https://raw.githubusercontent.com/econ-ark/econ-ark-tools/master/Virtual/Machine/ISO-maker
startFile="start.sh"
finishFile="finish.sh"
seed_file="econ-ark.seed"
ks_file=ks.cfg
rclocal_file=rc.local
late_command_file=late_command.sh

# file names & paths
iso_from="/media/sf_VirtualBox"       # where to find the original ISO
iso_done="/media/sf_VirtualBox/ISO-made/econ-ark-tools"       # where to store the final iso file - shared with host machine
[[ ! -d "$iso_done" ]] && mkdir -p "$iso_done"
iso_make="/usr/local/share/iso_make"  # source folder for ISO file
# create working folders
echo " remastering your iso file"

mkdir -p "$iso_make"
mkdir -p "$iso_make/iso_org"
mkdir -p "$iso_make/iso_new"
mkdir -p "$iso_done/$size"
rm -f "$iso_make/$ks_file" # Make sure new version is downloaded
rm -f "$iso_make/$seed_file" # Make sure new version is downloaded
rm -f "$iso_make/$startFile" # Make sure new version is downloaded
rm -f "$iso_make/$rclocal_file" # Make sure new version is downloaded

datestr=`date +"%Y%m%d-%H%M%S"`
hostname="built-$datestr"
currentuser="$( whoami)"

# define spinner function for slow tasks
# courtesy of http://fitnr.com/showing-a-bash-spinner.html
spinner()
{
    local pid=$1
    local delay=0.75
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# define download function
# courtesy of http://fitnr.com/showing-file-download-progress-using-wget.html
download()
{
    local url=$1
    echo -n "    "
    wget --progress=dot $url 2>&1 | grep --line-buffered "%" | \
        sed -u -e "s,\.,,g" | awk '{printf("\b\b\b\b%4s", $2)}'
    echo -ne "\b\b\b\b"
    echo " DONE"
}

# define function to check if program is installed
# courtesy of https://gist.github.com/JamieMason/4761049
function program_is_installed {
    # set to 1 initially
    local return_=1
    # set to 0 if not found
    type $1 >/dev/null 2>&1 || { local return_=0; }
    # return value
    echo $return_
}

# print a pretty header
echo
echo " +---------------------------------------------------+"
echo " |            UNATTENDED UBUNTU ISO MAKER            |"
echo " +---------------------------------------------------+"
echo

# ask if script runs without sudo or root priveleges
if [ $currentuser != "root" ]; then
    echo " you need sudo privileges to run this script, or run it as root"
    exit 1
fi

#check that we are in ubuntu 16.04+

case "$(lsb_release -rs)" in
    16*|18*) ub1604="yes" ;;
    *) ub1604="" ;;
esac

#get the latest versions of Ubuntu LTS
cd $iso_from

iso_makehtml=$iso_make/tmphtml
rm $iso_makehtml >/dev/null 2>&1
wget -O $iso_makehtml 'http://cdimage.ubuntu.com/' >/dev/null 2>&1

prec=$(fgrep Precise $iso_makehtml | head -1 | awk '{print $3}' | sed 's/href=\"//; s/\/\"//')
trus=$(fgrep Trusty $iso_makehtml | head -1 | awk '{print $3}' | sed 's/href=\"//; s/\/\"//')
xenn=$(fgrep Xenial $iso_makehtml | head -1 | awk '{print $3}' | sed 's/href=\"//; s/\/\"//')
bion=$(fgrep Bionic $iso_makehtml | head -1 | awk '{print $3}' | sed 's/href=\"//; s/\/\"//')
prec_vers=$(fgrep Precise $iso_makehtml | head -1 | awk '{print $6}')
trus_vers=$(fgrep Trusty $iso_makehtml | head -1 | awk '{print $6}')
xenn_vers=$(fgrep Xenial $iso_makehtml | head -1 | awk '{print $6}')
bion_vers=$(fgrep Bionic $iso_makehtml | head -1 | awk '{print $6}')

name='econ-ark'

# ask whether to include vmware tools or not
while true; do
    echo " which ubuntu edition would you like to remaster:"
    echo
    echo "  [1] Ubuntu $prec LTS Server amd64 - Precise Pangolin"
    echo "  [2] Ubuntu $trus LTS Server amd64 - Trusty Tahr"
    echo "  [3] Ubuntu $xenn LTS Server amd64 - Xenial Xerus"
    echo "  [4] Ubuntu $bion LTS Server amd64 - Bionic Beaver"
    echo
    read -ep " please enter your preference: [1|2|3|4]: " -i "4" ubver
    case $ubver in
        [1]* )  download_file="ubuntu-$prec_vers-server-amd64.iso"           # filename of the iso to be downloaded
                download_location="http://cdimage.ubuntu.com/releases/$prec/"     # location of the file to be downloaded
                new_iso_name="ubuntu-$prec_vers-server-amd64-unattended_$name.iso" # filename of the new iso file to be created
                break;;
	[2]* )  download_file="ubuntu-$trus_vers-server-amd64.iso"             # filename of the iso to be downloaded
                download_location="http://cdimage.ubuntu.com/releases/$trus/"     # location of the file to be downloaded
                new_iso_name="ubuntu-$trus_vers-server-amd64-unattended_$name.iso"   # filename of the new iso file to be created
                break;;
        [3]* )  download_file="ubuntu-$xenn_vers-server-amd64.iso"
                download_location="http://cdimage.ubuntu.com/releases/$xenn/"
                new_iso_name="ubuntu-$xenn_vers-server-amd64-unattended_$name.iso"
                break;;
        [4]* )  download_file="ubuntu-18.04.4-server-amd64.iso"
                download_location="http://releases.ubuntu.com/18.04/"
                new_iso_base="ubuntu-18.04.4-server-amd64-unattended_$name"
                new_iso_name="ubuntu-18.04.4-server-amd64-unattended_$name.iso"
                break;;
        * ) echo " please answer [1], [2], [3] or [4]";;
    esac
done

if [ -f /etc/timezone ]; then
  timezone=`cat /etc/timezone`
elif [ -h /etc/localtime ]; then
  timezone=`readlink /etc/localtime | sed "s/\/usr\/share\/zoneinfo\///"`
else
  checksum=`md5sum /etc/localtime | cut -d' ' -f1`
  timezone=`find /usr/share/zoneinfo/ -type f -exec md5sum {} \; | grep "^$checksum" | sed "s/.*\/usr\/share\/zoneinfo\///" | head -n 1`
fi

# ask the user questions about his/her preferences
read -ep " please enter your preferred timezone: " -i "${timezone}" timezone
read -ep " please enter your preferred username: " -i "econ-ark" username
read -ep " please enter your preferred password: " -i "kra-noce" password
printf "\n"
read -ep " confirm your preferred password: " -i "kra-noce" password2
printf "\n"
read -ep " Make ISO bootable via USB: " -i "yes" bootable

# check if the passwords match to prevent headaches
if [[ "$password" != "$password2" ]]; then
    echo " your passwords do not match; please restart the script and try again"
    echo
    exit
fi

# download the ubuntu iso. If it already exists, do not delete in the end.
cd $iso_from
if [[ ! -f $iso_from/$download_file ]]; then
    echo -n " downloading $download_file: "
    download "$download_location$download_file"
fi
if [[ ! -f $iso_from/$download_file ]]; then
	echo "Error: Failed to download ISO: $download_location$download_file"
	echo "This file may have moved or may no longer exist."
	echo
	echo "You can download it manually and move it to $iso_from/$download_file"
	echo "Then run this script again."
	exit 1
fi

cd $iso_make
# download rc.local file
[[ -f $iso_make/$rclocal_file ]] && rm $iso_make/$rclocal_file

echo -n " downloading $rclocal_file: "
download "$online/$rclocal_file"

# download econ-ark seed file
[[ -f $iso_make/$seed_file ]] && rm $iso_make/$seed_file 

echo -n " downloading $seed_file: "
download "$online/$seed_file"

# download kickstart file
[[ -f $iso_make/$ks_file ]] && rm $iso_make/$ks_file

echo -n " downloading $ks_file: "
download "$online/$ks_file"

# install required packages
echo " installing required packages"
if [ $(program_is_installed "mkpasswd") -eq 0 ] || [ $(program_is_installed "mkisofs") -eq 0 ]; then
    (apt-get -y update > /dev/null 2>&1) &
    spinner $!
    (apt-get -y install whois genisoimage > /dev/null 2>&1) &
    spinner $!
fi
if [[ $bootable == "yes" ]] || [[ $bootable == "y" ]]; then
    if [ $(program_is_installed "isohybrid") -eq 0 ]; then
      #16.04
      if [[ $ub1604 == "yes" || $(lsb_release -cs) == "artful" ]]; then
        (apt-get -y install syslinux syslinux-utils > /dev/null 2>&1) &
        spinner $!
      else
        (apt-get -y install syslinux > /dev/null 2>&1) &
        spinner $!
      fi
    fi
fi

# mount the image
if grep -qs $iso_make/iso_org /proc/mounts ; then
    echo " image is already mounted"
    echo " unmounting before remounting (to make sure latest version is what is mounted)"
    (umount $iso_make/iso_org )
fi

echo 'Mounting '$download_file' as '$iso_make/iso_org
cp $iso_from/$download_file /tmp/$download_file
(mount -o loop /tmp/$download_file $iso_make/iso_org > /dev/null 2>&1)

# copy the iso contents to the working directory
echo 'Copying the iso contents from iso_org to iso_new'
( rsync -rai --delete $iso_make/iso_org/ $iso_make/iso_new ) &
spinner $!

# set the language for the installation menu
cd $iso_make/iso_new
#doesn't work for 16.04
echo en > $iso_make/iso_new/isolinux/lang

#16.04
#taken from https://github.com/fries/prepare-ubuntu-unattended-install-iso/blob/master/make.sh
#sed -i -r 's/timeout\s+[0-9]+/timeout 1/g' $iso_make/iso_new/isolinux/isolinux.cfg

# set late command

# late_command="chroot /target curl -L -o /var/local/start.sh $online/$startFile ;\
#      chroot /target curl -L -o /var/local/finish.sh $online/$finishFile ;\
#      chroot /target curl -L -o /etc/rc.local $online/$rclocal_file ;\
#      chroot /target chmod +x /var/local/start.sh ;\
#      chroot /target chmod +x /var/local/finish.sh ;\
#      chroot /target chmod +x /etc/rc.local ;\
#      chroot /target mkdir -p /etc/lightdm/lightdm.conf.d ;\
#      chroot /target curl -L -o /etc/lightdm/lightdm.conf.d/autologin-econ-ark.conf $online/root/etc/lightdm/lightdm.conf.d/autologin-econ-ark.conf ;\
#      chroot /target chmod 755 /etc/lightdm/lightdm.conf.d/autologin-econ-ark.conf ;"

# late_command="in-target curl -L -o /var/local/start.sh $online/$startFile ;\
#      in-target curl -L -o /var/local/finish.sh $online/$finishFile ;\
#      in-target curl -L -o /etc/rc.local $online/$rclocal_file ;\
#      in-target chmod +x /var/local/start.sh ;\
#      in-target chmod +x /var/local/finish.sh ;\
#      in-target chmod +x /etc/rc.local ;\
#      in-target mkdir -p /etc/lightdm/lightdm.conf.d ;\
#      in-target curl -L -o /etc/lightdm/lightdm.conf.d/autologin-econ-ark.conf $online/root/etc/lightdm/lightdm.conf.d/autologin-econ-ark.conf ;\
#      in-target chmod 755 /etc/lightdm/lightdm.conf.d/autologin-econ-ark.conf"

# 20200713-1732h - failed:
# late_command="in-target bash -c 'wget -r --output-document=/var/local/start.sh  $online/$startFile   ';\
# in-target bash -c 'wget -r --output-document=/var/local/finish.sh $online/$finishFile'  ;\
# in-target bash -c 'wget -r --output-document=/etc/rc.local        $online/$rclocal_file'  ;\ 
# in-target bash -c 'chmod +x /var/local/start.sh'  ;\
# in-target bash -c 'chmod +x /var/local/finish.sh'  ;\
# in-target bash -c 'chmod +x /etc/rc.local'  ;\
# in-target bash -c 'mkdir -p /etc/lightdm/lightdm.conf.d'  ;\
# in-target bash -c 'wget -r --output-document=/etc/lightdm/lightdm.conf.d/autologin-econ-ark.conf $online/root/etc/lightdm/lightdm.conf.d/autologin-econ-ark.conf'  ;\
# in-target bash ' chmod 755 /etc/lightdm/lightdm.conf.d/autologin-econ-ark.conf' "

# 20200713-1853h - failed:
# late_command="in-target bash -c 'wget -r --output-document=/var/local/start.sh  $online/$startFile   ';\
# in-target bash -c 'wget -r --output-document=/var/local/finish.sh $online/$finishFile'  ;\
# in-target bash -c 'wget -r --output-document=/etc/rc.local        $online/$rclocal_file'  ;\ 
# in-target bash -c 'chmod +x /var/local/start.sh'  ;\
# in-target bash -c 'chmod +x /var/local/finish.sh'  ;\
# in-target bash -c 'chmod +x /etc/rc.local'  ;\
# in-target bash -c 'mkdir -p /etc/lightdm/lightdm.conf.d'  ;\
# in-target bash -c 'wget -r --output-document=/etc/lightdm/lightdm.conf.d/autologin-econ-ark.conf $online/root/etc/lightdm/lightdm.conf.d/autologin-econ-ark.conf'  ;\
# in-target bash -c 'chmod 755 /etc/lightdm/lightdm.conf.d/autologin-econ-ark.conf' "

### # # Copy the late_command file to the root
### cp -rT $iso_make/$late_command_file $iso_make/iso_new/$late_command_file
### chmod +x $iso_make/iso_new/$late_command_file

# 20200714-0904h: Failed
#late_command="in-target sudo apt -y install git ; in-target bash -c 'mkdir /tmp ; cd /tmp ; git clone https://github.com/econ-ark/econ-ark-tools ; chmod +x /tmp/econ-ark-tools/Virtual/Machine/ISO-maker/late_command.sh ; /tmp/econ-ark-tools/Virtual/Machine/ISO-maker/late_command.sh'"

# late_command="in-target /bin/bash -c 'apt -y install git ; git clone https://github.com/econ-ark/econ-ark-tools /tmp/econ-ark-tools ; /tmp/econ-ark-tools/Virtual/Machine/ISO-maker/late_command.sh'"  

# Removed the line below:
#### in-target sed -i 's/^.*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config ;\

# Removed the line below; reinsert after start.sh
late_command="chroot /target curl -L -o /var/local/start.sh $online/$startFile ;\
     chroot /target curl -L -o /var/local/finish.sh $online/$finishFile ;\
     chroot /target curl -L -o /etc/rc.local $online/$rclocal_file ;\
     chroot /target chmod +x /var/local/start.sh ;\
     chroot /target chmod +x /var/local/finish.sh ;\
     chroot /target chmod +x /etc/rc.local ;\
     chroot /target mkdir -p /etc/lightdm/lightdm.conf.d ;\
     chroot /target curl -L -o /etc/lightdm/lightdm.conf.d/autologin-econ-ark.conf $online/root/etc/lightdm/lightdm.conf.d/autologin-econ-ark.conf ;\
     chroot /target chmod 755 /etc/lightdm/lightdm.conf.d/autologin-econ-ark.conf "

# copy the seed file to the iso
cp -rT $iso_make/$seed_file $iso_make/iso_new/preseed/$seed_file

# copy the kickstart file to the root
cp -rT $iso_make/$ks_file $iso_make/iso_new/$ks_file
chmod 744 $iso_make/iso_new/$ks_file

# include firstrun script
echo "# setup firstrun script">> $iso_make/iso_new/preseed/$seed_file
echo "d-i preseed/late_command                                    string      $late_command " >> $iso_make/iso_new/preseed/$seed_file

# generate the password hash
pwhash=$(echo $password | mkpasswd -s -m sha-512)

# update the seed file to reflect the users' choices
# the normal separator for sed is /, but both the password and the timezone may contain it
# so instead, I am using @
sed -i "s@{{username}}@$username@g" $iso_make/iso_new/preseed/$seed_file
sed -i "s@{{pwhash}}@$pwhash@g"     $iso_make/iso_new/preseed/$seed_file
sed -i "s@{{hostname}}@$hostname@g" $iso_make/iso_new/preseed/$seed_file
sed -i "s@{{timezone}}@$timezone@g" $iso_make/iso_new/preseed/$seed_file

# calculate checksum for seed file
seed_checksum=$(md5sum $iso_make/iso_new/preseed/$seed_file)

# # add thxe autoinstall option to the menu
# sed -i "/label install/ilabel autoinstall\n\
#   menu label ^Autoinstall Econ-ARK Xubuntu Server\n\
#   kernel /install/vmlinuz\n\
#   append file=/cdrom/preseed/ubuntu-server.seed initrd=/install/initrd.gz DEBCONF_DEBUG=5 auto=true priority=high preseed/file=/cdrom/preseed/econ-ark.seed                                       -- ks=cdrom:/ks.cfg " $iso_make/iso_new/isolinux/txt.cfg
  
# add the autoinstall option to the menu
sudo /bin/sed -i 's|set timeout=30|set timeout=5\nmenuentry "Autoinstall Econ-ARK Xubuntu Server" {\n	set gfxpayload=keep\n	linux	/install/vmlinuz   boot=casper file=/cdrom/preseed/econ-ark.seed auto=true priority=critical locale=en_US          ---\n	initrd	/install/initrd.gz\n}|g' $iso_make/iso_new/boot/grub/grub.cfg # 	linux /install/vmlinuz append file=/cdrom/preseed/ubuntu-server.seed initrd=/install/initrd.gz DEBCONF_DEBUG=5 auto=true priority=high preseed/file=/cdrom/preseed/econ-ark.seed       ---\n	initrd	/install/initrd.gz\n\


#sed -i -r 's/timeout=[0-9]+/timeout=1/g' $iso_make/iso_new/boot/grub/grub.cfg
#sed -i -r 's/timeout 1/timeout 30/g'     $iso_make/iso_new/isolinux/isolinux.cfg # Somehow this gets changed; change it back
sudo /bin/sed -i 's|default install|default auto-install\nlabel auto-install\n  menu label ^Autoinstall Econ-ARK Xubuntu Server\n  kernel /install/vmlinuz\n  append file=/cdrom/preseed/econ-ark.seed vga=788 initrd=/install/initrd.gz auto=true priority=critical locale=en_US       ---|g'     $iso_make/iso_new/isolinux/txt.cfg

echo " creating the remastered iso"
cd $iso_make/iso_new

[[ -e "$iso_make/$new_iso_name" ]] && rm "$iso_make/$new_iso_name"
cmd="(mkisofs -D -r -V XUBUNTARK -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o $iso_make/$new_iso_name . > /dev/null 2>&1) &"
echo "$cmd"
eval "$cmd"

spinner $!

# make iso bootable (for dd'ing to USB stick)
if [[ $bootable == "yes" ]] || [[ $bootable == "y" ]]; then
    isohybrid $iso_make/$new_iso_name
fi

# Move it to the destination
cmd="[[ -e $iso_done/$size/$new_iso_name ]] && rm $iso_done/$size/$new_iso_name"
echo "$cmd"
eval "$cmd"
cmd="mv $iso_make/$new_iso_name $iso_done/$size/$new_iso_name"
echo "$cmd"
eval "$cmd"

# print info to user
echo " -----"
echo " finished remastering your ubuntu iso file"
echo " the new file is located at: $iso_make/$new_iso_name"
echo " your username is: $username"
echo " your password is: $password"
echo " your hostname is: $hostname"
echo " your timezone is: $timezone"
echo

echo 'Task finished at:'
datestr=`date +"%Y%m%d-%H%M%S"`
echo "$datestr"
echo ""


cmd="rclone --progress copy '"$iso_done/$size/$new_iso_name"'"
cmd+=" econ-ark-google-drive:econ-ark@jhuecon.org/Resources/Virtual/Machine/XUBUNTU-$size/$new_iso_base"
echo 'To copy to Google drive, execute the command below:'
echo ''
echo "$cmd"

# uncomment the exit to perform cleanup of drive after run
exit

umount $iso_make/iso_org
rm -rf $iso_make/iso_new
rm -rf $iso_make/iso_org
rm -rf $iso_makehtml

# unset vars
unset username
unset password
unset hostname
unset timezone
unset pwhash
unset download_file
unset download_location
unset new_iso_name
unset iso_from
unset iso_make
unset iso_done
unset tmp
unset seed_file
