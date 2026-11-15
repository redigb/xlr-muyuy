package pe.muyuy.core.red;

import io.agroal.api.AgroalDataSource;
import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

import java.sql.Connection;
import java.sql.SQLException;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Red pública anónima (SPECS_v2 §9.3 y §15): quién compartió el paquete con quién, sin IDs reales
 * (alias aleatorios en CADA consulta) y sin datos demo.
 */
@ApplicationScoped
public class ServicioRed {

    static final int MAX_SALTOS = 5;
    static final int MAX_CONEXIONES = 2000;
    static final int DIAS_SERIE = 30;

    @Schema(description = "Anonymous node. The alias changes on every request")
    public record Nodo(String id) {}

    @Schema(description = "A COMPARTIO edge: 'origen' shared the package with 'destino'")
    public record Arista(String origen, String destino, @Schema(description = "Day (YYYY-MM-DD)") String fecha) {}

    public record Metricas(
            @Schema(description = "Devices in the sharing network") int dispositivos,
            @Schema(description = "COMPARTIO edges") int comparticiones,
            @Schema(description = "Field observations received") int observaciones,
            @Schema(description = "Observations validated (NASA + neighbor consensus)") int observacionesValidadas,
            @Schema(description = "observaciones_validadas / observaciones, 0..1") double pctValidadas,
            @Schema(description = "Most devices reached from one origin (max 5 hops)") int alcanceMax,
            @Schema(description = "Longest sharing chain, in hops (max 5)") int saltosMax) {}

    @Schema(description = "Daily new activity")
    public record Dia(String fecha, int dispositivos, int comparticiones, int observaciones) {}

    public record RedPublica(List<Nodo> nodos, List<Arista> conexiones, Metricas metricas,
                             @Schema(description = "Last 30 days, oldest first") List<Dia> serie) {}

    private final AgroalDataSource ds;

    public ServicioRed(AgroalDataSource ds) { this.ds = ds; }

    public RedPublica publica() {
        try (Connection c = ds.getConnection()) {
            List<String[]> aristas = new ArrayList<>();   // origen, destino, fecha (IDs reales: nunca salen)
            try (var ps = c.prepareStatement("select origen, destino, fecha::date::text from conexiones "
                    + "where tipo = 'COMPARTIO' and not demo order by fecha limit " + MAX_CONEXIONES);
                 var rs = ps.executeQuery()) {
                while (rs.next()) aristas.add(new String[]{rs.getString(1), rs.getString(2), rs.getString(3)});
            }

            Map<String, String> alias = alias(aristas);
            List<Nodo> nodos = alias.values().stream()
                    .sorted((a, b) -> Integer.compare(Integer.parseInt(a.substring(1)), Integer.parseInt(b.substring(1))))
                    .map(Nodo::new).toList();
            List<Arista> conexiones = aristas.stream()
                    .map(a -> new Arista(alias.get(a[0]), alias.get(a[1]), a[2])).toList();

            int[] alcance = alcanceYSaltos(aristas);
            int obs = contar(c, "select count(*) from observaciones where not demo");
            int validadas = contar(c, "select count(*) from observaciones where not demo and estado = 'validada'");
            Metricas m = new Metricas(nodos.size(), aristas.size(), obs, validadas,
                    obs == 0 ? 0 : Math.round(1000.0 * validadas / obs) / 1000.0, alcance[0], alcance[1]);
            return new RedPublica(nodos, conexiones, m, serie(c));
        } catch (SQLException e) {
            throw new IllegalStateException("No se pudo leer la red", e);
        }
    }

    /** Alias "n1".."nN" en orden aleatorio: no se puede seguir a un dispositivo entre consultas. */
    static Map<String, String> alias(List<String[]> aristas) {
        Set<String> ids = new HashSet<>();
        for (String[] a : aristas) { ids.add(a[0]); ids.add(a[1]); }
        List<String> orden = new ArrayList<>(ids);
        Collections.shuffle(orden);
        Map<String, String> out = new HashMap<>();
        for (int i = 0; i < orden.size(); i++) out.put(orden.get(i), "n" + (i + 1));
        return out;
    }

    /** [alcance máximo, saltos máximos]: BFS desde cada origen (equivale al WITH RECURSIVE de §9.2). */
    static int[] alcanceYSaltos(List<String[]> aristas) {
        Map<String, List<String>> salida = new HashMap<>();
        for (String[] a : aristas) salida.computeIfAbsent(a[0], k -> new ArrayList<>()).add(a[1]);
        int alcanceMax = 0;
        int saltosMax = 0;
        for (String origen : salida.keySet()) {
            Map<String, Integer> visto = new HashMap<>(Map.of(origen, 0));
            var cola = new ArrayDeque<String>(List.of(origen));
            while (!cola.isEmpty()) {
                String d = cola.poll();
                int s = visto.get(d);
                if (s == MAX_SALTOS) continue;
                for (String sig : salida.getOrDefault(d, List.of())) {
                    if (visto.putIfAbsent(sig, s + 1) == null) cola.add(sig);
                }
            }
            alcanceMax = Math.max(alcanceMax, visto.size() - 1);
            saltosMax = Math.max(saltosMax, Collections.max(visto.values()));
        }
        return new int[]{alcanceMax, saltosMax};
    }

    private List<Dia> serie(Connection c) throws SQLException {
        String sql = "select d::date::text, "
                + "(select count(*) from dispositivos where not demo and creado::date = d::date), "
                + "(select count(*) from conexiones where tipo = 'COMPARTIO' and not demo and fecha::date = d::date), "
                + "(select count(*) from observaciones where not demo and creado::date = d::date) "
                + "from generate_series(current_date - " + (DIAS_SERIE - 1) + ", current_date, interval '1 day') d "
                + "order by d";
        List<Dia> out = new ArrayList<>();
        try (var ps = c.prepareStatement(sql); var rs = ps.executeQuery()) {
            while (rs.next()) out.add(new Dia(rs.getString(1), rs.getInt(2), rs.getInt(3), rs.getInt(4)));
        }
        return out;
    }

    private static int contar(Connection c, String sql) throws SQLException {
        try (var ps = c.prepareStatement(sql); var rs = ps.executeQuery()) {
            return rs.next() ? rs.getInt(1) : 0;
        }
    }
}
