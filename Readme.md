# Kubernetes Webservice Demo

This project is a small demo to run a containerized webservice in a Kubernetes cluster.

## Steps to Reproduce

### Requirements

Please set up these beforehand:

- Docker
- minikube itself

### Change hardcoded values

1. Change the web access domain in:
   - `nginx.conf:11`
   - `nginx.conf:18`
   - `k8s/web/ingress-http.yaml:11`
   - `k8s/web/ingress-https.yaml:13`
2. The loaded web content is configured at:
   - `k8s/web/deployment.yaml:22`

### Prepare image

1. Clone this repo into a folder.
2. Generate SSL certs:

   ```bash
   certbot certonly --standalone -d "my.domain" --agree-tos -m "mail@my.domain" --non-interactive
   ```
   2.1 move the generated cert material into the ./certs/ folder
      ```bash
      mkdir -p certs/
      mv /etc/letsencrypt/.../* certs/
      ```
4. Build the image:

   ```bash
   docker build -t web:1.0 .
   ```

5. Add image to minikube (Traefik will be pulled from a registry):

   ```bash
   minikube image load web:1.0
   ```

### Prepare minikube

1. Make life easier with:

   ```bash
   alias kubectl='minikube kubectl --'
   ```

2. Apply the kubectl configs provided by Traefik:

   ```bash
   kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v3.5/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml
   kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v3.5/docs/content/reference/dynamic-configuration/kubernetes-crd-rbac.yml
   ```

3. Apply the configs in this repo:

   ```bash
   kubectl apply -f k8s/traefik/namespace.yaml
   kubectl apply -f k8s/web/namespace.yaml
   kubectl apply -R -f k8s/
   ```

4. Watch pods as containers deploy:

   ```bash
   kubectl get pods -n traefik -w
   kubectl get pods -n web -w
   ```

### Forward IP traffic

First, set some variables. Make sure to fill in your correct values:

```bash
HTTP_PORT=$(kubectl -n traefik get svc traefik -o jsonpath='{.spec.ports[?(@.name=="web")].nodePort}')
HTTPS_PORT=$(kubectl -n traefik get svc traefik -o jsonpath='{.spec.ports[?(@.name=="websecure")].nodePort}')
EXT_IF='eth0'
KUBE_IF='br-686bb28858ee'
PUBLIC_IP='91.98.88.70'
TRAEFIK_IP='192.168.49.2'
NODE_IP=$(minikube ip)
```

Next, apply forwarding rules so traffic designated to the web ports gets handled by the Traefik controller inside the kube network:

```bash
iptables -t nat -A PREROUTING -i "$EXT_IF" -p tcp -d "$PUBLIC_IP" --dport 80 -j DNAT --to-destination "$NODE_IP:$HTTP_PORT"
iptables -t nat -A PREROUTING -i "$EXT_IF" -p tcp -d "$PUBLIC_IP" --dport 443 -j DNAT --to-destination "$NODE_IP:$HTTPS_PORT"

iptables -t nat -A POSTROUTING -p tcp -d $NODE_IP --dport $HTTPS_PORT -j MASQUERADE
iptables -t nat -A POSTROUTING -p tcp -d $NODE_IP --dport $HTTP_PORT -j MASQUERADE

iptables -t nat -A POSTROUTING -o $KUBE_IF -p tcp -d $TRAEFIK_IP --dport 30222 -j MASQUERADE
iptables -t nat -A POSTROUTING -o $KUBE_IF -p tcp -d $TRAEFIK_IP --dport 31954 -j MASQUERADE
```

### Done

Now, assuming you have a DNS entry, it should work!
