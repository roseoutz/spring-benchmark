#!/usr/bin/env bash
set -euo pipefail

print_usage() {
  cat >&2 <<'USAGE'
Usage: run_k6_adapter.sh <adapter> [<adapter> ...] [-- k6 args]

Examples:
  run_k6_adapter.sh spring_vt -- --vus 50 --duration 2m
  run_k6_adapter.sh spring_vt spring_platform -- --vus 20
USAGE
}

if [[ $# -lt 1 ]]; then
  print_usage
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
K6_SCRIPT="${REPO_ROOT}/k6/workload.js"
REPORT_DIR="${REPO_ROOT}/reports"
mkdir -p "${REPORT_DIR}"

if ! command -v k6 >/dev/null 2>&1; then
  echo "k6 binary not found on PATH" >&2
  exit 2
fi

declare -a ADAPTERS=()
declare -a K6_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --)
      shift
      K6_ARGS=("$@")
      break
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      ADAPTERS+=("$1")
      ;;
  esac
  shift || true
done

if [[ ${#ADAPTERS[@]} -eq 0 ]]; then
  echo "No adapters specified" >&2
  exit 1
fi

run_for_adapter() {
  local adapter_key="$1"
  shift
  local timestamp="$(date +"%Y%m%d-%H%M%S")"
  local report_file="${REPORT_DIR}/${adapter_key}-${timestamp}.md"
  local tmp_output
  tmp_output="$(mktemp)"
  trap 'rm -f "${tmp_output}"' RETURN

  local run_cmd=(k6 run "${K6_SCRIPT}" "$@")

  set +e
  set +o pipefail
  ADAPTER="${adapter_key}" LOG_TPS="${LOG_TPS:-true}" "${run_cmd[@]}" | tee "${tmp_output}"
  local k6_exit=${PIPESTATUS[0]}
  set -e
  set -o pipefail

  local threshold_errors
  threshold_errors=$(grep -n "ERRO" "${tmp_output}" || true)

  {
    echo "# ${adapter_key} k6 Report (${timestamp})"
    echo
    echo "- Command: \`ADAPTER=${adapter_key} ${run_cmd[*]}\`"
    echo "- Exit Code: ${k6_exit}"
    if [[ -n "${threshold_errors}" ]]; then
      echo "- Threshold Errors:"
      while IFS= read -r line; do
        [[ -z "${line}" ]] && continue
        echo "  - ${line}"
      done <<< "${threshold_errors}"
    else
      echo "- Threshold Errors: None"
    fi
    echo
    echo "## Raw Output"
    echo
    echo '\```'
    cat "${tmp_output}"
    echo '\```'
  } > "${report_file}"

  echo "" >&2
  echo "Markdown report written to ${report_file}" >&2

  return ${k6_exit}
}

overall_exit=0
for adapter in "${ADAPTERS[@]}"; do
  if ! run_for_adapter "${adapter}" "${K6_ARGS[@]}"; then
    overall_exit=$?
    echo "Adapter ${adapter} failed with exit ${overall_exit}" >&2
  fi
done

exit ${overall_exit}
