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

function explorer() {

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
  echo "We will now deploy Kuber Board..."
  echo

  helm install \
    --set google.apiKey="AIzaSyA4GOtTmfHmAL5t8jn0LBZ_SsInQukugAU" \
    --set google.clientId="448379464054-clm37e3snnt3154cak4o5jqqmu4phs92.apps.googleusercontent.com" \
    --set google.redirect="" \
    --set google.secret="ZVxzNkOk98T2vEGbF5L-EQX3" \
    --set google.scope="profile email https://www.googleapis.com/auth/contacts.readonly https://www.googleapis.com/auth/user.emails.read" \
    --set hdfs="" \
    --set kuber.imagePullPolicy="Always" \
    --set kuber.insecureBindAddress="0.0.0.0" \
    --set kuber.ui="" \
    --set kuber.rest="" \
    --set kuber.ws="" \
    --set microsoft.applicationId="f7194ac8-ff71-47f6-839c-e3b20f247ebc" \
    --set microsoft.redirect="" \
    --set microsoft.secret="seuLJSMO4\$ueukZU4578)}@" \
    --set microsoft.scope="User.ReadBasic.All" \
    --set spitfire.rest="http://$SPITFIRE_LB_HOSTNAME" \
    --set spitfire.ws="ws://$SPITFIRE_LB_HOSTNAME" \
    --set twitter.consumerKey="Fsy5JzXec7wY5mPPsEdsNkAe4" \
    --set twitter.consumerSecret="q0suooaCz17lkiHZZi35OoXfBJrAPRyUBi0AssEppP9YXxBSRz" \
    --set twitter.redirect="" \
    explorer \
    -n explorer

  cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: explorer-lb
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: 3600
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 9091
  selector:
    app: explorer
    release: explorer
EOF

  echo "

# Run K8S Proxy

  kubectl proxy

# Browse Kuber

  http://localhost:8001/api/v1/namespaces/default/services/http:kuber-kuber:9091/proxy

# Check the LoadBalancer Ingress value for \`explorer-lb\` (rerun in a few minutes if no hostname is shown)

   kubectl describe services explorer-lb | grep Ingress
"
  kubectl describe services explorer-lb
  echo
  kubectl describe services explorer-lb | grep Ingress
  echo

}

function ingress() {

#    cert-manager \
  helm install \
    stable/cert-manager \
    --name cert-manager \
    --namespace default

  export COMMON_NAME=datalayer.io
  export DNS_NAME=a90d1550f12ea11e882360208f03724d-1324046284.eu-central-1.elb.amazonaws.com

  openssl genrsa -out ca.key 2048
  openssl req -x509 -new -nodes -key ca.key -subj "/CN=${COMMON_NAME}" -days 3650 -out ca.crt
  kubectl create secret tls issuer-key --cert=ca.crt --key=ca.key --namespace default

  cat << EOF | kubectl apply -f -
apiVersion: certmanager.k8s.io/v1alpha1
kind: Issuer
metadata:
  name: ca-issuer
  namespace: default
spec:
  ca:
    secretName: issuer-key
EOF

  cat << EOF | kubectl apply -f -
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: "${DNS_NAME}-ca-cert"
  namespace: default
spec:
  secretName: "${DNS_NAME}-ca-tls"
  issuerRef:
    name: ca-issuer
    kind: Issuer
  commonName: "${COMMON_NAME}"
  dnsNames:
  - "${DNS_NAME}"
EOF

  kubectl get secret ${DNS_NAME}-ca-tls -o yaml
  kubectl describe certificate ${DNS_NAME}-ca-cert

# ---

  cat << EOF | kubectl apply -f -
apiVersion: certmanager.k8s.io/v1alpha1
kind: Issuer
metadata:
  name: letsencrypt-issuer
  namespace: default
spec:
  acme:
    server: https://acme-v01.api.letsencrypt.org/directory
    email: eric@datalayer.io
    privateKeySecretRef:
      name: issuer-key
    http01: {}
EOF

  cat << EOF | kubectl apply -f -
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: "${DNS_NAME}-letsencrypt-cert"
  namespace: default
spec:
  secretName: "${DNS_NAME}-letsencrypt-tls"
  issuerRef:
    name: letsencrypt-issuer
    kind: Issuer
  commonName: "${COMMON_NAME}"
  acme:
    config:
    - http01: 
        ingressClass: nginx
      domains:
      - "${DNS_NAME}"
EOF

  kubectl get secret ${DNS_NAME}-letsencrypt-tls -o yaml
  kubectl describe certificate ${DNS_NAME}-letsencrypt-cert

# ---

  helm install ingress \
    -n ingress

  cat << EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: explorer
  namespace: default
  annotations:
#    ingress.kubernetes.io/ssl-redirect: true
    kubernetes.io/ingress.class: nginx
    certmanager.k8s.io/issuer: letsencrypt-issuer
spec:
  rules:
  - host: "${DNS_NAME}"
    http:
      paths:
      - path: /spitfire
        backend:
          serviceName: spitfire-spitfire
          servicePort: 8080
      - path: /kuber
        backend:
          serviceName: explorer-kuber
          servicePort: 9091
      - path: /
        backend:
          serviceName: explorer-kuber
          servicePort: 9091
  tls:
    - hosts:
        - "${DNS_NAME}"
EOF

}

function options() {
  echo "Valid options are: heapster | k8s-dashboard | etcd | hdfs | spark | spitfire | explorer | ingress" 1>&2    
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

  ingress)
    ingress
    ;;

  *)
    echo "Unknown command: $CMD" 1>&2
    options
    exit 1

esac
