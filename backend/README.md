# accessIC backend (GPU)

The live reconstruction and FastAPI `/localize` service run on the remote NVIDIA GPU host (`accessIC-backend` on Lambda). That codebase is the source of truth for HLoc, COLMAP, and inference.

## Do not rewrite from this repo

This directory is a pointer only. Keep the working GPU pipeline as the baseline. Change the response schema there to match [`../shared/api/localize.schema.json`](../shared/api/localize.schema.json) when you freeze the contract (Stage 2).

## Expected local layout on the GPU machine

```text
accessIC-backend/
├── dataset/
├── outputs/whalen_floor1/
├── main.py
├── build_whalen_map.py
├── batch_test_api.py
└── requirements.txt
```

## Contract freeze checklist (Stage 2)

1. Return `status: "success"` only when a pose is actually estimated.
2. Use `transform_matrix_map_from_camera` as the authoritative pose (`T_M_from_C`).
3. Use `quaternion_xyzw` (xyzw order) derived from the same estimator output.
4. Failed poses: `status: "failed"`, `error_code`, `error` — no pose fields.
5. Accept client-supplied `image_width_px`, `image_height_px`, and `intrinsics_3x3`; do not depend on EXIF.
6. Record `map_id` / code version with every successful response.

## Run (on the GPU host)

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 1
```

Expose via a secured tunnel or campus endpoint for the iOS client. Prefer HTTPS and a simple auth token for public demos.
