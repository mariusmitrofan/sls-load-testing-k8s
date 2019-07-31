ES_HOST ?= your_elasticsearch_hostname_here
ES_PORT ?= 9200
AWS_ARN ?= get_node_instance_role_from_output
CONTEXT ?= get_context_from_output

default:
	make apply_base
	make apply_nginx
apply_base:
	export AWS_ARN=$(AWS_ARN)
	export ES_HOST=$(ES_HOST)
	export ES_PORT=$(ES_PORT)
	export CONTEXT=$(CONTEXT)
	sed -e "s~arn_aws_role_here~${AWS_ARN}~g" -e 's~ES_HOST~${ES_HOST}~g' -e 's~ES_PORT~${ES_PORT}~g' k8s_base-resources.yaml > deploy.yaml
	kubectl config use-context ${CONTEXT}
	kubectl apply -f deploy.yaml
apply_nginx:
	kubectl config use-context ${CONTEXT}
	kubectl apply -f k8s_nginx-resources.yaml
monitoring:
	kubectl config use-context ${CONTEXT}
	kubectl create serviceaccount --namespace kube-system tiller
	kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
	helm init --service-account tiller
	helm install --name monitoring  --namespace monitoring stable/prometheus-operator --set kubelet.serviceMonitor.https=true --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
	kubectl delete service monitoring-grafana -n monitoring
	(kubectl delete configmap nginx-dashboard -n monitoring) || (true)
	kubectl delete configmap monitoring-grafana -n monitoring
	kubectl delete secret monitoring-grafana -n monitoring
	python3 replace_ldap_toml.py
	kubectl apply -f custom-grafana-config.yaml
	kubectl patch deployment monitoring-grafana --patch "$(cat patch-deployment-grafana.yaml)" -n monitoring
	kubectl -n monitoring delete po -l app=grafana

