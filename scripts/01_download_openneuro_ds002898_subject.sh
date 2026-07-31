#!/usr/bin/env bash
set -euo pipefail

SUBJECT="${1:-sub-01}"
DATASET="/media/andraderenew/Elements/neuroimaging/pet_fdg-suvr-pvc_spm-petpve12_openneuro-ds002898/openneuro-ds002898"
TOOLS="$HOME/.local/share/openneuro-ds002898-tools"
AWS="$TOOLS/bin/aws"
LOG="$HOME/Downloads/ds002898_${SUBJECT}_download.log"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

[[ "$SUBJECT" =~ ^sub-[A-Za-z0-9]+$ ]] || die "usage: $0 sub-XX"
[[ -d "/media/andraderenew/Elements" ]] || die "Elements drive is not mounted"

if [[ ! -x "$AWS" ]]; then
    echo "=== INSTALLING ANONYMOUS OPENNEURO DOWNLOAD TOOL ==="
    mkdir -p "$HOME/.local/share"
    python3 -m venv "$TOOLS"
    "$TOOLS/bin/python" -m pip install --upgrade pip
    "$TOOLS/bin/python" -m pip install "awscli<2"
fi

mkdir -p "$DATASET"

echo "=== DOWNLOADING OPENNEURO ds002898 / $SUBJECT ==="
echo "Target: $DATASET"

"$AWS" s3 sync \
    "s3://openneuro.org/ds002898/" \
    "$DATASET/" \
    --no-sign-request \
    --only-show-errors \
    --exclude "*" \
    --include "dataset_description.json" \
    --include "README*" \
    --include "CHANGES*" \
    --include "LICENSE*" \
    --include "participants.tsv" \
    --include "participants.json" \
    --include "$SUBJECT/anat/*" \
    --include "$SUBJECT/pet/*" \
    --include "derivatives/mcflirt/$SUBJECT/pet/*" \
    2>&1 | tee "$LOG"

T1_COUNT="$(
    find "$DATASET/$SUBJECT" -type f \
        \( -iname '*T1w.nii' -o -iname '*T1w.nii.gz' \) \
        2>/dev/null | wc -l
)"
PET_COUNT="$(
    find "$DATASET/$SUBJECT" -type f \
        \( -iname '*pet.nii' -o -iname '*pet.nii.gz' \) \
        2>/dev/null | wc -l
)"
JSON_COUNT="$(
    find "$DATASET/$SUBJECT" -type f -iname '*pet.json' \
        2>/dev/null | wc -l
)"

echo "T1w files: $T1_COUNT"
echo "PET NIfTI files: $PET_COUNT"
echo "PET JSON files: $JSON_COUNT"

[[ "$T1_COUNT" -ge 1 ]] || die "no T1w file downloaded"
[[ "$PET_COUNT" -ge 1 ]] || die "no PET NIfTI file downloaded"
[[ "$JSON_COUNT" -ge 1 ]] || die "no PET JSON sidecar downloaded"

echo "DOWNLOAD COMPLETE"
