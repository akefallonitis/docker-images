#!/bin/bash

## Funtion expecting 2 parametters and print them as a yaml KV only if the value is not empty
to_yaml_kv() {
	declare yamlKey="${1}" yamlValue="${2}";

	if [[ -n "${yamlKey}" ]] && [[ -n "${yamlValue}" ]]; then
		printf '%s: %s\n' "${yamlKey}" "${yamlValue}";
	fi

}

## Function expecting a named parametter and a **litteral duration** printing a 
##    yaml version of the litteral duration so that elastalert can use it.
## Duration MUST be written as a number followed by the unit.
##    Allowed Units are : `seconds`, `minutes`, `hours`, `days` and `weeks` and can be
##    written case insensitively.
##    Space character are allowed between numbers and units.
##    As second argument may include spaces Do not forget to doublequote arguments
##    when calling the function.
## Example :
#  user@example:~$ to_yaml_time "run_every" "1 hour : 21 Minutes & 6seconds not interpreted"
#  run_every:
#      hours: 1
#      minutes: 21
#      seconds: 6
##
to_yaml_time() {
	declare yamlKey="${1}" timeValue="${2}";
	if [[ -n "${yamlKey}" ]] && [[ -n "${timeValue}" ]]; then
		shopt -s nocasematch
		# REGEXP are now case insensitives
		printf '%s:\n' "${yamlKey}";
		[[ "${timeValue}" =~ [[:space:]]*([[:digit:]]*)[[:space:]]*weeks? ]] && \
			printf '    weeks: %s\n' "${BASH_REMATCH[1]}";
		[[ "${timeValue}" =~ [[:space:]]*([[:digit:]]*)[[:space:]]*days? ]] && \
			printf '    days: %s\n' "${BASH_REMATCH[1]}";
		[[ "${timeValue}" =~ [[:space:]]*([[:digit:]]*)[[:space:]]*hours? ]] && \
			printf '    hours: %s\n' "${BASH_REMATCH[1]}";
		[[ "${timeValue}" =~ [[:space:]]*([[:digit:]]*)[[:space:]]*minutes? ]] && \
			printf '    minutes: %s\n' "${BASH_REMATCH[1]}";
		[[ "${timeValue}" =~ [[:space:]]*([[:digit:]]*)[[:space:]]*seconds? ]] && \
			printf '    seconds: %s\n' "${BASH_REMATCH[1]}";
		shopt -u nocasematch
		# REGEXP are now case sensitive
	fi
}

## Function extracting a yaml value from a key in a yaml file.
get_yaml_value() {
	declare yamlKey="${1}" yamlFile="${2}";
	if [[ ! -f ${yamlFile} ]]; then 
		exit -1;
	fi
	local fullLine=$(egrep "${yamlKey}[[:space:]]*:[[:space:]]+" "${yamlFile}");
	# The following line delete every character after the first # encouterd : trims out YAML comments
	local yamlKeyValue="${fullLine%%#*}"
	# The following line delete everything behind the string ': ' : Delete the YAML key.
	printf "${yamlKeyValue#*: }";
}

## Function forging ElasticSearch URI based on the environment variables :
## USE_SSL, ES_USERNAME, ES_PASSWORD, ELASTICSEARCH_HOST, ELASTICSEARCH_PORT and ES_URL_PREFIX
elasticsearch_uri() {
	## Create Base HTTP[S]? URI 
	if [[ ${USE_SSL} = "True" ]]; then
		printf 'https://';
	else
		printf 'http://';
	fi

	## Set the basic authentication part of the URL
	if [[ -n ${ES_USERNAME} ]] && [[ -n ${ES_PASSWORD} ]]; then
		printf '%s:%s@' "${ES_USERNAME}" "${ES_PASSWORD}";
	fi

	printf '%s:%s/' "${ELASTICSEARCH_HOST}" "${ELASTICSEARCH_PORT}";
	# Eventually append with URL prefix
	if [[ -n ${ES_URL_PREFIX} ]]; then
		printf '%s/' "${ES_URL_PREFIX}";
	fi
}

if [[ ! -f "${ELASTALERT_INSTALLATION_PATH}/config.yaml" ]]; then
	printf 'INFO:entrypoint.sh:Loading configuration from container environement variables.\n'
	## Config File generation
	cat > "${ELASTALERT_INSTALLATION_PATH}/config.yaml" <<-EOF
	##
	## ELASTICSEARCH CONFIGURATION
	##

	# The elasticsearch hostname for metadata writeback
	# Note that every rule can have its own elasticsearch host
	es_host: ${ELASTICSEARCH_HOST}
	# The elasticsearch port
	es_port: ${ELASTICSEARCH_PORT}

	# Optional URL prefix for elasticsearch
	$(to_yaml_kv "es_url_prefix" "${ES_URL_PREFIX}")

	# Connect with SSL to elasticsearch
	$(to_yaml_kv "use_ssl" "${USE_SSL}")
	$(to_yaml_kv "verify_certs" "${VERIFY_CERTS}")

	# Option basic-auth username and password for elasticsearch
	$(to_yaml_kv "es_username" "${ES_USERNAME}")
	$(to_yaml_kv "es_password" "${ES_PASSWORD}")

	# GET request with body is the default option for Elasticsearch. 
	# If it fails for some reason, you can pass 'GET', 'POST' or 'source'.
	# See http://elasticsearch-py.readthedocs.io/en/master/connection.html?highlight=send_get_body_as#transport
	# for details
	$(to_yaml_kv "es_send_get_body_as" "${ES_SEND_GET_BODY_AS}")

	$(to_yaml_kv "es_conn_timeout" "${ES_CONN_TIMEOUT}")

	# The index on es_host which is used for metadata storage
	# This can be a unmapped index, but it is recommended that you run
	# elastalert-create-index to set a mapping
	writeback_index: ${WRITEBACK_INDEX:-elastalert_status}

	##
	## ELASTALERT PROCESS CONFIGURATION
	##

	# This is the folder that contains the rule yaml files
	# Any .yaml file will be loaded as a rule
	rules_folder: ${ELASTALERT_RULES_FOLDER}

	$(to_yaml_kv "scan_subdirectories" "${SCAN_SUBDIRECTORIES}")

	# How often ElastAlert will query elasticsearch
	# The unit can be anything from weeks to seconds
	$(to_yaml_time "run_every" "${RUN_EVERY:-1 minutes}")

	# ElastAlert will buffer results from the most recent
	# period of time, in case some log sources are not in real time
	$(to_yaml_time "buffer_time" "${BUFFER_TIME:-45 minutes}")

	# If true, ElastAlert will disable rules which throw uncaught exceptions.
	# It will upload a traceback message to elastalert_metadata and if notify_email 
	# is set,send an email notification.
	# This defaults to True.
	$(to_yaml_kv "disable_rules_on_error" "${DISABLE_RULES_ON_ERROR}")

	# If an alert fails for some reason, ElastAlert will retry
	# sending the alert until this time period has elapsed
	$(to_yaml_time "alert_time_limit" "${ALERT_TIME_LIMIT:-2 days}")

	##
	## Email settings
	##

	$(to_yaml_kv "notify_email" "${NOTIFY_EMAIL}")
	$(to_yaml_kv "from_addr" "${FROM_ADDR}")
	$(to_yaml_kv "smtp_host" "${SMTP_HOST}")
	$(to_yaml_kv "email_reply_to" "${EMAIL_REPLY_TO}")

	EOF
else
	printf 'INFO:entrypoint.sh:Loading configuration from mounted config file.\n'
	## Set variables ELASTICSEARCH_HOST and ELASTICSEARCH_PORT based on config file or raise an error
	ELASTICSEARCH_HOST=$(get_yaml_value "es_host" "${ELASTALERT_INSTALLATION_PATH}/config.yaml");
	ELASTICSEARCH_PORT=$(get_yaml_value "es_port" "${ELASTALERT_INSTALLATION_PATH}/config.yaml")

	## Eventually set USE_SSL, VERIFY_CERTS, ES_USERNAME, ES_PASSWORD
	USE_SSL=$(get_yaml_value "use_ssl" "${ELASTALERT_INSTALLATION_PATH}/config.yaml");
	VERIFY_CERTS=$(get_yaml_value "verify_certs" "${ELASTALERT_INSTALLATION_PATH}/config.yaml");
	ES_USERNAME=$(get_yaml_value "es_username" "${ELASTALERT_INSTALLATION_PATH}/config.yaml");
	ES_PASSWORD=$(get_yaml_value "es_password" "${ELASTALERT_INSTALLATION_PATH}/config.yaml");
	WRITEBACK_INDEX=$(get_yaml_value "writeback_index" "${ELASTALERT_INSTALLATION_PATH}/config.yaml");
fi

## Error handling for
if [[ -z "${ELASTICSEARCH_HOST}" ]] || [[ -z "${ELASTICSEARCH_PORT}" ]]; then
	printf 'ERROR:entrypoint.sh:Not enought information to reach ES cluster. \n';
	exit -1;
fi

## Testing for Writeback index status
printf 'INFO:entrypoint.sh:Stalling for Elasticsearch, trying to reach %s\n' "$(elasticsearch_uri)";
while true; do
	if [[ $(curl -o /dev/null --silent --write-out '%{http_code}' "$(elasticsearch_uri)") = 200 ]]; then
		printf 'INFO:entrypoint.sh:Elasticsearch cluster found.\n';
		break;
	else
		printf 'WARN:entrypoint.sh:Cannot reach Elasticsearch cluster retrying in 3 seconds.\n';
		sleep 3;
	fi
done

printf 'INFO:entrypoint.sh:Checking existance of writeback index <%s>\n' "${WRITEBACK_INDEX:-elastalert_status}";

res_http_code=$(curl -o /dev/null --silent --write-out '%{http_code}' "$(elasticsearch_uri)${WRITEBACK_INDEX:-elastalert_status}");

case "${res_http_code}" in
200) # 200 OK is returned by Elasticsearch API when the index already exists
	printf 'INFO:entrypoint.sh:Elastalert writeback index already exists.\n'
	;;
404) # 404 Not found is returned by ES API when the index does not exist
	printf 'INFO:entrypoint.sh:Elastalert writeback index does not currently exist.\n'
	python -m elastalert.create_index \
				 --index "${WRITEBACK_INDEX:-elastalert_status}" \
				 --old-index "" > /dev/null \
				 && printf 'INFO:entrypoint.sh:Writeback index %s created.\n' "${WRITEBACK_INDEX:-elastalert_status}"\
				 || printf 'CRIT:entrypoint.sh:Cannot create Elastalert writeback index.\n'
	;;
401) # 401 Basic HTTP auth failure.
	printf 'ERROR:entrypoint.sh:Authentication failure on %s:%s' "${ELASTICSEARCH_HOST}" "${ELASTICSEARCH_PORT}"; [[ -n ${ES_URL_PREFIX} ]] && printf '/%s ' "${ES_URL_PREFIX}";
	if [[ -z ${ES_USERNAME} ]] && [[ -z ${ES_PASSWORD} ]]; then 
		printf 'INFO:entrypoint.sh:Reason Basic authentication is required to reach Elasticsearch API\n';
	else
		printf 'INFO:entrypoint.sh:Reason Bad Username / Password\n';
	fi
	;;
esac

## Starting Elastalert process
exec python -m elastalert.elastalert \
		--config "${ELASTALERT_INSTALLATION_PATH}/config.yaml" \
		$@ ## <- All other arguments (for the CMD docker directive)