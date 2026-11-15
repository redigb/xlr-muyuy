package pe.muyuy.core;

import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;
import pe.muyuy.core.data.RepositorioCalendarios;
import pe.muyuy.core.data.RepositorioCultivos;
import pe.muyuy.core.data.RepositorioZonas;
import pe.muyuy.core.engine.MotorRotaciones;
import pe.muyuy.core.model.Rotacion;
import pe.muyuy.core.model.Zona;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Prueba del flujo de uso (constitución II): datos reales de data/ → zona → calendario → motor → explicador,
 * igual que lo hará el armado del paquete.
 */
@QuarkusTest
class MotorFlujoTest {

    @Inject RepositorioZonas zonas;
    @Inject RepositorioCalendarios calendarios;
    @Inject RepositorioCultivos cultivos;
    @Inject MotorRotaciones motor;
    @Inject Explicador explicador;

    private List<Rotacion> candidatas(Zona z) {
        return motor.recomendar(z, calendarios.deZona(z.id()).orElseThrow(), cultivos.catalogoPara(z.region()));
    }

    @Test
    void lasCuatroZonasGeneranCandidatasExplicables() {
        assertEquals(4, zonas.todas().size());
        for (Zona z : zonas.todas()) {
            var cal = calendarios.deZona(z.id()).orElseThrow();
            List<Rotacion> r = candidatas(z);
            assertTrue(r.stream().anyMatch(x -> !x.esPracticaComun()), z.id() + " sin candidatas nuevas");
            assertEquals(z.practicaComun() != null, r.stream().anyMatch(Rotacion::esPracticaComun), z.id());
            for (Rotacion x : r) {
                assertFalse(explicador.explicar(x, z, cal, "es").isBlank());
                assertFalse(x.validarConExperto().isBlank());
            }
        }
    }

    @Test
    void sierraDaEntre6y10DiversasPorCultivoInicial() {
        Zona sierra = zonas.porId("huanuco-sierra").orElseThrow();
        for (String inicial : sierra.cultivosIniciales()) {
            var nuevas = candidatas(sierra).stream()
                    .filter(r -> !r.esPracticaComun() && r.cultivoInicial().equals(inicial)).toList();
            assertTrue(nuevas.size() >= 6 && nuevas.size() <= 10, inicial + ": " + nuevas.size());
            Set<String> segundos = new HashSet<>();
            nuevas.forEach(r -> assertTrue(segundos.add(r.secuencia().get(1)), "2.a campania repetida " + r.id()));
        }
        var comun = candidatas(sierra).stream().filter(Rotacion::esPracticaComun).findFirst().orElseThrow();
        assertEquals(List.of("papa", "papa", "descanso"), comun.secuencia());
    }

    @Test
    void deterministaEnTodasLasZonas() {
        for (Zona z : zonas.todas()) assertEquals(candidatas(z), candidatas(z), z.id());
    }

    @Test
    void selvaYSierraSonDistintas() {
        var sierra = candidatas(zonas.porId("huanuco-sierra").orElseThrow()).stream().map(Rotacion::id).toList();
        var selva = candidatas(zonas.porId("huanuco-selva").orElseThrow()).stream().map(Rotacion::id).toList();
        assertTrue(sierra.stream().noneMatch(selva::contains));
    }
}
