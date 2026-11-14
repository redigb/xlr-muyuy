package pe.muyuy.core;

import io.quarkus.arc.DefaultBean;
import jakarta.enterprise.context.ApplicationScoped;
import pe.muyuy.core.model.Calendario;
import pe.muyuy.core.model.Rotacion;
import pe.muyuy.core.model.Zona;

/** Respaldo sin IA (Groq caído / 429 / sin clave). Cualquier otro Explicador la reemplaza. */
@DefaultBean
@ApplicationScoped
public class ExplicadorPlantilla implements Explicador {

    @Override
    public String explicar(Rotacion r, Zona zona, Calendario calendario, String idioma) {
        String seq = String.join(" -> ", r.secuencia());
        var p = r.puntajes();
        String plantilla = "en".equals(idioma)
                ? "%s in %s. Water %.0f%%, soil %.0f%%, income %.0f%%, safety %.0f%%."
                : "%s en %s. Agua %.0f%%, suelo %.0f%%, ingresos %.0f%%, seguridad %.0f%%.";
        return plantilla.formatted(seq, zona.nombre(), p.agua() * 100, p.suelo() * 100, p.ingresos() * 100, p.riesgo() * 100);
    }
}
