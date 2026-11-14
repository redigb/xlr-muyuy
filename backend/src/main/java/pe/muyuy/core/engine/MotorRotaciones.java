package pe.muyuy.core.engine;

import pe.muyuy.core.model.Calendario;
import pe.muyuy.core.model.Rotacion;
import pe.muyuy.core.model.Zona;

import java.util.List;

/**
 * Contrato del motor (se confirma el sabado 9:00).
 * Devuelve SIEMPRE 3 rotaciones: [0] la actual + 2 recomendadas, de forma determinista.
 * La API inyecta esta interfaz; no conoce MotorFalso ni MotorReal.
 */
public interface MotorRotaciones {
    List<Rotacion> recomendar(Zona zona, Calendario calendario);
}
