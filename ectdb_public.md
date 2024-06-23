## Eduroam tools container-based deployment: Overall considerations
Based on (REANNZ/ectdb-public)(https://github.com/REANNZ/etcbd-public]

The ancilliary tools package consists of three separate sets of tools:

- Admintool
- Metrics
- Monitoring

Each of the tools is (at the moment) designed to run in an isolated environment. They can be run on a single docker host by mapping each to a different port. The configuration files provided here are designed this way:

- Admintool runs on ports 80 and 443 (HTTP and HTTPS)
- Monitoring tools run on ports 8080 and 8443 (HTTP and HTTPS)
- Metrics runs on ports 9080 and 9443 (HTTP and HTTPS)

## System Requirements

All of the services are packaged as Docker containers, so are not tightly linked to the details of the system they are running on. However, the following considerations apply to the system:

- The system should be running a recent version of Linux supported by Docker(Manual is tested on Ubuntu 22
- The system can be either a virtual machine or a physical (real hardware) system.)
- The system should have at least 5GB of disk space (recommended 10GB) available under /var/lib/docker (on the /var partition or on the root filesystem if not partitioned).
- The system should have at least 4GB of RAM (recommended 8GB) available.
- Docker (Install and configure Docker - [Manual](https://github.com/REANNZ/etcbd-public/blob/master/Docker-setup.md))
- Mailserver - Some of the tools (admintool and monitoring) will need to send outgoing email. Please make sure you have the details of an SMTP ready - either one provided by your systems administrator, or one running on the local system.

## Basic Setup

On each of the VMs, start by cloning the git repository:

```git clone https://github.com/REANNZ/etcbd-public```















