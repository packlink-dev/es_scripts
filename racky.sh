#!/bin/bash

uploadfile(){
	source rackspace.rc
	local RESPONSE=/tmp/.racky.response
	local DATE=$(date +%Y%m%d)
	local CFROOT=${1}
	local CFCONTAINER=${CFROOT}/${2}/${DATE}
	local LOCAL_DIR=${3}
	local FILE_NAME=${4}
	local FILE_MD5SUM=${5:-$( md5sum ${LOCAL_DIR}/${FILE_NAME} | awk '{print $1}')}

	curl -s -XPOST https://identity.api.rackspacecloud.com/v2.0/tokens \
	  -H "Content-Type: application/json" \
	  -d '{
	    "auth": {
	      "RAX-KSKEY:apiKeyCredentials": {
		"username": "'${RACKYUSER}'",
		"apiKey": "'${RACKYAPIK}'"
	      }
	    }
	  }' > ${RESPONSE}

	local TOKEN=$( cat ${RESPONSE} | jq -r .access.token.id )
	local ENDPOINT=$( cat ${RESPONSE} | jq -r '.access.serviceCatalog | .[] | select(.name=="cloudFiles") | .endpoints[0].publicURL' )

	HTTP_CODE=$(curl -sw %{http_code} -L -o /dev/null -XGET ${ENDPOINT}/${CFROOT} -H "X-Auth-Token: $TOKEN" -H "Accept: application/json" )
	[ "${HTTP_CODE}" == "404" ] && \
		echo -en "\e[01;35mCFROOT\e[01;37m [ \e[01;34m" && \
		HTTP_CODE=$( curl -sw %{http_code} -o /dev/null -XPUT ${ENDPOINT}/${CFROOT} -H "X-Auth-Token: ${TOKEN}" ) && \
		echo -e "\e[01;32mCREATED\e[01;37m [ \e[01;34m${HTTP_CODE}\e[01;37m ]\e[00m ]\e[00m"
	
	HTTP_CODE=$( curl -i -o ${RESPONSE} -sw %{http_code} -XPUT "${ENDPOINT}/${CFCONTAINER}/${FILE_NAME}" \
		-H "X-Auth-Token: $TOKEN" \
		-H "Content-Type: application/data" \
		-T ${LOCAL_DIR}/${FILE_NAME} )

	[ "${HTTP_CODE}" != "201" ] && echo -e "\e[01;31mERROR\e[01;37m [ \e[01;34m${HTTP_CODE}\e[01;37m ]\e[00m" && exit 3
	echo -e "\e[01;32mCREATED\e[01;37m [ \e[01;34m${HTTP_CODE}\e[01;37m ]\e[00m"
	echo -e "\e[01;33mENDPOINT\e[01;37m [ \e[01;34m${ENDPOINT}/${CFCONTAINER}/${FILE_NAME}\e[01;37m ]\e[00m"
	grep ${FILE_MD5SUM} ${RESPONSE} 2>&1 >> /dev/null || echo -e "\e[01;34mWRONG UPLOAD\e[01;37m [ \e[01;34m${FILE_MD5SUM}/${UPLOAD_SUM}\e[01;37m ]\e[00m"
}

usage(){
	cat << __EOF__
$0 <root directory> <directory> <local directory> <file>

	root directory:  Cloud Files Root Directory.
	directory:       Directory where you want to save the file.
	local directory: In local, where is the file what you want upload.
	file;            File to upload

  Example:

  $0 logger_test index_test /root/es_scripts archiving.list

__EOF__
}

test(){
	md5sum /root/es_scripts/archiving.list > /root/es_scripts/archiving.meta
	uploadfile logger_test_b index_test_2 /root/es_scripts archiving.meta
	uploadfile logger_test_b index_test_2 /root/es_scripts archiving.list $( awk '{print $1}' /root/es_scripts/archiving.meta )
	exit 0
}	

# test

[[ $# < 4 ]] && usage && exit 1

# uploadfile logger_test index_test_2 /root/es_scripts archiving.list
uploadfile $1 $2 $3 $4 $5
