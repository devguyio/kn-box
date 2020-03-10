#!/usr/bin/env bash

set -e

# Turn colors in this script off by setting the NO_COLOR variable in your
# environment to any value:
#
# $ NO_COLOR=1 test.sh
NO_COLOR=${NO_COLOR:-""}
if [ -z "$NO_COLOR" ]; then
  header=$'\e[1;33m'
  reset=$'\e[0m'
else
  header=''
  reset=''
fi

serving_version="v0.13.0"
eventing_version="v0.13.1"
kourier_version="v0.3.10"
istio_version="1.4.4"
kube_version="v1.17.3"

MEMORY="$(minikube config view | awk '/memory/ { print $3 }')"
CPUS="$(minikube config view | awk '/cpus/ { print $3 }')"
DISKSIZE="$(minikube config view | awk '/disk-size/ { print $3 }')"
DRIVER="$(minikube config view | awk '/vm-driver/ { print $3 }')"

function header_text {
  echo "$header$*$reset"
}

header_text "Starting Knative on minikube!"
header_text "Using Kubernetes Version:               ${kube_version}"
header_text "Using Knative Serving Version:          ${serving_version}"
header_text "Using Knative Eventing Version:         ${eventing_version}"
header_text "Using Kourier Version:                  ${kourier_version}"
header_text "Using Istio Version:                    ${istio_version}"

minikube start --memory="${MEMORY:-16348}" --cpus="${CPUS:-10}" --kubernetes-version="${kube_version}" --vm-driver="${DRIVER:-kvm2}" --disk-size="${DISKSIZE:-30g}" --extra-config=apiserver.enable-admission-plugins="LimitRanger,NamespaceExists,NamespaceLifecycle,ResourceQuota,ServiceAccount,DefaultStorageClass,MutatingAdmissionWebhook"
header_text "Waiting for core k8s services to initialize"
sleep 5; while echo && kubectl get pods -n kube-system | grep -v -E "(Running|Completed|STATUS)"; do sleep 5; done

header_text "Setting up Istio"
curl -L "https://raw.githubusercontent.com/knative/serving/${serving_version}/third_party/istio-${istio_version}/istio-ci-no-mesh.yaml" \
    | sed 's/LoadBalancer/NodePort/' \
    | kubectl apply --filename -


# Label the default namespace with istio-injection=enabled.
header_text "Labeling default namespace w/ istio-injection=enabled"
kubectl label namespace default istio-injection=enabled
header_text "Waiting for istio to become ready"
sleep 5; while echo && kubectl get pods -n istio-system | grep -v -E "(Running|Completed|STATUS)"; do sleep 5; done

header_text "Setting up Knative Serving"

 n=0
   until [ $n -ge 2 ]
   do
      kubectl apply --filename https://github.com/knative/serving/releases/download/${serving_version}/serving-core.yaml && break
      n=$[$n+1]
      sleep 5
   done

header_text "Waiting for Knative Serving to become ready"
sleep 5; while echo && kubectl get pods -n knative-serving | grep -v -E "(Running|Completed|STATUS)"; do sleep 5; done




# header_text "Setting up Kourier"
# kubectl apply -f "https://raw.githubusercontent.com/3scale/kourier/${kourier_version}/deploy/kourier-knative.yaml"

# header_text "Waiting for Kourier to become ready"
# sleep 5; while echo && kubectl get pods -n kourier-system | grep -v -E "(Running|Completed|STATUS)"; do sleep 5; done

# header_text "Configure Knative Serving to use the proper 'ingress.class' from Kourier"
# kubectl patch configmap/config-network \
#   -n knative-serving \
#   --type merge \
#   -p '{"data":{"clusteringress.class":"kourier.ingress.networking.knative.dev",
#                "ingress.class":"kourier.ingress.networking.knative.dev"}}'

header_text "Setting up Knative Eventing"
kubectl apply --filename https://github.com/knative/eventing/releases/download/${eventing_version}/eventing.yaml

header_text "Waiting for Knative Eventing to become ready"
sleep 5; while echo && kubectl get pods -n knative-eventing | grep -v -E "(Running|Completed|STATUS)"; do sleep 5; done


header_text "Setting up Knative Monitoring"

 n=0
   until [ $n -ge 2 ]
   do
      kubectl apply --filename https://github.com/knative/serving/releases/download/${serving_version}/monitoring-core.yaml && break
      n=$[$n+1]
      sleep 5
   done

 n=0
   until [ $n -ge 2 ]
   do
      kubectl apply --filename https://github.com/knative/serving/releases/download/${serving_version}/monitoring-metrics-prometheus.yaml && break
      n=$[$n+1]
      sleep 5
   done

 n=0
   until [ $n -ge 2 ]
   do
      kubectl apply --filename https://github.com/knative/serving/releases/download/${serving_version}/monitoring-logs-elasticsearch.yaml && break
      n=$[$n+1]
      sleep 5
   done

 n=0
   until [ $n -ge 2 ]
   do
      kubectl apply --filename https://github.com/knative/serving/releases/download/${serving_version}/monitoring-tracing-jaeger-in-mem.yaml && break
      n=$[$n+1]
      sleep 5
   done

 n=0
   until [ $n -ge 2 ]
   do
      kubectl apply --filename https://github.com/knative/serving/releases/download/${serving_version}/monitoring-tracing-zipkin-in-mem.yaml && break
      n=$[$n+1]
      sleep 5
   done

header_text "Waiting for Knative Monitoring to become ready"
sleep 5; while echo && kubectl get pods -n knative-monitoring | grep -v -E "(Running|Completed|STATUS)"; do sleep 5; done
