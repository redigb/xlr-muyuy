package pe.muyuy.core;

import pe.muyuy.core.model.Calendario;
import pe.muyuy.core.model.Rotacion;
import pe.muyuy.core.model.Zona;

/** La implementa el companiero en ai/ (Groq). Si no hay implementacion, se usa ExplicadorPlantilla. */
public interface Explicador {
    String explicar(Rotacion rotacion, Zona zona, Calendario calendario);
}
