#!/bin/bash

SPECIFIC_OVERLAY=$1
OVERLAYS_BASE="overlays" # Adjust if your base path is different
PACKAGE_FOLDER="manifests/packages"
CONFIG_FOLDER="manifests/config"
PACKAGE_PREFIX="pkg-"

build_overlay() {
    local overlay_name="$1"
    local overlay_src="${OVERLAYS_BASE}/${overlay_name}"
    local config_dest="${CONFIG_FOLDER}/${overlay_name}"

    if [[ ! -f "${overlay_src}/kustomization.yaml" ]]; then
        echo "No 'kustomization.yaml' file found in overlay: ${overlay_name}. Skipping..."
        return
    fi

    local helm_flag=""
    if grep -q "helmCharts" "base/kustomization.yaml" 2>/dev/null || grep -q "helmCharts" "${overlay_src}/kustomization.yaml" 2>/dev/null; then
        helm_flag="--enable-helm"
    fi

    echo "Building overlay: ${overlay_name}"

    # Ensure destination directories exist
    mkdir -p "${config_dest}"
    mkdir -p "${PACKAGE_FOLDER}"

    # Run the kustomize build command, redirecting stdout to the file.
    # We pipe stderr through process substitution to filter out warnings without corrupting the YAML file.
    kustomize build ${helm_flag} "${overlay_src}" > "${config_dest}/${overlay_name}-generated.yaml" 2> >(grep -i -v "Warn" | grep -i -v "Deprecat" >&2)
    kustomize build ${helm_flag} "${overlay_src}" > "${PACKAGE_FOLDER}/${PACKAGE_PREFIX}${overlay_name}.yaml" 2> >(grep -i -v "Warn" | grep -i -v "Deprecat" >&2)

    if command -v nomos >/dev/null 2>&1; then
        echo "Checking nomos status"
        nomos vet --source-format=unstructured --no-api-server-check --path "${config_dest}/"
    else
        echo "'nomos' is not installed and is highly recommended. Proceeding without nomos verification"
    fi
}

if [[ -z "${SPECIFIC_OVERLAY}" ]]; then
    echo "Building all overlays"
    rm -rf "${PACKAGE_FOLDER}"
    mkdir -p "${PACKAGE_FOLDER}"
    rm -rf "${CONFIG_FOLDER}"
    mkdir -p "${CONFIG_FOLDER}"

    # Find all directories within the overlays base
    for overlay_dir in "$OVERLAYS_BASE"/*/; do
        # Extract the directory name without the trailing slash
        overlay_name=$(basename "${overlay_dir}")
        build_overlay "${overlay_name}"
    done
else
    build_overlay "${SPECIFIC_OVERLAY}"
fi
