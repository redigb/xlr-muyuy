"""pytest pipeline/  — pipeline-api sin red (calendario_para_punto reemplazado)."""
from fastapi.testclient import TestClient

import calendario as cal
import servicio

cliente = TestClient(servicio.app)


def test_salud():
    assert cliente.get("/salud").json() == {"ok": True}


def test_calendario_pasa_lat_lon_y_elevacion(monkeypatch):
    llamado = {}

    def falso(lat, lon, elev):
        llamado.update(lat=lat, lon=lon, elev=elev)
        return {"fuente": "NASA POWER", "anios": 40, "calendario": [{"mes": m} for m in range(1, 13)]}

    monkeypatch.setattr(cal, "calendario_para_punto", falso)
    r = cliente.get("/calendario", params={"lat": -9.5, "lon": -76.0, "elev": 3200})
    assert r.status_code == 200 and len(r.json()["calendario"]) == 12
    assert llamado == {"lat": -9.5, "lon": -76.0, "elev": 3200}


def test_sin_elevacion_es_opcional(monkeypatch):
    monkeypatch.setattr(cal, "calendario_para_punto", lambda lat, lon, elev: {"elev": elev})
    assert cliente.get("/calendario", params={"lat": 0, "lon": 0}).json() == {"elev": None}


def test_fuera_de_rango_da_422():
    assert cliente.get("/calendario", params={"lat": 80, "lon": 0}).status_code == 422


def test_si_nasa_falla_da_502(monkeypatch):
    def falla(*_):
        raise TimeoutError("sin respuesta")

    monkeypatch.setattr(cal, "calendario_para_punto", falla)
    assert cliente.get("/calendario", params={"lat": 1, "lon": 1}).status_code == 502
