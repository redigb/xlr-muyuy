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
        // Solo los nuevos (no se siembran en Huánuco); papa, haba, trigo… también llevan "global"
        return cultivos.todos().stream().filter(c -> c.zonas().equals(List.of("global")))
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

    private List<String> iniciales(Punto p) { return motor.inicialesPara(p.zona(), p.cal(), cultivos.todos()); }

    @Test
    void iowaSiembraEnMayoYEmpiezaConMaizYSigueSoya() throws Exception {
        Punto iowa = punto("eeuu-iowa", 291);
        List<Rotacion> rs = recomendar(iowa);
        System.out.println("Iowa siembra=" + motor.mesSiembra(iowa.zona(), iowa.cal()) + " iniciales=" + iniciales(iowa)
                + " ej=" + rs.stream().limit(4).map(r -> String.join(">", r.secuencia())).toList());
        assertEquals(5, motor.mesSiembra(iowa.zona(), iowa.cal()), "tras las heladas, no con la lluvia");
        assertTrue(iniciales(iowa).get(0).equals("maiz"), "el maíz es el cultivo principal: " + iniciales(iowa));
        System.out.println("Iowa segundos tras maiz=" + rs.stream().filter(r -> r.secuencia().get(0).equals("maiz"))
                .map(r -> r.secuencia().get(1)).toList());
        assertTrue(rs.stream().anyMatch(r -> r.secuencia().get(0).equals("maiz")
                        && cultivos.requerido(r.secuencia().get(1)).fijaNitrogeno()),
                "maíz → leguminosa (repone el nitrógeno que se lleva el maíz)");
    }

    @Test
    void leguminosasNoAbrenSiHayCultivosPrincipales() throws Exception {
        for (var p : List.of(punto("eeuu-iowa", 291), punto("kenia-nakuru", 1850), punto("niger-niamey", 210))) {
            String primero = iniciales(p).get(0);
            assertFalse(cultivos.requerido(primero).fijaNitrogeno(), p.zona().nombre() + " abre con " + primero);
        }
    }

    @Test
    void conRiegoLaLluviaNoDescartaCultivos() throws Exception {
        Punto seco = punto("eeuu-california", 58);
        Zona z = seco.zona();
        Zona conRiego = new Zona(z.id(), z.nombre(), z.region(), z.lat(), z.lon(), z.elevacionM(), true, List.of(), null);
        long secano = cultivos.todos().stream().filter(c -> motor.esApto(z, c, seco.cal())).count();
        long regado = cultivos.todos().stream().filter(c -> motor.esApto(conRiego, c, seco.cal())).count();
        System.out.println("California aptos secano=" + secano + " riego=" + regado + " iniciales riego="
                + motor.inicialesPara(conRiego, seco.cal(), cultivos.todos()));
        assertTrue(regado > secano, "con riego entran más cultivos (" + secano + " → " + regado + ")");
    }

    @Test
    void estadosUnidosConClimaReal() throws Exception {
        for (var p : List.of(punto("eeuu-iowa", 291), punto("eeuu-kansas", 544), punto("eeuu-california", 58))) {
            List<Rotacion> rs = recomendar(p);
            System.out.println(p.zona().nombre() + " siembra=" + motor.mesSiembra(p.zona(), p.cal())
                    + " iniciales=" + iniciales(p)
                    + " ej=" + rs.stream().limit(3).map(r -> String.join(">", r.secuencia())).toList());
            assertFalse(rs.isEmpty(), p.zona().nombre());
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
