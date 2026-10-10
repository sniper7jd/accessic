# accessIC: Markerless Indoor Accessible Navigation

accessIC combines Structure-from-Motion (SfM) visual positioning with client-side pathfinding for step-free indoor routes without beacons, QR codes, or indoor GPS.

**Current prototype scope:** Whalen Center first floor only. Business School / H&S / outdoor links are future graph extensions after Whalen localization and routing are trustworthy.

---

## 1. System architecture

```text
[iPhone]
  │  JPEG + intrinsics + capture-time ARKit pose
  ▼
[NVIDIA GPU — FastAPI POST /localize]
  SuperPoint → NetVLAD → LightGlue/PnP
  returns T_M_from_C (map ← COLMAP camera)
  ▲
[Native iOS — SwiftUI + ARKit + RealityKit]
  PoseAligner: T_W_from_M = T_W_from_A · C_A_from_C · T_M_from_C⁻¹
  2D floor map (primary) · optional AR · accessible Dijkstra · speech
```

### Coordinate frames

| Symbol | Meaning |
|--------|---------|
| `M` | Whalen reconstructed map frame |
| `C` | COLMAP camera (`X` right, `Y` down, `Z` forward) |
| `A` | ARKit camera (`Y` up, local `Z` toward user) |
| `W` | ARKit session world |

Camera-axis conversion (not a substitute for metric scale):

```text
C_A_from_C = diag(1, -1, -1, 1)
T_W_from_M = T_W_from_A · C_A_from_C · inverse(T_M_from_C)
```

---

## 2. Repository layout

```text
accessIC/
├── backend/                 # Pointer docs; live code stays on the GPU host
├── ios/accessIC/            # Stage 1 Swift sources (add to a Mac-created Xcode app)
├── shared/api/
│   └── localize.schema.json # Frozen Python ↔ Swift contract
└── README.md
```

---

## 3. API contract

See [`shared/api/localize.schema.json`](shared/api/localize.schema.json).

- Authoritative pose: `transform_matrix_map_from_camera` (`T_M_from_C`, JSON row-major).
- Quaternion: `quaternion_xyzw` (xyzw).
- Failure: `status: "failed"` with `error_code` and `error` — **no pose fields**.
- Never treat HTTP 200 alone as successful localization.
- Client sends JPEG plus `image_width_px`, `image_height_px`, and `intrinsics_3x3` (no EXIF reliance).

---

## 4. Milestone status

| Phase | Milestone | Status | Notes |
|-------|-----------|--------|-------|
| 1 | A100 GPU environment | Complete | PyTorch, LightGlue, SuperPoint on CUDA |
| 2 | Stray Scanner captures | Complete | 4 Whalen 1st-floor sessions |
| 3 | SfM map construction | Complete | Sparse COLMAP model |
| 4 | Live `/localize` | Complete (preliminary) | 21/21 batch; ~166 avg inliers; ~6.3 s — **not** proof of absolute accuracy |
| 5 | Metric scale + map version | Not started | Required before physical AR anchors |
| 6 | iOS client Stage 1 shell | In progress (this repo) | Mock UI only until contract + scale + device verification |
| 7 | Accessible 2D / voice | Pending | After verified graph |

**Batch test snapshot (preliminary):** 21 success / 0 fail, avg inliers 165.8, avg latency 6.315 s. These pass the API success criteria on the current test set; they do not establish navigation-grade absolute positioning.

---

## 5. Implementation order

1. Preserve GPU backend baseline.
2. Freeze response contract to `localize.schema.json`.
3. Establish metric scale (Stray odometry + measured lengths).
4. Create Xcode app on a Mac; add `ios/accessIC` sources; run on a physical iPhone.
5. Capture one `ARFrame` (image + intrinsics + `T_W_from_A`); upload; parse status explicitly.
6. Verify one surveyed AR anchor via `PoseAligner`.
7. Add verified floor graph + accessible routing (2D first).
8. Accessibility polish; then profile GPU latency.

---

## 6. Honest demo rules

- Mock localization is for UI/routing development only and must stay visibly labeled.
- Do not claim a virtual object is aligned with a physical doorway until measured on site.
- Do not describe unverified graph edges as accessible.
- Prefer a clear “Locating…” and failure path over a fast but misaligned arrow.
