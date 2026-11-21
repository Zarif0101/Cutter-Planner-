# Benchmark: Marker Planner engine vs sparrow (sparrow studio), 2026-11-21

Same input for both: the example T-shirt (Marker Planner default measurements), 10 mm seam allowance,
15 mm hem, 2 mm gap between pieces, 10 mm selvedge margin each side, 0°/180° turns only (grain kept).
Each piece was widened by 1 mm (half the gap) and both solvers placed these widened shapes in the usable
width, so the geometry is identical. Utilisation = widened piece area / (usable width × used length).

Machine: this office PC (16 logical cores), Chrome-based browser pane.
Our engine: one thread (Web Worker not used in the test, same code). sparrow studio: https://sparrowstudio.app/
(runs locally, MIT-licensed solver), "Standard", workers automatic (3) unless noted.

| Marker | Usable width | Ours Quick | Ours Thorough | Ours Thorough + 60 s | sparrow 10 s | sparrow 1 worker | sparrow ≤ 60 s |
|---|---|---|---|---|---|---|---|
| 6 garments S1 M2 L2 XL1, 66 in | 1656.4 mm | 3.671 m · 84.2% · 4 s | 3.522 m · 87.8% · 14 s | 3.517 m · 87.9% · 74 s | 3.476 m · 89.0% | 3.445 m · 89.8% · 50 s | **3.423 m · 90.3%** · 60 s |
| same, 60 in | 1504 mm | 4.437 m · 76.8% · 5 s | 4.517 m · 75.4% · 15 s | 4.434 m · 76.8% · 75 s | – | – | **4.271 m · 79.7%** · 39 s |
| 11 garments S2 M4 L3 XL2, 66 in | 1656.4 mm | 6.773 m · 83.4% · 9 s | 6.556 m · 86.2% · 25 s | 6.503 m · 86.9% · 85 s | – | – | **6.333 m · 89.2%** · 43 s |

sparrow's best is 2.7%, 3.7% and 2.6% shorter than our best after a minute, and its 10-second result already beats ours.

Found on the way: our seam-allowance offset made small self-crossing loops where the neckline meets the
shoulder (back pieces). sparrow refused them ("Contour self-intersects"). Fixed in the engine with
`untangle()` after every offset; our Thorough result on the 66 in marker improved from 3.550 m to 3.522 m.

Workflow caveats seen in sparrow studio (manual use): importing a second instance kept the old width and
quantities; every imported part defaulted to "Free rotation" and had to be set to "Half-turns" by hand.
