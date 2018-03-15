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

function k8s-dashboard() {
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
  helm upgrade spark spark \
    --set spark.imagePullPolicy=Always 
}

function spitfire() {

  helm upgrade spitfire spitfire \
    --set spitfire.hostNetwork=false \
    --set spitfire.imagePullPolicy=Always \
    --set spitfire.notebookRepo=https://github.com/radiusoss/notebook-init.git 

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

function explorer() {
  
  echo "Please enter the hostname created for the spitfire-lb:"
  #read SPITFIRE_LB_HOSTNAME
  export SPITFIRE_LB_HOSTNAME=spitfire.radiusiot.com
  echo
  echo "You entered: $SPITFIRE_LB_HOSTNAME"
  echo
  echo "We will now deploy Kuber Board..."
  echo

  helm upgrade explorer explorer \
    --set explorer.hostNetwork=false \
    --set explorer.imagePullPolicy="Always" \
    --set google.apiKey="AIzaSyA4GOtTmfHmAL5t8jn0LBZ_SsInQukugAU" \
    --set google.clientId="448379464054-clm37e3snnt3154cak4o5jqqmu4phs92.apps.googleusercontent.com" \
    --set google.redirect="" \
    --set google.secret="ZVxzNkOk98T2vEGbF5L-EQX3" \
    --set google.scope="profile email https://www.googleapis.com/auth/contacts.readonly https://www.googleapis.com/auth/user.emails.read" \
    --set hdfs="" \
    --set kuber.insecureBindAddress="0.0.0.0" \
    --set kuber.insecurePort="9091" \
    --set kuber.manageReservations="true" \
    --set kuber.rest="" \
    --set kuber.ui="" \
    --set kuber.ws="" \
    --set microsoft.applicationId="f7194ac8-ff71-47f6-839c-e3b20f247ebc" \
    --set microsoft.redirect="" \
    --set microsoft.secret="seuLJSMO4\$ueukZU4578)}@" \
    --set microsoft.scope="User.ReadBasic.All" \
    --set spitfire.rest="https://$SPITFIRE_LB_HOSTNAME" \
    --set spitfire.ws="wss://$SPITFIRE_LB_HOSTNAME" \
    --set twitter.consumerKey="Fsy5JzXec7wY5mPPsEdsNkAe4" \
    --set twitter.consumerSecret="q0suooaCz17lkiHZZi35OoXfBJrAPRyUBi0AssEppP9YXxBSRz" \
    --set twitter.redirect=""

  echo "

# Run K8S Proxy

  kubectl proxy

# Browse Kuber

  http://localhost:8001/api/v1/namespaces/default/services/http:kuber-kuber:9091/proxy

# Check the LoadBalancer Ingress value for \`explorer-lb\` (rerun in a few minutes if no hostname is shown)

   kubectl describe services explorer-lb | grep Ingress
"

}

function cert-manager() {
  kubectl create secret tls issuer-key --cert=ca.crt --key=ca.key --namespace default
}

function ingress() {
  helm upgrade ingress ingress -f ingress/values-explorer.yaml
  
  helm upgrade alb-ingress alb-ingress-controller-helm -f alb-ingress-controller-helm/values-alb.yaml

  #helm registry upgrade quay.io/coreos/alb-ingress-controller-helm alb-ingress -f ingress/values-alb.yaml

  export DNS_NAME=$DNS_NAME
  cat << EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: spitfire
  namespace: default
  annotations:
    "kubernetes.io/ingress.class": "alb"
    "alb.ingress.kubernetes.io/scheme": "internet-facing"
    "alb.ingress.kubernetes.io/subnets": "subnet-fe6fbd87,subnet-0a8e7541"
    "alb.ingress.kubernetes.io/backend-protocol": "HTTP"
    "alb.ingress.kubernetes.io/healthcheck-protocol": "HTTP"
    "alb.ingress.kubernetes.io/healthcheck-path": "/spitfire"
    "alb.ingress.kubernetes.io/certificate-arn": "arn:aws:acm:us-west-2:100392638540:certificate/faa2bfbf-ff19-4e12-9bbe-220af0b77146"
    "alb.ingress.kubernetes.io/connection-idle-timeout": "3600"
    "alb.ingress.kubernetes.io/successCodes": "200,202,302"
spec:
  rules:
  - host: spitfire.radiusiot.com
    http:
      paths: 
      - path: /
        backend:
          serviceName: spitfire-spitfire
          servicePort: 80
EOF

  cat << EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: explorer
  namespace: default
  annotations:
    "kubernetes.io/ingress.class": "nginx"
    "ingress.kubernetes.io/ssl-redirect": "true"
spec:
#  tls:
#  - hosts:
#    - "platform.radiusiot.com"
#    secretName: issuer-key
  rules:
  - host: platform.radiusiot.com
    http:
      paths: 
      - path: /
        backend:
          serviceName: explorer-explorer
          servicePort: 9091
EOF

}

function options() {
  echo "Valid options are: heapster | k8s-dashboard | etcd | hdfs | spark | spitfire | explorer | cert-manager | ingress" 1>&2    
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

  k8s-dashboard)
    k8s-dashboard
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

  explorer)
    explorer
    ;;

  cert-manager)
    cert-manager
    ;;

  ingress)
    ingress
    ;;

  *)
    echo "Unknown command: $CMD" 1>&2
    options
    exit 1

esac
