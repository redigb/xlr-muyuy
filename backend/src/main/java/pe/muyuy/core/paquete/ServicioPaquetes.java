package pe.muyuy.core.paquete;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.agroal.api.AgroalDataSource;
import jakarta.enterprise.context.ApplicationScoped;
import org.jboss.logging.Logger;
import pe.muyuy.core.Explicador;
import pe.muyuy.core.ExplicadorPlantilla;
import pe.muyuy.core.data.RepositorioCalendarios;
import pe.muyuy.core.data.RepositorioCultivos;
import pe.muyuy.core.data.RepositorioReglas;
import pe.muyuy.core.data.RepositorioZonas;
import pe.muyuy.core.engine.MotorRotaciones;
import pe.muyuy.core.model.Calendario;
import pe.muyuy.core.model.Cultivo;
import pe.muyuy.core.model.Rotacion;
import pe.muyuy.core.model.Zona;
import pe.muyuy.core.paquete.PaqueteDoc.Alerta;
import pe.muyuy.core.paquete.PaqueteDoc.Meta;
import pe.muyuy.core.paquete.PaqueteDoc.Nucleo;
import pe.muyuy.core.paquete.PaqueteDoc.Paquete;
import pe.muyuy.core.paquete.PaqueteDoc.Seccion;
import pe.muyuy.core.paquete.PaqueteDoc.ZonaPaquete;

import java.sql.SQLException;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Ciclo de vida del paquete (SPECS_v2 §3.4): GENERAR → SELLAR (version++ solo si el hash cambió) → GUARDAR.
 * Se genera en el primer pedido tras arrancar y queda en memoria; regenerar() lo rehace.
 */
@ApplicationScoped
public class ServicioPaquetes {

    private static final Logger LOG = Logger.getLogger(ServicioPaquetes.class);
    private static final String IDIOMA = "es";

    /** Paquete ya sellado, listo para servir. contenido = JSON exacto que se guarda y se responde. */
    public record Sellado(String zonaId, int version, String hash, String contenido) {
        public String clave() { return zonaId + "@" + version; }
    }

    private final RepositorioZonas zonas;
    private final RepositorioCalendarios calendarios;
    private final RepositorioCultivos cultivos;
    private final RepositorioReglas reglas;
    private final MotorRotaciones motor;
    private final Explicador explicador;
    private final ObjectMapper mapper;
    private final AgroalDataSource ds;
    private final Explicador respaldo = new ExplicadorPlantilla();
    private final Map<String, Sellado> cache = new ConcurrentHashMap<>();

    public ServicioPaquetes(RepositorioZonas zonas, RepositorioCalendarios calendarios, RepositorioCultivos cultivos,
                            RepositorioReglas reglas, MotorRotaciones motor, Explicador explicador,
                            ObjectMapper mapper, AgroalDataSource ds) {
        this.zonas = zonas;
        this.calendarios = calendarios;
        this.cultivos = cultivos;
        this.reglas = reglas;
        this.motor = motor;
        this.explicador = explicador;
        this.mapper = mapper;
        this.ds = ds;
    }

    /** Vacío si la zona no existe o no tiene calendario. */
    public Optional<Sellado> obtener(String zonaId) {
        Sellado enCache = cache.get(zonaId);
        if (enCache != null) return Optional.of(enCache);
        Optional<Zona> zona = zonas.porId(zonaId);
        Optional<Calendario> cal = calendarios.deZona(zonaId);
        if (zona.isEmpty() || cal.isEmpty()) return Optional.empty();
        synchronized (this) {
            return Optional.of(cache.computeIfAbsent(zonaId, id -> generar(zona.get(), cal.get())));
        }
    }

    public Optional<Sellado> regenerar(String zonaId) {
        cache.remove(zonaId);
        return obtener(zonaId);
    }

    /** La próxima petición regenera el paquete (p. ej. hay alertas nuevas de la comunidad). */
    public void invalidar(String zonaId) { cache.remove(zonaId); }

    public void registrarDescarga(Sellado s) {
        try (var c = ds.getConnection();
             var ps = c.prepareStatement("insert into descargas (clave_paquete) values (?)")) {
            ps.setString(1, s.clave());
            ps.executeUpdate();
        } catch (SQLException e) {
            LOG.warn("No se pudo contar la descarga de " + s.clave(), e);   // contar nunca rompe la descarga
        }
    }

    // ---------------------------------------------------------------- generar + sellar

    private Sellado generar(Zona zona, Calendario cal) {
        Optional<Sellado> previo = ultimo(zona.id());
        Map<String, String> explicacionesPrevias = previo.map(this::explicacionesDe).orElse(Map.of());

        List<Rotacion> rotaciones = explicar(motor.recomendar(zona, cal, cultivos.todos()), zona, cal, explicacionesPrevias);
        List<Cultivo> usados = rotaciones.stream().flatMap(r -> r.secuencia().stream()).distinct().sorted()
                .map(cultivos::requerido).toList();

        Nucleo nucleo = new Nucleo(
                new ZonaPaquete(zona.id(), zona.nombre(), zona.lat(), zona.lon(), zona.elevacionM()),
                cal.fuente(), reglas.reglas().mesSiembra(), cal.calendario(),
                Map.of(), usados, rotaciones, alertas(zona.id()));
        Map<String, Object> extras = Map.of();

        String hash = Sello.hash(mapper, nucleo, extras);
        int version = previo.map(p -> p.hash().equals(hash) ? p.version() : p.version() + 1).orElse(1);

        LocalDate hoy = LocalDate.now(ZoneOffset.UTC);
        Map<String, Seccion> secciones = new LinkedHashMap<>();
        secciones.put("calendario", new Seccion(hoy.toString(), hoy.plusMonths(3).toString()));
        secciones.put("condiciones", new Seccion(hoy.toString(), hoy.plusDays(14).toString()));
        secciones.put("alertas", new Seccion(hoy.toString(), hoy.plusDays(7).toString()));

        Meta meta = new Meta(2, "zona_oficial", zona.id(), null, !"global".equals(zona.region()), IDIOMA,
                version, Instant.now().truncatedTo(ChronoUnit.SECONDS).toString(), hash, secciones, List.of());

        Sellado sellado = new Sellado(zona.id(), version, hash, json(new PaqueteDoc(new Paquete(meta, nucleo, extras))));
        guardar(sellado);
        LOG.infof("Paquete %s sellado (%s, %d rotaciones)", sellado.clave(), hash.substring(0, 19), rotaciones.size());
        return sellado;
    }

    /**
     * 1) Reutiliza la explicación previa si la rotación no cambió y no era la de plantilla.
     * 2) Pide el resto al Explicador en UN lote. 3) Lo que falte (o si falla) va con plantilla.
     */
    private List<Rotacion> explicar(List<Rotacion> rotaciones, Zona zona, Calendario cal, Map<String, String> previas) {
        Map<String, String> textos = new HashMap<>();
        List<Rotacion> pendientes = new java.util.ArrayList<>();
        for (Rotacion r : rotaciones) {
            String previa = previas.get(huella(r.id(), mapper.valueToTree(r.puntajes())));
            boolean reutilizable = previa != null && !previa.isBlank()
                    && !previa.equals(respaldo.explicar(r, zona, cal, IDIOMA));
            if (reutilizable) textos.put(r.id(), previa); else pendientes.add(r);
        }
        if (!pendientes.isEmpty()) {
            try {
                explicador.explicarTodas(pendientes, zona, cal, IDIOMA).forEach((id, t) -> {
                    if (t != null && !t.isBlank()) textos.put(id, t);
                });
            } catch (RuntimeException e) {
                LOG.warn("Explicador falló para " + zona.id() + "; se usa la plantilla", e);
            }
        }
        return rotaciones.stream()
                .map(r -> r.conExplicacion(textos.getOrDefault(r.id(), respaldo.explicar(r, zona, cal, IDIOMA))))
                .toList();
    }

    private Map<String, String> explicacionesDe(Sellado previo) {
        Map<String, String> out = new HashMap<>();
        try {
            for (JsonNode r : mapper.readTree(previo.contenido()).at("/paquete/nucleo/rotaciones")) {
                out.put(huella(r.path("id").asText(), r.path("puntajes")), r.path("explicacion").asText(""));
            }
        } catch (Exception e) {
            LOG.warn("No se pudieron leer las explicaciones previas de " + previo.clave(), e);
        }
        return out;
    }

    private static String huella(String id, JsonNode puntajes) { return id + "|" + puntajes; }

    private String json(Object o) {
        try { return mapper.writeValueAsString(o); }
        catch (Exception e) { throw new IllegalStateException("No se pudo serializar el paquete", e); }
    }

    // ---------------------------------------------------------------- base de datos

    /** Observaciones validadas (no demo) de los últimos 7 días, agrupadas por tipo y fecha. */
    private List<Alerta> alertas(String zonaId) {
        String sql = "select tipo, fecha_evento, count(distinct dispositivo_id) from observaciones "
                   + "where zona_id = ? and estado = 'validada' and not demo and fecha_evento >= current_date - 7 "
                   + "group by tipo, fecha_evento order by fecha_evento, tipo";
        List<Alerta> out = new java.util.ArrayList<>();
        try (var c = ds.getConnection(); var ps = c.prepareStatement(sql)) {
            ps.setString(1, zonaId);
            try (var rs = ps.executeQuery()) {
                while (rs.next()) out.add(new Alerta(rs.getString(1), rs.getDate(2).toLocalDate().toString(), rs.getInt(3)));
            }
        } catch (SQLException e) {
            LOG.warn("No se pudieron leer las alertas de " + zonaId + "; el paquete sale sin alertas", e);
        }
        return out;
    }

    private Optional<Sellado> ultimo(String zonaId) {
        String sql = "select version, hash, contenido from paquetes where zona_id = ? and idioma = ? "
                   + "order by version desc limit 1";
        try (var c = ds.getConnection(); var ps = c.prepareStatement(sql)) {
            ps.setString(1, zonaId);
            ps.setString(2, IDIOMA);
            try (var rs = ps.executeQuery()) {
                return rs.next()
                        ? Optional.of(new Sellado(zonaId, rs.getInt(1), rs.getString(2), rs.getString(3)))
                        : Optional.empty();
            }
        } catch (SQLException e) {
            throw new IllegalStateException("No se pudo leer el paquete de " + zonaId, e);
        }
    }

    private void guardar(Sellado s) {
        String sql = "insert into paquetes (clave, origen, zona_id, idioma, version, hash, contenido) "
                   + "values (?, 'zona_oficial', ?, ?, ?, ?, ?) "
                   + "on conflict (clave) do update set contenido = excluded.contenido, generado = now()";
        try (var c = ds.getConnection(); var ps = c.prepareStatement(sql)) {
            ps.setString(1, s.clave());
            ps.setString(2, s.zonaId());
            ps.setString(3, IDIOMA);
            ps.setInt(4, s.version());
            ps.setString(5, s.hash());
            ps.setString(6, s.contenido());
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new IllegalStateException("No se pudo guardar el paquete " + s.clave(), e);
        }
    }
}
