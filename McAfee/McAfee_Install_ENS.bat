REM Install McAfee Endpoint Security Threat Protection, Advanced Threat Protection, and Web Control silently
REM Ensure this script runs from the directory the ENS installer is located in
SetupEP.exe ADDLOCAL="tp,atp,wc" /l*v"C:\Logs\McAfee ENS Logs" /quiet