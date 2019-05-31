#!/usr/bin/env bash

#set -ux

TV_GIT_URL="https://github.com/openstack/tripleo-validations"

MR_DIR="diffs/master_rocky"
MS_DIR="diffs/master_stein"

library_patches="${MR_DIR}/library"
callback_patches="${MR_DIR}/callback_plugins"
lookup_patches="${MR_DIR}/lookup_plugins"
playbook_patches="${MR_DIR}/playbooks"
roles_patches="${MR_DIR}/roles"

ms_library_patches="${MS_DIR}/library"
ms_callback_patches="${MS_DIR}/callback_plugins"
ms_lookup_patches="${MS_DIR}/lookup_plugins"
ms_playbook_patches="${MS_DIR}/playbooks"
ms_roles_patches="${MS_DIR}/roles"
ms_validations_patches="${MS_DIR}/validations"

if [[ ! -d tv-master ]]; then
    git clone ${TV_GIT_URL} tv-master
fi

if [[ ! -d tv-stein ]]; then
    git clone ${TV_GIT_URL} tv-stein
    pushd tv-stein
    git checkout -b stable-stein origin/stable/stein
    popd
fi
if [[ ! -d tv-rocky ]]; then
    git clone ${TV_GIT_URL} tv-rocky
    pushd tv-rocky
    git checkout -b stable-rocky origin/stable/rocky
    popd
fi

if [[ -d ${MR_DIR} ]]; then
    rm -Rf ${MR_DIR}
fi

mkdir -p ${library_patches}
mkdir -p ${callback_patches}
mkdir -p ${lookup_patches}
mkdir -p ${playbook_patches}
mkdir -p ${roles_patches}

if [[ -d ${MS_DIR} ]]; then
    rm -Rf ${MS_DIR}
fi

mkdir -p ${ms_library_patches}
mkdir -p ${ms_callback_patches}
mkdir -p ${ms_lookup_patches}
mkdir -p ${ms_playbook_patches}
mkdir -p ${ms_roles_patches}
mkdir -p ${ms_validations_patches}

# library directory
for lib in `find ./tv-master/library -type f -regex '.*\.py'`; do
    library=$(basename ${lib})

    if [[ -f ./tv-stein/library/${library} ]]; then
        diff ${lib} ./tv-stein/library/${library}  2>&1 > /dev/null
        ret=$?
        if [ $ret != 0 ]; then
            diff -U 1000 --color ${lib} ./tv-stein/library/${library} > ./${ms_library_patches}/${library}.diff
        fi
    fi

    if [[ -f ./tv-rocky/validations/library/${library} ]]; then
        diff ${lib} ./tv-rocky/validations/library/${library}  2>&1 > /dev/null
        ret=$?
        if [ $ret != 0 ]; then
            diff -U 1000 --color ${lib} ./tv-rocky/validations/library/${library} > ./${library_patches}/${library}.diff
        fi
    fi
done

# callback_plugin directory
for cbp in `find ./tv-master/callback_plugins -type f -regex '.*\.py'`; do
    callback=$(basename ${cbp})

    if [[ -f ./tv-master/callback_plugins/${callback} ]]; then
        diff ${cbp} ./tv-master/callback_plugins/${callback}  2>&1 > /dev/null
        ret=$?
        if [ $ret != 0 ]; then
            diff -U 1000 --color ${cbp} ./tv-master/callback_plugins/${callback} > ./${ms_callback_patches}/${callback}.diff
        fi
    fi

    if [[ -f ./tv-rocky/validations/callback_plugins/${callback} ]]; then
        diff ${cbp} ./tv-rocky/validations/callback_plugins/${callback} 2>&1 > /dev/null
        ret=$?
        if [ $ret != 0 ]; then
            diff -U 1000 --color ${cbp} ./tv-rocky/validations/callback_plugins/${callback} > ./${callback_patches}/${callback}.diff
        fi
    fi
done

# lookup_plugin directory
for lk in `find ./tv-master/lookup_plugins -type f -regex '.*\.py'`; do
    lookup=$(basename ${lk})

    if [[ -f ./tv-stein/lookup_plugins/${lookup} ]]; then
        diff ${lk} ./tv-stein/lookup_plugins/${lookup} 2>&1 > /dev/null
        ret=$?
        if [ $ret != 0 ]; then
            diff -U 1000 --color ${lk} ./tv-stein/lookup_plugins/${lookup} > ./${ms_lookup_patches}/${lookup}.diff
        fi
    fi

    if [[ -f ./tv-rocky/validations/lookup_plugins/${lookup} ]]; then
        diff ${lk} ./tv-rocky/validations/lookup_plugins/${lookup} 2>&1 > /dev/null
        ret=$?
        if [ $ret != 0 ]; then
            diff -U 1000 --color ${lk} ./tv-rocky/validations/lookup_plugins/${lookup} > ./${lookup_patches}/${lookup}.diff
        fi
    fi
done

# playbooks directory
for pl in `find ./tv-master/playbooks -type f -regex '.*\.y[a]?ml'`; do
    playbook=$(basename ${pl})

    if [[ -f ./tv-stein/playbooks/${playbook} ]]; then
        diff ${pl} ./tv-stein/playbooks/${playbook} 2>&1 > /dev/null
        ret=$?
        if [ $ret != 0 ]; then
            diff -U 1000 --color ${pl} ./tv-stein/playbooks/${playbook} > ./${ms_playbook_patches}/${playbook}.diff
        fi
    fi

    if [[ -f ./tv-rocky/validations/${playbook} ]]; then
        if grep -q "include_role:" ${pl}; then
            sed -e '/tasks:/,$d' ${pl} > ./tv-master-${playbook}
        else
            sed -e '/roles:/,$d' ${pl} > ./tv-master-${playbook}
        fi
        sed -e '/tasks:/,$d' ./tv-rocky/validations/${playbook} > ./rocky-${playbook}

        diff ./tv-master-${playbook} ./rocky-${playbook} 2>&1 > /dev/null
        ret=$?
        if [ $ret != 0 ]; then
            diff -U 1000 --color ./tv-master-${playbook} ./rocky-${playbook} > ./${playbook_patches}/${playbook}.diff
        fi

        rm -Rf ./rocky-${playbook}
        rm -Rf ./tv-master-${playbook}
    fi
done


pushd tv-master
for role in `ls ./roles/`; do
    git diff master:roles/${role}/ origin/stable/stein:roles/${role}/ > ../${ms_roles_patches}/${role}.diff
done
popd

# roles directory
for role in `ls ./tv-master/roles/`; do
    output=""
    for branch in stein rocky; do

        if [ ${branch} == "stein" ]; then
            output=${ms_validations_patches}
        else
            output=${roles_patches}
        fi

        if [[ ! -f ./tv-master/roles/${role}/tasks/main.yml ]] &&
           [[ ! -f ./tv-master/roles/${role}/tasks/main.yaml ]]; then
            for task in `ls ./tv-master/roles/${role}/tasks/`; do
                touch ./${branch}-${task} && echo "---" > ./${branch}-${task}
                sed -e '1,/tasks/d' ./tv-${branch}/validations/${task} | cut -b 1-2 --complement >> ./${branch}-${task}
                diff ./tv-master/roles/${role}/tasks/${task} ./${branch}-${task} 2>&1 > /dev/null
                ret=$?
                if [ $ret != 0 ]; then
                    diff -U 400 --color ./tv-master/roles/${role}/tasks/${task} ./${branch}-${task} > ./${output}/${task}.diff
                fi
                rm -Rf ./${branch}-${task}
            done
        else
            if [[ ${role} == "xfs-check-ftype" ]]; then
                touch ./${branch}-${role} && echo "---" > ./rocky-${role}
                sed -e '1,/tasks/d' ./tv-${branch}/validations/check-ftype.yaml | cut -b 1-2 --complement >> ./${branch}-${role}
                diff ./tv-master/roles/${role}/tasks/main.yml ./${branch}-${role} 2>&1 > /dev/null
                ret=$?
                if [ $ret != 0 ]; then
                    diff -U 400 --color ./tv-master/roles/${role}/tasks/main.yml ./${branch}-${role} > ./${output}/${role}.diff
                fi
                rm -Rf ./${branch}-${role}
            fi

            if [[ -f ./tv-${branch}/validations/${role}.yaml ]]; then
                touch ./${branch}-${role} && echo "---" > ./${branch}-${role}
                sed -e '1,/tasks/d' ./tv-${branch}/validations/${role}.yaml | cut -b 1-2 --complement >> ./${branch}-${role}
                inc_tasks=$(grep "include_tasks: " ./${branch}-${role} | tr -d " " | cut -d: -f2)
                if [[ -n $inc_tasks ]]; then
                    diff ./tv-master/roles/${role}/tasks/main.yml ./tv-${branch}/validations/${inc_tasks} 2>&1 > /dev/null
                    ret=$?
                    if [ $ret != 0 ]; then
                        diff -U 400 --color ./tv-master/roles/${role}/tasks/main.yml ./tv-${branch}/validations/${inc_tasks} > ./${output}/${role}.diff
                    fi
                else
                    diff ./tv-master/roles/${role}/tasks/main.yml ./${branch}-${role} 2>&1 > /dev/null
                    ret=$?
                    if [ $ret != 0 ]; then
                        diff -U 400 --color ./tv-master/roles/${role}/tasks/main.yml ./${branch}-${role} > ./${output}/${role}.diff
                    fi
                fi
                rm -Rf ./${branch}-${role}
            fi
        fi
    done
done
