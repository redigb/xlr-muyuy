"""Genera calendarios INVENTADOS (misma forma que los de NASA POWER) para desarrollo."""
import json, math, sys, pathlib

out = pathlib.Path(sys.argv[1])
zonas = json.loads((out / "zonas.json").read_text(encoding="utf-8"))

# (t_media_anual, amplitud_t, rango_diario, lluvia_anual_mm, et_mes_mm, helada_max)
perfil = {
    "sierra": (11.0, 1.5, 13.0, 900, 85, 0.75),
    "valle":  (19.0, 1.5, 12.0, 450, 110, 0.02),
    "selva":  (25.0, 1.0, 10.0, 3300, 120, 0.0),
    "global": (11.0, 1.5, 13.0, 900, 85, 0.75),
}
# fraccion de lluvia anual por mes (andes: lluvias oct-abr, seco jun-ago)
lluvia_frac = [0.15, 0.15, 0.14, 0.08, 0.03, 0.01, 0.01, 0.02, 0.04, 0.08, 0.13, 0.16]

for z in zonas:
    tm, amp, rango, lluvia_anual, et, hmax = perfil[z["region"]]
    cal = []
    for m in range(1, 13):
        t = tm + amp * math.cos((m - 2) / 12 * 2 * math.pi)       # mas calido en feb
        seco = 1 - lluvia_frac[m - 1] / max(lluvia_frac)
        t_min = round(t - rango / 2 - 3 * seco, 1)
        t_max = round(t + rango / 2, 1)
        lluvia = round(lluvia_anual * lluvia_frac[m - 1])
        et_m = round(et * (1 + 0.15 * seco))
        helada = round(min(1.0, hmax * max(0.0, (2.0 - t_min) / 2.5) + (0.02 if hmax > 0.1 else 0)), 2)
        cal.append({
            "mes": m, "prob_helada": helada, "lluvia_mm": lluvia, "et_mm": et_m,
            "balance_hidrico_mm": lluvia - et_m,
            "estres_calor": round(max(0.0, (t_max - 32) / 5), 2),
            "t_min": t_min, "t_max": t_max,
        })
    doc = {
        "zona": {k: z[k] for k in ("id", "nombre", "lat", "lon", "elevacion_m")},
        "fuente": "INVENTADO para desarrollo - reemplazar por NASA POWER 1985-2024",
        "anios": 0,
        "calendario": cal,
    }
    (out / f"calendario_{z['id']}.json").write_text(
        json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(z["id"], [c["prob_helada"] for c in cal])
