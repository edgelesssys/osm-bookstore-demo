# MarbleRun - OSM demo
Requirements:
* Kubernetes installed and configured (e.g. `minikube`)
* Docker with `buildx` support
* MarbleRun CLI setup
* OSM CLI setup

>*NOTE: The demo is currently running in Simulation mode.*

1. Install OSM

    ```bash
    osm install --set=OpenServiceMesh.enablePermissiveTrafficPolicy=true --set=OpenServiceMesh.enableEgress=true
    ```

1. Setup MarbleRun
  
    Install the control plane
    ```bash
    marblerun install --simulation
    marblerun check
    ```

    Port-forward the Coordinator to localhost
    ```bash
    export MARBLERUN=localhost:4433
    kubectl -n marblerun port-forward svc/coordinator-client-api 4433:4433 --address localhost >/dev/null &
    ```

    Set the manifest
    ```bash
    marblerun manifest set marblerun-manifest.json $MARBLERUN --insecure
    ```

1. Create the required namespaces, add them to OSM and enable MarbleRun injection
  
    ```bash
    for i in bookstore bookbuyer bookthief bookwarehouse; do kubectl create ns $i; done
    osm namespace add bookstore bookbuyer bookthief bookwarehouse
    marblerun namespace add bookstore bookbuyer bookthief bookwarehouse --no-sgx-injection
    ```

1. Deploy the applications

    ```bash
    kubectl apply -f manifests/apps/bookwarehouse.yaml
    kubectl apply -f manifests/apps/bookstore.yaml
    kubectl apply -f manifests/apps/bookbuyer.yaml
    kubectl apply -f manifests/apps/bookthief.yaml
    ```

1. Check if everything is running ;)

    Forward bookbuyer, bookthief, and bookstore web-frontend to localhost
    ```bash
    ./scripts/port-forward-all.sh
    ```

    In a browser, open up the following urls:
    * http://localhost:8080 - bookbuyer
    * http://localhost:8083 - bookthief
    * http://localhost:8084 - bookstore

    You should see increasing numbers in books bought/stolen for bookbuyer and bookthief, as well as increasing numbers in books sold for bookstore

# Docker

1. Generate a signing key

    ```bash
    openssl genrsa -out private.pem -3 3072
    ```

1. Build the images

    ```
    DOCKER_REGISTRY=<your_registry> SIGNING_KEY=private.pem make docker
    ```


# TODO:
* Get the demo working with MarbleRun being part of OSM. This will require traffic policies for gRPC connections to the Coordinator.
* The book warehouse recently switched to MySQL for storage... Wouldn't it be interesting to integrate EdgelessDB here, too?

# License

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
