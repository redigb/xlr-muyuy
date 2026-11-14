package pe.muyuy.core.data;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;

/** Lee los JSON de muyuy.data-dir con el ObjectMapper de Quarkus (snake_case). */
@ApplicationScoped
public class LectorJson {

    private final ObjectMapper mapper;
    private final Path dir;

    public LectorJson(ObjectMapper mapper, @ConfigProperty(name = "muyuy.data-dir") Path dir) {
        this.mapper = mapper;
        this.dir = dir;
    }

    public boolean existe(String archivo) { return Files.isRegularFile(dir.resolve(archivo)); }

    public <T> T leer(String archivo, Class<T> tipo) {
        try { return mapper.readValue(dir.resolve(archivo).toFile(), tipo); }
        catch (IOException e) { throw new UncheckedIOException("No se pudo leer " + dir.resolve(archivo), e); }
    }

    public <T> T leer(String archivo, TypeReference<T> tipo) {
        try { return mapper.readValue(dir.resolve(archivo).toFile(), tipo); }
        catch (IOException e) { throw new UncheckedIOException("No se pudo leer " + dir.resolve(archivo), e); }
    }
}
