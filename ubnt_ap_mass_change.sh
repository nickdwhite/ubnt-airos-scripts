#!/bin/bash

# Redirect and set up logging
# https://stackoverflow.com/questions/3173131/redirect-copy-of-stdout-to-log-file-from-within-bash-script-itself
exec > >(tee -i /var/log/ubnt_change.log)
exec 2>&1


APADDRESS=$1

UBNTVER=$2

NEWOCTET3=$3

UPDATEOCTET3=$4

USERNAME=ubnt
PASSWORD=password

AC2SERVER1=10.10.1.1
AC2SERVER2=10.10.2.2

SNMPCOMMUNITY=mysnmpcommunity

#echo "Type the IP address of the AP you want to check/add DFS(exanple: 10.10.255.255:"

#read APADDR

#if [[ ! -z $APADDRESS ]]
#then

function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^172\.31\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}
function valid_new_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^10\.10\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}




    echo "Getting client list from ${APADDRESS}"
    if [[ ${UBNTVER} = "2" ]]; then
        HOSTS=`sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no ${USERNAME}@${APADDRESS} wstalist |grep \"lastip\" | awk '{print $2}' | sed s/\"/\/g | sed s/,//g | tr '\r\n' ' '`
    else
		if [[ ${UBNTVER} = "" || ${UBNTVER} = "1" ]]; then
		    HOSTS=`sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no ${USERNAME}@${APADDRESS} wstalist |grep \"lastip\" | awk '{print $3}' | sed s/\"/\/g | sed s/,//g | tr '\r\n' ' '`
		fi
    fi
    for HOSTNAME in ${HOSTS} ; do
        echo "Checking ${HOSTNAME}"
		if valid_ip ${HOSTNAME}; then.
		    echo "IP matches 172.31"
		else
		    echo "Not 172.31 IP"
		    continue
		fi
		echo " - Turning on Discovery"
		sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no ${USERNAME}@${HOSTNAME} sed -i s/discovery.status=disabled/discovery.status=enabled/g /tmp/system.cfg
		echo " - Checking SNMP Settings"
		sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no ${USERNAME}@${HOSTNAME} sed -i s/snmp.community=public/snmp.community=${SNMPCOMMUNITY}/g /tmp/system.cfg
		echo " - Checking for WDS mode"
        sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no ${USERNAME}@${HOSTNAME} sed -i s/wireless.1.wds.status=disabled/wireless.1.wds.status=enabled/g /tmp/system.cfg

		echo " - Removing old AirControl servers"
		ACSERVERS=`sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no ${USERNAME}@${HOSTNAME} mca-provision-list | awk -F"http://" '{print $2}' | awk -F":" '{print $1}'`
		for SERVER in ${ACSERVERS} ; do
		    echo " - Found server: ${SERVER}"
		    if [[ ${SERVER} != ${AC2SERVER1} && ${SERVER} != ${AC2SERVER2} ]]; then
				echo " - Removing server: ${SERVER}"
				sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no ${USERNAME}@${HOSTNAME} mca-provision-rm ${SERVER}
		    fi
		done
		OCTET3=`echo ${HOSTNAME} | awk '{print $1}' | cut -f3 -d"."`
		OCTET4=`echo ${HOSTNAME} | awk '{print $1}' | cut -f4 -d"."`
		if [[ ${UPDATEOCTET3} == "Y" ]]; then
            if valid_ip ${HOSTNAME}; then
                #We check to see if we want to overwrite the third octet of the IP with the POP #. Some radios might be 10.10 format, but have the wrong pop #
                echo " - Connecting to ${HOSTNAME} to change octet of Management IP"
                MGMTINT=`sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no ${USERNAME}@${HOSTNAME} cat /tmp/system.cfg | grep "mlan" | awk '{print $1}' | cut -f1,2 -d"."`
                echo " - Management interface: ${MGMTINT}"
                DEVINT=`sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no ${USERNAME}@${HOSTNAME} cat /tmp/system.cfg | grep "${MGMTINT}.devname" | awk '{print $1}' | cut -f2 -d"="`
        		echo " - Device interface: ${DEVINT}"
        		#Change the Management IP
		        echo " - IP will now be changed to 10.10.${NEWOCTET3}.${OCTET4} on Management Interface ${DEVINT}"
		        sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no ${USERNAME}@${HOSTNAME} sed -i s/${MGMTINT}.ip=${HOSTNAME}/${MGMTINT}.ip=10.10.${NEWOCTET3}.${OCTET4}/g /tmp/system.cfg
                sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no ${USERNAME}@${HOSTNAME} sed -i s/${MGMTINT}.netmask=255.255.255.0/${MGMTINT}.netmask=255.255.255.0/g /tmp/system.cfg
                sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no ${USERNAME}@${HOSTNAME} sed -i s/route.1.gateway=172.31.0.1/route.1.gateway=10.10.${NEWOCTET3}.254/g /tmp/system.cfg
		    fi
        else
		    if valid_ip ${HOSTNAME}; then
		
		    #Now we log into the radio and check/change the IPs
		    echo " - Connecting to ${HOSTNAME} to check Management IP"
		    MGMTINT=`sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no ${USERNAME}@${HOSTNAME} cat /tmp/system.cfg | grep "mlan" | awk '{print $1}' | cut -f1,2 -d"."`
		    echo " - Management interface: ${MGMTINT}"
		    DEVINT=`sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no ${USERNAME}@${HOSTNAME} cat /tmp/system.cfg | grep "${MGMTINT}.devname" | awk '{print $1}' | cut -f2 -d"="`
		    echo " - Device interface: ${DEVINT}"
		


		    #Change the Management IP
		    echo " - IP will now be changed to 10.10.${OCTET3}.${OCTET4} on Management Interface ${DEVINT}"
		    sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no ${USERNAME}@${HOSTNAME} sed -i s/${MGMTINT}.ip=${HOSTNAME}/${MGMTINT}.ip=10.10.${OCTET3}.${OCTET4}/g /tmp/system.cfg
		    sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no ${USERNAME}@${HOSTNAME} sed -i s/${MGMTINT}.netmask=255.255.0.0/${MGMTINT}.netmask=255.255.255.0/g /tmp/system.cfg
		    sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no ${USERNAME}@${HOSTNAME} sed -i s/route.1.gateway=172.31.0.1/route.1.gateway=10.10.${OCTET3}.254/g /tmp/system.cfg
		    fi
		fi
		echo " - Saving configuration..."
		sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no ${USERNAME}@${HOSTNAME} /sbin/cfgmtd -p /etc/ -w
		echo " - Rebooting radio..."
		sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no ${USERNAME}@${HOSTNAME} reboot
    done

#fi
