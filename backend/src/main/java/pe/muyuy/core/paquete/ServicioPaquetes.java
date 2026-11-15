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
import pe.muyuy.core.data.RepositorioZonas;
import pe.muyuy.core.engine.MotorReal;
import pe.muyuy.core.imagen.FuenteImagen;
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
import java.util.Base64;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Ciclo de vida del paquete (SPECS_v2 §3.4): GENERAR → SELLAR (version++ solo si el hash cambió) → GUARDAR.
 * Se genera en el primer pedido tras arrancar y queda en memoria; regenerar() lo rehace.
 * Mismo sellado para zonas oficiales (es / en) y para coordenadas (§11.1).
 */
@ApplicationScoped
public class ServicioPaquetes {

    private static final Logger LOG = Logger.getLogger(ServicioPaquetes.class);
    public static final String ES = "es";
    public static final String EN = "en";
    public static final Set<String> IDIOMAS = Set.of(ES, EN);
    static final String ZONA_OFICIAL = "zona_oficial";
    static final String COORDENADA = "coordenada";

    /** Paquete ya sellado. base = "huanuco-sierra", "huanuco-sierra|en" o "-9.5_-76.0|en". */
    public record Sellado(String zonaId, int version, String hash, String contenido) {
        public String clave() { return zonaId + "@" + version; }
    }

    /** De dónde sale el paquete. Determina la clave, la fila en `paquetes` y la meta. */
    record Origen(String tipo, String zonaId, String celda, String idioma) {
        static Origen oficial(String zonaId, String idioma) { return new Origen(ZONA_OFICIAL, zonaId, null, idioma); }
        static Origen coordenada(String celda, String idioma) { return new Origen(COORDENADA, null, celda, idioma); }

        boolean esCoordenada() { return COORDENADA.equals(tipo); }

        /** Clave sin versión. Las zonas oficiales en español conservan la clave histórica. */
        String base() {
            if (esCoordenada()) return celda + "|" + idioma;
            return ES.equals(idioma) ? zonaId : zonaId + "|" + idioma;
        }
    }

    private final RepositorioZonas zonas;
    private final RepositorioCalendarios calendarios;
    private final RepositorioCultivos cultivos;
    private final MotorRotaciones motor;
    private final Explicador explicador;
    private final ObjectMapper mapper;
    private final AgroalDataSource ds;
    private final FuenteImagen imagenes;
    private final Explicador respaldo = new ExplicadorPlantilla();
    private final Map<String, Sellado> cache = new ConcurrentHashMap<>();

    public ServicioPaquetes(RepositorioZonas zonas, RepositorioCalendarios calendarios, RepositorioCultivos cultivos,
                            MotorRotaciones motor, Explicador explicador, ObjectMapper mapper, AgroalDataSource ds,
                            FuenteImagen imagenes) {
        this.imagenes = imagenes;
        this.zonas = zonas;
        this.calendarios = calendarios;
        this.cultivos = cultivos;
        this.motor = motor;
        this.explicador = explicador;
        this.mapper = mapper;
        this.ds = ds;
    }

    // ---------------------------------------------------------------- zonas oficiales

    /** Vacío si la zona no existe o no tiene calendario. */
    public Optional<Sellado> obtener(String zonaId) { return obtener(zonaId, ES); }

    public Optional<Sellado> obtener(String zonaId, String idioma) {
        Origen origen = Origen.oficial(zonaId, idioma(idioma));
        Sellado enCache = cache.get(origen.base());
        if (enCache != null) return Optional.of(enCache);
        Optional<Zona> zona = zonas.porId(zonaId);
        Optional<Calendario> cal = calendarios.deZona(zonaId);
        if (zona.isEmpty() || cal.isEmpty()) return Optional.empty();
        synchronized (this) {
            return Optional.of(cache.computeIfAbsent(origen.base(), k -> generar(origen, zona.get(), cal.get())));
        }
    }

    public Optional<Sellado> regenerar(String zonaId) {
        invalidar(zonaId);
        return obtener(zonaId);
    }

    /** La próxima petición regenera el paquete (p. ej. hay alertas nuevas de la comunidad). */
    public void invalidar(String zonaId) {
        for (String idioma : IDIOMAS) cache.remove(Origen.oficial(zonaId, idioma).base());
    }

    // ---------------------------------------------------------------- coordenadas

    /** Paquete de una celda generado hace menos de `dias` (caché persistente, §14). */
    public Optional<Sellado> coordenadaReciente(String celda, String idioma, int dias) {
        Origen origen = Origen.coordenada(celda, idioma(idioma));
        Sellado enCache = cache.get(origen.base());
        if (enCache != null) return Optional.of(enCache);
        String sql = "select version, hash, contenido from paquetes where origen = ? and celda = ? and idioma = ? "
                   + "and generado > now() - make_interval(days => ?) order by version desc limit 1";
        try (var c = ds.getConnection(); var ps = c.prepareStatement(sql)) {
            ps.setString(1, COORDENADA);
            ps.setString(2, celda);
            ps.setString(3, origen.idioma());
            ps.setInt(4, dias);
            try (var rs = ps.executeQuery()) {
                if (!rs.next()) return Optional.empty();
                Sellado s = new Sellado(origen.base(), rs.getInt(1), rs.getString(2), rs.getString(3));
                cache.put(origen.base(), s);
                return Optional.of(s);
            }
        } catch (SQLException e) {
            LOG.warn("No se pudo leer la caché de la celda " + celda, e);
            return Optional.empty();
        }
    }

    /** Genera y sella el paquete de una celda. `zona` debe tener region "coordenada". */
    public Sellado coordenada(String celda, String idioma, Zona zona, Calendario cal) {
        Origen origen = Origen.coordenada(celda, idioma(idioma));
        synchronized (this) {
            Sellado s = generar(origen, zona, cal);
            cache.put(origen.base(), s);
            return s;
        }
    }

    // ---------------------------------------------------------------- descargas

    public void registrarDescarga(Sellado s) {
        try (var c = ds.getConnection();
             var ps = c.prepareStatement("insert into descargas (clave_paquete) values (?)")) {
            ps.setString(1, s.clave());
            ps.executeUpdate();
        } catch (SQLException e) {
            LOG.warn("No se pudo contar la descarga de " + s.clave(), e);   // contar nunca rompe la descarga
        }
    }

    /** es / en; cualquier otro valor cae a español. */
    public static String idioma(String pedido) {
        return pedido != null && IDIOMAS.contains(pedido.toLowerCase()) ? pedido.toLowerCase() : ES;
    }

    // ---------------------------------------------------------------- generar + sellar

    private Sellado generar(Origen origen, Zona zona, Calendario cal) {
        String idioma = origen.idioma();
        Optional<Sellado> previo = ultimo(origen);
        Map<String, String> explicacionesPrevias = previo.map(this::explicacionesDe).orElse(Map.of());

        List<Rotacion> rotaciones = explicar(motor.recomendar(zona, cal, cultivos.todos()), zona, cal, idioma,
                explicacionesPrevias);
        if (EN.equals(idioma)) {
            rotaciones = rotaciones.stream()
                    .map(r -> r.conValidar(MotorReal.validar(r.puntajes(), cultivos.requerido(r.secuencia().get(1)), EN)))
                    .toList();
        }
        List<Cultivo> usados = rotaciones.stream().flatMap(r -> r.secuencia().stream()).distinct().sorted()
                .map(cultivos::requerido).toList();

        String idZona = origen.esCoordenada() ? "celda_" + origen.celda() : zona.id();
        Nucleo nucleo = new Nucleo(
                new ZonaPaquete(idZona, zona.nombre(), zona.lat(), zona.lon(), zona.elevacionM()),
                cal.fuente(), motor.mesSiembra(zona, cal), cal.calendario(),
                Map.of(), usados, rotaciones, alertas(origen));
        // Imagen satelital solo en zonas oficiales (§3.3): coordenadas quedan livianas.
        Map<String, Object> extras = origen.esCoordenada() ? Map.of()
                : imagenes.jpeg(zona).<Map<String, Object>>map(b -> Map.of(
                        "imagen_satelital_b64", Base64.getEncoder().encodeToString(b))).orElse(Map.of());

        String hash = Sello.hash(mapper, nucleo, extras);
        int version = previo.map(p -> p.hash().equals(hash) ? p.version() : p.version() + 1).orElse(1);

        LocalDate hoy = LocalDate.now(ZoneOffset.UTC);
        Map<String, Seccion> secciones = new LinkedHashMap<>();
        secciones.put("calendario", new Seccion(hoy.toString(), hoy.plusMonths(3).toString()));
        secciones.put("condiciones", new Seccion(hoy.toString(), hoy.plusDays(14).toString()));
        secciones.put("alertas", new Seccion(hoy.toString(), hoy.plusDays(7).toString()));

        boolean validada = !origen.esCoordenada() && !"global".equals(zona.region());
        Meta meta = new Meta(2, origen.tipo(), origen.zonaId(), origen.celda(), validada, idioma,
                version, Instant.now().truncatedTo(ChronoUnit.SECONDS).toString(), hash, secciones,
                extras.isEmpty() ? List.of() : List.of("imagen"));

        Sellado sellado = new Sellado(origen.base(), version, hash,
                json(new PaqueteDoc(new Paquete(meta, nucleo, extras))));
        guardar(origen, sellado);
        LOG.infof("Paquete %s sellado (%s, %d rotaciones)", sellado.clave(), hash.substring(0, 19), rotaciones.size());
        return sellado;
    }

    /**
     * 1) Reutiliza la explicación previa si la rotación no cambió y no era la de plantilla.
     * 2) Pide el resto al Explicador en UN lote. 3) Lo que falte (o si falla) va con plantilla.
     */
    private List<Rotacion> explicar(List<Rotacion> rotaciones, Zona zona, Calendario cal, String idioma,
                                    Map<String, String> previas) {
        Map<String, String> textos = new HashMap<>();
        List<Rotacion> pendientes = new java.util.ArrayList<>();
        for (Rotacion r : rotaciones) {
            String previa = previas.get(huella(r.id(), mapper.valueToTree(r.puntajes())));
            boolean reutilizable = previa != null && !previa.isBlank()
                    && !previa.equals(respaldo.explicar(r, zona, cal, idioma));
            if (reutilizable) textos.put(r.id(), previa); else pendientes.add(r);
        }
        if (!pendientes.isEmpty()) {
            try {
                explicador.explicarTodas(pendientes, zona, cal, idioma).forEach((id, t) -> {
                    if (t != null && !t.isBlank()) textos.put(id, t);
                });
            } catch (RuntimeException e) {
                LOG.warn("Explicador falló para " + zona.id() + "; se usa la plantilla", e);
            }
        }
        return rotaciones.stream()
                .map(r -> r.conExplicacion(textos.getOrDefault(r.id(), respaldo.explicar(r, zona, cal, idioma))))
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
    private List<Alerta> alertas(Origen origen) {
        String columna = origen.esCoordenada() ? "celda" : "zona_id";
        String sql = "select tipo, fecha_evento, count(distinct dispositivo_id) from observaciones "
                   + "where " + columna + " = ? and estado = 'validada' and not demo and fecha_evento >= current_date - 7 "
                   + "group by tipo, fecha_evento order by fecha_evento, tipo";
        List<Alerta> out = new java.util.ArrayList<>();
        try (var c = ds.getConnection(); var ps = c.prepareStatement(sql)) {
            ps.setString(1, origen.esCoordenada() ? origen.celda() : origen.zonaId());
            try (var rs = ps.executeQuery()) {
                while (rs.next()) out.add(new Alerta(rs.getString(1), rs.getDate(2).toLocalDate().toString(), rs.getInt(3)));
            }
        } catch (SQLException e) {
            LOG.warn("No se pudieron leer las alertas de " + origen.base() + "; el paquete sale sin alertas", e);
        }
        return out;
    }

    private Optional<Sellado> ultimo(Origen origen) {
        String columna = origen.esCoordenada() ? "celda" : "zona_id";
        String sql = "select version, hash, contenido from paquetes where origen = ? and " + columna + " = ? "
                   + "and idioma = ? order by version desc limit 1";
        try (var c = ds.getConnection(); var ps = c.prepareStatement(sql)) {
            ps.setString(1, origen.tipo());
            ps.setString(2, origen.esCoordenada() ? origen.celda() : origen.zonaId());
            ps.setString(3, origen.idioma());
            try (var rs = ps.executeQuery()) {
                return rs.next()
                        ? Optional.of(new Sellado(origen.base(), rs.getInt(1), rs.getString(2), rs.getString(3)))
                        : Optional.empty();
            }
        } catch (SQLException e) {
            throw new IllegalStateException("No se pudo leer el paquete de " + origen.base(), e);
        }
    }

    private void guardar(Origen origen, Sellado s) {
        String sql = "insert into paquetes (clave, origen, zona_id, celda, idioma, version, hash, contenido) "
                   + "values (?, ?, ?, ?, ?, ?, ?, ?) "
                   + "on conflict (clave) do update set contenido = excluded.contenido, generado = now()";
        try (var c = ds.getConnection(); var ps = c.prepareStatement(sql)) {
            ps.setString(1, s.clave());
            ps.setString(2, origen.tipo());
            ps.setString(3, origen.zonaId());
            ps.setString(4, origen.celda());
            ps.setString(5, origen.idioma());
            ps.setInt(6, s.version());
            ps.setString(7, s.hash());
            ps.setString(8, s.contenido());
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new IllegalStateException("No se pudo guardar el paquete " + s.clave(), e);
        }
    }
}
