package pe.muyuy.core.data;

import jakarta.enterprise.context.ApplicationScoped;
import pe.muyuy.core.model.Reglas;

@ApplicationScoped
public class RepositorioReglas {

    private final Reglas reglas;

    public RepositorioReglas(LectorJson lector) { this.reglas = lector.leer("reglas.json", Reglas.class); }

    public Reglas reglas() { return reglas; }
}
