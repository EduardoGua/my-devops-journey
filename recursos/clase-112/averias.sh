#!/bin/bash
# Averías de Kubernetes para la clase 112.
#   bash averias.sh            → crea el namespace «averias» con seis aplicaciones averiadas
#   bash averias.sh limpiar    → borra el namespace y todo lo que contiene
# Necesita tu cluster de kind en marcha (kubectl get nodes → Ready).
# Regla de honor: no leas el resto del archivo antes de diagnosticarlas.
set -u
NS=averias

if [[ ${1:-} == limpiar ]]; then
  kubectl delete namespace "$NS" --ignore-not-found --wait=false
  echo "Averías borradas (el namespace tarda unos segundos en desaparecer)."
  exit 0
fi

kubectl get nodes >/dev/null 2>&1 || { echo "No llego al cluster: ¿está en marcha? (kubectl get nodes)"; exit 1; }
if kubectl get namespace "$NS" >/dev/null 2>&1; then
  echo "El namespace $NS ya existe. Si quieres empezar de cero: bash $0 limpiar, espera unos segundos y vuelve a lanzarlo."
  exit 1
fi

kubectl create namespace "$NS" >/dev/null
kubectl apply -n "$NS" -f - >/dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalogo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: catalogo
  template:
    metadata:
      labels:
        app: catalogo
    spec:
      containers:
        - name: catalogo
          image: ghcr.io/stefanprodan/podinfo:v6.15.0
          ports:
            - containerPort: 9898
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pagos
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pagos
  template:
    metadata:
      labels:
        app: pagos
    spec:
      containers:
        - name: pagos
          image: python:3.14-slim
          command: ["python", "-c"]
          args:
            - |
              import os, time
              print("pagos: arrancando", flush=True)
              pasarela = os.environ["PASARELA_URL"]
              print("pagos: conectado a", pasarela, flush=True)
              time.sleep(86400)
          env:
            - name: PASARELA_ULR
              value: https://pasarela.lab.test
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: informes
spec:
  replicas: 1
  selector:
    matchLabels:
      app: informes
  template:
    metadata:
      labels:
        app: informes
    spec:
      containers:
        - name: informes
          image: busybox:1.37
          command: ["sh", "-c", "echo generando informes; sleep 86400"]
          resources:
            requests:
              memory: 64Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: buscador
spec:
  replicas: 1
  selector:
    matchLabels:
      app: buscador
  template:
    metadata:
      labels:
        app: buscador
    spec:
      containers:
        - name: buscador
          image: python:3.14-slim
          command: ["python", "-c"]
          args:
            - |
              indice = []
              while True:
                  indice.append(bytearray(16 * 1024 * 1024))
          resources:
            requests:
              memory: 64Mi
            limits:
              memory: 128Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tienda
spec:
  replicas: 2
  selector:
    matchLabels:
      app: tienda
  template:
    metadata:
      labels:
        app: tienda
    spec:
      containers:
        - name: tienda
          image: ghcr.io/stefanprodan/podinfo:6.15.0
          ports:
            - name: http
              containerPort: 9898
---
apiVersion: v1
kind: Service
metadata:
  name: tienda
spec:
  selector:
    app: tiendas
  ports:
    - port: 80
      targetPort: 9898
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: clientes
spec:
  replicas: 2
  selector:
    matchLabels:
      app: clientes
  template:
    metadata:
      labels:
        app: clientes
    spec:
      containers:
        - name: clientes
          image: ghcr.io/stefanprodan/podinfo:6.15.0
          ports:
            - name: http
              containerPort: 9898
          readinessProbe:
            httpGet:
              path: /ready
              port: http
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: clientes
spec:
  selector:
    app: clientes
  ports:
    - port: 80
      targetPort: 9898
---
apiVersion: v1
kind: Pod
metadata:
  name: sonda
spec:
  containers:
    - name: sonda
      image: busybox:1.37
      command: ["sleep", "1d"]
EOF

echo "Preparando las averías (la primera vez descarga imágenes: hasta 2 minutos)…"
kubectl -n "$NS" wait --for=condition=Ready pod/sonda --timeout=180s >/dev/null 2>&1
sleep 20
echo "Listo, en el namespace $NS. Los avisos, tal como llegarían:"
echo "  catalogo: «desplegamos el catálogo nuevo y no arranca nunca»"
echo "  pagos:    «el servicio de pagos se reinicia sin parar»"
echo "  informes: «los informes no salen; su pod no avanza»"
echo "  buscador: «el buscador se cae cada pocos segundos y su log no dice nada»"
echo "  tienda:   «la tienda no carga, y eso que sus pods están bien»"
echo "  clientes: «la web de clientes no responde, aunque sus pods están Running»"
echo "Para probar las dos últimas desde dentro del cluster:"
echo "  kubectl -n $NS exec sonda -- wget -qO- -T 3 http://tienda"
