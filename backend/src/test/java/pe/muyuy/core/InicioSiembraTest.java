package pe.muyuy.core;

import org.junit.jupiter.api.Test;
import pe.muyuy.core.engine.InicioSiembra;
import pe.muyuy.core.model.Calendario;
import pe.muyuy.core.model.MesClima;

import java.util.List;
import java.util.stream.IntStream;

import static org.junit.jupiter.api.Assertions.assertEquals;

/** SPECS_v2 §4.6: inicio de siembra calculado para coordenadas. */
class InicioSiembraTest {

    /** lluvia por mes (1..12), ET fija 100, helada opcional. */
    private static Calendario cal(double[] lluvia, double[] helada) {
        List<MesClima> meses = IntStream.rangeClosed(1, 12).mapToObj(m -> new MesClima(m,
                helada == null ? 0 : helada[m - 1], lluvia[m - 1], 100, lluvia[m - 1] - 100, 0, 10, 20)).toList();
        return new Calendario(null, "test", 40, meses);
    }

    @Test
    void empiezaConLaRachaHumedaMasLarga() {
        // húmedo (≥ 50 mm): oct–mar (racha circular de 6) y may (racha de 1)
        double[] lluvia = {80, 80, 80, 10, 60, 10, 10, 10, 10, 90, 90, 90};
        assertEquals(10, InicioSiembra.calcular(cal(lluvia, null)));
    }

    @Test
    void sinEstacionSecaEsElPrimerMesSinHelada() {
        double[] lluvia = new double[12];
        java.util.Arrays.fill(lluvia, 120);
        double[] helada = {0.6, 0.5, 0.3, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1};
        assertEquals(4, InicioSiembra.calcular(cal(lluvia, helada)));
    }

    @Test
    void todoElAnoAptoEsEnero() {
        double[] lluvia = new double[12];
        java.util.Arrays.fill(lluvia, 120);
        assertEquals(1, InicioSiembra.calcular(cal(lluvia, null)));
    }

    @Test
    void climaTempladoSiembraTrasElInvierno() {
        // Iowa: helada oct–abr (7 meses); la lluvia empezaría en junio pero manda la temperatura → mayo
        double[] lluvia = {20, 20, 40, 40, 40, 120, 120, 120, 120, 40, 20, 20};
        double[] helada = {1, 1, 0.9, 0.6, 0.2, 0, 0, 0, 0.1, 0.5, 0.9, 1};
        assertEquals(5, InicioSiembra.calcular(cal(lluvia, helada)));
    }

    @Test
    void inviernoQueCruzaElAnoSiembraEnMarzo() {
        double[] helada = {0.7, 0.6, 0.1, 0, 0, 0, 0, 0, 0, 0, 0.2, 0.8};
        assertEquals(3, InicioSiembra.calcular(cal(new double[12], helada)));
    }

    @Test
    void heladaCortaNoEsInviernoYMandaLaLluvia() {
        // Sierra andina: 2 meses con helada fuerte (jul–ago) → sigue la regla de lluvias (octubre)
        double[] lluvia = {80, 80, 80, 10, 10, 10, 10, 10, 10, 90, 90, 90};
        double[] helada = {0, 0, 0, 0, 0.1, 0.45, 0.82, 0.53, 0.05, 0, 0, 0};
        assertEquals(10, InicioSiembra.calcular(cal(lluvia, helada)));
    }

    @Test
    void desiertoSinMesesHumedosEsEnero() {
        assertEquals(1, InicioSiembra.calcular(cal(new double[12], null)));
    }
}
