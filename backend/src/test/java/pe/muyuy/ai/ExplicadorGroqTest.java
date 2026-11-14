package pe.muyuy.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;
import pe.muyuy.ai.ClienteGroq.Mensaje;
import pe.muyuy.ai.ClienteGroq.Peticion;
import pe.muyuy.ai.ClienteGroq.Respuesta;
import pe.muyuy.core.data.RepositorioCalendarios;
import pe.muyuy.core.data.RepositorioCultivos;
import pe.muyuy.core.data.RepositorioZonas;
import pe.muyuy.core.engine.MotorRotaciones;
import pe.muyuy.core.model.Calendario;
import pe.muyuy.core.model.Rotacion;
import pe.muyuy.core.model.Zona;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

/** Explicador con un Groq falso (sin red): lote, respaldo y contenido del prompt. */
@QuarkusTest
class ExplicadorGroqTest {

    @Inject RepositorioZonas zonas;
    @Inject RepositorioCalendarios calendarios;
    @Inject RepositorioCultivos cultivos;
    @Inject MotorRotaciones motor;
    @Inject ObjectMapper mapper;

    private final List<Peticion> llamadas = new ArrayList<>();

    private ExplicadorGroq con(ClienteGroq cliente, boolean habilitado, String clave) {
        return new ExplicadorGroq(cliente, cultivos, mapper, habilitado, Optional.ofNullable(clave), "modelo-test", Optional.of("low"));
    }

    private Zona sierra() { return zonas.porId("huanuco-sierra").orElseThrow(); }
    private Calendario cal() { return calendarios.deZona("huanuco-sierra").orElseThrow(); }
    private List<Rotacion> rotaciones() { return motor.recomendar(sierra(), cal(), cultivos.todos()); }

    /** Lo que viaja a Groq: snake_case y reasoning_effort solo si está configurado. */
    @Test
    void peticionViajaConReasoningEffortEnSnakeCase() throws Exception {
        var conEsfuerzo = mapper.writeValueAsString(new Peticion("m", List.of(), 0.2, 100, java.util.Map.of("type", "json_object"), "low"));
        assertTrue(conEsfuerzo.contains("\"reasoning_effort\":\"low\""), conEsfuerzo);
        assertTrue(conEsfuerzo.contains("\"max_tokens\":100") && conEsfuerzo.contains("\"response_format\""), conEsfuerzo);
        var sin = mapper.writeValueAsString(new Peticion("m", List.of(), 0.2, 100, null, null));
        assertFalse(sin.contains("reasoning_effort"), sin);
    }

    @Test
    void unaSolaLlamadaExplicaTodasLasRotaciones() {
        List<Rotacion> rots = rotaciones();
        ClienteGroq falso = (auth, p) -> {
            llamadas.add(p);
            assertEquals("Bearer clave-x", auth);
            StringBuilder json = new StringBuilder("{\"explicaciones\":{");
            for (int i = 0; i < rots.size(); i++) {
                json.append(i > 0 ? "," : "").append('"').append(rots.get(i).id()).append("\":\"Texto ").append(i).append('"');
            }
            return new Respuesta(List.of(new Respuesta.Opcion(new Mensaje("assistant", json.append("}}").toString()))));
        };
        var out = con(falso, true, "clave-x").explicarTodas(rots, sierra(), cal(), "es");

        assertEquals(1, llamadas.size(), "debe ser una sola llamada por zona");
        assertEquals(rots.size(), out.size());
        assertEquals("Texto 0", out.get(rots.get(0).id()));

        Peticion p = llamadas.get(0);
        assertEquals("modelo-test", p.model());
        assertEquals("json_object", p.responseFormat().get("type"));
        String datos = p.messages().get(1).content();
        assertTrue(datos.contains("Sierra de Huanuco"));
        assertTrue(datos.contains("Tarwi") && datos.contains("fija nitrógeno"), "el prompt usa nombres y datos del motor");
        rots.forEach(r -> assertTrue(datos.contains("id: " + r.id())));
        assertTrue(p.messages().get(0).content().contains("no inventes"));
    }

    @Test
    void siGroqFallaDevuelveVacioYNoRevienta() {
        ClienteGroq roto = (auth, p) -> { throw new RuntimeException("429 Too Many Requests"); };
        assertTrue(con(roto, true, "clave-x").explicarTodas(rotaciones(), sierra(), cal(), "es").isEmpty());

        ClienteGroq basura = (auth, p) -> new Respuesta(List.of(new Respuesta.Opcion(new Mensaje("assistant", "no soy json"))));
        assertTrue(con(basura, true, "clave-x").explicarTodas(rotaciones(), sierra(), cal(), "es").isEmpty());

        Rotacion r = rotaciones().get(0);
        assertFalse(con(roto, true, "clave-x").explicar(r, sierra(), cal(), "es").isBlank(), "explicar() cae a la plantilla");
    }

    @Test
    void sinClaveODeshabilitadoNoLlamaAGroq() {
        ClienteGroq espia = (auth, p) -> { llamadas.add(p); return new Respuesta(List.of()); };
        assertTrue(con(espia, true, "").explicarTodas(rotaciones(), sierra(), cal(), "es").isEmpty());
        assertTrue(con(espia, true, null).explicarTodas(rotaciones(), sierra(), cal(), "es").isEmpty());
        assertTrue(con(espia, false, "clave-x").explicarTodas(rotaciones(), sierra(), cal(), "es").isEmpty());
        assertTrue(llamadas.isEmpty());
    }

    @Test
    void promptEnIngles() {
        assertTrue(ExplicadorGroq.sistema("en").contains("simple English"));
        assertTrue(ExplicadorGroq.sistema("es").contains("español sencillo"));
    }
}
