# MarbleRun - OSM demo
Requirements:
* Kubernetes installed and configured (e.g. `minikube`)
* Docker with `buildx` support
* MarbleRun CLI setup
* OSM CLI setup

*NOTE: The demo is currently running in Simulation mode.*


1. Build the demo application images
  
    ```bash
     make docker-build-bookbuyer && make docker-build-bookstore && make docker-build-bookthief && make docker-build-bookwarehouse
    ```

1. Install OSM

    ```bash
    osm install --set=OpenServiceMesh.enablePermissiveTrafficPolicy=true --set=OpenServiceMesh.enableEgress=true
    ```

1. Setup MarbleRun
  
    ```bash
    marblerun install --simulation
    marblerun check
    export MARBLERUN=localhost:4433
    kubectl -n marblerun port-forward svc/coordinator-client-api 4433:4433 --address localhost >/dev/null &
    marblerun manifest set demo/marblerun-manifest.json $MARBLERUN --insecure
    ```

1. Create the required namespaces, add them to OSM and enable MarbleRun injection
  
    ```bash
    for i in bookstore bookbuyer bookthief bookwarehouse; do kubectl create ns $i; done
    osm namsepace add bookstore bookbuyer bookthief bookwarehouse
    marblerun namespace add bookstore bookbuyer bookthief bookwarehouse
    ```

1. Deploy the applications

    ```bash
    kubectl apply -f docs/example/manifests/apps/bookwarehouse.yaml
    kubectl apply -f docs/example/manifests/apps/bookstore.yaml
    kubectl apply -f docs/example/manifests/apps/bookbuyer.yaml
    kubectl apply -f docs/example/manifests/apps/bookthief.yaml
    ```

1. Check if everything is running ;)

    Forward bookbuyer, bookthief, and bookstore web-frontend to localhost
    ```bash
    cp .env.example .env
    ./scripts/port-forward-all.sh
    ```

    In a browser, open up the following urls:
    * http://localhost:8080 - bookbuyer
    * http://localhost:8083 - bookthief
    * http://localhost:8084 - bookstore

    You should see increasing numbers in books bought/stolen for bookbuyer and bookthief, as well as increasing numbers in books sold for bookstore

# TODO:
* Get the demo working with MarbleRun being part of OSM. This will require traffic policies for gRPC connections to the Coordinator.
* Migrate the demo to its own repo
* The book warehouse recently switched to MySQL for storage... Wouldn't it be interesting to integrate EdgelessDB here, too?
