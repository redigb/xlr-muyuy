package pe.muyuy.core.imagen;

import pe.muyuy.core.model.Zona;

import java.util.Optional;

/** Foto satelital de la zona para `extras.imagen_satelital_b64` (SPECS_v2 §3.3). Vacío si no hay. */
public interface FuenteImagen {
    Optional<byte[]> jpeg(Zona zona);
}
