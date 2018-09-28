ElasticSearch and Kibana Management Tool

This is a PowerShell script file that provides developers with the ability to execute common adminstrative task using the ElasticSearch API.

How to install the tool?
1. On any server, navigate to the C drive
2. Create the following folder structure: C:\Alarmnet\ESMgr
3. Copy ESMgr1.ps1 and ESConfig.xml to the ESMgr folder

How to run this tool?
1. Run Powershell as an Adminstrator
2. Type the following command in the console window: cd C:\Alarmnet\ESMgr\
3. Type the following command in the console window: .\ESMgr.ps1

How to configure and test this tool on your own machine?
1. Install ElasticSearch as a Window Service
2. Install Kibana as a Window Service
3. Open the ESConfig.xml file and under the DEV element modify the following properties
   DNS.servers = <change this to your computer name>
   Services.ESServiceName = <change the value to to the ElasticSearch window service name only>
   Services.KibanaServiceName = <change the value to the Kibana window service name only>