"""pipeline-api (SPECS_v2 §11.3): mismo cálculo que calendario.py para cualquier punto.

Interno: sin puerto público; solo lo llama el backend por la red de Docker.
  uvicorn servicio:app --host 0.0.0.0 --port 8000
"""
from __future__ import annotations

from fastapi import FastAPI, HTTPException, Query

import calendario as cal

app = FastAPI(title="Muyuy pipeline-api", version="1.0")


@app.get("/salud")
def salud() -> dict:
    return {"ok": True}


@app.get("/calendario")
def calendario(
    lat: float = Query(..., ge=-60, le=60),
    lon: float = Query(..., ge=-180, le=180),
    elev: float | None = Query(None, ge=-500, le=9000, description="Elevación real del lugar (m)"),
) -> dict:
    """Calendario de 12 meses (NASA POWER 1985-2024, corregido por altitud, ET0 Hargreaves)."""
    try:
        return cal.calendario_para_punto(lat, lon, elev)
    except Exception as e:  # NASA caída, datos incompletos, timeout…
        raise HTTPException(status_code=502, detail=f"NASA POWER no disponible: {e}") from e
