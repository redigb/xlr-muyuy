"""Calendario agroclimático desde NASA POWER (spec v2.1, secciones 2 y 11.3).

Mismo cálculo para zonas oficiales (regenera data/calendario_<zona>.json) y para
cualquier coordenada (lo usa servicio.py → /calendario).

  python pipeline/calendario.py            # regenera las zonas de data/zonas.json
  python pipeline/calendario.py sierra     # solo las zonas cuyo id contiene "sierra"

Cálculo:
- NASA POWER diario, comunidad AG, 1985–2024: T2M_MAX, T2M_MIN, PRECTOTCORR.
- Corrección por altitud: la celda de POWER (~50 km) tiene su propia elevación;
  se ajusta la temperatura con el gradiente estándar −6.5 °C por km.
- ET0 por Hargreaves (FAO-56, ec. 52) con radiación extraterrestre Ra (ec. 21).
- Por mes: promedio de los 40 años. prob_helada = fracción de años con al menos
  un día de helada agronómica (T mín del aire ≤ 2 °C) en ese mes.

Limitaciones conocidas (declararlas en la evaluación):
- Celda de ~0.5°: sierra y valle de Huánuco comparten celda; solo cambia la altitud.
- POWER subestima la lluvia de la selva (Tingo María ≈ 1100 mm vs ~3000 mm medidos).
"""
from __future__ import annotations

import json
import math
import pathlib
import sys
import urllib.request
from collections import defaultdict
from dataclasses import dataclass

POWER_URL = (
    "https://power.larc.nasa.gov/api/temporal/daily/point"
    "?parameters=T2M_MAX,T2M_MIN,PRECTOTCORR&community=AG"
    "&longitude={lon}&latitude={lat}&start={inicio}0101&end={fin}1231&format=JSON"
)
ANIO_INICIO = 1985
ANIO_FIN = 2024
GRADIENTE_C_POR_M = 0.0065       # −6.5 °C por km (atmósfera estándar)
UMBRAL_CALOR_C = 32.0            # día con estrés por calor
# Helada agronómica: T mín del AIRE (2 m) ≤ 2 °C. La superficie suele estar 2–3 °C
# más fría y la celda de ~50 km suaviza las noches frías. Mismo umbral que usa el
# backend para marcar como sospechosa una helada reportada (ServicioComunidad).
UMBRAL_HELADA_C = 2.0
FALTANTE = -999.0                # valor de POWER para datos faltantes

RAIZ = pathlib.Path(__file__).resolve().parent.parent
DATA = RAIZ / "data"
CACHE = pathlib.Path(__file__).resolve().parent / "raw"


@dataclass(frozen=True)
class Dia:
    anio: int
    mes: int
    doy: int
    t_max: float
    t_min: float
    lluvia: float


# ----------------------------------------------------------------- descarga

def descargar(lat: float, lon: float, *, timeout: float = 60) -> dict:
    """JSON crudo de POWER. Cachea en pipeline/raw/ (no va a GitHub)."""
    CACHE.mkdir(exist_ok=True)
    archivo = CACHE / f"power_{lat:.2f}_{lon:.2f}_{ANIO_INICIO}_{ANIO_FIN}.json"
    if archivo.exists():
        return json.loads(archivo.read_text(encoding="utf-8"))
    url = POWER_URL.format(lat=lat, lon=lon, inicio=ANIO_INICIO, fin=ANIO_FIN)
    req = urllib.request.Request(url, headers={"User-Agent": "muyuy-pipeline/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        crudo = json.loads(resp.read().decode("utf-8"))
    if "properties" not in crudo:
        raise RuntimeError(f"POWER no devolvió datos: {str(crudo)[:200]}")
    archivo.write_text(json.dumps(crudo), encoding="utf-8")
    return crudo


def dias_de_power(crudo: dict) -> list[Dia]:
    p = crudo["properties"]["parameter"]
    dias = []
    for fecha, t_max in p["T2M_MAX"].items():
        t_min = p["T2M_MIN"].get(fecha, FALTANTE)
        lluvia = p["PRECTOTCORR"].get(fecha, FALTANTE)
        if FALTANTE in (t_max, t_min, lluvia):
            continue
        anio, mes, dia = int(fecha[:4]), int(fecha[4:6]), int(fecha[6:8])
        doy = (_fecha_ordinal(anio, mes, dia) - _fecha_ordinal(anio, 1, 1)) + 1
        dias.append(Dia(anio, mes, doy, float(t_max), float(t_min), max(0.0, float(lluvia))))
    return dias


def elevacion_power(crudo: dict) -> float | None:
    coords = crudo.get("geometry", {}).get("coordinates", [])
    return float(coords[2]) if len(coords) > 2 and coords[2] is not None else None


# ------------------------------------------------------------------ cálculo

def radiacion_extraterrestre(lat: float, doy: int) -> float:
    """Ra en mm/día equivalentes de evaporación (FAO-56 ec. 21 × 0.408)."""
    phi = math.radians(lat)
    dr = 1 + 0.033 * math.cos(2 * math.pi / 365 * doy)
    delta = 0.409 * math.sin(2 * math.pi / 365 * doy - 1.39)
    ws = math.acos(max(-1.0, min(1.0, -math.tan(phi) * math.tan(delta))))
    ra_mj = (24 * 60 / math.pi) * 0.0820 * dr * (
        ws * math.sin(phi) * math.sin(delta) + math.cos(phi) * math.cos(delta) * math.sin(ws)
    )
    return 0.408 * ra_mj


def et0_hargreaves(t_max: float, t_min: float, ra_mm: float) -> float:
    t_media = (t_max + t_min) / 2
    return max(0.0, 0.0023 * ra_mm * (t_media + 17.8) * math.sqrt(max(0.0, t_max - t_min)))


def calendario(dias: list[Dia], lat: float, correccion_c: float = 0.0) -> list[dict]:
    """12 meses agregados. `correccion_c` se suma a T máx y T mín (altitud)."""
    # (anio, mes) -> acumulados
    lluvia = defaultdict(float)
    et = defaultdict(float)
    heladas = defaultdict(int)
    calor = defaultdict(int)
    n_dias = defaultdict(int)
    tmin_sum = defaultdict(float)
    tmax_sum = defaultdict(float)

    for d in dias:
        t_max = d.t_max + correccion_c
        t_min = d.t_min + correccion_c
        k = (d.anio, d.mes)
        lluvia[k] += d.lluvia
        et[k] += et0_hargreaves(t_max, t_min, radiacion_extraterrestre(lat, d.doy))
        heladas[k] += 1 if t_min <= UMBRAL_HELADA_C else 0
        calor[k] += 1 if t_max > UMBRAL_CALOR_C else 0
        n_dias[k] += 1
        tmin_sum[k] += t_min
        tmax_sum[k] += t_max

    meses = []
    for mes in range(1, 13):
        claves = [k for k in n_dias if k[1] == mes and n_dias[k] >= 20]  # meses casi completos
        if not claves:
            raise ValueError(f"Sin datos suficientes para el mes {mes}")
        n = len(claves)
        lluvia_mm = sum(lluvia[k] for k in claves) / n
        et_mm = sum(et[k] for k in claves) / n
        meses.append({
            "mes": mes,
            "prob_helada": round(sum(1 for k in claves if heladas[k] > 0) / n, 2),
            "dias_helada": round(sum(heladas[k] for k in claves) / n, 1),
            "lluvia_mm": round(lluvia_mm, 1),
            "et_mm": round(et_mm, 1),
            "balance_hidrico_mm": round(lluvia_mm - et_mm, 1),
            "estres_calor": round(sum(calor[k] for k in claves) / sum(n_dias[k] for k in claves), 2),
            "t_min": round(sum(tmin_sum[k] / n_dias[k] for k in claves) / n, 1),
            "t_max": round(sum(tmax_sum[k] / n_dias[k] for k in claves) / n, 1),
        })
    return meses


def calendario_para_punto(lat: float, lon: float, elev_m: float | None) -> dict:
    """Calendario de cualquier punto. `elev_m` = elevación real del lugar (None = sin corrección)."""
    crudo = descargar(lat, lon)
    dias = dias_de_power(crudo)
    elev_celda = elevacion_power(crudo)
    correccion = 0.0
    nota = "sin corrección por altitud"
    if elev_m is not None and elev_celda is not None:
        correccion = round((elev_celda - elev_m) * GRADIENTE_C_POR_M, 2)
        nota = (f"corregido por altitud: celda NASA {elev_celda:.0f} m → lugar {elev_m:.0f} m "
                f"({correccion:+.1f} °C)")
    anios = len({d.anio for d in dias})
    return {
        "fuente": f"NASA POWER (AG) diario {ANIO_INICIO}-{ANIO_FIN}, {nota}; ET0 Hargreaves (FAO-56)",
        "anios": anios,
        "elevacion_celda_m": elev_celda,
        "correccion_c": correccion,
        "calendario": calendario(dias, lat, correccion),
    }


# ------------------------------------------------------------------- zonas

def regenerar_zonas(filtro: str = "") -> None:
    zonas = json.loads((DATA / "zonas.json").read_text(encoding="utf-8"))
    for z in zonas:
        if filtro and filtro not in z["id"]:
            continue
        r = calendario_para_punto(z["lat"], z["lon"], z.get("elevacion_m"))
        doc = {
            "zona": {k: z[k] for k in ("id", "nombre", "lat", "lon", "elevacion_m")},
            "fuente": r["fuente"],
            "anios": r["anios"],
            "calendario": r["calendario"],
        }
        (DATA / f"calendario_{z['id']}.json").write_text(
            json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        heladas = [m["prob_helada"] for m in r["calendario"]]
        print(f"{z['id']}: {r['anios']} años, corrección {r['correccion_c']:+.1f} °C, helada {heladas}")


def _fecha_ordinal(anio: int, mes: int, dia: int) -> int:
    import datetime
    return datetime.date(anio, mes, dia).toordinal()


if __name__ == "__main__":
    regenerar_zonas(sys.argv[1] if len(sys.argv) > 1 else "")
