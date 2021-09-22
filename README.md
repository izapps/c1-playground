# Playground

- [Playground](#playground)
  - [Requirements and Support Matrix](#requirements-and-support-matrix)
    - [Suport Matrix](#suport-matrix)
    - [Tools Installation](#tools-installation)
  - [Configure](#configure)
  - [Start](#start)
  - [Tear Down](#tear-down)
  - [Add-On: Registry](#add-on-registry)
    - [Access Registry](#access-registry)
  - [Add-On: Cloud One Container Security](#add-on-cloud-one-container-security)
    - [Access Smart Check](#access-smart-check)
  - [Add-On: Scan-Image and Scan-Namespace](#add-on-scan-image-and-scan-namespace)
  - [Add-On: Prometheus & Grafana](#add-on-prometheus--grafana)
    - [Access Prometheus & Grafana](#access-prometheus--grafana)
  - [Add-On: Falco](#add-on-falco)
    - [Generate some events](#generate-some-events)
    - [Fun with privileged mode](#fun-with-privileged-mode)
    - [Access Falco UI](#access-falco-ui)
  - [Add-On: Krew](#add-on-krew)
  - [Add-On: Starboard](#add-on-starboard)
  - [Add-On: Open Policy Agent](#add-on-open-policy-agent)
    - [Example Policy: Registry Whitelisting](#example-policy-registry-whitelisting)
  - [Add-On: Gatekeeper](#add-on-gatekeeper)
    - [Example Policy: Namespace Label Mandates](#example-policy-namespace-label-mandates)
  - [Play with the Playground](#play-with-the-playground)

Ultra fast and slim kubernetes playground.

Currently, the following services are integrated:

- Prometheus & Grafana
- Starboard
- Falco Runtime Security including Kubernetes Auditing
- Container Security
  - Smart Check
  - Deployment Admission Control, Continuous Compliance
- Open Policy Agent
- Gatekeeper

## Requirements and Support Matrix

> Note: The Playgound is designed to work on this operating systems
>
> - Ubuntu Bionic and newer
> - Cloud9 with Ubuntu
> - MacOS 10+
>
> Besides the cluster life-cycle scripts `up` and `down`, the deployment scripts are supporting the following managed cluster types:
>
> - GKE
> - (EKS)
> - (AKS)

### Suport Matrix

Operating System | Cluster Type | Registry | Container Security Admission & Continuous | Container Security Runtime | Falco | Gatekeeper | OPA | Prometheus | Starboard 
---------------- | ------------ | -------- | ----------------------------------------- | ---------------------------| ----- | ---------- | --- | ---------- | ---------
Ubuntu | Playground | X | X |  | X | X | X | X | X
Ubuntu | GKE | X | X | X | X | X | X | X | X
Ubuntu | (EKS) | (X) | (X) | (X) | (X) | (X) | (X) | (X) | (X)
Ubuntu | Azure | X | X | X | X | X | X | X | X
Cloud9 w/ Ubuntu | Playground | X | X |  | X | X | X | X | X
MacOS | Playground | X | X |  |  | X | X | X |X

### Tools Installation

In all of these possible environments you're going to run a script called `tools.sh`. This will ensure you have the latest versions of

- `brew` (MacOS only),
- `docker` or `Docker for Mac`.
- `kubectl`,
- `kustomize`,
- `helm`,
- `kind`,
- `krew` and
- `kubebox`

installed.

Follow the steps for your platform below.

<details>
<summary>Linux</summary>

Install required packages if not available. **After the installation continue in a new shell.**

```sh
./tools.sh
```

**IMPORTANT: Proceed in a new shell!**

</details>

<details>
<summary>MacOS</summary>

Install required packages if not available. **After the installation continue in a new shell.**

```sh
./tools.sh
```

Then, go to the `Preferences` of Docker for Mac, then `Resources` and `Advanced`. Ensure to have at least 4 CPUs and 12+ GB of Memory assigned to Docker.

**IMPORTANT: Proceed in a new shell!**

</details>

<details>
<summary>Cloud9</summary>

- Select Create Cloud9 environment
- Give it a name
- Choose “t3.xlarge” or better for instance type and
- Ubuntu Server 18.04 LTS as the platform.
- For the rest take all default values and click Create environment

When it comes up, customize the environment by closing the welcome tab and lower work area, and opening a new terminal tab in the main work area.

Install required packages if not available. **After the installation continue in a new shell.**

```sh
./tools.sh
```

</details>

## Configure

First step is to clone the repo to your machine and second you create your personal configuration file.

```sh
git clone https://github.com/mawinkler/c1-playground.git
cd c1-playground
cp config.json.sample config.json
```

Typically you don't need to change anything here besides setting your api key for C1. If you're planning to use Cloud One Container Security you don't need an activation key for smart check, the api key is then sufficient.

```json
{
    ...
    "api_key": "YOUR KEY HERE",
    "activation_key": "YOUR KEY HERE"
}
```

Follow the steps for your platform below.

<details>
<summary>Linux</summary>

> If running on a Cloud9, you now need to resize the disk of the EC2 instance20GB, execute:
>  
> ```sh
> ./resize.sh
> ```

The `up.sh` script later on will deploy a load balancer amongst other cluster components. It will get a range of ip addresses assigned to distribute them to service clients. The defined range is `X.X.255.1-X.X.255.250`. If the registry is deployed it will very likely be the second service requesting a load balancer IP, so typically it will get the `172.18.255.2` assignend which we define as an insecure registry for our local docker daemon.

To do this, create or modify `/etc/docker/daemon.json` to include a small subset probable ips for the registry.

```json
{"insecure-registries": ["172.18.255.1:5000","172.18.255.2:5000","172.18.255.3:5000"]}
```

Finally restart the docker daemon.

```sh
sudo systemctl restart docker
```

In the following step [Start](#start), you'll create the cluster, typically followed by creating the cluster registry. The last line of the output from `./deploy-registry.sh` shows you a docker login example. Try this. If it fails you need to verify the IP address range of the integrated load balancer that it matches the IPs from above. Typically, this is not required.

If it failed, we need to determine the network that is being used for the node ip pool. For that, we need to run `up.sh` and then query the nodes.

```sh
kubectl get nodes -o json | jq -r '.items[0].status.addresses[] | select(.type=="InternalIP") | .address'
```

```sh
172.18.0.2
```

Adapt the file `/etc/docker/daemon.json` accordingly. Then

```sh
./stop.sh
sudo systemctl restart docker
```

</details>

<details>
<summary>MacOS</summary>
Due to the fact, that there is no `docker0` bridge on MacOS, we need to use ingresses to enable access to services running on our cluster. To make this work, you need to modify your local `hosts`-file.

Change the line for 127.0.0.1 from

```txt
127.0.0.1 localhost
```

to

```txt
127.0.0.1 localhost playground-registry smartcheck grafana prometheus
```

</details>

<details>
<summary>Cloud9</summary>

You now need to resize the disk of the EC2 instance to 30GB, execute:

```sh
./resize.sh
```

The `up.sh` script later on will deploy a load balancer amongst other cluster components. It will get a range of ip addresses assigned to distribute them to service clients. The defined range is `X.X.255.1-X.X.255.250`. If the registry is deployed it will very likely be the second service requesting a load balancer IP, so typically it will get the `172.18.255.2` assignend which we define as an insecure registry for our local docker daemon.

To do this, create or modify `/etc/docker/daemon.json` to include a small subset probable ips for the registry.

```json
{"insecure-registries": ["172.18.255.1:5000","172.18.255.2:5000","172.18.255.3:5000"]}
```

Finally restart the docker daemon.

```sh
sudo systemctl restart docker
```

In the following step [Start](#start), you'll create the cluster, typically followed by creating the cluster registry. The last line of the output from `./deploy-registry.sh` shows you a docker login example. Try this. If it fails you need to verify the IP address range of the integrated load balancer that it matches the IPs from above. Typically, this is not required.

If it failed, we need to determine the network that is being used for the node ip pool. For that, we need to run `up.sh` and then query the nodes.

```sh
kubectl get nodes -o json | jq -r '.items[0].status.addresses[] | select(.type=="InternalIP") | .address'
```

```sh
172.18.0.2
```

Adapt the file `/etc/docker/daemon.json` accordingly. Then

```sh
./stop.sh
sudo systemctl restart docker
```

</details>

## Start

Simply run

```sh
./up.sh
```

## Tear Down

```sh
./down.sh
```

## Add-On: Registry

To deploy the registry run:

```sh
./deploy-registry.sh
```

### Access Registry 

Follow the steps for your platform below.

<details>
<summary>Linux</summary>

A file called `services` is either created or updated with the link and the credentials to connect to the registry.

Example:

- `Registry login with: echo trendmicro | docker login https://172.18.255.1:5000 --username admin --password-stdin`

</details>

<details>
<summary>MacOS</summary>

A file called `services` is either created or updated with the link and the credentials to connect to the registry.

Example:

- `Registry login with: echo trendmicro | docker login https://playground-registry:443 --username admin --password-stdin`

</details>

<details>
<summary>Cloud9</summary>

A file called `services` is either created or updated with the link and the credentials to connect to the registry.

Example:

- `Registry login with: echo trendmicro | docker login https://172.18.255.1:5000 --username admin --password-stdin`

</details>

## Add-On: Cloud One Container Security

To deploy Container Security run:

```sh
./deploy-smartcheck.sh
./deploy-container-security.sh
```

### Access Smart Check

Follow the steps for your platform below.

<details>
<summary>Linux</summary>

A file called `services` is either created or updated with the link and the credentials to connect to smartcheck.

Example:

- `Smart check UI on: https://192.168.1.121:8443 w/ admin/trendmicro`

</details>

<details>
<summary>MacOS</summary>

A file called `services` is either created or updated with the link and the credentials to connect to smartcheck.

Example:

- `Smart check UI on: https://smartcheck:443 w/ admin/trendmicro`

</details>

<details>
<summary>Cloud9</summary>

If working on a Cloud9 environment you need to adapt the security group of the corresponding EC2 instance to enable access from your browwer. To share Smart Check over the internet, follow the steps below.

1. Query the public IP of your Cloud9 instance with
   ```sh
   curl http://169.254.169.254/latest/meta-data/public-ipv4
   ```
2. In the IDE for the environment, on the menu bar, choose your user icon, and then choose Manage EC2 Instance
3. Select the security group associated to the instance and select Edit inbound rules.
4. Add an inbound rule for the `proxy_listen_port` configured in you config.json (default: 8443) and choose Source Anywhere
5. Depending on the currently configured Network ACL you might need to add a rule to allow ingoing traffic on the same port. To do this go to the VPC within the Cloud9 instance is running and proceed to the associated Main network ACL.
6. Ensure that an inbound rule is set which allows traffic on the `proxy_listen_port`. If not, click on `Edit inbound rules` and add a rule with a low Rule number, Custom TCP, Port range 8443 (or your configured port), Source 0.0.0.0/0 and Allow.

You should now be able to connect to Smart Check on the public ip of your Cloud9 with your configured port.

</details>

## Add-On: Scan-Image and Scan-Namespace

The two scripts `scan-image.sh` and `scan-namespace.sh` do what you would expect. Running

```sh
./scan-image.sh nginx:latest
```

starts an asynchronous scan of the latest version of nginx. The scan will run on Smart Check, but you are immedeately back in the shell. To access the scan results either use the UI or API of Smart Check.

If you add the flag `-s` the scan will be synchronous, so you get the scan results directly in your shell.

```sh
./scan-image.sh -s nginx:latest
```

```json
...
{ critical: 6,
  high: 39,
  medium: 40,
  low: 13,
  negligible: 2,
  unknown: 3 }
```

The script

```sh
./scan-namespace.sh
```

scans all used images within the current namespace. Maybe do a `kubectl config set-context --current --namespace <NAMESPACE>` beforehand to select the namespace to be scanned.

## Add-On: Prometheus & Grafana

By running `deploy-prometheus-grafana.sh` you'll get a fully functional and preconfigured Prometheus and Grafana instance on the playground.

The following additional scrapers are configured:

- [api-collector](https://github.com/mawinkler/api-collector)
- [Falco]((#add-on-falco))
- smartcheck-metrics

### Access Prometheus & Grafana

Follow the steps for your platform below.

<details>
<summary>Linux</summary>

By default, the Prometheus UI is on port 8081, Grafana on port 8080.

A file called `services` is either created or updated with the link and the credentials to connect to smartcheck.

Example:

- `Prometheus UI on: http://192.168.1.121:8081`
- `Grafana UI on: http://192.168.1.121:8080 w/ admin/trendmicro`

</details>

<details>
<summary>MacOS</summary>

A file called `services` is either created or updated with the link and the credentials to connect to smartcheck.

Example:

- `Prometheus UI on: http://prometheus`
- `Grafana UI on: http://grafana w/ admin/trendmicro`

</details>

<details>
<summary>Cloud9</summary>

See: [Access Smart Check (Cloud9)](#access-smart-check-cloud9), but use the `proxy_listen_port`s configured in your config.json (default: 8080 (grafana) and 8081 (prometheus)) and choose Source Anywhere. Don't forget to check your inbound rules to allow these ports.

Alternatively, you can get the configured port for the service with `cat services`.

Access to the services should then be possible with the public ip of your Cloud9 instance with your configured port(s).

Example:

- Grafana: <http://YOUR-CLOUD9-PUBLIC-IP:8080>
- Prometheus: <http://YOUR-CLOUD9-PUBLIC-IP:8081>

</details>

## Add-On: Falco

The deployment of Falco runtime security is very straigt forward with the playground. Simply execute the script `deploy-falco.sh`, everything else is prepared.

> Note for MacOS: Falco is currently unsupported on MacOS

```sh
./deploy-falco.sh
```

The web-ui is available on <http://HOSTNAME:8082/ui> (default)

To test the k8s auditing try to create a configmap:

```sh
cat <<EOF | kubectl apply -f -
apiVersion: v1
data:
  ui.properties: |
    color.good=purple
    color.bad=yellow
    allow.textmode=true
  access.properties: |
    aws_access_key_id = AKIAXXXXXXXXXXXXXXXX
    aws_secret_access_key = 1CHPXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
kind: ConfigMap
metadata:
  name: awscfg
EOF
```

Falco is integrated with Prometheus and Grafana as well. A Dashboard is available for import with the ID 11914.

![alt text](images/falco-grafana.png "Grafana Dashboard")

If you want to test out own falco rules, create a file called `falco/additional_rules.yaml` write your rules. It will be included when running `deploy-falco.sh`.

Example:

```yaml
- macro: container
  condition: container.id != host

- macro: spawned_process
  condition: evt.type = execve and evt.dir=<

- rule: (AR) Run shell in container
  desc: a shell was spawned by a non-shell program in a container. Container entrypoints are excluded.
  condition: container and proc.name = bash and spawned_process and proc.pname exists and not proc.pname in (bash, docker)
  output: "Shell spawned in a container other than entrypoint (user=%user.name container_id=%container.id container_name=%container.name shell=%proc.name parent=%proc.pname cmdline=%proc.cmdline)"
  priority: WARNING
```

### Generate some events

```sh
docker run -it --rm falcosecurity/event-generator run syscall --loop
```

### Fun with privileged mode

```sh
function shell () {
  kubectl run shell --restart=Never -it --image mawinkler/kod:latest \
  --rm --attach \
  --overrides \
    '
    {
      "spec":{
        "hostPID": true,
        "containers":[{
          "name":"kod",
          "image": "mawinkler/kod:latest",
          "imagePullPolicy": "Always",
          "stdin": true,
          "tty": true,
          "command":["/bin/bash"],
          "nodeSelector":{
            "dedicated":"master"
          },
          "securityContext":{
            "privileged":true
          }
        }]
      }
    }
    '
}
```

You can paste this into a new file `shell.sh` and source the file.

```sh
source shell.sh
```

Then you can type the following to demonstrate a privilege escalation in Kubernetes.

```sh
shell
```

If you don't see a command prompt, try pressing enter.

```sh
root@shell:/# godmode
root@playground-control-plane:/# 
```

You're now on the control plane of the cluster and should be kubernetes-admin.

If you're wondering what you can do now...

```sh
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
kubectl auth can-i create deployments -n kube-system
```

```sh
kubectl create deployment echo --image=inanimate/echo-server
kubectl get pods
```

### Access Falco UI

Follow the steps for your platform below.

<details>
<summary>Linux</summary>

By default, the Falco UI is on port 8082.

A file called `services` is either created or updated with the link and the credentials to connect to smartcheck.

Example:

- `Falco UI on: http://192.168.1.121:8082/ui/#/`

</details>

<details>
<summary>MacOS</summary>

***Currently not supported***

</details>

<details>
<summary>Cloud9</summary>

See: [Access Smart Check (Cloud9)](#access-smart-check-cloud9), but use the `proxy_listen_port`s configured in your config.json (default: 8082) and choose Source Anywhere. Don't forget to check your inbound rules to allow the port.

Alternatively, you can get the configured port for the service with `cat services`.

Access to the services should then be possible with the public ip of your Cloud9 instance with your configured port(s).

Examle

- Falco UI: <http://YOUR-CLOUD9-PUBLIC-IP:8082/ui/#/>

</details>

## Add-On: Krew

Krew is a tool that makes it easy to use kubectl plugins. Krew helps you discover plugins, install and manage them on your machine. It is similar to tools like apt, dnf or brew. Today, over 130 kubectl plugins are available on Krew.

Example usage:

```sh
kubectl krew list
kubectl krew install tree
```

The tree command is a kubectl plugin to browse Kubernetes object hierarchies as a tree.

```sh
kubectl tree node playground-control-plane -A
```

## Add-On: Starboard

Fundamentally, Starboard gathers security data from various Kubernetes security tools into Kubernetes Custom Resource Definitions (CRD). These extend the Kubernetes APIs so that users can manage and access security reports through the Kubernetes interfaces, like kubectl.

To deploy it, run

```sh
./deploy-starboard.sh
```

```sh
kubectl logs -f -n starboard deployment/starboard-starboard-operator
```

Workload Scanning

```sh
kubectl get job -n starboard
kubectl get vulnerabilityreports --all-namespaces -o wide
kubectl get configauditreports --all-namespaces -o wide
```

Infrastructure Scanning - The operator discovers also Kubernetes nodes and runs CIS Kubernetes Benchmark checks on each of them. The results are stored as CISKubeBenchReport objects.

```sh
kubectl get ciskubebenchreports -o wide
```

Inspect any of the reports run something like this

```sh
kubectl describe vulnerabilityreport -n kube-system daemonset-kindnet-kindnet-cni
```

## Add-On: Open Policy Agent

The Open Policy Agent (OPA, pronounced “oh-pa”) is an open source, general-purpose policy engine that unifies policy enforcement across the stack. OPA provides a high-level declarative language that lets you specify policy as code and simple APIs to offload policy decision-making from your software. You can use OPA to enforce policies in microservices, Kubernetes, CI/CD pipelines, API gateways, and more.

You don’t have to write policies on your own at the beginning of your journey, OPA and Gatekeeper both have excellent community libraries. You can have a look, fork them, and use them in your organization from here, [OPA](https://github.com/open-policy-agent/library), and [Gatekeeper](https://github.com/open-policy-agent/gatekeeper-library) libraries.

### Example Policy: Registry Whitelisting

```sh
cat <<EOF >opa/registry-whitelist.rego
package kubernetes.admission

deny[msg] {
  input.request.kind.kind == "Pod"
  image := input.request.object.spec.containers[_].image
  not startswith(image, "172.18.255.1/")
  msg := sprintf("Image is not from our trusted cluster registry: %v", [image])
}
EOF

kubectl -n opa create configmap registry-whitelist --from-file=opa/registry-whitelist.rego
```

Try to create a deployment

```sh
kubectl create deployment echo --image=inanimate/echo-server
```

If you now run a `kubectl get pods`, the echo-server should ***NOT*** show up.

Access the logs from OPA

```sh
kubectl -n opa logs -l app=opa -c opa -f
```

There should be something like

```json
"message": "Error creating: admission webhook \"validating-webhook.openpolicyagent.org\" denied the request: Image is not from our trusted cluster registry: inanimate/echo-server",
```

## Add-On: Gatekeeper

Gatekeeper is a customizable admission webhook for Kubernetes that dynamically enforces policies executed by the OPA. Gatekeeper uses CustomResourceDefinitions internally and allows us to define ConstraintTemplates and Constraints to enforce policies on Kubernetes resources such as Pods, Deployments, Jobs.

OPA/Gatekeeper uses its own declarative language called Rego, a query language. You define rules in Rego which, if invalid or returned a false expression, will trigger a constraint violation and blocks the ongoing process of creating/updating/deleting the resource.

***ConstraintTemplate***

A ConstraintTemplate consists of both the Rego logic that enforces the Constraint and the schema for the Constraint, which includes the schema of the CRD and the parameters that can be passed into a Constraint.

***Constraint***

Constraint is an object that says on which resources are the policies applicable, and also what parameters are to be queried and checked to see if they are available in the resource manifest the user is trying to apply in your Kubernetes cluster. Simply put, it is a declaration that its author wants the system to meet a given set of requirements.

### Example Policy: Namespace Label Mandates

There is an example within the gatekeeper directory which you can apply by doing

```sh
kubectl apply -f gatekeeper/constrainttemplate.yaml
kubectl apply -f gatekeeper/constraints.yaml
```

From now on, any new namespace being created requires labels set for `stage`, `status` and `zone`.

To test it, run

```sh
kubectl create namespace nginx --dry-run=client -o yaml | kubectl apply -f -
```

```sh
Error from server ([label-check] 

DENIED. 
Reason: Our org policy mandates the following labels: 
You must provide these labels: {"stage", "status", "zone"}): error when creating "STDIN": admission webhook "validation.gatekeeper.sh" denied the request: [label-check] 

DENIED. 
Reason: Our org policy mandates the following labels: 
You must provide these labels: {"stage", "status", "zone"}
```

A valid namespace definition could look like the following:

```sh
cat <<EOF | kubectl apply -f - -o yaml
apiVersion: v1
kind: Namespace
metadata:
  name: nginx
  labels:
    zone: eu-central-1
    stage: dev
    status: ready
EOF
```

A subsequent nginx deployment can be done via:

```sh
kubectl create deployment --image=nginx --namespace nginx nginx
```

## Play with the Playground

If you wanna play within the playground and you're running it either on Linux or Cloud9, follow the lab guide [Play with the Playground (on Linux & Cloud9)](docs/play-on-linux.md).

If you're running the playground on MacOS, follow the lab guide [Play with the Playground (on MacOS)](docs/play-on-macos.md).

Both guides are basically identical, but since access to some services is different on Linux and MacOS there are two guides available.
