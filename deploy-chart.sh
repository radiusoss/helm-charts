#!/usr/bin/env bash

# Licensed to Datalayer (http://datalayer.io) under one or more
# contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership. Datalayer licenses this file
# to you under the Apache License, Version 2.0 (the 
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

function heapster() {
  helm install -n heapster \
    --namespace kube-system \
    heapster
}

function dashboard() {
  helm install k8s-dashboard \
    --namespace kube-system \
    --set=httpPort=3000,resources.limits.cpu=200m,rbac.create=true \
    -n k8s-dashboard
}

function etcd() {
  helm install etcd \
    --set StorageClass=gp2 \
    -n kuber-etcd
}

function hdfs() {
  helm install \
    --set imagePullPolicy=Always \
    --set persistence.nameNode.enabled=true \
    --set persistence.nameNode.storageClass=gp2 \
    --set persistence.dataNode.enabled=true \
    --set persistence.dataNode.storageClass=gp2 \
    --set hdfs.dataNode.replicas=3 \
    hdfs \
    -n hdfs
}

function spark() {
  helm install spark \
    --set spark.imagePullPolicy=Always \
    -n spark
}

function spitfire() {

  helm install \
    --set spitfire.imagePullPolicy=Always \
    --set spitfire.notebookRepo=https://github.com/datalayer/notebook-init.git \
    spitfire \
    -n spitfire

  cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: spitfire-lb
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: spitfire
    release: spitfire
EOF

  cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: spitfire-spark-ui-lb
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 4040
  selector:
    app: spitfire
    release: spitfire
EOF

echo """
# Check HDFS

  kubectl exec -it hdfs-hdfs-hdfs-nn-0 -- hdfs dfsadmin -report

# Run K8S Proxy

  kubectl proxy

# Browse Dashboard

  http://localhost:8001/api/v1/namespaces/kube-system/services/http:k8s-dashboard-kubernetes-dashboard:/proxy/#!/overview?namespace=_all

# Browse Spitfire

  http://localhost:8001/api/v1/namespaces/default/services/http:spitfire-spitfire:8080/proxy
"

}

function kuber_plane() {

  echo "
  
# Before running the next step, check the LoadBalancer Ingress value for \`spitifire-lb\` (rerun in a few minutes if no hostname is shown)

   kubectl describe services spitfire-lb | grep Ingress
"
  kubectl describe services spitfire-lb
  echo
  kubectl describe services spitfire-lb | grep Ingress
  echo
  echo "Please enter the hostname created for the spitfire-lb:"
  read SPITFIRE_LB_HOSTNAME
  echo
  echo "You entered: $SPITFIRE_LB_HOSTNAME"
  echo
  echo "We will now deploy Kuber Plane..."
  echo

  helm install \
    --set kuber.imagePullPolicy=Always \
    --set hdfs="" \
    --set kuber.insecureBindAddress="0.0.0.0" \
    --set kuber.plane="" \
    --set kuber.rest="" \
    --set kuber.ws="" \
    --set microsoft.applicationId="f7194ac8-ff71-47f6-839c-e3b20f247ebc" \
    --set microsoft.redirect="" \
    --set microsoft.secret="seuLJSMO4\$ueukZU4578)}@" \
    --set microsoft.scope="User.ReadBasic.All" \
    --set spitfire.rest="https://$SPITFIRE_LB_HOSTNAME" \
    --set spitfire.ws="wss://$SPITFIRE_LB_HOSTNAME" \
    --set twitter.consumerKey="Fsy5JzXec7wY5mPPsEdsNkAe4" \
    --set twitter.consumerSecret="q0suooaCz17lkiHZZi35OoXfBJrAPRyUBi0AssEppP9YXxBSRz" \
    --set twitter.redirect="" \
    kuber-plane \
    -n kuber-plane

  cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: kuber-plane-lb
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: 3600
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 9091
  selector:
    app: kuber-plane
    release: kuber-plane
EOF

  echo "

# Run K8S Proxy

  kubectl proxy

# Browse Kuber

  http://localhost:8001/api/v1/namespaces/default/services/http:kuber-kuber:9091/proxy

# Check the LoadBalancer Ingress value for \`kuber-lb\` (rerun in a few minutes if no hostname is shown)

   kubectl describe services kuber-plane-lb | grep Ingress
"
  kubectl describe services kuber-plane-lb
  echo
  kubectl describe services kuber-plane-lb | grep Ingress
  echo

}

function ingress() {
  
  cat << EOF | kubectl create -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: nginx
  name: spitfire-ingress
  namespace: default
spec:
  rules:
  - http:
      paths:
      - path: /
        backend:
          serviceName: spitfire-spitfire
          servicePort: 8080
EOF

  cat << EOF | kubectl create -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: nginx
  name: kuber-ingress
  namespace: default
spec:
  rules:
  - http:
      paths:
      - path: /
        backend:
          serviceName: kuber-kuber
          servicePort: 9091
EOF

}


function options() {
  echo "Valid options are: heapster | dashboard | etcd | spitfire | hdfs | spark | spitfire | kuber_plane | ingress" 1>&2    
}

CMD="$1"
if [ -z "$CMD" ]; then
  echo "No command to execute has been provided." 1>&2  
  options
  exit 1
fi

case "$CMD" in

  heapster)
    heapster
    ;;

  dashboard)
    dashboard
    ;;

  etcd)
    etcd
    ;;

  hdfs)
    hdfs
    ;;

  spark)
    spark
    ;;

  spitfire)
    spitfire
    ;;

  ingress)
    ingress
    ;;

  *)
    echo "Unknown command: $CMD" 1>&2
    options
    exit 1

esac
