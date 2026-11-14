package pe.muyuy.core.model;

/**
 * Zona agricola. region = sierra | valle | selva | global (cruza con Cultivo.zonas).
 * cultivoActual = lo que el agricultor siembra hoy (inicio de la rotacion).
 */
public record Zona(String id, String nombre, String region, double lat, double lon,
                   int elevacionM, String cultivoActual) {}
