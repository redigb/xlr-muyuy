package pe.muyuy.core.data;

import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.health.HealthCheck;
import org.eclipse.microprofile.health.HealthCheckResponse;
import org.eclipse.microprofile.health.Readiness;
import pe.muyuy.core.model.Zona;

/** /q/health/ready falla si algun JSON no carga o falta el calendario de una zona. */
@Readiness
@ApplicationScoped
public class DatosHealthCheck implements HealthCheck {

    private final RepositorioZonas zonas;
    private final RepositorioCultivos cultivos;
    private final RepositorioCalendarios calendarios;
    private final RepositorioReglas reglas;

    public DatosHealthCheck(RepositorioZonas zonas, RepositorioCultivos cultivos,
                            RepositorioCalendarios calendarios, RepositorioReglas reglas) {
        this.zonas = zonas;
        this.cultivos = cultivos;
        this.calendarios = calendarios;
        this.reglas = reglas;
    }

    @Override
    public HealthCheckResponse call() {
        var r = HealthCheckResponse.named("datos");
        try {
            var sinCalendario = zonas.todas().stream()
                    .filter(z -> calendarios.deZona(z.id()).isEmpty()).map(Zona::id).toList();
            r.withData("zonas", zonas.todas().size())
             .withData("cultivos", cultivos.todos().size())
             .withData("reglas", reglas.reglas().reglas().size())
             .withData("sin_calendario", sinCalendario.toString());
            return r.status(sinCalendario.isEmpty()).build();
        } catch (RuntimeException e) {
            return r.down().withData("error", String.valueOf(e.getMessage())).build();
        }
    }
}
