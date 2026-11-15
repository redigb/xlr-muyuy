package pe.muyuy.core.data;

import com.fasterxml.jackson.core.type.TypeReference;
import jakarta.enterprise.context.ApplicationScoped;
import pe.muyuy.core.model.Cultivo;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@ApplicationScoped
public class RepositorioCultivos {

    private final Map<String, Cultivo> cultivos = new LinkedHashMap<>();

    public RepositorioCultivos(LectorJson lector) {
        lector.leer("cultivos.json", new TypeReference<List<Cultivo>>() {})
              .forEach(c -> cultivos.put(c.id(), c));
    }

    public List<Cultivo> todos() { return List.copyOf(cultivos.values()); }

    public Optional<Cultivo> porId(String id) { return Optional.ofNullable(cultivos.get(id)); }

    public Cultivo requerido(String id) {
        return porId(id).orElseThrow(() -> new IllegalArgumentException("Cultivo desconocido: " + id));
    }

    /**
     * Catálogo con el que el motor arma las rotaciones. Zonas oficiales (sierra | valle | selva): solo lo que
     * se siembra ahí (validado con MIDAGRI) + descanso. Coordenadas y "global": TODO el catálogo, el clima filtra.
     */
    public List<Cultivo> catalogoPara(String region) {
        if (region == null || "global".equals(region) || "coordenada".equals(region)) return todos();
        return cultivos.values().stream()
                .filter(c -> c.esDescanso() || c.zonas().contains(region))
                .toList();
    }

    /** Cultivos (sin descanso) declarados para la region: sierra | valle | selva | global (= todos). */
    public List<Cultivo> deRegion(String region) {
        return cultivos.values().stream()
                .filter(c -> !c.esDescanso())
                .filter(c -> "global".equals(region) || c.zonas().contains(region))
                .toList();
    }
}
