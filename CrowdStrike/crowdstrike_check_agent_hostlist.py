#!/usr/bin/env python3
"""
Reads in a pre-formatted CSV of hostnames called CrowdStrike_Host_Check.csv

Asks the user for CrowdStrike API Client, API Secret, and Directory containing the input CSV.

Iterates though the CSV checking for each host in the console,
and writing out the results of that check as: 
Hostname, Agent Installed True/False, and Last Seen time.

Script supports being run on Windows and macOS.
"""
import csv
import os
from datetime import datetime
from falconpy import api_complete as FalconSDK

# Ask the user for Falcon Client ID and Secret
INPUT_CLIENT_ID = input("Enter the CrowdStrike API Client: ")
INPUT_CLIENT_SECRET = input("Enter the CrowdStrike API Client Secret: ")

FALCON = FalconSDK.APIHarness(
    client_id=INPUT_CLIENT_ID, client_secret=INPUT_CLIENT_SECRET)

# Ask the user for the input directory
if os.name == "nt":  # check if the operating system is Windows
    INPUT_HOST_CSV_DIRECTORY = input(
        "Enter the directory containing the 'CrowdStrike_Host_Check.csv' input file: ")
    # Use backward slashes for Windows
    INPUT_HOST_CSV_DIRECTORY = INPUT_HOST_CSV_DIRECTORY.replace("/", "\\")
else:  # for macOS and Linux, use forward slashes
    INPUT_HOST_CSV_DIRECTORY = input(
        "Enter the directory containing the 'CrowdStrike_Host_Check.csv' input file: ").replace("\\", "/")

# Remove the trailing slash from the input directory path
if INPUT_HOST_CSV_DIRECTORY.endswith("/") or INPUT_HOST_CSV_DIRECTORY.endswith("\\"):
    INPUT_HOST_CSV_DIRECTORY = INPUT_HOST_CSV_DIRECTORY[:-1]

# Set the input and output file paths
INPUT_HOST_CSV_FILENAME = "CrowdStrike_Host_Check.csv"
OUTPUT_HOST_CSV_FILENAME = f"CrowdStrike_Host_Check_COMPLETE_{datetime.now().strftime('%Y%m%d_%H%M')}.csv"
INPUT_HOST_CSV_PATH = os.path.join(INPUT_HOST_CSV_DIRECTORY, INPUT_HOST_CSV_FILENAME)
OUTPUT_HOST_CSV_PATH = os.path.join(INPUT_HOST_CSV_DIRECTORY, OUTPUT_HOST_CSV_FILENAME)

# Read in the input CSV file
with open(INPUT_HOST_CSV_PATH, "r", encoding="utf-8") as input_csv_file:
    csv_reader = csv.reader(input_csv_file)
    # Skip the header
    next(csv_reader)
    print("File read successfully, starting host checks...")
    # Create a list to store the results
    results = []

    # Loop through each host in the input file
    for row in csv_reader:
        if row:  # Check if row is not empty
            hostname = row[0]

        # Check if the host has the CrowdStrike agent installed
        devices = FALCON.command(
            "QueryDevicesByFilter", filter=f"hostname:'{hostname}*'")

        if devices["body"]["resources"]:
            device_id = devices['body']['resources']
            response = FALCON.command("GetDeviceDetails", ids=[device_id][0])
            if response["body"]["resources"]:
                AGENT_INSTALLED = True
                LAST_SEEN = response['body']['resources'][0]['last_seen']
            else:
                AGENT_INSTALLED = False
                LAST_SEEN = "Multiple AID's dectected."
        else:
            AGENT_INSTALLED = False
            LAST_SEEN = "N/A"

        results.append([hostname, AGENT_INSTALLED, LAST_SEEN])
print("Checks complete, writing output file...")

# Write the results to the output CSV file
with open(OUTPUT_HOST_CSV_PATH, "w", newline="", encoding="utf-8") as output_csv_file:
    csv_writer = csv.writer(output_csv_file)
    # Write the header row
    csv_writer.writerow(["Hostname", "CrowdStrike Agent installed", "Last Check-In Date"])
    # Write the results rows
    csv_writer.writerows(results)

print("Host check complete, review the output file " + OUTPUT_HOST_CSV_FILENAME + " in " + INPUT_HOST_CSV_DIRECTORY)
