package pe.muyuy.core.model;

/** Una campania (anio) de la rotacion: 1 cultivo sembrado en mesSiembra. */
public record Campania(int numero, String cultivoId, String cultivoNombre, String familia, int mesSiembra) {}
