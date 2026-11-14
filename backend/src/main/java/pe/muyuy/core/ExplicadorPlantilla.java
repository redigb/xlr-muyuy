package pe.muyuy.core;

import io.quarkus.arc.DefaultBean;
import jakarta.enterprise.context.ApplicationScoped;
import pe.muyuy.core.model.Calendario;
import pe.muyuy.core.model.Campania;
import pe.muyuy.core.model.Rotacion;
import pe.muyuy.core.model.Zona;

import java.util.stream.Collectors;

/**
 * Respaldo sin IA (Groq caido / 429 / sin clave). @DefaultBean: cualquier otra
 * implementacion @ApplicationScoped de Explicador la reemplaza automaticamente.
 */
@DefaultBean
@ApplicationScoped
public class ExplicadorPlantilla implements Explicador {

    @Override
    public String explicar(Rotacion r, Zona zona, Calendario calendario) {
        String seq = r.campanias().stream().map(Campania::cultivoNombre).collect(Collectors.joining(" -> "));
        return "%s en %s: %s. Agua %.0f%%, suelo %.0f%%, ingresos %.0f%%, seguridad %.0f%%."
                .formatted(r.nombre(), zona.nombre(), seq,
                        r.puntajes().agua() * 100, r.puntajes().suelo() * 100,
                        r.puntajes().ingresos() * 100, r.puntajes().riesgo() * 100);
    }
}
