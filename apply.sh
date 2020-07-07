#!/usr/bin/env bash

apply_state () {
    delete=0
    if [[ -f ${1} ]]
    then
        echo "Processing ${1}"
    else
        prev_commit=$(git rev-parse @~)
        git checkout ${prev_commit} ${1}
        echo "Processing ${1}"
        delete=1
    fi

    kind=$(grep -m 1 "kind:" ${1} | cut -d":" -f2 | awk '{$1=$1;print}')
    version=$(grep -m 1 "version:" ${1} | cut -d":" -f2 | awk '{$1=$1;print}')
    package=$(grep -m 1 "package:" ${1} | cut -d":" -f2 | awk '{$1=$1;print}')
    name=$(grep -m 1 "name:" ${1} | cut -d":" -f2 | awk '{$1=$1;print}')

    if [[ ${kind} == "ClusterGroup" ]]
    then
        if [[ delete -eq 1 ]]
        then
            tmc clustergroup delete ${name}
        else
            op=$(tmc clustergroup get ${name})
            if [[ $? -eq 0 ]]
            then
                echo "Already exists. Updating."
                tmc clustergroup update ${name} -f ${1}
            else
                echo "Does not exist. Creating."
                tmc clustergroup create -f ${1}
            fi
        fi
    fi

    if [[ ${kind} == "Cluster" ]]
    then
        if [[ delete -eq 1 ]]
        then
            tmc cluster delete ${name}
        else
            op=$(tmc cluster get ${name} -o json)
            if [[ $? -eq 0 ]]
            then
                echo "Already exists. Updating."
                version=$(echo $op | jq '.objectMeta.resourceVersion')
                #version=$(echo  $version | sed -e 's/"//g')
                sed -e "s/objectMeta:/objectMeta:\n  resourceVersion: $version/g" ${1} > tmpfile.yaml
                echo $(cat tmpfile.yaml)
                tmc cluster update ${name} -f tmpfile.yaml
                rm tmpfile.yaml
            else
                echo "Does not exist. Creating."
                tmc cluster create -f ${1}
            fi
        fi
    fi

    if [[ ${kind} == "Workspace" ]]
    then
        if [[ delete -eq 1 ]]
        then
            tmc workspace delete ${name}
        else
            op=$(tmc workspace get ${name})
            if [[ $? -eq 0 ]]
            then
                echo "Already exists. Updating."
                tmc workspace update ${name} -f ${1}
            else
                echo "Does not exist. Creating."
                tmc workspace create -f ${1}
            fi
        fi
    fi

    if [[ ${kind} == "Policy" ]]
    then
        type=$(grep "policyType:" ${1} | cut -d":" -f2 | awk '{$1=$1;print}')
        if [[ ${package} == "vmware.tanzu.mc.v1alpha.workspace.policy" ]]
        then
            command="workspace"
            parent_name=$(grep "workspaceName:" ${1} | cut -d":" -f2 | awk '{$1=$1;print}')
        fi
        if [[ delete -eq 1 ]]
        then
            tmc ${command} ${type} delete ${name} ${parent_name}
        else
            op=$(tmc ${command} ${type} get ${name} ${parent_name})
            if [[ $? -eq 0 ]]
            then
                echo "Already exists. Updating."
                tmc ${command} ${type} update ${name} ${parent_name} -f ${1}
            else
                echo "Does not exist. Creating."
                tmc ${command} ${type} create -f ${1}
            fi
        fi
    fi

    if [[ ${kind} == "IAMPolicy" ]]
    then
        if [[ ${package} == "vmware.tanzu.mc.v1alpha.workspace.iampolicy" ]]
        then
            command="workspace"
        fi
        name=$(grep -m 1 "name:" ${1} | cut -d":" -f2 | awk '{$1=$1;print}')
        if [[ delete -eq 1 ]]
        then
            tmc ${command} iam delete ${name}
        else
            op=$(tmc ${command} iam get-policy ${name})
            if [[ $? -eq 0 ]]
            then
                echo "Already exists. Updating."
                sed -n '/roleBindings/,$p' ${1} > tmpfile.yaml
                tmc ${command} iam update-policy ${name} -f tmpfile.yaml
                rm tmpfile.yaml
            #else
                #echo "Does not exist. Creating."
                #tmc ${command} iam create -f ${1}
            fi
        fi
    fi
}

while read line; do apply_state ${line}; done < <(git diff --name-only HEAD HEAD~1 | grep yaml)