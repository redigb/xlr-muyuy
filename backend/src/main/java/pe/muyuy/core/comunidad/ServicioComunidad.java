package pe.muyuy.core.comunidad;

import io.agroal.api.AgroalDataSource;
import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import pe.muyuy.core.data.RepositorioCalendarios;
import pe.muyuy.core.data.RepositorioZonas;
import pe.muyuy.core.model.MesClima;
import pe.muyuy.core.paquete.Sello;
import pe.muyuy.core.paquete.ServicioPaquetes;

import java.security.MessageDigest;
import java.security.SecureRandom;
import java.sql.Connection;
import java.sql.Date;
import java.sql.SQLException;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

import static java.nio.charset.StandardCharsets.UTF_8;

/**
 * Lo que ESCRIBEN los usuarios (SPECS_v2 §8, §9, §11.2): dispositivos anónimos, observaciones de campo
 * con puntaje automático (NASA + consenso) y conexiones "compartí el paquete con".
 */
@ApplicationScoped
public class ServicioComunidad {

    public static final Set<String> TIPOS = Set.of("helada", "sequia", "lluvia_fuerte", "granizo", "plaga", "otro");
    private static final int DIAS_CONSENSO = 3;

    @Schema(description = "Anonymous device credential. The app stores it; the server keeps only the token hash")
    public record Registro(
            @Schema(description = "Anonymous device id") UUID id,
            @Schema(description = "Secret for /api/sync (header Authorization: Bearer <token>). Cannot be recovered: store it") String token) {}

    public record Dispositivo(UUID id, boolean demo) {}

    @Schema(description = "Something the farmer saw in their field, recorded offline")
    public record ObservacionIn(
            @Schema(description = "UUID generated on the phone. Makes sending idempotent: resending never duplicates", required = true) UUID idLocal,
            @Schema(description = "Official zone where it happened (or use celda)") String zonaId,
            @Schema(description = "0.5° grid cell when not in an official zone") String celda,
            @Schema(description = "helada (frost) | sequia (drought) | lluvia_fuerte (heavy rain) | granizo (hail) | plaga (pest) | otro (other)", required = true) String tipo,
            @Schema(description = "Event date (YYYY-MM-DD). Cannot be in the future", required = true) LocalDate fechaEvento,
            @Schema(description = "Optional measured value (e.g. mm of rain)") Double valor,
            @Schema(description = "Approximate latitude; rounded to ~1 km before storing (privacy)") Double latAprox,
            @Schema(description = "Approximate longitude; rounded to ~1 km before storing") Double lonAprox,
            @Schema(description = "true = comes from the demo; never counts for alerts or metrics") boolean demo,
            @Schema(description = "When it was recorded on the phone (ISO-8601)") String creado) {}

    @Schema(description = "An 'I shared the package with' record: builds the community network (graph)")
    public record ConexionIn(
            @Schema(description = "Device id that shared", required = true) String origen,
            @Schema(description = "Device id that received", required = true) String destino,
            @Schema(description = "Only COMPARTIO (shared) for now", required = true) String tipo,
            @Schema(description = "Shared package, 'zone@version'", examples = "huanuco-sierra@12") String paquete,
            @Schema(description = "true = comes from the demo") boolean demo,
            @Schema(description = "When it was shared (ISO-8601)") String fecha) {}

    @Schema(description = "Everything stored offline since the last sync")
    public record SyncIn(
            @Schema(description = "Field observations") List<ObservacionIn> observaciones,
            @Schema(description = "Package-sharing connections") List<ConexionIn> conexiones) {}

    @Schema(description = "Result of one submitted observation")
    public record Detalle(
            @Schema(description = "id_local sent by the app") UUID idLocal,
            @Schema(description = "true if it was stored") boolean aceptada,
            @Schema(description = "validada/validated (≥ 70) | pendiente/pending (40–69) | sospechosa/suspicious (< 40); the app shows ✅ or ⏳") String estado,
            @Schema(description = "Automatic score 0..100: up to 55 for matching NASA + up to 45 for neighbor consensus") Integer puntaje,
            @Schema(description = "Rejection or suspicion reason code, if any") String motivo) {}

    @Schema(description = "Sync summary")
    public record SyncOut(
            @Schema(description = "Stored observations (includes already-existing resends)") int aceptadas,
            @Schema(description = "Observations rejected for invalid data or daily limit") int rechazadas,
            @Schema(description = "Valid connections received") int conexiones,
            @Schema(description = "Status of each observation") List<Detalle> detalle) {}

    private record Grupo(String zonaId, String tipo, LocalDate fecha) {}
    private record Fila(UUID id, UUID dispositivo, LocalDate fecha) {}

    private final AgroalDataSource ds;
    private final RepositorioZonas zonas;
    private final RepositorioCalendarios calendarios;
    private final ServicioPaquetes paquetes;
    private final int maxPorDia;
    private final SecureRandom azar = new SecureRandom();

    public ServicioComunidad(AgroalDataSource ds, RepositorioZonas zonas, RepositorioCalendarios calendarios,
                             ServicioPaquetes paquetes,
                             @ConfigProperty(name = "muyuy.limites.observaciones-por-dia", defaultValue = "50") int maxPorDia) {
        this.ds = ds;
        this.zonas = zonas;
        this.calendarios = calendarios;
        this.paquetes = paquetes;
        this.maxPorDia = maxPorDia;
    }

    // ---------------------------------------------------------------- dispositivos

    /** Token = "<id>.<secreto>". Solo se guarda su hash: si se filtra la base, los tokens no sirven. */
    public Registro registrar(boolean demo) {
        UUID id = UUID.randomUUID();
        byte[] secreto = new byte[32];
        azar.nextBytes(secreto);
        String token = id + "." + Base64.getUrlEncoder().withoutPadding().encodeToString(secreto);
        ejecutar("insert into dispositivos (id, token_hash, demo) values (?, ?, ?)", id, Sello.sha256(token), demo);
        return new Registro(id, token);
    }

    public Optional<Dispositivo> autenticar(String token) {
        if (token == null || !token.contains(".")) return Optional.empty();
        UUID id;
        try { id = UUID.fromString(token.substring(0, token.indexOf('.'))); }
        catch (IllegalArgumentException e) { return Optional.empty(); }

        try (var c = ds.getConnection();
             var ps = c.prepareStatement("select token_hash, demo, bloqueado from dispositivos where id = ?")) {
            ps.setObject(1, id);
            try (var rs = ps.executeQuery()) {
                if (!rs.next() || rs.getBoolean("bloqueado")) return Optional.empty();
                boolean igual = MessageDigest.isEqual(rs.getString("token_hash").getBytes(UTF_8),
                        Sello.sha256(token).getBytes(UTF_8));
                if (!igual) return Optional.empty();
                Dispositivo d = new Dispositivo(id, rs.getBoolean("demo"));
                try (var up = c.prepareStatement("update dispositivos set ultimo_contacto = now() where id = ?")) {
                    up.setObject(1, id);
                    up.executeUpdate();
                }
                return Optional.of(d);
            }
        } catch (SQLException e) {
            throw new IllegalStateException("No se pudo autenticar el dispositivo", e);
        }
    }

    // ---------------------------------------------------------------- sync

    public SyncOut sincronizar(Dispositivo d, SyncIn in) {
        List<ObservacionIn> obs = in == null || in.observaciones() == null ? List.of() : in.observaciones();
        List<ConexionIn> cons = in == null || in.conexiones() == null ? List.of() : in.conexiones();
        List<Detalle> rechazadas = new ArrayList<>();
        List<UUID> aceptadas = new ArrayList<>();
        Set<Grupo> tocados = new LinkedHashSet<>();
        int conexionesOk = 0;

        try (Connection c = ds.getConnection()) {
            int hoy = contarHoy(c, d.id());
            for (ObservacionIn o : obs) {
                String motivo = validar(o);
                boolean demo = o.demo() || d.demo();
                if (motivo == null && !existe(c, o.idLocal())) {
                    if (hoy >= maxPorDia) motivo = "limite_diario";
                    else { insertar(c, d.id(), o, demo); hoy++; }
                }
                if (motivo != null) { rechazadas.add(new Detalle(o.idLocal(), false, null, null, motivo)); continue; }
                aceptadas.add(o.idLocal());
                if (!demo && o.zonaId() != null) tocados.add(new Grupo(o.zonaId(), o.tipo(), o.fechaEvento()));
            }
            for (Grupo g : tocados) recalcularConsenso(c, g);
            for (ConexionIn x : cons) if (insertarConexion(c, x, d.demo())) conexionesOk++;

            List<Detalle> detalle = new ArrayList<>(rechazadas);
            for (UUID idLocal : aceptadas) detalle.add(leerDetalle(c, idLocal));
            tocados.stream().map(Grupo::zonaId).distinct().forEach(paquetes::invalidar);   // alertas nuevas → paquete nuevo
            return new SyncOut(aceptadas.size(), rechazadas.size(), conexionesOk, detalle);
        } catch (SQLException e) {
            throw new IllegalStateException("No se pudo sincronizar", e);
        }
    }

    /** null = válida; si no, el motivo del rechazo. */
    String validar(ObservacionIn o) {
        LocalDate hoy = LocalDate.now(ZoneOffset.UTC);
        if (o.idLocal() == null) return "id_local requerido";
        if (o.tipo() == null || !TIPOS.contains(o.tipo())) return "tipo desconocido";
        if (o.fechaEvento() == null) return "fecha_evento requerida";
        if (o.fechaEvento().isAfter(hoy.plusDays(1))) return "fecha futura";
        if (o.fechaEvento().isBefore(hoy.minusDays(365))) return "fecha muy antigua";
        if (o.zonaId() == null && (o.celda() == null || o.celda().isBlank())) return "zona_id o celda requerida";
        if (o.zonaId() != null && zonas.porId(o.zonaId()).isEmpty()) return "zona desconocida";
        if (o.latAprox() != null && Math.abs(o.latAprox()) > 90) return "ubicacion invalida";
        if (o.lonAprox() != null && Math.abs(o.lonAprox()) > 180) return "ubicacion invalida";
        return null;
    }

    private void insertar(Connection c, UUID dispositivo, ObservacionIn o, boolean demo) throws SQLException {
        int nasa = Puntaje.nasa(o.tipo(), mesClima(o.zonaId(), o.fechaEvento()));
        String sql = "insert into observaciones (id, id_local, dispositivo_id, zona_id, celda, tipo, fecha_evento, valor, "
                + "lat_aprox, lon_aprox, puntaje, estado, motivo_sospecha, demo) values (?,?,?,?,?,?,?,?,?,?,?,?,?,?) "
                + "on conflict (id_local) do nothing";
        try (var ps = c.prepareStatement(sql)) {
            ps.setObject(1, UUID.randomUUID());
            ps.setObject(2, o.idLocal());
            ps.setObject(3, dispositivo);
            ps.setString(4, o.zonaId());
            ps.setString(5, o.celda());
            ps.setString(6, o.tipo());
            ps.setDate(7, Date.valueOf(o.fechaEvento()));
            ps.setObject(8, o.valor());
            ps.setObject(9, redondear(o.latAprox()));          // ~1 km: privacidad
            ps.setObject(10, redondear(o.lonAprox()));
            ps.setInt(11, nasa);
            ps.setString(12, Puntaje.estado(nasa));
            ps.setString(13, Puntaje.motivoSospecha(o.tipo(), nasa, nasa));
            ps.setBoolean(14, demo);
            ps.executeUpdate();
        }
    }

    /** Recalcula puntaje y estado de las observaciones reales del grupo y sus vecinas (±3 días). */
    private void recalcularConsenso(Connection c, Grupo g) throws SQLException {
        List<Fila> filas = new ArrayList<>();
        String sql = "select id, dispositivo_id, fecha_evento from observaciones "
                + "where zona_id = ? and tipo = ? and not demo and fecha_evento between ? and ?";
        try (var ps = c.prepareStatement(sql)) {
            ps.setString(1, g.zonaId());
            ps.setString(2, g.tipo());
            ps.setDate(3, Date.valueOf(g.fecha().minusDays(2L * DIAS_CONSENSO)));
            ps.setDate(4, Date.valueOf(g.fecha().plusDays(2L * DIAS_CONSENSO)));
            try (var rs = ps.executeQuery()) {
                while (rs.next()) {
                    filas.add(new Fila(rs.getObject(1, UUID.class), rs.getObject(2, UUID.class), rs.getDate(3).toLocalDate()));
                }
            }
        }
        try (var up = c.prepareStatement("update observaciones set puntaje = ?, estado = ?, motivo_sospecha = ? where id = ?")) {
            for (Fila f : filas) {
                Set<UUID> otros = new HashSet<>();
                for (Fila v : filas) {
                    boolean cerca = Math.abs(ChronoUnit.DAYS.between(f.fecha(), v.fecha())) <= DIAS_CONSENSO;
                    if (cerca && !v.dispositivo().equals(f.dispositivo())) otros.add(v.dispositivo());
                }
                int nasa = Puntaje.nasa(g.tipo(), mesClima(g.zonaId(), f.fecha()));
                int total = Math.min(100, nasa + Puntaje.consenso(otros.size()));
                up.setInt(1, total);
                up.setString(2, Puntaje.estado(total));
                up.setString(3, Puntaje.motivoSospecha(g.tipo(), nasa, total));
                up.setObject(4, f.id());
                up.addBatch();
            }
            up.executeBatch();
        }
    }

    private boolean insertarConexion(Connection c, ConexionIn x, boolean demoDispositivo) throws SQLException {
        if (x == null || !"COMPARTIO".equals(x.tipo())) return false;
        if (x.origen() == null || x.destino() == null || x.origen().isBlank() || x.destino().isBlank()) return false;
        if (x.origen().equals(x.destino())) return false;
        // paquete '' en vez de NULL para que la restricción UNIQUE evite duplicados
        String sql = "insert into conexiones (origen, destino, tipo, paquete, demo) values (?,?,?,?,?) on conflict do nothing";
        try (var ps = c.prepareStatement(sql)) {
            ps.setString(1, x.origen());
            ps.setString(2, x.destino());
            ps.setString(3, x.tipo());
            ps.setString(4, x.paquete() == null ? "" : x.paquete());
            ps.setBoolean(5, x.demo() || demoDispositivo);
            ps.executeUpdate();
            return true;
        }
    }

    // ---------------------------------------------------------------- utilidades

    private MesClima mesClima(String zonaId, LocalDate fecha) {
        if (zonaId == null) return null;
        return calendarios.deZona(zonaId).map(cal -> cal.mes(fecha.getMonthValue())).orElse(null);
    }

    private static Double redondear(Double v) { return v == null ? null : Math.round(v * 100) / 100.0; }

    private int contarHoy(Connection c, UUID dispositivo) throws SQLException {
        try (var ps = c.prepareStatement("select count(*) from observaciones where dispositivo_id = ? and creado >= current_date")) {
            ps.setObject(1, dispositivo);
            try (var rs = ps.executeQuery()) { rs.next(); return rs.getInt(1); }
        }
    }

    private boolean existe(Connection c, UUID idLocal) throws SQLException {
        try (var ps = c.prepareStatement("select 1 from observaciones where id_local = ?")) {
            ps.setObject(1, idLocal);
            try (var rs = ps.executeQuery()) { return rs.next(); }
        }
    }

    private Detalle leerDetalle(Connection c, UUID idLocal) throws SQLException {
        try (var ps = c.prepareStatement("select estado, puntaje, motivo_sospecha from observaciones where id_local = ?")) {
            ps.setObject(1, idLocal);
            try (var rs = ps.executeQuery()) {
                rs.next();
                return new Detalle(idLocal, true, rs.getString(1), rs.getInt(2), rs.getString(3));
            }
        }
    }

    private void ejecutar(String sql, Object... params) {
        try (var c = ds.getConnection(); var ps = c.prepareStatement(sql)) {
            for (int i = 0; i < params.length; i++) ps.setObject(i + 1, params[i]);
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new IllegalStateException("Error de base de datos", e);
        }
    }
}
