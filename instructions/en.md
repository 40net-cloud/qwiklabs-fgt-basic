# FortiGate: Protecting Google Compute resources with FortiGate
## Overview
This lab is intended for network administrators implementing network traffic inspection in Google Cloud using FortiGate next-gen firewalls. You will learn the reference architecture and configure inbound, outbound and east-west traffic inspection using a FortiGate HA cluster.

### Objectives
In this lab you will:

- Redirect inbound traffic to a frontend VM running in Google Cloud
- Secure outbound traffic from Google Cloud to Internet
- Secure east-west traffic between VMs running in Google Cloud

### Architecture
The lab starts with all cloud resources pre-deployed to match the FortiGate recommended architecture described below. Although all cloud resources are deployed and do not require any additional configuration, the FortiGates have only the following elements configured:

- [HA clustering](https://docs.fortinet.com/document/fortigate/7.2.0/cli-reference/23620/config-system-ha)
- [health probe responders](https://docs.fortinet.com/document/fortigate/7.2.0/cli-reference/122620/config-system-probe-response) (including ELB public IP as secondary IP on port1 interface)
- health probe static routes on port2
- [SDN connector](https://docs.fortinet.com/document/fortigate/7.2.0/cli-reference/87620/config-system-sdn-connector)
- licensing

You will configure all remaining FortiGate options necessary to make the setup work.

![](https://lucid.app/publicSegments/view/29fb78a7-5d17-4e09-9ac4-ee8049af4654/image.png)

FortiGate reference architecture for Google Cloud leverages 2 common *"building blocks"*: active-passive HA cluster in load balancer sandwich, and hub-and-spoke with VPC peering and custom route export.

#### Active-passive HA cluster
High availability clusters are deployed between 2 separate availability zones of the same region to elevate the [SLA](https://cloud.google.com/compute/sla) of the solution to 99.99%. FortiGates are usually deployed in an active-passive pair leveraging Fortinet's proprietary FGCP protocol for configuration and state synchronization. Traffic from the Internet is directed to the currently active VM instance using an external load balancer to be matched against access policy, inspected against malicious payload and redirected using a Virtual IP to the destination server (in case of this lab - frontend VM). Packets from VPC Network is routed to FortiGates using internal load balancer as the next hop.

#### Hub and spoke with VPC peering
While the [VPC Peering](https://cloud.google.com/vpc/docs/vpc-peering) itself is non-transitive (two VPC networks can communicate only if **directly** peered), it's different if peering is combined with custom route and a routing NVA (network virtual appliance). A custom route created in the *hub* VPC with next hop set to FortiGate (or ILB fronting a FortiGate cluster) can be exported to all peered VPCs using *export custom route* property. The route imported to peered *spoke* VPCs will apply to all traffic leaving the *spoke* VPC sending it to the FortiGate appliance. Note that the route table is evaluated only once when the packet is leaving its source, it is not re-evaluated once the packet crosses the peering (so it's not affected by a peered subnet route in the *hub* VPC when on the way to FortiGate). It is important to note that the default route in spoke VPCs would take precedence over the route imported via the peering and thus has to be deleted.

## Lab
### Initial configuration
#### First connection and setting password
1. Open FortiGate management URL in your browser
2. Accept the initial password information
3. Log in using **admin** as username and **FGT Password** as initial password (by default password is set to the primary VM instance id)
4. change password to your own and login again
5. you can skip dashboard configuration by clicking **Later**

#### Configure FortiGate route to workload VPCs
While the cloud network infrastructure is pre-configured for this lab, you still need to adjust FortiGates routing configuration to indicate the route to workload VPCs (frontend and backend):

1. in FortiGate web console choose **Network** > **Static Routes** from left menu and click **Create New**
2. as destination provide an aggregated CIDR for both workload subnets: **10.0.0.0/23**
3. as Gateway Address provide local subnet gateway: **172.20.1.1**
4. as Interface select **port2**
5. ignore warning about possible gateway unreachability
6. click **OK** to add the route

### Step 1: outbound traffic
Workload servers are already deployed, but they cannot finish their bootstrapping without connectivity with Internet. In this step you will enable and inspect outbound traffic from workload VMs in peered networks to Internet.

> While in this lab you will create a default rule for all traffic, in production environments it is recommended to create more granular settings. See other labs for managing outbound traffic.

1. Connect to primary FortiGate management (all configuration will be done on primary and replicated to secondary instance).
2. Create a firewall policy allowing all traffic from port2 to port1.
    - From the left menu select **Policy & Objects** > **Firewall Policy**
    - Click **Create New** button at the top
    - provide name for the new policy
    - as **Incoming interface** choose **port2** and for **Outgoing** **port1**
    - for **Source**, **Destination** and **Service** choose **all**
    - in **Security Profiles** enable **Application Control**
    - at the bottom change **Log Allowed Traffic** from **Security Events** to **All Sessions**
    - Save the new policy by clicking **OK**

3. Stop and start *frontend-vm* and *backend-vm* instances using **STOP** and **START/RESUME** buttons at the top of the instance details page in GCP console
4. In the FortiGate web console **Log & Report** > **Forwarding Logs** you should see traffic coming from 10.0.0.2 and 10.0.1.2 to multiple services including Ubuntu update.

<ql-activity-tracking step=1>
Verify you configured outbound connectivity correctly.
</ql-activity-tracking>

fgt logs?
flow logs?

### Step 2: inbound traffic
In this step you will enable access from Internet to a web application frontend VM via FortiGate. In production environment you will use a farm of compute resources (VMs or serverless) behind an internal load balancer. For the sake of simplicity this lab uses single VMs to emulate frontend and backend farms.

In a cloud environment protected by a firewall no other VM is directly available from Internet. You can enforce this policy using Organization Policy constraints [`constraints/compute.vmExternalIpAccess`](https://cloud.google.com/resource-manager/docs/organization-policy/org-policy-constraints), but using constraints is beyond the scope of this lab.

1. Inspect your external load balancer. It has been already deployed with one frontend IP address.
    1. in GCP web console go to **Network services** > **Load balancing**
    2. find and open details of the load balancer with name starting by *fgtbes-elb*
    3. make sure exactly one backend is indicated as healthy
    4. note down the public IP address in **Frontend** section - you will need it in next steps
2. Connect to primary FortiGate
3. Your frontend server is available at 10.0.0.2. Create a Virtual IP (VIP) mapping ELB frontend IP to 10.0.0.2 and limit to port 80
    1. in **Policy & Objects** open **VirtualIPs** and click **Create New (Virtual IP)** button at the top
    2. name your VIP
    3. as **Interface** select **port1**
    4. in **External IP address/range** field provide ELB public IP you noted earlier
    5. in **Map to** enter the frontend server private IP: **10.0.0.2**
    6. enable **Port Forwarding**
    7. as both **External service port** and **Map to IPv4 port** provide the HTTP port number: **80**
    8. confirm the configuration of new Virtual IP by clicking **OK**
4. Right-click on the VIP and select **Create firewall policy using this object** from context menu
5. Fill in missing firewall policy fields:
    1. provide a firewall policy name
    2. as **Outgoing interface** select **port2**
    3. as **Source** select **all**
    4. as **Service** select **HTTP**
    5. disable **NAT**
    6. in **Security Profiles** enable **IPS**
    7. in **Log Allowed Traffic** select **All Sessions**
5. In your browser try connecting to ELB public IP over HTTP protocol (http://ELB_ADDRESS/). After few seconds you should receive a *504 Gateway Time-out* message indicating you have reached the frontend proxy server but the connection between frontend and backend server failed.

<ql-activity-tracking step=1>
Verify you configured inbound connectivity correctly.
</ql-activity-tracking>

Activity tracking:
fgt config?
flow logs?

### Step 3:  east-west connections
Some applications might require traffic inspection between application tiers (eg. using IPS - Intrusion Prevention System). Note that in GCP you must deploy different application tiers into different VPC networks. Due to the nature of Google Cloud networking only traffic leaving a VPC can be redirected to a network virtual appliance for inspection.

In this step you will enable secure connectivity between VMs in frontend and backend VPC networks. You will use Fortinet Fabric Connector to build a firewall rule based on metadata rather than using static CIDRs.

1. Connect to primary FortiGate
2. use left menu to navigate to **Policy & Objects** > **Addresses** and create dynamic addr3esses for frontend and backend network tags:
    1. use **Create New** button to create a new address
    2. provide **gcp-frontend** as name
    3. in **Type** select **Dynamic**
    4. SDN Connector for GCP was already pre-configured as *gcp*. Select it in the **SDN Connector** field
    5. in **Filter** field select **Tag=frontend**
    6. save new address by clicking **OK**
    7. repeat steps 1-6 for the *backend* network tag
3. create a firewall policy allowing traffic from frontend to backend with port2 as both source and destination interface
    1. in **Policy & Objects** > **Firewall Policy** click **Create New** button at the top
    2. name the policy
    3. as both **Incoming Interface** and **Outgoing Interface** select **port2** as both VM instances are peered with the internal VPC of the firewall
    4. as **Source** select **gcp-frontend**
    5. as **Destination** select **gcp-backend**
    6. as **Service** select **HTTP**
    7. disable **NAT**
    8. in **Security Profiles** enable **Antivirus** and **IPS**
    9. enable logging of all sessions
    10. save the policy by clicking **OK**
4. use your web browser to connect to ELB public IP address over HTTP protocol. You should receive a **It works!** message (if you see the default nginx page or 502 error - wait few seconds and refresh the page).
5. Click **Try getting EICAR** button to attempt downloading a harmless EICAR test virus file. Your attempt will be blocked by FortiGate. You can verify details about detected incident in FortiGate **Forward Traffic** log.

<ql-activity-tracking step=1>
Verify east-west connectivity between frontend and backend.
</ql-activity-tracking>

Activity tracking:
fgt config?
flow logs?
