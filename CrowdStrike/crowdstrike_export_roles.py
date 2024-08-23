"""
Extract all roles available in CrowdStrike and export to the console and to a CSV in the location of the script.

RequiresPython3, falconpy
"""
## Set envrionment variables
#!/usr/bin/env python3
from falconpy import UserManagement
import json
import csv
from datetime import datetime

# Authenticate to the Falcon console.
falcon = UserManagement(client_id="API_KEY",
                        client_secret="API_SECRET"
                        )

## Define Functions

# Extract and export all available CrowdStrike roles
def export_roles():    
    try:
        response = falcon.get_available_role_ids()
        print(response)
        if response["status_code"] == 200:
            print("Available roles:")
            for role_name in response["body"]["resources"]:
                print(role_name)
            #Create a CSV with the current date/time to be written
            csv_role_report = 'csv_role_report_' + str(datetime.now().strftime('%Y_%m_%d_%H_%M_%S')) + '.csv'
            with open(csv_role_report, "w") as csv_role_report:
                csv_role_report.write("Role List\n")
                for role_name in response["body"]["resources"]:
                    csv_role_report.write(role_name+"\n")
        else:
            for error_result in response["body"]["errors"]:
                print("Script Failed: " + error_result["message"])
    except: print("Failure to try the script.")

## Execute functions

export_roles()
