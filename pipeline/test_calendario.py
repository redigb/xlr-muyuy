"""pytest pipeline/  — sin red: datos sintéticos con la forma de NASA POWER."""
import math

import pytest

import calendario as cal


def power_sintetico(t_max, t_min, lluvia, elev=3400.0, anios=(2000, 2001)):
    """Crudo con la forma de POWER: cada día del año con los valores dados (por mes)."""
    import datetime
    p = {"T2M_MAX": {}, "T2M_MIN": {}, "PRECTOTCORR": {}}
    for anio in anios:
        d = datetime.date(anio, 1, 1)
        while d.year == anio:
            k = d.strftime("%Y%m%d")
            p["T2M_MAX"][k] = t_max(d.month)
            p["T2M_MIN"][k] = t_min(d.month)
            p["PRECTOTCORR"][k] = lluvia(d.month)
            d += datetime.timedelta(days=1)
    return {"geometry": {"coordinates": [-76.0, -9.9, elev]}, "properties": {"parameter": p}}


def test_helada_solo_en_meses_frios():
    crudo = power_sintetico(lambda m: 16, lambda m: 1 if m in (6, 7) else 4, lambda m: 2)
    meses = cal.calendario(cal.dias_de_power(crudo), lat=-9.9)
    assert meses[5]["prob_helada"] == 1.0 and meses[6]["prob_helada"] == 1.0
    assert meses[0]["prob_helada"] == 0.0
    assert meses[5]["dias_helada"] == 30.0


def test_correccion_por_altitud_enfria_si_el_lugar_esta_mas_alto():
    crudo = power_sintetico(lambda m: 16, lambda m: 4, lambda m: 2, elev=3000)
    dias = cal.dias_de_power(crudo)
    assert cal.calendario(dias, -9.9)[0]["prob_helada"] == 0.0
    # lugar 400 m más alto que la celda → −2.6 °C → T mín 1.4 → helada agronómica
    meses = cal.calendario(dias, -9.9, correccion_c=(3000 - 3400) * cal.GRADIENTE_C_POR_M)
    assert meses[0]["t_min"] == pytest.approx(1.4, abs=0.05)
    assert meses[0]["prob_helada"] == 1.0


def test_lluvia_et_y_balance():
    crudo = power_sintetico(lambda m: 20, lambda m: 8, lambda m: 3)
    meses = cal.calendario(cal.dias_de_power(crudo), lat=-9.9)
    enero = meses[0]
    assert enero["lluvia_mm"] == pytest.approx(93.0, abs=0.1)        # 31 días × 3 mm
    assert 80 < enero["et_mm"] < 160                                  # Hargreaves en trópico
    assert enero["balance_hidrico_mm"] == pytest.approx(enero["lluvia_mm"] - enero["et_mm"], abs=0.2)


def test_faltantes_se_ignoran():
    crudo = power_sintetico(lambda m: 16, lambda m: 4, lambda m: 2)
    primer = next(iter(crudo["properties"]["parameter"]["T2M_MIN"]))
    crudo["properties"]["parameter"]["T2M_MIN"][primer] = cal.FALTANTE
    assert len(cal.dias_de_power(crudo)) == 366 + 365 - 1   # 2000 es bisiesto


def test_estres_calor():
    crudo = power_sintetico(lambda m: 35 if m == 1 else 25, lambda m: 15, lambda m: 2)
    meses = cal.calendario(cal.dias_de_power(crudo), lat=-9.9)
    assert meses[0]["estres_calor"] == 1.0 and meses[1]["estres_calor"] == 0.0


def test_radiacion_extraterrestre_fao56():
    # FAO-56 ejemplo 8: 20° S, 3 de septiembre (doy 246) → Ra = 32.2 MJ/m²/día
    assert cal.radiacion_extraterrestre(-20, 246) / 0.408 == pytest.approx(32.2, abs=0.2)


def test_forma_compatible_con_el_backend():
    crudo = power_sintetico(lambda m: 16, lambda m: 4, lambda m: 2)
    mes = cal.calendario(cal.dias_de_power(crudo), lat=-9.9)[0]
    for campo in ("mes", "prob_helada", "lluvia_mm", "et_mm", "balance_hidrico_mm",
                  "estres_calor", "t_min", "t_max"):
        assert campo in mes
    assert not math.isnan(mes["et_mm"])
