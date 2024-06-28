#!/bin/bash

yc iam key create \
  --service-account-name sa \
  --output authorized-key.json
  
yc cm certificate add-access-binding \
  --id fpq7ajd40buasl4ilckg \
  --service-account-name sa \
  --role certificate-manager.certificates.downloader
  
yc cm certificate list-access-bindings --id fpq7ajd40buasl4ilckg

helm repo add external-secrets https://charts.external-secrets.io

helm install external-secrets \
  external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace
  
kubectl create namespace ns

kubectl --namespace ns create secret generic yc-auth \
  --from-file=authorized-key=authorized-key.json
  
  
kubectl --namespace ns apply -f - <<< '
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: secret-store
spec:
  provider:
    yandexcertificatemanager:
      auth:
        authorizedKeySecretRef:
          name: yc-auth
          key: authorized-key'
          
          
kubectl --namespace ns apply -f - <<< '
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: external-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: secret-store
    kind: SecretStore
  target:
    name: k8s-secret
    template:
      type: kubernetes.io/tls
  data:
  - secretKey: tls.crt
    remoteRef:
      key: fpq7ajd40buasl4ilckg
      property: chain
  - secretKey: tls.key
    remoteRef:
      key: fpq7ajd40buasl4ilckg
      property: privateKey'
      
      
kubectl -n ns get secret k8s-secret -ojson \
  | jq '."data"."tls.crt"' -r \
  | base64 --decode
  
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx

kubectl --namespace ns apply -f - <<< '
apiVersion: v1
kind: Service
metadata:
  name: app
spec:
  selector:
    app: app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
  labels:
    app: app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
      - name: app
        image: nginx:latest
        ports:
        - containerPort: 80'
