#!/bin/bash

source snapshots.conf

data_nodes(){
	curl -s -XGET "http://${HOST}:9200/_cat/nodes?h=r,n" | awk '/^d/ {print $2}' | xargs -i echo -n {}" "
}

relocate(){
	[ ! -d relocate ] && mkdir -v relocate

	while read INDEX SHARD
	do
	    # NODE=eskibanarock
	    # echo $INDEX 
	    # echo $SHARD
	    # echo $NODE
            for NODE in $( data_nodes )
            do
		    echo -e "\e[01;33mReallocating in \e[01;35m$NODE \e[01;37m[\e[01;36m ${INDEX} \e[01;37m]\e[00m"
		    curl -s -o relocate/${INDEX}.${SHARD}.${NODE}.json -XPOST "http://${HOST}:9200/_cluster/reroute" -d '{
			 "commands" : [ {
			       "allocate" : {
				   "index" : "'${INDEX}'", 
				   "shard" : '${SHARD}', 
				   "node" : "'${NODE}'", 
				   "allow_primary" : true
			       }
			     }
			 ]
		     }'
		    sleep ${DELAY}
            done
	    # echo -e "\e[00m"
	done < <( curl -s -XGET http://${HOST}:9200/_cat/shards | grep -i unassigned | awk '{print $1,$2}' | sort )
	# Note!
	#  bash redirections:
	#  <
	#  <<
	#  <<<
	#  <( )
}

ACTION=${1}

case ${ACTION} in
	ls|LS)
		PATTERN=${2}
		echo -e "\e[01;33mindices: \e[01;35m${ACTION}\e[00m"
		curl -s -XGET http://${HOST}:9200/_cat/indices?h=i,s,dc,ss
		# "\e[01;37m[\e[01;36m ${INDICES} \e[01;37m]\e[00m"
		;;
		
	delete|DELETE)
		ARGS=(${@})
		INDICES=${ARGS[@]:1}
		echo -e "\e[01;33mindices: \e[01;35m${ACTION} \e[01;37m[\e[01;36m ${INDICES} \e[01;37m]\e[00m"
		if [ ! -z "${INDICES}" ]
		then
			for INDEX in ${INDICES[@]}
			do
				curl -s -XPOST "http://${HOST}:9200/${INDEX}/_close"
				echo curl -s -XDELETE "http://${HOST}:9200/${INDEX}"
			done
			curl -s -XPOST "http://${HOST}:9200/_optimize"
		fi
		;;
	optimize|OPTIMIZE)
		echo -e "\e[01;33mindices: \e[01;35m${ACTION}\e[00m"
		curl -s -XGET http://${HOST}:9200/_cat/nodes | sed '1d' | sort
		
		;;
	relocate|RELOCATE)
		echo -e "\e[01;33mindices: \e[01;35m${ACTION}\e[00m"
		relocate
		;;
	*)
		echo "in progressss...."
		;;
esac
		
