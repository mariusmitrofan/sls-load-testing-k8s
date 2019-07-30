ES_HOST ?= your_elasticsearch_hostname_here
ES_PORT ?= 9200
AWS_ARN ?= get_node_instance_role_from_output
CONTEXT ?= get_context_from_output

default:
	make apply
apply:
	export AWS_ARN=$(AWS_ARN)
	export ES_HOST=$(ES_HOST)
	export ES_PORT=$(ES_PORT)
	export CONTEXT=$(CONTEXT)
	sed -e "s~arn_aws_role_here~${AWS_ARN}~g" -e 's~ES_HOST~${ES_HOST}~g' -e 's~ES_PORT~${ES_PORT}~g' k8s_resources.yaml > deploy.yaml
	kubectl config use-context ${CONTEXT}
	kubectl apply -f deploy.yaml

