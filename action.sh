#!/bin/bash -e

export DIRECTORY=${DIRECTORY:-.update}
export DIRECTORY_PATH=${DIRECTORY}/${DIRECTORY_PATH}
export FILE_PATTERN=${FILE_PATTERN:-variables.tf}
export BRANCH=${BRANCH:-develop}
export SUFFIX=${SUFFIX:-\"}

if [[ "${SUFFIX}" == "off" ]]; then
    unset SUFFIX
fi

if [ -z "${SSH_PRIVATE_KEY}" ]; then
    echo "ERROR: SSH_PRIVATE_KEY is required to clone private repositories" && exit 1
fi

if [ -z "${TARGET_REPO}" ]; then
    echo "ERROR: TARGET_REPO must be set to an SSH git clone URL" && exit 2
fi

if [ -z "${SEARCH_KEY}" ]; then
    export SEARCH_KEY="$(echo ${GITHUB_REPOSITORY} | sed -e 's|.*/||'):"
fi

if [ -z "${REPLACE_VALUE}" ]; then
    export REPLACE_VALUE=${GITHUB_SHA}
fi

# enable cloning of private repositories
mkdir -p ~/.ssh
ssh-keyscan -t rsa github.com >>~/.ssh/known_hosts
eval $(ssh-agent)
ssh-add - <<<"${SSH_PRIVATE_KEY}"

# clone target git repository
git clone -b ${BRANCH} ${TARGET_REPO} ${DIRECTORY}
cd ${DIRECTORY_PATH}

# update the value
sed -i '' -i -e "s/${SEARCH_KEY}.*/${SEARCH_KEY}${REPLACE_VALUE}${SUFFIX}/g" $FILE_PATTERN
git config --global user.email "no@reply.com"
git config --global user.name "GitHub Actions"
git commit -am "${SEARCH_KEY}${REPLACE_VALUE}" || echo "No changes needed"

# retry logic to mitigate race conditions between multiple repositories
for i in 1 2 3 4 5; do git push && exit 0 || git pull -r && sleep 5; done
echo "ERROR: could not push to git repo" && exit 5