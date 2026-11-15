package pe.muyuy.core;

import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;
import pe.muyuy.core.data.RepositorioCalendarios;
import pe.muyuy.core.data.RepositorioCultivos;
import pe.muyuy.core.data.RepositorioZonas;
import pe.muyuy.core.engine.MotorRotaciones;
import pe.muyuy.core.model.Calendario;
import pe.muyuy.core.model.Cultivo;
import pe.muyuy.core.model.MesClima;
import pe.muyuy.core.model.Rotacion;
import pe.muyuy.core.model.Zona;

import java.util.List;
import java.util.stream.IntStream;

import static org.junit.jupiter.api.Assertions.*;

/** Reglas del motor que pueden fallar en silencio (constitución II). */
@QuarkusTest
class MotorReglasTest {

    @Inject MotorRotaciones motor;
    @Inject RepositorioZonas zonas;
    @Inject RepositorioCultivos cultivos;
    @Inject RepositorioCalendarios calendarios;

    private static final Zona SECANO = new Zona("t", "Test", "sierra", 0, 0, 0, false, List.of("papa"), null);
    private static final Zona RIEGO = new Zona("t", "Test", "sierra", 0, 0, 0, true, List.of("papa"), null);

    /** Calendario sintético: los 12 meses iguales. */
    private static Calendario cal(double tMin, double tMax, double lluvia) {
        var meses = IntStream.rangeClosed(1, 12)
                .mapToObj(m -> new MesClima(m, 0, lluvia, 80, lluvia - 80, 0, tMin, tMax)).toList();
        return new Calendario(null, "test", 40, meses);
    }

    private Cultivo c(String id) { return cultivos.requerido(id); }

    // ---------- H2: esApto

    @Test
    void heladaLetalNoEsApto() {
        // maíz amiláceo: ktmp 0. Media 20 °C (óptima) pero t_min -2 → letal
        assertFalse(motor.esApto(SECANO, c("maiz_amilaceo"), cal(-2, 42, 200)));
        assertTrue(motor.esApto(SECANO, c("maiz_amilaceo"), cal(5, 35, 200)), "control: sin helada sí es apto");
    }

    @Test
    void lluviaInsuficienteNoEsAptoSalvoRiego() {
        assertFalse(motor.esApto(SECANO, c("maiz_amilaceo"), cal(5, 35, 5)));
        assertTrue(motor.esApto(RIEGO, c("maiz_amilaceo"), cal(5, 35, 5)));
    }

    @Test
    void temperaturaFueraDeRangoNoEsApto() {
        assertFalse(motor.esApto(SECANO, c("papa"), cal(30, 40, 200)));   // media 35 > 20+3
        assertFalse(motor.esApto(SECANO, c("yuca"), cal(2, 10, 200)));    // media 6 < 22-3
    }

    @Test
    void aptitudEnSierraRealCoincideConLoQueSeSiembra() {
        // Calendario NASA POWER 1985-2024 real. Verdad: cultivos.json "zonas" (MIDAGRI).
        Zona sierra = zonas.porId("huanuco-sierra").orElseThrow();
        Calendario cal = calendarios.deZona(sierra.id()).orElseThrow();
        assertTrue(motor.esApto(sierra, c("papa"), cal));
        assertTrue(motor.esApto(sierra, c("maiz_amilaceo"), cal));   // se siembra hasta ~3300 m
        assertFalse(motor.esApto(sierra, c("maiz_duro"), cal));      // cultivo de selva
    }

    // ---------- H1: reglas de las candidatas (todas las zonas)

    @Test
    void candidatasRespetanReglasYPuntajesValidos() {
        for (Zona z : zonas.todas()) {
            var cal = calendarios.deZona(z.id()).orElseThrow();
            for (Rotacion r : motor.recomendar(z, cal, cultivos.todos())) {
                var p = r.puntajes();
                for (double v : new double[]{p.agua(), p.suelo(), p.ingresos(), p.riesgo(), p.total()}) {
                    assertTrue(v >= 0 && v <= 1, r.id() + " puntaje fuera de 0..1");
                }
                assertEquals(3, r.secuencia().size(), r.id());
                if (r.esPracticaComun()) continue;
                for (int i = 1; i < 3; i++) {
                    var a = c(r.secuencia().get(i - 1));
                    var b = c(r.secuencia().get(i));
                    assertNotEquals(a.familia(), b.familia(), z.id() + " familia repetida: " + r.id());
                    assertFalse(a.id().equals("papa") && b.id().equals("papa"), "papa -> papa: " + r.id());
                }
            }
        }
    }
}
