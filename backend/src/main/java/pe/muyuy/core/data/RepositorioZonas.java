package pe.muyuy.core.data;

import com.fasterxml.jackson.core.type.TypeReference;
import jakarta.enterprise.context.ApplicationScoped;
import pe.muyuy.core.model.Zona;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@ApplicationScoped
public class RepositorioZonas {

    private final Map<String, Zona> zonas = new LinkedHashMap<>();

    public RepositorioZonas(LectorJson lector) {
        lector.leer("zonas.json", new TypeReference<List<Zona>>() {})
              .forEach(z -> zonas.put(z.id(), z));
    }

    public List<Zona> todas() { return List.copyOf(zonas.values()); }

    public Optional<Zona> porId(String id) { return Optional.ofNullable(zonas.get(id)); }
}
