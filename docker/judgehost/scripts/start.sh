#!/bin/bash -e

function file_or_env {
    file=${1}_FILE
    if [ -n "${!file}" ]; then
        cat -- "${!file}"
    else
        printf '%s' "${!1}"
    fi
}

starter_pid=
stop_requested=0

forward_term() {
    local pid=
    local command_line=
    local lock_file
    lock_file="/opt/domjudge/judgehost/run/judge.$(hostname -s)-${DAEMON_ID}.lock"

    stop_requested=1
    if [[ -r "$lock_file" ]]; then
        pid="$(cat "$lock_file")"
        if [[ "$pid" =~ ^[0-9]+$ && "$pid" -gt 1 && -r "/proc/${pid}/cmdline" ]]; then
            command_line="$(tr '\0' ' ' < "/proc/${pid}/cmdline")"
            if [[ "$command_line" == *"/opt/domjudge/judgehost/bin/judgedaemon -n ${DAEMON_ID} "* ]]; then
                kill -TERM "$pid" 2>/dev/null || true
                return
            fi
        fi
    fi

    if [[ -n "$starter_pid" ]]; then
        kill -TERM "$starter_pid" 2>/dev/null || true
    fi
}

trap forward_term TERM INT HUP

echo "[..] Setting timezone"
ln -snf "/usr/share/zoneinfo/${CONTAINER_TIMEZONE}" /etc/localtime
echo "${CONTAINER_TIMEZONE}" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata
echo "[ok] Container timezone set to: ${CONTAINER_TIMEZONE}"; echo

cd /opt/domjudge/judgehost

JUDGEDAEMON_PASSWORD=$(file_or_env JUDGEDAEMON_PASSWORD)

echo "[..] Setting up restapi file"
if [[ -f /opt/domjudge/judgehost/legacy ]]
then
  echo "default	${DOMSERVER_BASEURL}api	${JUDGEDAEMON_USERNAME}	${JUDGEDAEMON_PASSWORD}" > etc/restapi.secret
else
  echo "default	${DOMSERVER_BASEURL}api/v4	${JUDGEDAEMON_USERNAME}	${JUDGEDAEMON_PASSWORD}" > etc/restapi.secret
fi
echo "[ok] Restapi file set up"; echo

echo "[..] Setting up cgroups"
bin/create_cgroups
echo "[ok] cgroups set up"; echo

echo "[..] Copying resolv.conf to chroot"
cp /etc/resolv.conf /chroot/domjudge/etc/resolv.conf
echo "[ok] resolv.conf copied"; echo

if ! id "domjudge-run-${DAEMON_ID}" > /dev/null 2>&1; then
  groupadd -g "${RUN_USER_UID_GID}" domjudge-run
  useradd -u "${RUN_USER_UID_GID}" -N -d /nonexistent -g nogroup -s /bin/false "domjudge-run-${DAEMON_ID}"
fi

# A stop signal interrupts wait while the daemon finishes its current judging.
set +e
[[ "$stop_requested" == 0 ]] || exit 0

sudo -u domjudge \
    DOMJUDGE_CREATE_WRITABLE_TEMP_DIR="${DOMJUDGE_CREATE_WRITABLE_TEMP_DIR}" \
    /opt/domjudge/judgehost/bin/judgedaemon -n "${DAEMON_ID}" &
starter_pid=$!
if [[ "$stop_requested" == 1 ]]; then
    forward_term
fi

while kill -0 "$starter_pid" 2>/dev/null; do
    wait "$starter_pid" || true
done
if wait "$starter_pid"; then
    result=0
else
    result=$?
fi

# Correct verdicts may still be uploading after the main daemon exits.
while pgrep -f '/opt/domjudge/judgehost/bin/[j]udgedaemon -e ' >/dev/null; do
    sleep 1
done
exit "$result"
