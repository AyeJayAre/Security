"""
Remove Roles from a user in CrowdStrike from an input or hard coded array.

Quieries the FalconAPI for user UUID based on user email, and then removes roles as 
listed in the ids arrary called by the response_revoke_roles command.

Requires Python3 and falconpy
"""
#!/usr/bin/env python3
from cgi import test
from falconpy import UserManagement

# Authenticate to the Falcon console. Required hard-coded API user account and secret.
falcon = UserManagement(client_id="API Account ID",
                        client_secret="API Acount Secret"
                        )

### Set the user list based on varying critiera that can be adjusted in the script prior to running for ad-hoc changes.

## Prompt the user for a username at script runtime, format should be firstname.lastname@email.com
#user_email = input("What is the email address of the users account who's roles will be removed? ")

# Pass a list of user accounts.
user_list = ['example.user1@email.com', 'example.user2@email.com']

# Loop through each user account and remove the roles listed in the ids array.
for user in user_list :
    response_uuid = falcon.retrieve_user_uuid(uid=user)
    print(response_uuid.keys())
    body = response_uuid.get("body")
    uuid = body.get("resources")
    user = uuid 
    response_revoke_roles = falcon.revoke_user_role_ids(user_uuid=user, ids=['binarly_admin', 'binarly_user', 'fim_manager','firewall_manager','help_desk','horizon_admin','horizon_analyst ")','horizon_read_only_analyst','intel_admin','intel_all_analyst','intel_basic_analyst','help_desk','intel_ecrime_analyst','intel_malware_submitter','intel_targeted_analyst','kubernetes_protection_admin', 'kubernetes_protection_analyst', 'kubernetes_protection_read_only_analyst' , 'mobile_admin' , 'prevention_policy_manager' , 'quarantine_manager' , 'remediation_manager' , 'remote_responder' , 'remote_responder_one' , 'response_workflow_author' , 'scheduled_report_admin' , 'scheduled_report_analyst' , 'security_lea' , 'vulnerability_manager', 'custom_ioas_manager', 'security_lead', 'prevention_hashes_manager', 'overwatch_malware_submitter', 'image_viewer', 'image_admin', 'horizon_analyst', 'falconhost_read_only', 'falconhost_investigator', 'falconhost_analyst', 'falcon_console_guest', 'event_viewer', 'endpoint_manager', 'discover_analyst', 'device_control_manager', 'desktop_support', 'dashboard_admin', 'custom_ioas_manager'] )
    print(response_revoke_roles)

    # Write the print output to a local file FalconpyLog.txt.
    with open("FalconpyLog.txt", "a") as external_file:
        add_text = response_revoke_roles
        print(add_text, file=external_file)
        external_file.close()
