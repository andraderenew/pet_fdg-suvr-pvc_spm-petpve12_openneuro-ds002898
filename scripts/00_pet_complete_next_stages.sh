#!/usr/bin/env bash
set -euo pipefail

STAGE="${1:-help}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_stage() {
    local script="$1"
    shift
    echo
    echo "================================================================"
    echo "RUNNING: $script $*"
    echo "================================================================"
    "$SCRIPT_DIR/$script" "$@"
}

case "$STAGE" in
    audit)
        run_stage "08_audit_petpve12_inputs.sh"
        ;;
    pvc)
        run_stage "09_run_petpve12_psf_sensitivity.sh"
        ;;
    atlas)
        run_stage "10_prepare_dk_atlas_reference.sh"
        ;;
    suvr)
        run_stage "11_compute_suvr_roi_sensitivity.sh"
        ;;
    report)
        run_stage "12_build_public_report.sh"
        ;;
    validate)
        run_stage "13_validate_complete_outputs.sh"
        ;;
    all)
        run_stage "08_audit_petpve12_inputs.sh"
        run_stage "09_run_petpve12_psf_sensitivity.sh"
        run_stage "10_prepare_dk_atlas_reference.sh"
        run_stage "11_compute_suvr_roi_sensitivity.sh"
        run_stage "12_build_public_report.sh"
        run_stage "13_validate_complete_outputs.sh"
        ;;
    stage-github)
        run_stage "14_stage_github_results.sh"
        ;;
    push-github)
        run_stage "14_stage_github_results.sh" --push
        ;;
    status)
        WORK="/media/andraderenew/Elements/neuroimaging/pet_fdg-suvr-pvc_spm-petpve12_openneuro-ds002898/work/sub-01"
        echo "Work directory:"
        echo "  $WORK"
        echo
        find "$WORK" -maxdepth 4 -type f -printf '%s\t%p\n' 2>/dev/null | sort -n | tail -60
        ;;
    help|*)
        cat <<'EOF'
OpenNeuro ds002898 PETPVE12 controlled completion

Run in this order:

  ./00_pet_complete_next_stages.sh audit
  ./00_pet_complete_next_stages.sh pvc
  ./00_pet_complete_next_stages.sh atlas
  ./00_pet_complete_next_stages.sh suvr
  ./00_pet_complete_next_stages.sh report
  ./00_pet_complete_next_stages.sh validate

Or run all processing stages, without GitHub push:

  ./00_pet_complete_next_stages.sh all

Only after reviewing every final QC image:

  ./00_pet_complete_next_stages.sh stage-github

To commit and push after staging:

  ./00_pet_complete_next_stages.sh push-github

Scientific policy:
- nominal protocol-aligned PSF: 5 mm isotropic;
- sensitivity PSFs: 4, 6 and 8 mm isotropic;
- MG settings: GM threshold 0.5 and WM/CSF signal threshold 0.9;
- SUVR reference: bilateral Desikan-Killiany cerebellar cortex labels 8 and 47;
- this is a research portfolio demonstration, not clinical software.
EOF
        ;;
esac
