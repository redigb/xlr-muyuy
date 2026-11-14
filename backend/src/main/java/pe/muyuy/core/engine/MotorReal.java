package pe.muyuy.core.engine;

import jakarta.enterprise.context.ApplicationScoped;
import pe.muyuy.core.data.RepositorioReglas;
import pe.muyuy.core.model.Calendario;
import pe.muyuy.core.model.Confianza;
import pe.muyuy.core.model.Cultivo;
import pe.muyuy.core.model.MesClima;
import pe.muyuy.core.model.Nivel;
import pe.muyuy.core.model.NivelConfianza;
import pe.muyuy.core.model.Puntajes;
import pe.muyuy.core.model.Reglas;
import pe.muyuy.core.model.Rotacion;
import pe.muyuy.core.model.Zona;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.IntStream;

/**
 * Motor determinista (SPECS_v2 §4.3): aptitud → secuencias de 3 campañas → reglas prohibidas
 * → puntajes → hasta max_candidatas diversas por cultivo inicial + práctica común.
 */
@ApplicationScoped
public class MotorReal implements MotorRotaciones {

    private static final String PAPA = "papa";
    private final Reglas reglas;

    public MotorReal(RepositorioReglas repo) { this.reglas = repo.reglas(); }

    // ---------------------------------------------------------------- aptitud

    @Override
    public boolean esApto(Zona zona, Cultivo c, Calendario cal) {
        if (c.esDescanso()) return true;
        List<MesClima> ciclo = ciclo(cal, c);
        double tMedia = ciclo.stream().mapToDouble(MesClima::tMedia).average().orElse(0);
        double tol = reglas.toleranciaTempC();
        if (tMedia < c.tOptMin() - tol || tMedia > c.tOptMax() + tol) return false;
        if (ciclo.stream().anyMatch(m -> m.tMin() < c.ktmp())) return false;          // helada letal
        if (zona.riego()) return true;
        double lluvia = ciclo.stream().mapToDouble(MesClima::lluviaMm).sum();
        double necesidad = c.lluviaOptMin() * c.cicloMeses() / 12.0;
        return lluvia >= reglas.factorLluviaMin() * necesidad;
    }

    // ---------------------------------------------------------------- candidatas

    @Override
    public List<Rotacion> recomendar(Zona zona, Calendario cal, List<Cultivo> catalogo) {
        Map<String, Cultivo> porId = new LinkedHashMap<>();
        catalogo.forEach(c -> porId.put(c.id(), c));
        List<Cultivo> aptos = catalogo.stream()
                .filter(c -> !c.esDescanso() && esApto(zona, c, cal))
                .sorted(Comparator.comparing(Cultivo::id))
                .toList();
        Set<String> aptosIds = new HashSet<>(aptos.stream().map(Cultivo::id).toList());

        List<Rotacion> out = new ArrayList<>();
        List<String> comun = zona.practicaComun();
        if (comun != null && porId.keySet().containsAll(comun)) {
            out.add(construir(comun.stream().map(porId::get).toList(), true, cal));
        }

        for (String inicialId : zona.cultivosIniciales()) {
            Cultivo inicial = porId.get(inicialId);
            if (inicial == null || !aptosIds.contains(inicialId)) continue;

            List<Rotacion> todas = new ArrayList<>();
            for (Cultivo b : aptos) {
                for (Cultivo c : aptos) {
                    List<Cultivo> seq = List.of(inicial, b, c);
                    if (permitida(seq)) todas.add(construir(seq, false, cal));
                }
            }
            todas.sort(Comparator.comparingDouble((Rotacion r) -> r.puntajes().total()).reversed()
                    .thenComparing(Rotacion::id));

            Set<String> segundos = new HashSet<>();
            for (Rotacion r : todas) {
                if (segundos.size() >= reglas.maxCandidatas()) break;
                if (segundos.add(r.secuencia().get(1))) out.add(r);
            }
        }
        return List.copyOf(out);
    }

    /** Prohibidas: misma familia en campañas seguidas (incluye papa → papa). */
    static boolean permitida(List<Cultivo> seq) {
        for (int i = 1; i < seq.size(); i++) {
            Cultivo a = seq.get(i - 1), b = seq.get(i);
            if (a.familia().equals(b.familia())) return false;
            if (PAPA.equals(a.id()) && PAPA.equals(b.id())) return false;
        }
        return true;
    }

    // ---------------------------------------------------------------- puntajes

    private Rotacion construir(List<Cultivo> seq, boolean comun, Calendario cal) {
        double agua = seq.stream().mapToDouble(c -> puntajeAgua(c, cal)).average().orElse(0);
        double ingresos = seq.stream().mapToDouble(Cultivo::valorMercado).average().orElse(0);
        double riesgo = 1 - seq.stream().mapToDouble(c -> dano(c, cal)).average().orElse(0);

        long familias = seq.stream().filter(c -> !c.esDescanso()).map(Cultivo::familia).distinct().count();
        Cultivo ultimo = seq.get(seq.size() - 1);
        double suelo = 0.3
                + (seq.stream().anyMatch(Cultivo::fijaNitrogeno) ? 0.3 : 0)
                + (familias >= 3 ? 0.2 : 0)
                + (ultimo.cobertura() || "Poaceae".equals(ultimo.familia()) ? 0.2 : 0);

        Puntajes p = Puntajes.de(agua, suelo, ingresos, riesgo);
        List<String> ids = seq.stream().map(Cultivo::id).toList();
        String id = (comun ? "comun-" : "") + String.join("-", ids);
        return new Rotacion(id, ids.get(0), ids, p, confianza(cal), "", validar(p, seq.get(1)), comun);
    }

    private double puntajeAgua(Cultivo c, Calendario cal) {
        if (c.esDescanso()) return 1.0;
        double base = switch (c.agua()) { case baja -> 1.0; case media -> 0.7; case alta -> 0.4; };
        return Math.max(0, base - 0.1 * mesesSecos(c, cal));
    }

    /** Daño esperado 0..1: promedio de helada y sequía dentro del ciclo. */
    private double dano(Cultivo c, Calendario cal) {
        if (c.esDescanso()) return 0;
        double maxHelada = ciclo(cal, c).stream().mapToDouble(MesClima::probHelada).max().orElse(0);
        double helada = maxHelada * factor(c.toleraHelada(), 1.0, 0.5, 0.2);
        double sequia = (double) mesesSecos(c, cal) / c.cicloMeses() * factor(c.agua(), 0.3, 0.6, 1.0);
        return (helada + sequia) / 2;
    }

    private static double factor(Nivel n, double baja, double media, double alta) {
        return switch (n) { case baja -> baja; case media -> media; case alta -> alta; };
    }

    private long mesesSecos(Cultivo c, Calendario cal) {
        return ciclo(cal, c).stream().filter(m -> m.balanceHidricoMm() < reglas.balanceMesSecoMm()).count();
    }

    private List<MesClima> ciclo(Calendario cal, Cultivo c) {
        int meses = Math.min(c.cicloMeses(), 12);
        return IntStream.range(0, meses).mapToObj(i -> cal.mes(reglas.mesSiembra() + i)).toList();
    }

    private Confianza confianza(Calendario cal) {
        boolean anios = cal.anios() != null && cal.anios() >= reglas.aniosClimaAlta();
        return new Confianza(anios ? NivelConfianza.alta : NivelConfianza.media,
                NivelConfianza.alta, NivelConfianza.media, NivelConfianza.sin_datos);
    }

    /** Texto según el factor más débil (empate: agua, suelo, ingresos, riesgo). */
    private static String validar(Puntajes p, Cultivo segundo) {
        String nombre = segundo.nombre();
        double min = Math.min(Math.min(p.agua(), p.suelo()), Math.min(p.ingresos(), p.riesgo()));
        if (p.agua() == min) return "Confirma si hay agua suficiente (lluvia o riego) para " + nombre + ".";
        if (p.suelo() == min) return "Consulta a un agronomo sobre el suelo de tu parcela antes de sembrar " + nombre + ".";
        if (p.ingresos() == min) return "Confirma si hay semilla y compradores de " + nombre + " en tu zona.";
        return "Pregunta a tus vecinos por heladas y sequias en los meses de " + nombre + ".";
    }
}
