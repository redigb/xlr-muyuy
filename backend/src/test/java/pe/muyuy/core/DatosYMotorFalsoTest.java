package pe.muyuy.core;

import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;
import pe.muyuy.core.data.RepositorioCalendarios;
import pe.muyuy.core.data.RepositorioCultivos;
import pe.muyuy.core.data.RepositorioReglas;
import pe.muyuy.core.data.RepositorioZonas;
import pe.muyuy.core.engine.MotorRotaciones;
import pe.muyuy.core.model.Rotacion;
import pe.muyuy.core.model.Zona;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

@QuarkusTest
class DatosYMotorFalsoTest {

    @Inject RepositorioZonas zonas;
    @Inject RepositorioCultivos cultivos;
    @Inject RepositorioCalendarios calendarios;
    @Inject RepositorioReglas reglas;
    @Inject MotorRotaciones motor;

    @Test
    void cargaTodosLosDatos() {
        assertEquals(4, zonas.todas().size());
        assertTrue(cultivos.todos().size() >= 15);
        assertFalse(reglas.reglas().reglas().isEmpty());
        for (Zona z : zonas.todas()) {
            var cal = calendarios.deZona(z.id()).orElseThrow(() -> new AssertionError("Sin calendario: " + z.id()));
            assertEquals(12, cal.calendario().size(), z.id());
            assertTrue(cultivos.porId(z.cultivoActual()).isPresent(), z.id());
        }
    }

    @Test
    void siempreTresRotacionesPrimeroLaActualYDeterminista() {
        for (Zona z : zonas.todas()) {
            var cal = calendarios.deZona(z.id()).orElseThrow();
            List<Rotacion> r = motor.recomendar(z, cal);
            assertEquals(3, r.size(), z.id());
            assertTrue(r.get(0).actual(), z.id());
            assertEquals(r, motor.recomendar(z, cal), "no determinista en " + z.id());
        }
    }

    @Test
    void ningunaRecomendacionNuevaRepiteFamiliaSeguida() {
        for (Zona z : zonas.todas()) {
            var r = motor.recomendar(z, calendarios.deZona(z.id()).orElseThrow());
            for (Rotacion rot : r.subList(1, r.size())) {
                var c = rot.campanias();
                for (int i = 1; i < c.size(); i++) {
                    assertNotEquals(c.get(i - 1).familia(), c.get(i).familia(), z.id() + " " + rot.id());
                }
            }
        }
    }
}
