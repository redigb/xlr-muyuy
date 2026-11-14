package pe.muyuy.core.model;

import java.util.List;

/**
 * Resultado del motor. actual = true para la rotacion que el agricultor ya practica.
 * CONTRATO: despues del sabado 9:00 solo se AGREGAN campos, nunca se renombran ni quitan.
 */
public record Rotacion(String id, String nombre, boolean actual, List<Campania> campanias,
                       Puntajes puntajes, Confianza confianza, String validarConExperto) {}
