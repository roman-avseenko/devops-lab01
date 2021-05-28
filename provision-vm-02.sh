#!/bin/bash

# Message displayed while console login in
MESSAGE="Unauthorized access to this machine is prohibited
Press <Ctrl-D> if you are not an authorized user!"

# Banner displayed while ssh login in
BANNER="********************************************************************
*                                                                  *
* This system is for the use of authorized users only.  Usage of   *
* this system may be monitored and recorded by system personnel.   *
*                                                                  *
******************************************************************** "


function timezone_set {

        [[ $(timedatectl) == *"Europe/Minsk"* ]] && echo "Time zone Europe/Minsk is already set" && return 0
        timedatectl set-timezone Europe/Minsk && echo "Time zone is switched to Europe/Minsk"
}

function chronyd_on {

        if [[ "$(systemctl is-enabled chronyd)" == enabled ]];
        then
                echo "Chrony service is enabled!"
        else
                echo "Chrony service is disabled and inactive (dead). Enabling and activating..."
                systemctl enable --now chronyd
        fi
}

function add_message {
	
	echo "Adding message of a day and banner text"
	echo "$MESSAGE" | tee /etc/motd > /dev/null

	echo "$BANNER" | tee /etc/issue > /dev/null

	echo "Banner /etc/issue" | tee -a /etc/ssh/sshd_config > /dev/null
	systemctl restart sshd

}

function lv_create {
	
	echo "Creating logical volumes"
	
	#Create physical volume
	if ! pvs | grep -q "/dev/sdb"; then
		pvcreate /dev/sdb > /dev/null
	else
		echo "Physical volume on /dev/sdb is already exists"
	fi

	#Create volume group "data"
	if ! vgs | grep -q "data"; then
        	vgcreate data /dev/sdb > /dev/null
	else
        	echo "Volume group "data" is already exists"
	fi
	
	#Create logical volume "data01"
	if ! lvs | grep -q "data01"; then
		lvcreate -l 20%VG -n data01 data > /dev/null
	else
		echo "Logical volume "data01" is already exists"
	fi
	
	#File system creation for LV data01
	if ! blkid /dev/mapper/data-data01; then
		mkfs.ext4 /dev/mapper/data-data01 &> /dev/null
	else
		echo "File system on logical volume "data01" is already exists"
	fi

	#Create logical volume "data02"
	if ! lvs |  grep -q "data02"; then
                lvcreate -l 80%VG -n data02 data > /dev/null
        else
                echo "Logical volume "data02" is already exists"
        fi
	
	#File system creation for LV data02
        if ! blkid /dev/mapper/data-data02; then
                mkfs.ext3 /dev/mapper/data-data02 &> /dev/null
        else
                echo "File system on logical volume "data01" is already exists"
        fi
}

function mnt_lv {
	
	echo "Mounting logical volumes"
	
	#Mounting LV persistently
	if ! grep -q "/dev/mapper/data-data01" /etc/fstab; then
		echo "/dev/mapper/data-data01	/data01	ext4	defaults 0 0" >>/etc/fstab
	fi
	
	if ! grep -q "/dev/mapper/data-data02" /etc/fstab; then
                echo "/dev/mapper/data-data02   /data02 ext3    defaults 0 0" >>/etc/fstab
        fi
	

	#Mounting LV to their directories
	if ! mount | grep -q "/dev/mapper/data-data01"; then
		if [[ ! -d /data01 ]]; then
			mkdir /data01
		else
			echo "/data01 is already exists"
		fi
		mount /data01
	else
		echo "/data01 is already mounted"
	fi

	if ! mount | grep -q "/dev/mapper/data-data02"; then
                if [[ ! -d /data02 ]]; then
                        mkdir /data02
                else    
                        echo "/data02 is already exists"
                fi
                mount /data02
        else    
                echo "/data02 is already mounted"
        fi
}


timezone_set 	#Set timezone to Europe/Minsk
chronyd_on 	#Enable chronyd
add_message 	#Set banner and motd
lv_create 	# Create a logical volumes
mnt_lv		# Mount created logical volumes

echo "OK"