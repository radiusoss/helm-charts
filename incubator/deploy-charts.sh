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

function step_1() {

  helm install -n heapster \
    --namespace kube-system \
    stable/heapster

  helm install k8s-dashboard \
    --namespace kube-system \
    --set=httpPort=3000,resources.limits.cpu=200m,rbac.create=true \
    -n k8s-dashboard

  helm install etcd \
    --set StorageClass=gp2 \
    -n kuber-etcd

  helm install \
    --set persistence.nameNode.enabled=true \
    --set persistence.nameNode.storageClass=gp2 \
    --set persistence.dataNode.enabled=true \
    --set persistence.dataNode.storageClass=gp2 \
    --set hdfs.dataNode.replicas=3 \
    hdfs-k8s \
    -n hdfs-k8s

  helm install spark-k8s \
    -n spark-k8s

  helm install \
    spitfire \
    -n spitfire

  cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: spitfire-lb
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: tcp
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: spitfire
EOF

  echo """
# Check HDFS

  kubectl exec -it hdfs-k8s-hdfs-k8s-hdfs-nn-0 -- hdfs dfsadmin -report

# Run K8S Proxy

  kubectl proxy

# Browse Dashboard

  http://localhost:8001/api/v1/namespaces/kube-system/services/http:k8s-dashboard-kubernetes-dashboard:/proxy/#!/overview?namespace=_all

# Browse Apache Zeppelin

  http://localhost:8001/api/v1/namespaces/default/services/http:spitfire-spitfire:8080/proxy

# Before running the next step, check the LoadBalancer Ingress value for \`spitifire-lb\` (rerun in a few minutes if no hostname is shown)

   kubectl describe services spitfire-lb | grep Ingress
"

}

function step_2() {

  kubectl describe services spitfire-lb | grep Ingress
  echo
  echo "Please enter the hostname created for the spitfire-lb:"
  read SPITFIRE_LB_HOSTNAME
  echo
  echo "You entered: $SPITFIRE_LB_HOSTNAME"
  echo
  echo "We will now deploy the Kuber chart..."
  echo

  helm install \
    --set azure.applicationId="f145fb87-901d-4519-ad39-573c30770e6f" \
    --set azure.redirect="http://$SPITFIRE_LB_HOSTNAME" \
    --set azure.scope="User.ReadBasic.All+Contacts.Read+Mail.Send+Files.ReadWrite+Notes.ReadWrite" \
    --set hdfs="" \
    --set kuber.plane="" \
    --set kuber.rest="" \
    --set kuber.ws="" \
    --set spitfire.rest="http://$SPITFIRE_LB_HOSTNAME" \
    --set spitfire.ws="ws://$SPITFIRE_LB_HOSTNAME" \
    --set twitter.redirect="" \
    --set kuber.insecureBindAddress="0.0.0.0" \
    kuber \
    -n kuber

  cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: kuber-lb
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: tcp
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 9091
  selector:
    app: kuber
EOF

  echo "

# Run K8S Proxy

  kubectl proxy

# Browse Kuber

  http://localhost:8001/api/v1/namespaces/default/services/http:kuber-kuber:9091/proxy

# Check the LoadBalancer Ingress value for \`kuber-lb\` (rerun in a few minutes if no hostname is shown)

   kubectl describe services kuber-lb | grep Ingress

"
  kubectl describe services kuber-lb | grep Ingress
  echo

}

# step_1
step_2
