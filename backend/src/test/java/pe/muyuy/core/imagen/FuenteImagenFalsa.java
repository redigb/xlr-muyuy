package pe.muyuy.core.imagen;

import io.quarkus.test.Mock;
import jakarta.enterprise.context.ApplicationScoped;
import pe.muyuy.core.model.Zona;

import java.util.Optional;

/** Reemplaza a Worldview en las pruebas: un JPEG mínimo fijo, sin red. */
@Mock
@ApplicationScoped
public class FuenteImagenFalsa implements FuenteImagen {

    public static final byte[] JPEG = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0, 0, 0x10, (byte) 0xFF, (byte) 0xD9};

    @Override
    public Optional<byte[]> jpeg(Zona zona) { return Optional.of(JPEG); }
}
