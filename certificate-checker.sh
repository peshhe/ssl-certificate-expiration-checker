#!/bin/bash

#################################################################
# Define a function to make a HTTPS request to retrieve certificate information
https-request() {
    local warning_threshold="${2:-$WARNING_DAYS}" # Defaults to WARNING_DAYS if not provided
    local error_threshold="${3:-$ERROR_DAYS}" # Defaults to ERROR_DAYS if not provided
  
    # Extract hostname from the URL (remove protocol, path and port if any)
    hostname=$(echo "$website" | sed 's|https\?://||' | cut -d'/' -f1 | cut -d':' -f1)

    echo "Retrieving certificate for '$website' ..."

    # Use openssl to connect, get certificate, and then to extract expiration date
    cert_data=$(echo | timeout 10 openssl s_client -servername "$hostname" -connect "$hostname":443 2>/dev/null)
    if [[ $? -ne 0 || -z "$cert_data" ]]; then
        printf "$RED   [ERROR] Could not retrieve certificate for '$hostname'.$NC\n"
        slack_message=":x: ERROR: Could not retrieve certificate for *'$website'*. :x:\nCheck *network connection* or if that's a *valid website*."
        send_slack_alerts "$slack_message"
        printf "   Check network connection or if that's a valid website.\n\n"
        return 1 # This would help for counting the number of failed checks
    elif echo "$cert_data" | grep -q "BEGIN CERTIFICATE"; then
        # Passing the certificate data to parse-certificate function
        parse-certificate "$cert_data"

        # Display the expiration date in a human-readable format
        display-expiration "$end_date"
        expiration_date_sofia=$(TZ='Europe/Sofia' date -d "$expiry_date" '+%d %B %Y at %H:%M:%S %Z (Sofia/Bulgaria time zone)')

        # Calculate number of days until expiration
        calculate_days_until_expiry "$expiry_date"

        # Determine status based on thresholds
        local status_color="$GREEN"
        local status_text="OK"
        local status_message="The Certificate of '$hostname' is valid for $days_until_expiry more days"
        local slack_message=":white_check_mark: The Certificate of '$hostname' is valid for *$days_until_expiry more days* :tada:"

        if [[ $days_until_expiry -lt 0 ]]; then
            status_color="$RED"
            status_text="EXPIRED"
            days_until_expiry=$((days_until_expiry * -1))
            status_message="The Certificate of '$hostname' is expired $days_until_expiry days ago"
            slack_message=":x: The Certificate of '$hostname' is expired *$days_until_expiry days* ago :bangbang:"
        elif [[ $days_until_expiry -le $error_threshold ]]; then
            status_color="$RED"
            status_text="CRITICAL"
            status_message="The Certificate of '$hostname' is expiring very soon - in $days_until_expiry days"
            slack_message=":rotating_light: The Certificate of '$hostname' is expiring very soon - in *$days_until_expiry days* :warning:"
        elif [[ $days_until_expiry -le $warning_threshold ]]; then
            status_color="$YELLOW"
            status_text="WARNING"
            status_message="The Certificate of '$hostname' is expiring soon - in $days_until_expiry days"
            slack_message=":warning: The Certificate of '$hostname' is expiring soon - in *$days_until_expiry days* :warning:"
        fi

        # Display status with appropriate color
        printf "$status_color   [$status_text]  $status_message\n$NC"
        # Send Slack alert
        send_slack_alerts "The Certificate of $website has been checked: [$status_text]\n$slack_message\n*Expiration Date:* $expiration_date_sofia:flag-bg:\n"
        printf "   Expiration Date: $expiration_date_sofia\n\n"
    fi
}
# End of function https-request
#################################################################



#################################################################
# Function to parse the certificate data and extract expiration date
parse-certificate() {
    local cert_data=$1
    # Extract the certificate data and get the expiration date only
    end_date=$(echo "$cert_data" | openssl x509 -noout -enddate)

    if [[ -z "$end_date" ]]; then
        printf "$RED   [ERROR] Failed to parse expiry date for $hostname\n$NC"
        return 1
    fi
}
# End of function parse-certificate
#################################################################



#################################################################
# Function to display the expiration date in a human-readable format
display-expiration() {
    local end_date=$1
    # Extract expiration date in human-readable format
    expiry_date=$(echo "$end_date" | grep 'notAfter=' | cut -d'=' -f2)

    if [[ -z "$expiry_date" ]]; then
        printf "$RED   [ERROR] Failed to parse expiry date for $hostname\n$NC"
        return 1
    fi
}
# End of function display-expiration
#################################################################



#################################################################
# Function to calculate days until expiry
calculate_days_until_expiry() {
    expiry_epoch=$(date -d "$expiry_date" +%s)
    current_epoch=$(date +%s)
    days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 )) # There are 86400 seconds in a day
}
# End of function calculate_days_until_expiry
#################################################################



#################################################################
# Send Slack notification
send_slack_alerts() {
    # Slack webhook URL
    local message="$1"

    if [[ -z "$SLACK_WEBHOOK_URL" ]]; then
        echo "   SLACK_WEBHOOK_URL is not set. Skipping Slack alert."
        return 0
    fi

    # Define the raw JSON payload using Slack's 'Block Kit' format
    payload=$(cat << EOF
{
	"blocks": [
		{
			"type": "section",
			"text": {
				"type": "mrkdwn",
				"text": "$message"
			}
		},
		{
			"type": "section",
			"text": {
				"type": "plain_text",
				"text": " "
			}
		}
	]
}
EOF
)
    # Send the payload to Slack using curl
    if curl -s -f -o /dev/null -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK_URL"; then
        echo "   Slack alert sent successfully"
    else
        echo "   [ERROR] Failed to send Slack alert"
        return 1
    fi
}
# End of function send_slack_alerts
#################################################################



#################################################################
# Function to check if the config file exists and create a default if not
check_config_file() {
    if [ ! -f "$CONFIG_FILE" ]; then
        printf "$YELLOW\nWarning: Configuration file not found. Creating default: $CONFIG_FILE from a template.$NC\n"
        cat > "$CONFIG_FILE" << EOF
# websites.conf - Configuration File for SSL Certificate Expiration Checker
# this file was created as template and should be edited to add your own websites

# Format: WEBSITE_URL [WARNING_DAYS] [ERROR_DAYS]
# Lines starting with # are ignored

# Default thresholds will be used (30 days warning, 7 days error)
google.com
microsoft.com
apple.com

# Invalid websites for testing purposes:
wrong.domain.name. # Test with a wrong domain
https://www.not-existing.domain # Test with non-existing domain, but with 'https' and 'www'
invalid-domain.test 60 31 # Test with an invalid domain and custom thresholds
something_else # Test with a random string
expired-rsa-dv.ssl.com # Test with an expired certificate

# Custom thresholds
github.com 45 10
sap.com 365 14 # force to have [WARNING]
docker.com 365 200 # force to have [CRITICAL]

# Additional examples
example.com:8443 30 7 # with set port
expired-rsa-dv.ssl.com # expired certificate
www.google.com # Test with 'www'
https://google.com # Test with 'https'
https://www.google.com # Test with 'https' and 'www'
https://calendar.google.com/calendar # Test with a valid domain and path
EOF
        if [[ $? -eq 0 ]]; then
            printf "Default configuration file created. Please edit $CONFIG_FILE to add your own websites.\n\n\n"
        else
            printf "$RED\n[ERROR] Failed to create default configuration file $CONFIG_FILE. Please create it manually and add your websites.$NC\n\n\n"
            return 1
        fi
    fi
}
# End of function check_config_file
#################################################################



#################################################################
# Main script execution starts here

# Define the script file path and websites' config file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/websites.conf"
# Default thresholds
WARNING_DAYS=30
ERROR_DAYS=7
total_sites=0
failed_sites=0
# Define colours for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print header
printf "\nSSL Certificate Expiry Checker\n"
printf "==================================\n\n"
send_slack_alerts "Starting SSL Certificate Expiry Checker ... :rocket:\nTime of script execution: $(TZ='Europe/Sofia' date '+%d %B %Y at %H:%M:%S %Z (*Sofia/Bulgaria* time zone)') :clock3:\n"
echo

# Check if config file exists. If not, create a default one
check_config_file

# Process each website in the configuration file
while IFS= read -r line || [[ -n "$line" ]]; do
    # Strip any comments (even if they appear after the useful content)
    line_without_comment=$(echo "$line" | sed 's/#.*//')

    # Skip empty lines
    [[ -z "$line_without_comment" ]] && continue

    # Parse each line: website [warning_days] [error_days]
    read -r website warning_days error_days <<< "$line_without_comment"

    ((total_sites++)) # Increment total sites counter
    
    if ! https-request "$website" "$warning_days" "$error_days"; then
        ((failed_sites++)) # Increment failed sites counter
    fi
done < "$CONFIG_FILE" # Read from the config file

# Display summary
echo "=================================="
echo "Total sites checked: $total_sites"
echo "Failed checks: $failed_sites"
echo "Successful checks: $((total_sites - failed_sites))"
echo "=================================="
send_slack_alerts "Total sites checked: $total_sites\nFailed checks: $failed_sites\nSuccessful checks: $((total_sites - failed_sites))\nEnd of script execution.\n==================================\n"
echo "End of script execution."
# End of main script execution
#################################################################
