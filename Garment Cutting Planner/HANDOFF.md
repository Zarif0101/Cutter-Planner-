# Garment Cutting Planner: handoff notes

Context for the next session. Work done on 2026-11-21.

## The project
- The user is acting as the accountant of a Bangladesh knit-garment factory (doing this job for someone else; do not save personal memories about them).
- Goal: cut fabric waste in the cutting room (yield toward 90%) and automate marker making on a low budget, with no expensive machinery.
- The team are newcomers: explain simply, use examples, and ask only a few high-impact questions, one at a time.
- Reports are needed in both English and Bangla.

## Factory facts gathered in the interview
- Product: T-shirts, mostly polyester, sometimes cotton. About 50,000 a month, with several new orders every week.
- Markers are made by hand with cardboard patterns and chalk. There are no CAD files, and the pattern master works by hand.
- Fabric use is not tracked. The fabric width and number of layers change with each order.
- Equipment: a computer, a phone, a printer and internet. The budget is small, mainly for a plotter.
- A younger staff member who is good with computers will run the system.
- Priorities: 1. fabric waste, 2. time, 3. mistakes, 4. speed. No rush.
- Costs: yarn about 411 tk/kg (November bills 977–979: 4,508 kg for Tk 18.54 lakh), knitting 38 tk/kg and dyeing 100 tk/kg, so finished fabric is about 549 tk/kg. Jhut (scraps) sells for 4–5 tk/kg, so each wasted kg loses about 545 tk.
- Bill 979, line 2 (20D Creora) says 36 kg × 3 = 72 kg, which should be 108 kg. This still needs checking with the supplier.

## Files in this folder
- `Cutting-Room-Execution-Report-EN/BN` (.docx and .pdf): the execution report with 6 phases and 3 budget tiers (Tier 0 free; Tier 1 about Tk 3–4 lakh with a plotter at about Tk 2.5–3.5 lakh; Tier 2 adds quoted items).
- `report-source/`: plain-text sources of the report and `build-report.ps1`, which turns them into DOCX by hand-built XML and into PDF with Edge headless. The machine has no Word, LibreOffice, Python or Node.
  Rebuild with: `.\report-source\build-report.ps1 -Source report-source\report-en.txt -OutBase .\Cutting-Room-Execution-Report-EN -Lang en`
- `marker-planner.html`: the Marker Planner web app, published as a private artifact at
  https://claude.ai/artifact/PN49c9v6EB6e1TGW4zeJuJ (republish from this file to keep the link).
- `tests/`: headless-Edge test pages (`bench-tail.html` benchmarks the engines; `test-tail.html` runs a functional and security test). To use them, wrap them around the planner HTML with `window.__MP_NO_WORKER=true` and `__MP_NO_AUTORUN`, then run Edge `--headless=new --virtual-time-budget=... --dump-dom`.

## Marker Planner (engine v2)
- Manager screen: order quantities by size, fabric and table (width, GSM, table length and width, maximum layers), and a "Make cutting plan" button. It shows the lay plan, a size check, each marker drawing, and plotter files (.zip containing PLT, DXF and SVG, saved through the artifact `downloads` capability). It has a Keep improving panel (time or tries, marker or whole plan) and an Advanced settings section. It is bilingual (English and Bangla).
- Engine (runs in a Web Worker): conservative rasters with interval occupancy; a bottom-left start with order mutation; overlap minimisation with guided local search (shrink 4%, cell penalties); 1 mm compaction; and cut order planning using a pilot method with table and layer limits.
- Benchmark on the 6-garment marker: at 66 in, the old engine scored 84.4%, Thorough 86.9% and Quick about 83.2%. At 60 in, the old engine scored 74.8% and the new one about 76%. The example 4,500-piece order uses about 730–750 kg against about 778 kg with hand markers.
- Security fixes: SVG import rebuilt from an allow-list, file size and shape limits, all numeric inputs clamped, and saved settings validated.

## Marker Planner v3 (2026-11-21, later session)
- Saving fixed: outside claude.ai (file opened on a PC or phone) there is no `downloads` capability, so every save used to fail. Now it falls back to a normal browser download. Added Save/Open project (.json), lay plan CSV for Excel, and Print cutting sheet.
- Pattern pieces moved out of Advanced into step 1: Example T-shirt or My own pieces. Own pieces come from a phone photo or scan (tap 4 corners of a tape rectangle of known size → homography → Otsu threshold → trace → 0.6 mm simplify), DXF (AAMA blocks, layer 1 cut line, layer 7 grain) or SVG. Each piece has a size (or all sizes), a quantity per garment, turn, mirror, open-the-fold and a true-length rescale. Synthetic photo test: 300×400 and 350×600 mm pieces measured exactly.
- The factory uses a straight-knife cutter (photo sent). Step 3 has blade length and layer thickness, which give a suggested maximum layer count ((blade − 2.2 in) × 75% / thickness).
- New numbers: fabric cost in Tk, saving against hand markers in kg and Tk, cutting waste in kg and net Tk, metres to spread, knife travel and cutting hours, grams per garment.
- The planner is not yet verified inside claude.ai on a phone, and the browser download is not yet verified in real Chrome or Edge.

## Smart input (2026-11-22)
- The user wants little manual work and no paid AI for now. AI stays a disabled "Planned" option.
- Step 1 starts with a garment picker: T-shirt, long-sleeve T-shirt, tank top, polo, leggings, shorts, joggers.
  - Engine `GARMENT_PIECES` and `pieceShape()` cover body, sleeve, placket, leg (`legShape`: one-piece leg with front and back rise), waistband and cuff. Bands run across the grain.
  - Tops use `COLS`. Bottoms use `BCOLS` (waist, hip, front and back rise, thigh, knee, leg opening, inseam, band height) in the same 11-slot table; use `colIndex()`.
  - `state.measBy[garment]` holds each garment's table. Older saves (`meas`) load as the T-shirt table.
- Spec sheet reader, no AI (`readSpec` and `applySpec`):
  - Input: paste from Excel into the textarea (it reads on paste), CSV, or Excel through SheetJS 0.18.5 from cdnjs, loaded only when needed.
  - It finds the size row (XXL becomes 2XL), matches point-of-measure names with regex rules (`POM_RULES`, `POM_RULES_BOTTOM`), reads fractions and works out inches, cm or mm, halves full-round values (`FULL_ROUND`), and grades sizes the sheet leaves out using the pattern's own size steps.
  - Tested: a T-shirt sheet in inches and a leggings sheet in cm with circumferences.
- Smart photo (`straightenPiece`, `nameRoles`, `smartUpdate`):
  - Straightens each piece by minimum-area rectangle plus mirror symmetry.
  - Opens half patterns: one side has a straight run of 80% or more of the height, 12% or more longer than the other side.
  - Names pieces by size and neckline depth (front, back, sleeve ×2, placket ×2, leg ×2, waistband, cuff ×2).
  - "Make the other sizes automatically" grades the photographed size to S–2XL by measurement ratios.
  - Tested on a synthetic photo: half front at 17° became 53.1 × 74.8 cm against a true 53.0 × 74.8 cm, the back measured 53.1 × 74.7 cm, and 15 pieces were added.
- Photo detection now starts on a timer instead of `requestAnimationFrame`, because a hidden or background tab never fired it.

## Example photos for testing the scan (2026-11-22)
- Step 1, "From cardboard pattern" has an "Example photos" menu (`EXAMPLES`, `drawExample`, `openExample`). Each example draws cardboard pieces from the real pattern maths, adds tape, shadows and pencil marks, warps the sheet into a tilted 2400 px phone photo, and lists the true sizes in the dialog (`#ph-expect`) so the found sizes can be checked.
- Seven examples, all passing (true → found):
  - T-shirt M, half front at 17°, back, sleeve: front 53 × 74.8 → 53 × 74.7 (opened from half), back → 53 × 74.6, sleeve 23.3 × 23.5 → 23.1 × 23.4 ×2.
  - Polo L, tilted, two plackets: front/back 56 × 76.8 → 56 × 76.6, sleeve → 24 × 24.4 ×2, placket 5 × 16.6 ×2 (second marked "same").
  - Tank S, two halves, heavy shadow: both opened, 50 × 73.5 → 49.9 × 73.1, named front and back.
  - Leggings M, warm light: leg 55.4 × 107.3 → 55.3 × 107.3 ×2, waistband 66 × 14 → 66 × 14.1.
  - Joggers XL, noisy and blurred: leg 73.5 × 118.2 → 73.1 × 118 ×2, waistband 82 × 10 → 81.9 × 10, cuff ×2.
  - White card on a light table (low contrast): body 53 × 74.8 → 52.8 × 74.4, sleeve → 22.9 × 23.3 ×2, on Auto and on "Piece is lighter".
  - Flat-bed scan of one sleeve: 23.3 × 23.5 → 23.4 × 23.7 ×2.
- Fixes made while testing:
  - Thresholding tries Otsu, then re-splits the bright and dark sides (`otsu(g, lo, hi)`), keeping the reading with the most piece area. This fixed white card on a light table.
  - Half-pattern opening needs a tall piece with fill < 0.95 and solidity < 0.975, a long straight side of 70% or more, and is never used for bottoms (jogger legs were opened by mistake).
  - Bottoms are turned by a lower-leg mirror search over 360° plus a straight-hem check.
  - Pieces are named by matching their size to the pattern's own pieces (`expectedPieces`), not by fixed thresholds.

## sparrow engine: built in (2026-11-21)
- `marker-planner.html` now tightens markers with sparrow, compiled to WebAssembly and embedded in the page as about 470 KB of gzip + base64. The page is about 660 KB in total.
- Our engine still plans the lays (size mixes and layers). sparrow places the pieces: about 10 s per marker in Quick and 30 s in Thorough. It runs several Web Workers in parallel (up to 6, using cores − 1), each with a different seed, and the best layout wins. Spare runs go to the markers that use the most fabric.
- "Keep improving" also uses sparrow, warm-starting from each marker's best layout. If WebAssembly is unavailable or sparrow fails on a marker, the planner falls back to the built-in engine. Advanced settings has a Nesting engine choice: sparrow or Built-in.
- Results on the example order (4,500 pcs, 66 in):
  - Built-in engine: 750 kg, 83.1% yield, 30 s.
  - sparrow: 713 kg, 87.3% yield, 14 s.
  - sparrow plus 1 minute of Keep improving: 704 kg, 88.4% yield.
- Audit passed: 0 overlaps, gaps about 2 mm, everything inside the selvedge margin, before and after improving. Cancel works. DXF custom pieces work.
- Build:
  - The bridge is in `tools/sparrow-wasm` (target wasm32-wasip1, plain C ABI, no wasm-bindgen). The page supplies the WASI functions it needs (clock, random, fd_write).
  - Run `cargo build --release --target wasm32-wasip1` with `CARGO_TARGET_DIR=%USERPROFILE%\sparrow-build\target`, then `tools/sparrow-wasm/embed.ps1`.
  - `tools/serve.ps1` (launch.json "planner") serves the folder on localhost:8765 for testing. The browser pane would not open the 660 KB file directly.
- Running the downloaded wasm-bindgen.exe was blocked by the safety classifier and has been removed. The WASI route avoids it.
- Licences: sparrow is MIT and jagua-rs is MPL-2.0. A notice with the source links is in the page footer.
- Not yet verified:
  - Inside claude.ai: its viewer may block WebAssembly, in which case the planner falls back to the built-in engine. Advanced settings then says "sparrow cannot run in this browser".
  - Opening the file straight from disk in real Chrome or Edge.

## sparrow benchmark and build-in (history)
- Benchmark in `tests/benchmark-sparrow-2026-11-21.md`: sparrow saves 2.6–3.7% marker length against our engine. The user chose "Build it in".
- Fixed and republished: the seam-allowance offset made self-crossing loops at the neck and shoulder. Fixed with `untangle()` in the engine.
- Done so far:
  - Rust 1.100 installed for this user only: host x86_64-pc-windows-gnu, wasm32-unknown-unknown target, `--no-modify-path`. Use `$env:Path = "$env:USERPROFILE\.cargo\bin;$env:Path"`.
  - The installer checksum was verified against static.rust-lang.org.
  - sparrow source (main, 0.3.0, MIT) unpacked to `C:\Users\ayman\sparrow-build\src\sparrow-main`. Build output goes to `CARGO_TARGET_DIR=C:\Users\ayman\sparrow-build\target`.
  - Bridge crate started in `tools/sparrow-wasm`: Cargo.toml is written, `src/lib.rs` is still a placeholder, and `cargo fetch` has run. It pulled jagua-rs 2.0.0, wasm-bindgen 0.2.130, rayon-core 1.13, web-time 1.1.
- What the source showed:
  - `sparrow::optimizer::optimize(instance, rng, &mut listener, &mut terminator, &expl_cfg, &cmpr_cfg, None)`. The CLI is in `cli/src/cli.rs`.
  - Import uses `Importer::new(cfg.cde_config, cfg.poly_simpl_tolerance, cfg.narrow_concavity_cutoff_ratio)` and `jagua_rs::probs::spp::io::import_instance`. Export uses `jagua_rs::probs::spp::io::export(&sol, *EPOCH)`.
  - `SolutionListener::report(ReportType, &SPSolution)` reports improvements: ExplFeas, CmprFeas, Final. `BasicTerminator` handles the time limit.
  - `DEFAULT_SPARROW_CONFIG` splits time 80% explore and 20% compress. Set `n_workers = 1` for the browser.
  - `separator.rs` already uses the global rayon pool on wasm32. sparrow's `.cargo/config.toml` (threads and nightly) does not apply to the bridge crate, so build single-threaded on stable.
- Next steps:
  1. Read jagua-rs 2.0 for `ExtSPSolution` fields, the strip-width getter and `Instant` on wasm, in `%USERPROFILE%\.cargo\registry\src\*\jagua-rs-2.0.0`.
  2. Write `#[wasm_bindgen] solve(instance_json, time_ms, seed, progress_cb) -> solution JSON`.
  3. Run `cargo build --release --target wasm32-unknown-unknown`.
  4. Run `cargo install wasm-bindgen-cli --version 0.2.130`, then `wasm-bindgen --target no-modules`.
  5. Embed the wasm (base64) and the glue in `marker-planner.html`. Run 3–4 web workers with different seeds and keep the best result. Map item id, rotation and translation back to placements.
  6. Keep the current engine as the fallback.
  7. Test against the benchmark numbers, run an overlap audit, then republish.

## Open items
- Real factory numbers: fabric widths, layers, direction rules, gaps, buyer files, costing consumption, and weight lost in dyeing.
- Test the .plt/.dxf output on a real plotter, and test saving files inside claude.ai.
- Engine ideas: Quick mode is still a little weaker than the old engine at 66 in; true no-fit-polygon geometry; tubular fabric.
- Possible next steps: an Excel recording sheet for Phase 1, and an Apple-style design skill (emilkowalski/skills@apple-design, 318K installs, passed security audits), which has not been installed yet.
