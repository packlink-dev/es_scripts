#!/bin/bash

DELAY=${1:-5}
HOST=$(netstat -ltpn | awk '/9200/ {print $4}')
NODES=( $(curl -s -XGET http://${HOST}/_cat/nodes?h=n,m | grep -v '-' | awk '{print $1}' | xargs -i echo "{}") )
LEN=${#NODES[@]}

[ ! -d relocate ] && mkdir -v relocate

while read INDEX SHARD
do
    NODE=${NODES[$(( RANDOM % LEN ))]}
     #echo $INDEX 
     #echo $SHARD
     #echo $NODE
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
    # echo -e "\e[00m"
done < <( curl -s -XGET http://${HOST}/_cat/shards | grep -i unassigned | awk '{print $1,$2}' | sort )

# Note!
#  bash redirections:
#  <
#  <<
#  <<<
#  <( )
