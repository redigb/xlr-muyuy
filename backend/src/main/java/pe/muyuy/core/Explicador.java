package pe.muyuy.core;

import pe.muyuy.core.model.Calendario;
import pe.muyuy.core.model.Rotacion;
import pe.muyuy.core.model.Zona;

/** La implementa el compañero en ai/ (Groq). Sin implementación, se usa ExplicadorPlantilla. idioma = es | en. */
public interface Explicador {
    String explicar(Rotacion rotacion, Zona zona, Calendario calendario, String idioma);
}
