package pe.muyuy.core.model;

import java.util.List;

/** Rotación candidata (contrato v2.1). La app filtra por cultivoInicial y ordena por puntajes. */
public record Rotacion(String id, String cultivoInicial, List<String> secuencia, Puntajes puntajes,
                       Confianza confianza, String explicacion, String validarConExperto,
                       boolean esPracticaComun) {

    public Rotacion conExplicacion(String texto) {
        return new Rotacion(id, cultivoInicial, secuencia, puntajes, confianza, texto, validarConExperto, esPracticaComun);
    }
}
