# MarbleRun - OSM demo

Based on the [bookstore demo](https://docs.openservicemesh.io/docs/getting_started/quickstart/manual_demo/) by [Open Service Mesh](https://github.com/openservicemesh/osm), this demo showcases how [MarbleRun](https://github.com/edgelesssys/marblerun) can be integrated into a Kubernetes cluster managed with OSM.

## Changes made to the original demo

* All traffic between `bookbuyer`, `bookstore`, and `bookthief`, including connections to their webpage, is end-to-end encrypted using MarbleRun's [Transparent TLS feature](https://docs.edgeless.systems/marblerun/#/features/transparent-TLS). No changes to source code required!
* Webpage templates are embedded into the applications, instead of loaded from an unsecure host filesystem
* `bookwarehouse` uses [EdgelessDB](https://github.com/edgelesssys/edgelessdb) as a storage backend instead of MySQL

## Requirements:
* a cluster running Kubernetes v1.19 or greater (e.g. [`minikube`](https://minikube.sigs.k8s.io/docs/start/)) with [SGX enabled nodes](https://docs.edgeless.systems/marblerun/#/deployment/kubernetes)
* Docker with `buildx` support
* The [MarbleRun command-line tool](https://docs.edgeless.systems/marblerun/#/reference/cli)
* The [OSM command-line tool](https://docs.openservicemesh.io/docs/guides/cli/) setup
* The [Kubernetes command-line tool](https://kubernetes.io/docs/tasks/tools/#kubectl) - `kubectl`

## Install the control plane
### Install OSM

```bash
osm install --set=OpenServiceMesh.enablePermissiveTrafficPolicy=true --set=OpenServiceMesh.enableEgress=true
```

### Install MarbleRun
  
1. Add the MarbleRun namespace to the OSM mesh

    ```bash
    kubectl create namespace marblerun
    osm namespace add marblerun
    ```

1. Install the control plane

    ```bash
    marblerun install
    marblerun check
    ```

1. Port-forward the Coordinator to localhost

    ```bash
    export MARBLERUN=localhost:4433
    kubectl -n marblerun port-forward svc/coordinator-client-api 4433:4433 --address localhost >/dev/null &
    ```

1. Set the manifest

    The manifest defines the key properties of your confidential computing cluster.
    With the manifest we define command line arguments, environment variables, and files, for each Marble (your confidential application) in the cluster.

    ```bash
    marblerun manifest set manifests/marblerun-manifest.json $MARBLERUN
    ```

1. Retrieve MarbleRun's root certificate

    ```bash
    marblerun certificate chain $MARBLERUN -o marblerun.crt
    ```

## Deploy demo applications

### Manage application namespaces

1. Create the namespaces

    ```bash
    kubectl create namespace bookstore
    kubectl create namespace bookbuyer
    kubectl create namespace bookthief
    kubectl create namespace bookwarehouse
    ```

1. Add the new namespaces to the OSM control plane

    ```bash
    osm namespace add bookstore bookbuyer bookthief bookwarehouse
    ```

### Deploy the applications

```bash
kubectl apply -f manifests/apps/mysql.yaml
kubectl apply -f manifests/apps/bookwarehouse.yaml
kubectl apply -f manifests/apps/bookstore.yaml
kubectl apply -f manifests/apps/bookbuyer.yaml
kubectl apply -f manifests/apps/bookthief.yaml
```

## Checkpoint: What go installed?

The Open Service Mesh control plane and MarbleRun's control plane.
A Kubernetes Deployment and pods for each of `bookbuyer`, `bookthief`, `bookstore`, `bookwarehouse`, and EdgelessDB. Also, Kubernetes Services and Endpoints for `bookstore`, `bookwarehouse`, and EdgelessDB.

To view these resources on your cluster, run the following commands:
```bash
kubectl get deployments -n osm-system
kubectl get deployments -n marblerun
kubectl get deployments -n bookbuyer
kubectl get deployments -n bookthief
kubectl get deployments -n bookstore
kubectl get deployments -n bookwarehouse

kubectl get pods -n osm-system
kubectl get pods -n marblerun
kubectl get pods -n bookbuyer
kubectl get pods -n bookthief
kubectl get pods -n bookstore
kubectl get pods -n bookwarehouse

kubectl get services -n osm-system
kubectl get services -n marblerun
kubectl get services -n bookstore
kubectl get services -n bookwarehouse

kubectl get endpoints -n osm-system
kubectl get endpoints -n marblerun
kubectl get endpoints -n bookstore
kubectl get endpoints -n bookwarehouse
```

In addition, a [Kubernetes Service Account](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) was also created for each application. The Service Account serves as the application's identity which will be used later in the demo to create service-to-service access control policies.

### View the application UIs

Set up client port forwarding with the following steps to access the applications in the Kubernetes cluster. It is best to start a new terminal session for running the port forwarding script to maintain the port forwarding session, while using the original terminal to continue to issue commands.

In a new terminal session, run the following command to enable port forwarding into the Kubernetes cluster.
```bash
./scripts/port-forward-all.sh
```

In a browser, open up the following urls:
* https://localhost:8080 - bookbuyer
* https://localhost:8083 - bookthief
* https://localhost:8084 - bookstore
* https://localhost:8082 - bookstore-v2
    - _Note: This page will not be available at this time in the demo. This will become available during the SMI Traffic Split configuration set up_

You’ll be presented with a certificate warning, because your browser does not know MarbleRun’s root certificate (the authority that issued the used TLS certificates) as a root of trust. You can safely ignore this message for now and proceed to the website.
You should see increasing numbers in books bought/stolen for bookbuyer and bookthief, as well as increasing numbers in books sold for bookstore.

Alternatively you can run the `bookwatcher` terminal application to view the statistics in a single terminal window.
`bookwatcher` uses MarbleRun's root certificate to verify TLS connections to the other applications.
```bash
go run app/bookwatcher/bookwatcher.go -c marblerun.crt
```

## Traffic Policy

At the beginning we installed OSM with [Permissive Traffic Policy Mode](https://docs.openservicemesh.io/docs/guides/traffic_management/permissive_mode/) enabled.
In this mode, traffic between application services is automatically configured by `osm-controller`, and SMI policies are not enforced.
When permissive traffic policy mode is disabled, all trafic is denied by default unless explicitly allowed using a combination of SMI access and routing policies.

### Disable permissive traffic

We will now disable permissive traffic policy mode. To disable run the following command to patch the `osm-mesh-config` resource.
```bash
kubectl patch meshconfig osm-mesh-config -n osm-system -p '{"spec":{"traffic":{"enablePermissiveTrafficPolicyMode":false}}}'  --type=merge
```

The counters for `bookbuyer`, `bookthief`, and `bookstore v1` should now stop incrementing.

Additionally, since MarbleRun is part of the OSM mesh, Marble activation request will now also be denied.
Lets restart the `bookthief` deployment to test this.
```bash
kubectl rollout restart deployment -n bookthief bookthief
```

The newly created `bookthief` pod should now error on startup. Inspect the logs to verify this error occurs when the activation request is send.
```bash
kubectl logs -n bookthief deployment/bookthief bookthief
```

## Deploy SMI access control policies
At this point, applications do not have access to each other because no access control policies have been applied.

Apply the [SMI Traffic Target](https://github.com/servicemeshinterface/smi-spec/blob/v0.6.0/apis/traffic-access/v1alpha3/traffic-access.md) and [SMI Traffic Specs](https://github.com/servicemeshinterface/smi-spec/blob/v0.6.0/apis/traffic-specs/v1alpha4/traffic-specs.md) resources to define access control and routing policies for the applications to communicate:

1. Allow traffic to the MarbleRun Coordinator

    ```bash
    kubectl apply -f manifests/access/marblerun-access.yaml
    ```

    Restart `bookthief` to let the application reconnect to the MarbleRun coordinator.
    ```bash
    kubectl rollout restart deployment -n bookthief bookthief
    ```

    Restart `./scripts/port-forward-all.sh`

1. Allow traffic to `bookwarehouse` and the SQL storage backend

    ```bash
    kubectl apply -f manifests/access/bookwarehouse-access.yaml
    ```

1. Allow traffic between `bookstore`, `bookbuyer`, and `bookthief`

    ```bash
    kubectl apply -f manifests/access/traffic-access-v1.yaml
    ```

The counters for `bookbuyer`, and `bookstore` should be incrementing again:
* https://localhost:8080 - bookbuyer
* https://localhost:8084 - bookstore

However the counter is _not_ incrementing for `bookthief`:
* https://localhost:8083 - bookthief

That is because the deployed SMI Traffic Target resource only allows `bookbuyer` to communicate with the `bookstore`:
```bash
kubectl describe traffictarget -n bookstore bookstore
```

## Allowing the bookthief application to access the mesh

Currently the Bookthief application has not been authorized to participate in the service mesh communication. We will now uncomment the lines in the `manifests/access/traffic-access-v1.yaml` to allow `bookthief` to communicate with `bookstore`. Then, re-apply the manifest and watch the change in policy propagate.

Current TrafficTarget spec with commented `bookthief` kind:

```yaml
kind: TrafficTarget
apiVersion: access.smi-spec.io/v1alpha3
metadata:
  name: bookstore-v1
  namespace: bookstore
spec:
  destination:
    kind: ServiceAccount
    name: bookstore
    namespace: bookstore
  rules:
  - kind: HTTPRouteGroup
    name: bookstore-service-routes
    matches:
    - buy-a-book
    - books-bought
  sources:
  - kind: ServiceAccount
    name: bookbuyer
    namespace: bookbuyer
  #- kind: ServiceAccount
    #name: bookthief
    #namespace: bookthief
```

Updated TrafficTarget spec with uncommented `bookthief` kind:

```yaml
kind: TrafficTarget
apiVersion: access.smi-spec.io/v1alpha3
metadata:
 name: bookstore-v1
 namespace: bookstore
spec:
 destination:
   kind: ServiceAccount
   name: bookstore
   namespace: bookstore
 rules:
 - kind: HTTPRouteGroup
   name: bookstore-service-routes
   matches:
   - buy-a-book
   - books-bought
 sources:
 - kind: ServiceAccount
   name: bookbuyer
   namespace: bookbuyer
 - kind: ServiceAccount
   name: bookthief
   namespace: bookthief
```

Re-apply the access manifest with the updates.

```bash
kubectl apply -f manifests/access/traffic-access-v1-allow-bookthief.yaml
```

The counter for `bookthief` will start incrementing:
* https://localhost:8083 - bookthief

## Configure traffic split between two services

We will now demonstrate Open Service Meshe's traffic split feature, by dividing the traffic directed to the root `bookstore` service between the backends `bookstore` service and `bookstore-v2` service.

1. Deploy bookstore v2 application

    ```bash
    kubectl apply -f manifests/apps/bookstore-v2.yaml
    ```

    Wait for the `bookstore-v2` pod to be running in the `bookstore` namespace. The application will connect to the MarbleRun coordinator to register itself as a Marble and then start its service.
    
    Next, exit and restart the `scripts/port-forward-all.sh` script in order to access v2 of `bookstore`.
    * https://localhost:8082 - bookstore-v2

    The counter should _not_ be incrementing because no traffic policies have been defined to redirect traffic to the `bookstore-v2` service.

### Create SMI Traffic Split

1. Direct all traffic to `bookstore`

    Deploy the SMI traffic split policy to direct 100% of the traffic sent to the root `bookstore` service to the `bookstore` service backend.
    ```bash
    kubectl apply -f manifests/split/traffic-split-v1.yaml
    ```

    The count for books sold from `bookstore-v2` should remain at 0. This is because the current traffic split policy is weighted 100 for `bookstore`, and no other service is directly sending requests to `bookstore-v2`.

1. Split 50% of traffic to `bookstore-v2`

    Update the traffic split policy by adding the `bookstore-v2` backend to the spec and modifying the weight fields
    ```bash
    kubectl apply -f manifests/split/traffic-split-50-50.yaml
    ```

    Both book counters for `bookstore` and `bookstore-v2` should now be incrementing at an equal rate.

1. Direct all traffic to `bookstore-v2`

    ```bash
    kubectl apply -f manifests/split/traffic-split-v2.yaml
    ```

    The count for books sold from `bookstore` will stop incrementing because all traffic is redirected to the `bookstore-v2` backend


## Docker

1. Generate a signing key

    ```bash
    openssl genrsa -out private.pem -3 3072
    ```

1. Build the images

    ```
    DOCKER_REGISTRY=<your_registry> SIGNING_KEY=private.pem make docker
    ```

>Note: If you build your own images, you will have to change the used images in `manifests/apps/`

## License

Copyright 2020 Open Service Mesh Authors.

Copyright 2020 Edgeless Systems GmbH.

and others that have contributed code to the public domain.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
