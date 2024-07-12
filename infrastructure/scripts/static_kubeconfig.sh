#!/bin/bash

yc managed-kubernetes cluster list
export CLUSTER_ID=cath838q8i8bjtg9qih7

yc managed-kubernetes cluster \
   get-credentials cath838q8i8bjtg9qih7 \
   --external --kubeconfig=test.kubeconfig
   
yc managed-kubernetes cluster get --id $CLUSTER_ID --format json | \
  jq -r .master.master_auth.cluster_ca_certificate | \
  awk '{gsub(/\\n/,"\n")}1' > ca.pem
  
cat <<EOF > sa.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sa
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: sa
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: sa
  namespace: kube-system
---
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: sa-token
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: "sa"
EOF
    
SA_TOKEN=$(kubectl -n kube-system get secret $(kubectl -n kube-system get secret | \
  grep sa-token | \
  awk '{print $1}') -o json | \
  jq -r .data.token | \
  base64 -d)


MASTER_ENDPOINT=$(yc managed-kubernetes cluster get --id $CLUSTER_ID \
  --format json | \
  jq -r .master.endpoints.external_v4_endpoint)
  
  
kubectl config set-cluster k8s-cluster \
  --certificate-authority=ca.pem \
  --server=$MASTER_ENDPOINT \
  --kubeconfig=test.kubeconfig
  
kubectl config set-credentials sa \
  --token=$SA_TOKEN \
  --kubeconfig=test.kubeconfig
  
  
kubectl config set-context default \
  --cluster=k8s-cluster \
  --user=sa \
  --kubeconfig=test.kubeconfig
