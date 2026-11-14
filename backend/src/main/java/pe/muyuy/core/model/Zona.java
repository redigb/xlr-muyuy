package pe.muyuy.core.model;

import java.util.List;

/**
 * Zona oficial. cultivosIniciales = lo que se siembra hoy (inicio de las rotaciones).
 * practicaComun = rotación tradicional (puede ser null).
 */
public record Zona(String id, String nombre, String region, double lat, double lon, int elevacionM,
                   boolean riego, List<String> cultivosIniciales, List<String> practicaComun) {}
