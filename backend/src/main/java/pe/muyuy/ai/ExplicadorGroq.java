package pe.muyuy.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.jboss.logging.Logger;
import pe.muyuy.ai.ClienteGroq.Mensaje;
import pe.muyuy.ai.ClienteGroq.Peticion;
import pe.muyuy.core.Explicador;
import pe.muyuy.core.ExplicadorPlantilla;
import pe.muyuy.core.data.RepositorioCultivos;
import pe.muyuy.core.model.Calendario;
import pe.muyuy.core.model.MesClima;
import pe.muyuy.core.model.Rotacion;
import pe.muyuy.core.model.Zona;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * Explicaciones con Groq: UNA llamada por zona con todas las rotaciones (evita el límite de peticiones).
 * La IA solo redacta con los datos del motor. Sin clave, deshabilitado o ante cualquier fallo: plantilla.
 */
@ApplicationScoped
public class ExplicadorGroq implements Explicador {

    private static final Logger LOG = Logger.getLogger(ExplicadorGroq.class);

    private final ClienteGroq groq;
    private final RepositorioCultivos cultivos;
    private final ObjectMapper mapper;
    private final boolean habilitado;
    private final String clave;
    private final String modelo;
    private final String esfuerzo;
    private final Explicador plantilla = new ExplicadorPlantilla();

    public ExplicadorGroq(@RestClient ClienteGroq groq, RepositorioCultivos cultivos, ObjectMapper mapper,
                          @ConfigProperty(name = "groq.enabled", defaultValue = "true") boolean habilitado,
                          @ConfigProperty(name = "groq.clave") Optional<String> clave,
                          @ConfigProperty(name = "groq.model", defaultValue = "openai/gpt-oss-120b") String modelo,
                          @ConfigProperty(name = "groq.reasoning-effort") Optional<String> esfuerzo) {
        this.groq = groq;
        this.cultivos = cultivos;
        this.mapper = mapper;
        this.clave = clave.orElse("").trim();
        this.habilitado = habilitado && !this.clave.isEmpty();
        this.modelo = modelo;
        this.esfuerzo = esfuerzo.map(String::trim).filter(s -> !s.isEmpty()).orElse(null);
    }

    @Override
    public String explicar(Rotacion r, Zona zona, Calendario cal, String idioma) {
        return explicarTodas(List.of(r), zona, cal, idioma)
                .getOrDefault(r.id(), plantilla.explicar(r, zona, cal, idioma));
    }

    /** Devuelve solo las que Groq explicó; si algo falla devuelve vacío y quien llama usa la plantilla. */
    @Override
    public Map<String, String> explicarTodas(List<Rotacion> rotaciones, Zona zona, Calendario cal, String idioma) {
        if (!habilitado || rotaciones.isEmpty()) return Map.of();
        try {
            var peticion = new Peticion(modelo,
                    List.of(new Mensaje("system", sistema(idioma)), new Mensaje("user", datos(rotaciones, zona, cal))),
                    0.2, 150 * rotaciones.size() + 200, Map.of("type", "json_object"), esfuerzo);
            String texto = groq.chat("Bearer " + clave, peticion).texto();
            JsonNode json = mapper.readTree(texto).path("explicaciones");
            Map<String, String> out = new LinkedHashMap<>();
            for (Rotacion r : rotaciones) {
                String t = json.path(r.id()).asText("").trim();
                if (!t.isEmpty()) out.put(r.id(), t);
            }
            LOG.infof("Groq explicó %d de %d rotaciones de %s", out.size(), rotaciones.size(), zona.id());
            return out;
        } catch (Exception e) {
            LOG.warnf("Groq no respondió para %s (%s); se usa la plantilla", zona.id(), e.getMessage());
            return Map.of();
        }
    }

    // ---------------------------------------------------------------- prompt

    static String sistema(String idioma) {
        String lengua = "en".equals(idioma) ? "simple English" : "español sencillo, sin tecnicismos";
        return "Eres un extensionista agrícola que explica rotaciones de cultivo a pequeños agricultores. "
                + "Escribe en " + lengua + ". Para CADA rotación escribe 2 frases cortas: por qué ese orden de cultivos "
                + "ayuda (suelo, agua, plagas, ingresos) y qué cuidado tener según el clima dado. "
                + "Usa SOLO los datos que recibes; no inventes cifras, precios ni variedades. No cambies la recomendación. "
                + "Responde únicamente un JSON con la forma {\"explicaciones\": {\"<id>\": \"<texto>\"}} "
                + "con una entrada por cada id recibido.";
    }

    String datos(List<Rotacion> rotaciones, Zona zona, Calendario cal) {
        String heladas = cal.calendario().stream().filter(m -> m.probHelada() >= 0.3)
                .map(m -> String.valueOf(m.mes())).collect(Collectors.joining(","));
        String secos = cal.calendario().stream().filter(m -> m.balanceHidricoMm() < 0)
                .map(m -> String.valueOf(m.mes())).collect(Collectors.joining(","));
        double lluvia = cal.calendario().stream().mapToDouble(MesClima::lluviaMm).sum();

        StringBuilder sb = new StringBuilder();
        sb.append("Zona: ").append(zona.nombre()).append(" (").append(zona.elevacionM()).append(" m). ")
          .append("Lluvia anual: ").append(Math.round(lluvia)).append(" mm. ")
          .append("Meses con riesgo de helada: ").append(heladas.isEmpty() ? "ninguno" : heladas).append(". ")
          .append("Meses secos: ").append(secos.isEmpty() ? "ninguno" : secos).append(". ")
          .append("Siembra en el mes 10. Puntajes de 0 a 1 (riesgo: 1 = seguro).\n\nRotaciones:\n");
        for (Rotacion r : rotaciones) {
            var p = r.puntajes();
            String nombres = r.secuencia().stream().map(this::describir).collect(Collectors.joining(" -> "));
            sb.append("- id: ").append(r.id()).append(" | ").append(nombres)
              .append(" | agua ").append(p.agua()).append(", suelo ").append(p.suelo())
              .append(", ingresos ").append(p.ingresos()).append(", riesgo ").append(p.riesgo());
            if (r.esPracticaComun()) sb.append(" | es la práctica actual de la zona (explica su desventaja)");
            sb.append('\n');
        }
        return sb.toString();
    }

    private String describir(String cultivoId) {
        return cultivos.porId(cultivoId)
                .map(c -> c.nombre() + " (" + c.familia() + (c.fijaNitrogeno() ? ", fija nitrógeno" : "")
                        + (c.cobertura() ? ", cubre el suelo" : "") + ")")
                .orElse(cultivoId);
    }
}
