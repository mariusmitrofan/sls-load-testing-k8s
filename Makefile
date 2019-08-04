ifeq (,$(wildcard .env))
$(error "Please create the .env file first. Use .env.dist as baseline.")
endif

ifeq (, $(shell which aws))
$(error "AWS CLI was not detected in $(PATH). Please install it first.")
endif

ifeq (, $(shell which kubectl))
$(error "KUBECTL was not detected in $(PATH). Please install it first.")
endif

ifeq (, $(shell which helm))
$(error "HELM was not detected in $(PATH). Please install it first.")
endif

ifeq (, $(shell which pip3))
$(error "PIP3 was not detected in $(PATH). Please install it first.")
endif

include .env

FETCH_ARN = $(shell aws cloudformation describe-stacks --profile ${AwsProfile} --stack-name ${StackName} --query "Stacks[0].Outputs[?OutputKey=='NodeInstanceRole'].OutputValue" --output text)
FETCH_CONTEXT = $(shell aws cloudformation describe-stacks --profile ${AwsProfile} --stack-name ${StackName} --query "Stacks[0].Outputs[?OutputKey=='Context'].OutputValue" --output text)
SET_ARN=$(eval export AWS_ARN=$(FETCH_ARN))
SET_CONTEXT=$(eval export CONTEXT=$(FETCH_CONTEXT))

launch_stack:
	aws cloudformation create-stack \
		--stack-name ${StackName} \
		--template-body file://cloudformation-template.yaml \
		--profile ${AwsProfile} \
		--capabilities CAPABILITY_IAM  CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
		--parameters $(cat parameters.json)
	aws cloudformation wait stack-create-complete --stack-name ${StackName} --profile ${AwsProfile}
	aws eks update-kubeconfig --name ${ClusterName} --profile ${AwsProfile}
update_stack:
	aws cloudformation update-stack \
		--stack-name ${StackName} \
		--template-body file://cloudformation-template.yaml \
		--profile ${AwsProfile} \
		--capabilities CAPABILITY_IAM  CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
		--parameters $(cat parameters.json)
	aws cloudformation wait stack-update-complete --stack-name ${StackName} --profile ${AwsProfile}
	aws eks update-kubeconfig --name ${ClusterName} --profile ${AwsProfile}
bootstrap:
	pip3 install python-dotenv
	make apply_base
	make install_helm
	make install_prometheus_helm
	make monitoring
	make apply_nginx
deploy:
	make apply_base
	make apply_nginx
	make monitoring
apply_base:
	$(SET_ARN)
	$(SET_CONTEXT)
	sed -e "s~arn_aws_role_here~${AWS_ARN}~g" -e 's~ES_HOST~${ES_HOST}~g' -e 's~ES_PORT~${ES_PORT}~g' k8s_base-resources.yaml > deploy.yaml
	kubectl config use-context ${CONTEXT}
	kubectl apply -f deploy.yaml
	rm -f deploy.yaml
apply_nginx:
	$(SET_CONTEXT)
	kubectl config use-context ${CONTEXT}
	kubectl apply -f k8s_nginx-resources.yaml
install_helm:
	$(SET_CONTEXT)
	kubectl config use-context ${CONTEXT}
	kubectl create serviceaccount --namespace kube-system tiller
	kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
	helm init --upgrade --service-account tiller --wait
install_prometheus_helm:
	$(SET_CONTEXT)
	kubectl config use-context ${CONTEXT}
	helm install --name monitoring  --namespace monitoring stable/prometheus-operator --set kubelet.serviceMonitor.https=true --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
monitoring:
	$(SET_CONTEXT)
	kubectl config use-context ${CONTEXT}
	kubectl delete service monitoring-grafana -n monitoring
	(kubectl delete configmap nginx-dashboard -n monitoring) || (true)
	kubectl delete configmap monitoring-grafana -n monitoring
	kubectl delete secret monitoring-grafana -n monitoring
	python3 replace_ldap_toml.py
	kubectl apply -f deploy-custom-grafana-config.yaml
	rm -f deploy-custom-grafana-config.yaml
	kubectl patch deployment monitoring-grafana --patch '{"spec":{"template":{"spec":{"containers":[{"name":"grafana","volumeMounts":[{"mountPath":"/tmp/dashboards/nginx-dashboard.json","name":"nginx-dashboard"}]}],"volumes":[{"configMap":{"defaultMode":420,"name":"nginx-dashboard"},"name":"nginx-dashboard"}]}}}}' -n monitoring
	kubectl -n monitoring delete po -l app=grafana

