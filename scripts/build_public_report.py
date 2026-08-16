from __future__ import annotations

import os
from pathlib import Path

import numpy as np
import pandas as pd


subject = "sub-01"

repo_root = Path(__file__).resolve().parents[1]

project_root = Path(
    os.environ.get(
        "PET_PROJECT_ROOT",
        str(repo_root),
    )
)

work = project_root / "work" / subject
results = work / "results"

decomposition_path = (
    results
    / "diagnostic_primary_gray_psf_decomposition.tsv"
)

robust_summary_path = (
    results
    / "robust_primary_gray_psf_summary.tsv"
)

required = [
    decomposition_path,
    robust_summary_path,
    repo_root / "docs" / "RESULTS_SUB01.md",
    repo_root / "docs" / "METHODS_SUB01.md",
]

for path in required:
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(
            f"ERROR: missing report input: {path}"
        )

decomposition = pd.read_csv(
    decomposition_path,
    sep="\t",
)

summary = pd.read_csv(
    robust_summary_path,
    sep="\t",
)

if len(decomposition) != 84:
    raise SystemExit(
        f"ERROR: expected 84 primary-gray ROIs, "
        f"got {len(decomposition)}"
    )

if int(
    decomposition["low_gm_support_lt20"].sum()
) != 3:
    raise SystemExit(
        "ERROR: expected three low-support ROIs"
    )

robust = decomposition[
    decomposition["robust_primary_gm20"] == 1
].copy()

if len(robust) != 81:
    raise SystemExit(
        f"ERROR: expected 81 robust ROIs, "
        f"got {len(robust)}"
    )

row = summary[
    summary["population"]
    == "robust_primary_gray_gm20"
]

if len(row) != 1:
    raise SystemExit(
        "ERROR: robust summary row missing"
    )

row = row.iloc[0]

expected = {
    "suvr_cv_median_percent":
        1.4366986814905816,
    "suvr_cv_max_percent":
        6.037496750311221,
    "pvc_activity_cv_median_percent":
        3.0289178454729178,
    "pvc_activity_cv_max_percent":
        8.58715489301545,
}

for key, expected_value in expected.items():
    observed = float(row[key])

    if not np.isclose(
        observed,
        expected_value,
        rtol=0.0,
        atol=1e-10,
    ):
        raise SystemExit(
            f"ERROR: report metric drift "
            f"{key}: {observed}"
        )

if int(row["n_rois"]) != 81:
    raise SystemExit(
        "ERROR: robust report n_rois != 81"
    )

results_text = (
    repo_root
    / "docs"
    / "RESULTS_SUB01.md"
).read_text(
    encoding="utf-8"
)

methods_text = (
    repo_root
    / "docs"
    / "METHODS_SUB01.md"
).read_text(
    encoding="utf-8"
)

required_result_fragments = [
    "81 ROIs",
    "1.437%",
    "6.037%",
    "3.029%",
    "8.587%",
    "6.858%",
    "low-support",
]

for fragment in required_result_fragments:
    if fragment not in results_text:
        raise SystemExit(
            "ERROR: canonical results document "
            f"missing: {fragment}"
        )

required_method_fragments = [
    "at least 20 voxels",
    "post hoc during QA",
    "All 84 predefined primary ROIs remain",
]

for fragment in required_method_fragments:
    if fragment not in methods_text:
        raise SystemExit(
            "ERROR: canonical methods document "
            f"missing: {fragment}"
        )

(results / "RESULTS_SUB01.md").write_text(
    results_text,
    encoding="utf-8",
)

(results / "METHODS_SUB01.md").write_text(
    methods_text,
    encoding="utf-8",
)

print("REPORT_SCIENTIFIC_VALIDATION=PASS")
print("REPORT_PRIMARY_ROIS=84")
print("REPORT_LOW_SUPPORT=3")
print("REPORT_ROBUST_ROIS=81")
print(
    "REPORT_SUVR_MEDIAN",
    float(row["suvr_cv_median_percent"]),
)
print(
    "REPORT_SUVR_MAX",
    float(row["suvr_cv_max_percent"]),
)
print(
    "REPORT_PVC_MEDIAN",
    float(
        row[
            "pvc_activity_cv_median_percent"
        ]
    ),
)
print(
    "REPORT_PVC_MAX",
    float(
        row[
            "pvc_activity_cv_max_percent"
        ]
    ),
)
