# ubnt-airos-scripts
A collection of bash scripts to make mass changes to Ubiquiti AirOS wireless devices.

# ubnt_ap_mass_change.sh
This script could be used to change the IP address of an AP and all associated client radios. In the example, it is changing radios from 172.31.X.Y/16 to 10.10.X.Y/24. It also sets the SNMP community string, turns on Discovery, logs to a log file, and more. Can be easily modified to do other things like mass-apply DFS codes, or update NTP server settings. 
