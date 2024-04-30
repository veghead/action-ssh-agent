#!/bin/bash
#

echo "Adding github host keys"
SSH_HOME="${HOME}/.ssh";
[ -d "${SSH_HOME}" ] || mkdir "${SSH_HOME}"
umask 077
cat << EOH >${SSH_HOME}/known_hosts
github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
EOH

SSH_AGENT_ARGS=""

if [ "x${INPUT_SSH_AUTH_SOCK_PATH}" != "x" ]
then
    SSH_AGENT_ARGS="-a ${INPUT_SSH_AUTH_SOCK_PATH}"
fi

TMP_FILE=$( mktemp )
ssh-agent ${SSH_AGENT_ARGS} >${TMP_FILE}
source "${TMP_FILE}"
rm "${TMP_FILE}"

STATE="NUFFINK"

IFS="
"
for KEY in ${INPUT_PRIVATE_KEYS}
do
    if [[ "${STATE}" = "NUFFINK" && "${KEY}" =~ -----BEGIN ]]
    then
        STATE="INKEY"
        NEXT_KEY=""
    fi
    if [[ "${STATE}" = "INKEY" ]]
    then
        NEXT_KEY="${NEXT_KEY}${KEY}"$'\n'
        if [[ "${KEY}" =~ -----END ]]
        then
            echo "${NEXT_KEY}" | ssh-add -
            STATE="NUFFINK"
        fi
    fi
done


# Get a list of the stored keys' public-keys and comments 
# from ssh-add
unset IFS
KID=0
ssh-add -L | while read TYPE PUBLIC COMMENT
do
    if [[ "${COMMENT}" =~ github\.com[:/]([_.a-zA-Z0-9-]+\/[_.a-zA-Z0-9-]+) ]]
    then
        ORG_REPO="${BASH_REMATCH[1]}"
        echo "${TYPE} ${PUBLIC}" > "${SSH_DIR}/key-${KID}"
        cat <<EOF >>"${SSH_DIR}/config"
Host key-${KID}.github.com
    Hostname github.com
    IdentityFile ${SSH_DIR}/key-${KID}
    IdentitiesOnly yes

EOF
	git config --global --replace-all url."git@key-${KID}.github.com:${ORG_REPO}".insteadOf "https://github.com/${ORG_REPO}"
        git config --global --add url."git@key-${KID}.github.com:${ORG_REPO}".insteadOf "git@github.com:${ORG_REPO}"
        git config --global --add url."git@key-${KID}.github.com:${ORG_REPO}".insteadOf "ssh://git@github.com/${ORG_REPO}"

        let "KID=KID+1"
    else
        echo "Oops: ${COMMENT}"	
    fi
done


