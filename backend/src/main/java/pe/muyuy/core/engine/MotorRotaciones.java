package pe.muyuy.core.engine;

import pe.muyuy.core.model.Calendario;
import pe.muyuy.core.model.Cultivo;
import pe.muyuy.core.model.Rotacion;
import pe.muyuy.core.model.Zona;

import java.util.List;

/** Contrato v2.1 del motor. Determinista: mismo input = mismo output. */
public interface MotorRotaciones {

    /** TODAS las candidatas (hasta max_candidatas por cultivo inicial) + la práctica común si existe. */
    List<Rotacion> recomendar(Zona zona, Calendario calendario, List<Cultivo> catalogo);

    /** ¿El clima de la zona permite el cultivo sembrado en el mes de siembra? */
    boolean esApto(Zona zona, Cultivo cultivo, Calendario calendario);
}
