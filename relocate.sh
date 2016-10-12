#!/bin/bash

DELAY=${1:-5}
HOST=hulk
curl -s -XGET http://${HOST}:9200/_cat/nodes
echo

[ ! -d relocate ] && mkdir -v relocate

while read INDEX SHARD
do
    NODE=eskibanarock
    # echo $INDEX 
    # echo $SHARD
    # echo $NODE
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
done < <( curl -s -XGET http://${HOST}:9200/_cat/shards | grep -i unassigned | awk '{print $1,$2}' | sort )

# Note!
#  bash redirections:
#  <
#  <<
#  <<<
#  <( )
