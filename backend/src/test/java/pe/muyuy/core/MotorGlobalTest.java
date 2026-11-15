package pe.muyuy.core;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;
import pe.muyuy.core.data.RepositorioCalendarios;
import pe.muyuy.core.data.RepositorioCultivos;
import pe.muyuy.core.data.RepositorioZonas;
import pe.muyuy.core.engine.MotorReal;
import pe.muyuy.core.engine.MotorRotaciones;
import pe.muyuy.core.model.Calendario;
import pe.muyuy.core.model.Cultivo;
import pe.muyuy.core.model.MesClima;
import pe.muyuy.core.model.Rotacion;
import pe.muyuy.core.model.Zona;

import java.io.InputStream;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Catálogo global (fuera de Huánuco) con clima REAL de NASA POWER 1985-2024 guardado en
 * src/test/resources/calendarios/ (generado con pipeline/calendario.py, sin red en la prueba).
 */
@QuarkusTest
class MotorGlobalTest {

    @Inject MotorRotaciones motor;
    @Inject RepositorioCultivos cultivos;
    @Inject RepositorioZonas zonas;
    @Inject RepositorioCalendarios calendarios;
    @Inject ObjectMapper mapper;

    private record Punto(Zona zona, Calendario cal) {}

    private Punto punto(String archivo, int elevacionM) throws Exception {
        try (InputStream in = getClass().getResourceAsStream("/calendarios/" + archivo + ".json")) {
            JsonNode d = mapper.readTree(in);
            Zona z = new Zona("celda_" + archivo, archivo, MotorReal.REGION_COORDENADA,
                    d.path("lat").asDouble(), d.path("lon").asDouble(), elevacionM, false, List.of(), null);
            List<MesClima> meses = mapper.convertValue(d.path("calendario"), new TypeReference<>() {});
            return new Punto(z, new Calendario(z, d.path("fuente").asText(), d.path("anios").asInt(), meses));
        }
    }

    private Set<String> globales() {
        return cultivos.todos().stream().filter(c -> c.zonas().contains("global") && !c.esDescanso())
                .map(Cultivo::id).collect(Collectors.toSet());
    }

    private Set<String> usados(List<Rotacion> rs) {
        return rs.stream().flatMap(r -> r.secuencia().stream()).collect(Collectors.toSet());
    }

    private List<Rotacion> recomendar(Punto p) {
        return motor.recomendar(p.zona(), p.cal(), cultivos.catalogoPara(p.zona().region()));
    }

    @Test
    void sahelSinPapaYConCerealesDeSecano() throws Exception {
        Punto niger = punto("niger-niamey", 210);
        List<String> iniciales = motor.inicialesPara(niger.zona(), niger.cal(), cultivos.todos());
        List<Rotacion> rs = recomendar(niger);
        System.out.println("Niger iniciales=" + iniciales + " usados=" + usados(rs));
        assertFalse(rs.isEmpty(), "el Sahel debe tener opciones");
        assertFalse(usados(rs).contains("papa"), "papa no aguanta el calor del Sahel");
        assertTrue(iniciales.stream().anyMatch(globales()::contains), "inicia con un cultivo global: " + iniciales);
    }

    @Test
    void keniaYPunjabUsanElCatalogoGlobal() throws Exception {
        for (var p : List.of(punto("kenia-nakuru", 1850), punto("india-punjab", 250))) {
            List<Rotacion> rs = recomendar(p);
            System.out.println(p.zona().nombre() + " iniciales="
                    + motor.inicialesPara(p.zona(), p.cal(), cultivos.todos()) + " usados=" + usados(rs));
            assertFalse(rs.isEmpty(), p.zona().nombre());
            assertTrue(usados(rs).stream().anyMatch(globales()::contains), p.zona().nombre() + " sin cultivos globales");
        }
    }

    @Test
    void huanucoSigueSoloConCultivosAndinos() {
        Set<String> globales = globales();
        for (Zona z : zonas.todas()) {
            if ("global".equals(z.region())) continue;
            var rs = motor.recomendar(z, calendarios.deZona(z.id()).orElseThrow(), cultivos.catalogoPara(z.region()));
            assertTrue(usados(rs).stream().noneMatch(globales::contains), z.id() + " no debe recibir cultivos de otros países");
        }
    }
}
