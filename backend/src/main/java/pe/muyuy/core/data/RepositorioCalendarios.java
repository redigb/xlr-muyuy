package pe.muyuy.core.data;

import jakarta.enterprise.context.ApplicationScoped;
import pe.muyuy.core.model.Calendario;

import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/** data/calendario_<zonaId>.json. Se cachea; reinicia el contenedor si cambian los datos. */
@ApplicationScoped
public class RepositorioCalendarios {

    private final LectorJson lector;
    private final Map<String, Calendario> cache = new ConcurrentHashMap<>();

    public RepositorioCalendarios(LectorJson lector) { this.lector = lector; }

    public Optional<Calendario> deZona(String zonaId) {
        String archivo = "calendario_" + zonaId + ".json";
        if (!cache.containsKey(zonaId) && !lector.existe(archivo)) return Optional.empty();
        return Optional.of(cache.computeIfAbsent(zonaId, id -> lector.leer(archivo, Calendario.class)));
    }
}
