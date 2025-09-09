# SSL Certificate Expiration Checker

A Bash script tool to monitor SSL certificate expiration dates for multiple websites with customizable thresholds, Slack notifications, and containerized deployment options.

## Table of contents

- [Features](#features)
- [Quick Start](#quick-start)
  - [GitHub Actions workflow (Option 1)](#github-actions-workflow-option-1)
  - [Docker Deployment (Option 2)](#docker-deployment-option-2)
  - [Local Execution (Option 3)](#local-execution-option-3)
- [Configuration](#configuration)
- [Slack Integration](#slack-integration)
- [GitHub Actions Workflows](#github-actions-workflows)
- [Requirements](#requirements)

## Features

- **Bulk Certificate Monitoring**: Check multiple websites from the [`websites.conf`](websites.conf) configuration file.
- **Customizable Thresholds**: Set warning and critical alert thresholds per website.
- **Slack Integration**: Automatic notifications with status updates and emojis.
- **Multiple Deployment Options**: Run locally, in Docker containers, or via GitHub Actions.
- **Robust Error Handling**: Graceful handling of network issues and invalid domains.
- **Time Zone Support**: Display expiration dates in Sofia/Bulgaria timezone.
- **Color-Coded Output**: Visual status indicators (Green/Yellow/Red).
- **Comprehensive Logging**: Detailed execution summaries and statistics.

#### Security Features

- **Non-root execution**: Docker container runs as unprivileged user (UID 1001)
- **Secure environment variables**: Sensitive data passed securely
- **Timeout protection**: 10-second timeout on SSL connections
- **Input validation**: Robust parsing of configuration file


## Quick Start

There are several ways you can utilise this tool. The easiest one is probably [GitHub Actions workflow (Option 1)](#github-actions-workflow-option-1) as it runs in [GitHub Actions](../../actions). The [Docker Deployment (Option 2)](#docker-deployment-option-2) is also easy for running on your local machine - either [Using my Docker Hub Image](#using-docker-hub-image) or [Building the Docker image Locally](#building-docker-image-locally). There is also a more advanced option to [run the script locally on a Linux machine](#local-execution-option-3), but you'll need to make sure you have all the needed [tools for local execution](#local-execution) **installed in advance**.

### GitHub Actions workflow (Option 1)

You just need to copy this repository and upload it to your GitHub account. Once that's done navigate to the **_Actions_** tab on your repo, then **_Check SSL Certificates on GitHub Actions runner_** from your left side (or just [click here](../../actions/workflows/check-certificates-locally.yml)) and you will see a grey button on the right side **_Run workflow_**. Once you click that button you will see a green one with the same label **_Run workflow_** - click it and wait about 20 second for the magic.

This workflow is also configured to automatically run on **Sundays at 01:00** and **daily at 14:30**! This can be disabled with just commenting the below lines in [check-certificates-locally.yml](.github/workflows/check-certificates-locally.yml) file:

<table><th>Automatic runs on schedule</th><th>Disabling the automatic runs</th></tr><td>

```bash
schedule:
  - cron: '0 1 * * 0' # At 01:00 on Sunday
  - cron: '30 14 * * *' # At 14:30 every day
```

</td><td>

```bash
# schedule:
#   - cron: '0 1 * * 0' # At 01:00 on Sunday
#   - cron: '30 14 * * *' # At 14:30 every day
```

</td></table>

### Docker Deployment (Option 2)

#### Using Docker Hub Image

```bash
docker run --rm \
  -e SLACK_WEBHOOK_URL="your-webhook-url" \
  -v $(pwd)/websites.conf:/app/websites.conf \
  peshhe/ssl-cert-checker:latest
```

#### Building Docker image Locally

```bash
docker build -t ssl-cert-checker .
docker run --rm \
  -e SLACK_WEBHOOK_URL="your-webhook-url" \
  ssl-cert-checker
```

### Local Execution (Option 3)

1. Clone the repository:
```bash
git clone https://github.com/peshhe/ssl-certificate-expiration-checker.git && \
cd ssl-certificate-expiration-checker
```

2. Make the script executable:
```bash
chmod +x certificate-checker.sh
```

3. Edit the configuration file:
```bash
nano websites.conf
```

4. Run the checker:
```bash
./certificate-checker.sh
```

## Configuration

### Website Configuration Format

Edit the [`websites.conf`](websites.conf) to specify websites to monitor:

```bash
# Format: WEBSITE_URL [WARNING_DAYS] [ERROR_DAYS]
# Lines starting with # are ignored

# Using default thresholds (30 days warning, 7 days critical)
google.com
microsoft.com

# Custom thresholds
github.com 45 10
example.com:8443 60 14

# Various URL formats supported
https://www.example.com
https://api.example.com/health
subdomain.example.com:9443
10.20.30.111:443
```

### Environment Variables

Variable | Description | Required | Example value
--- | --- | --- | ---
`SLACK_WEBHOOK_URL` | Slack webhook URL for notifications | No | `https://hooks.slack.com/services/T00000000/ B00000000/XXXXXXXXXXXXXXXXXXXXXXXX`
`WARNING_DAYS` | Global warning threshold | No | `30`
`ERROR_DAYS` | Global critical threshold | No | `7`

### Default Thresholds

- **WARNING**: 30 days before expiration (Yellow alert)
- **CRITICAL**: 7 days before expiration (Red alert)
- **EXPIRED**: Certificate has already expired (Red alert)

## Slack Integration

The tool sends rich notifications to Slack using [Block Kit](https://docs.slack.dev/block-kit/) format with:

- Status emojis (✅ OK, ⚠️ Warning, 🚨 Critical, ❌ Expired)
- Detailed expiration information
- Bulgaria time zone display
- Execution summaries

### Setting up Slack Webhook

1. Create a Slack app in your workspace
2. Enable Incoming Webhooks
3. Create a webhook URL for your channel
4. Set the `SLACK_WEBHOOK_URL` environment variable

## GitHub Actions Workflows

### Local Runner Execution

**File**: `.github/workflows/check-certificates-locally.yml`

- **Purpose:** Easily run certificate checks on GitHub's infrastructure.
- **Trigger:** Manual trigger, available via `workflow_dispatch`.
- **Schedule:** Sundays at 01:00 and daily at 14:30.

### Docker Hub Deployment

**File**: `.github/workflows/build-container-dockerhub.yml`

- **Purpose:** Build and push Docker images to Docker Hub.
- **Trigger:** On **merged** PRs to `dev` & `prod` branches as well as manual trigger.
- **Tagging:** `gha-sha-{commit-hash}`

### Azure Container Deployment

**File**: `.github/workflows/build-container-acr.yml`

- **Purpose**: Build, push to Azure Container Registry, and then deploy to Azure Container Instances.
- **Trigger**: Manual workflow dispatch
- **Features**: Automatic cleanup after execution

This GHA workflow requires additional secrets to be configured:

Secret | Description | Example value
--- | --- | ---
AZURE_CREDENTIALS | The credentials in (`JSON` format) GitHub Actions uses to [Login With a Service Principal Secret](https://github.com/Azure/login#login-with-a-service-principal-secret) to Azure CLI. This allows it to manage Azure resources. | `{"clientId": "****", "subscriptionId": "****", "clientSecret": "****", "tenantId": "****"}`
REGISTRY_USERNAME | Admin user, used to login to the Azure Container Registry | `ssl0certificate0checker`
REGISTRY_PASSWORD | The password for the admin user of the CR | `rand0m/symbOl$+from=AZURE`
REGISTRY_URL | Container Registry's Login server | `ssl0certificate0checker.azurecr.io`
SLACK_CERTIFICATE_CHECKER_WEBHOOK | **_Optional:_** The webhook URL used to [send Slack alerts](https://docs.slack.dev/messaging/sending-messages-using-incoming-webhooks). | `https://hooks.slack.com/services/T00000000/ B00000000/XXXXXXXXXXXXXXXXXXXXXXXX`
RESOURCE_GROUP | repository variable, containing the name of the Azure Resource Group, where the ACI will be deployed in  | `rg-certificate-checker`

#### ⚠️ **Important:** `RESOURCE_GROUP` is [repository **variable**](../../settings/variables/actions), not a **secret**!

## Requirements

Depends on which approach you decide to go with you may need (some of) these prerequisites:

### Local Execution

- **Bash**: Version 4.0 or higher
- **OpenSSL**: For certificate retrieval and parsing
- **curl**: For Slack notifications
- **Standard Unix utilities**: `date`, `cut`, `sed`, `grep`

### Docker

- **Docker Engine**: 20.10 or higher
- **Base Image**: Alpine Linux (minimal footprint)

### GitHub Actions

- **Repository secrets** for Slack webhook URLs
- **Appropriate permissions** for Docker Hub or Azure deployments

## Future tasks

Tasks to do with this project:

- Limit forking, to avoid malicious usage of GitHub Actions
- Trim this `README.md` file to be easily understandable
- Lower the number of scheduled tasks, or fully disable them

---

**Author**: [peshhe](https://github.com/peshhe)
**Repository**: [ssl-certificate-expiration-checker](https://github.com/peshhe/ssl-certificate-expiration-checker)