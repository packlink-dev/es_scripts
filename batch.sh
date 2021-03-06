#!/bin/bash

source snapshots.conf

ls_snapshot_indexes(){
    local SNAPSHOT=${1}
    curl -s -XGET http://${HOST}:9200/_snapshot/${REPO}/${SNAPSHOT} | jq -r ' .snapshots |.[] | .indices | .[] ' | sort
}

close(){
    local INDEX=${1}
    curl -s -XPOST http://${HOST}:9200/${INDEX}/_close
}

optimize(){
    curl -s -XPOST http://${HOST}:9200/_optimize
}

[[ $# < 1 ]] && exit 1

FILE=${1}

for LINE in $(cat ${FILE})
do
    echo ls_snapshot_indexes ${LINE}
    for INDEX in $(ls_snapshot_indexes ${LINE})
    do
        close ${INDEX}
        echo
        ./snapshots.sh restore ${LINE} ${INDEX}
        sleep 5
        echo
    done
    echo "${LINE} done" >> ./batch.done
    optimize
done
