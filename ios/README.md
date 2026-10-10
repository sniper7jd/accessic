# accessIC iOS client (Stage 1)

SwiftUI + ARKit + RealityKit sources for the Whalen Center first-floor prototype.

**This Linux environment cannot compile or run the app.** Create the Xcode project on your Mac, add these sources, and verify on a physical iPhone.

## Create the Xcode project (Mac)

1. Xcode → **File → New → Project → App**
2. Product name: `accessIC`
3. Interface: **SwiftUI**, Language: **Swift**, minimum deployment: **iOS 17.0**
4. Save under this repo as `ios/accessIC.xcodeproj` (or keep the generated folder and replace its sources with the files in `ios/accessIC/`)
5. Delete the template `ContentView.swift` / `*App.swift` if they conflict, then add every file under `ios/accessIC/` to the app target
6. Add `Resources/whalen_floor1_graph.prototype.json` to the target (Copy Bundle Resources)
7. Add a unit-test target and include `Tests/PoseAlignerTests.swift`

### Info.plist / target capabilities

| Key | Value |
|-----|--------|
| `NSCameraUsageDescription` | accessIC uses the camera for visual localization and optional AR guidance. |
| `NSLocalNetworkUsageDescription` | accessIC talks to the campus localization service on your local network. |
| `NSAppTransportSecurity` | Prefer HTTPS (Cloudflare tunnel). For temporary HTTP lab use only, add an exception you will remove before demo day. |

Enable **Augmented Reality** capability if Xcode prompts for it.

## Stage 1 behavior

- **2D Map** is the primary navigation surface.
- **AR** is optional and does **not** place world anchors while Mock mode is on.
- **Settings** toggles Mock vs Network, API base URL, and optional bearer token.
- Mock responses are labeled **MOCK — not physical alignment**.
- Floor graph file is `whalen_floor1_graph.prototype.json` with `data_state: "ui_prototype"`. It is for UI/Dijkstra testing only — not surveyed Whalen coordinates.

## Run on device

1. Select your physical iPhone (ARKit required).
2. Build & run.
3. Grant camera permission.
4. With Mock on: tap **Locate Me** → status shows mock pose + banner; route UI works on the prototype graph.
5. With Mock off: NetworkLocalizer calls `POST {baseURL}/localize` using the frozen schema. Expect failures until the GPU contract (Stage 2) and capture upload (Stage 4) are complete.

## Assumptions (Stage 1)

1. The GPU backend remains the source of truth; this repo does not rewrite HLoc/COLMAP.
2. Absolute positioning accuracy is **not** established by the 21/21 batch result.
3. `transform_matrix_map_from_camera` means \(T_{M \leftarrow C}\) (map ← COLMAP camera).
4. COLMAP camera is X-right / Y-down / Z-forward; ARKit camera is Y-up / Z-toward-user; \(C_{A \leftarrow C}=\mathrm{diag}(1,-1,-1,1)\).
5. Physical AR anchors stay disabled until `units == "meters"` and Mock is off.
6. `whalen_floor1_graph.prototype.json` is schematic UI data (`data_state: ui_prototype`), not surveyed Whalen coordinates.
7. Scope is Whalen Center 1st floor only — not Business School / H&S.
8. An Xcode project must be created on a Mac; this environment cannot claim a device build.
9. NetworkLocalizer already posts the frozen multipart fields; the GPU must accept them in Stage 2.
10. Capture currently prefers a live `ARFrame` when the AR tab has run; otherwise a placeholder JPEG is used for mock/UI flow.

## Acceptance (Stage 1)

- [ ] App builds in Xcode on a physical iPhone
- [ ] Camera permission and AR session start without the GPU
- [ ] Mock localize updates 2D status and never claims physical doorway alignment
- [ ] `PoseAlignerTests` pass in the unit-test target
- [ ] No Business School / H&S navigation claims in UI copy

## Next stages (not done here)

- Stage 2: GPU returns `shared/api/localize.schema.json`
- Stage 3: verified metric scale → `units: "meters"`
- Stage 4: real `ARFrame` capture + calibration upload
- Stage 5: one surveyed anchor using `T_W_from_M`
- Stage 6: replace prototype graph with verified live map data
