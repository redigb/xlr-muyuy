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
 * <p>
 * Zonas con region "coordenada" (§4.6): mes de siembra calculado del calendario, cultivos
 * iniciales = los 3 más aptos, ingresos neutros (0.5) y confianza máxima media.
 */
@ApplicationScoped
public class MotorReal implements MotorRotaciones {

    public static final String REGION_COORDENADA = "coordenada";
    private static final String PAPA = "papa";
    private static final int INICIALES_COORDENADA = 3;
    private static final double INGRESOS_NEUTROS = 0.5;

    private final Reglas reglas;

    public MotorReal(RepositorioReglas repo) { this.reglas = repo.reglas(); }

    /** Mes de siembra de la zona: fijo (reglas.json) o calculado si es una coordenada. */
    @Override
    public int mesSiembra(Zona zona, Calendario cal) {
        return esCoordenada(zona) ? InicioSiembra.calcular(cal) : reglas.mesSiembra();
    }

    // ---------------------------------------------------------------- aptitud

    @Override
    public boolean esApto(Zona zona, Cultivo c, Calendario cal) {
        return esApto(zona, c, cal, mesSiembra(zona, cal));
    }

    private boolean esApto(Zona zona, Cultivo c, Calendario cal, int mes) {
        if (c.esDescanso()) return true;
        List<MesClima> ciclo = ciclo(cal, c, mes);
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
        int mes = mesSiembra(zona, cal);
        boolean coordenada = esCoordenada(zona);
        Map<String, Cultivo> porId = new LinkedHashMap<>();
        catalogo.forEach(c -> porId.put(c.id(), c));
        List<Cultivo> aptos = catalogo.stream()
                .filter(c -> !c.esDescanso() && esApto(zona, c, cal, mes))
                .sorted(Comparator.comparing(Cultivo::id))
                .toList();
        Set<String> aptosIds = new HashSet<>(aptos.stream().map(Cultivo::id).toList());

        List<Rotacion> out = new ArrayList<>();
        List<String> comun = zona.practicaComun();
        if (!coordenada && comun != null && porId.keySet().containsAll(comun)) {
            out.add(construir(comun.stream().map(porId::get).toList(), true, cal, mes, coordenada));
        }

        for (String inicialId : iniciales(zona, aptos, cal, mes)) {
            Cultivo inicial = porId.get(inicialId);
            if (inicial == null || !aptosIds.contains(inicialId)) continue;

            List<Rotacion> todas = new ArrayList<>();
            for (Cultivo b : aptos) {
                for (Cultivo c : aptos) {
                    List<Cultivo> seq = List.of(inicial, b, c);
                    if (permitida(seq)) todas.add(construir(seq, false, cal, mes, coordenada));
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

    /**
     * Zonas oficiales: los de zonas.json. Coordenadas: los 3 con mejor orden según
     * 1) se siembra en todo el mundo (zonas incluye "global"; los nativos andinos quedan como opción dentro),
     * 2) cultivo principal (cereal o tubérculo), 3) aptitud al clima. Las leguminosas van al final:
     * entran después en la rotación (leguminosa tras cultivo exigente).
     */
    private List<String> iniciales(Zona zona, List<Cultivo> aptos, Calendario cal, int mes) {
        if (!esCoordenada(zona) || (zona.cultivosIniciales() != null && !zona.cultivosIniciales().isEmpty())) {
            return zona.cultivosIniciales() == null ? List.of() : zona.cultivosIniciales();
        }
        Comparator<Cultivo> orden = Comparator
                .comparing((Cultivo c) -> c.fijaNitrogeno())
                .thenComparing(c -> !c.zonas().contains("global"))
                .thenComparing(c -> !c.principal())
                .thenComparingDouble(c -> -aptitud(zona, c, cal, mes))
                .thenComparing(Cultivo::id);
        return aptos.stream().sorted(orden)
                .limit(INICIALES_COORDENADA)
                .map(Cultivo::id)
                .toList();
    }

    /**
     * Qué tan bien le va al cultivo en este clima, 0..1: temperatura dentro del óptimo (50%),
     * lluvia del ciclo frente a su necesidad (30%) y valor de mercado (20%). La helada letal y la falta de
     * lluvia ya los descartó esApto; el daño parcial lo mide el puntaje de riesgo de la rotación.
     */
    double aptitud(Zona zona, Cultivo c, Calendario cal, int mes) {
        List<MesClima> ciclo = ciclo(cal, c, mes);
        double tMedia = ciclo.stream().mapToDouble(MesClima::tMedia).average().orElse(0);
        double fuera = Math.max(0, Math.max(c.tOptMin() - tMedia, tMedia - c.tOptMax()));
        double temperatura = Math.max(0, 1 - fuera / Math.max(1, reglas.toleranciaTempC()));
        double necesidad = c.lluviaOptMin() * c.cicloMeses() / 12.0;
        double lluvia = zona.riego() || necesidad <= 0 ? 1
                : Math.min(1, ciclo.stream().mapToDouble(MesClima::lluviaMm).sum() / necesidad);
        return 0.5 * temperatura + 0.3 * lluvia + 0.2 * c.valorMercado();
    }

    @Override
    public List<String> inicialesPara(Zona zona, Calendario cal, List<Cultivo> catalogo) {
        int mes = mesSiembra(zona, cal);
        List<Cultivo> aptos = catalogo.stream()
                .filter(c -> !c.esDescanso() && esApto(zona, c, cal, mes))
                .sorted(Comparator.comparing(Cultivo::id)).toList();
        return iniciales(zona, aptos, cal, mes);
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

    private Rotacion construir(List<Cultivo> seq, boolean comun, Calendario cal, int mes, boolean coordenada) {
        double agua = seq.stream().mapToDouble(c -> puntajeAgua(c, cal, mes)).average().orElse(0);
        double ingresos = coordenada ? INGRESOS_NEUTROS
                : seq.stream().mapToDouble(Cultivo::valorMercado).average().orElse(0);
        double riesgo = 1 - seq.stream().mapToDouble(c -> dano(c, cal, mes)).average().orElse(0);

        long familias = seq.stream().filter(c -> !c.esDescanso()).map(Cultivo::familia).distinct().count();
        Cultivo ultimo = seq.get(seq.size() - 1);
        double suelo = 0.3
                + (seq.stream().anyMatch(Cultivo::fijaNitrogeno) ? 0.3 : 0)
                + (familias >= 3 ? 0.2 : 0)
                + (ultimo.cobertura() || "Poaceae".equals(ultimo.familia()) ? 0.2 : 0);

        Puntajes p = Puntajes.de(agua, suelo, ingresos, riesgo);
        List<String> ids = seq.stream().map(Cultivo::id).toList();
        String id = (comun ? "comun-" : "") + String.join("-", ids);
        return new Rotacion(id, ids.get(0), ids, p, confianza(cal, coordenada), "",
                validar(p, seq.get(1), "es"), comun);
    }

    private double puntajeAgua(Cultivo c, Calendario cal, int mes) {
        if (c.esDescanso()) return 1.0;
        double base = switch (c.agua()) { case baja -> 1.0; case media -> 0.7; case alta -> 0.4; };
        return Math.max(0, base - 0.1 * mesesSecos(c, cal, mes));
    }

    /** Daño esperado 0..1: promedio de helada y sequía dentro del ciclo. */
    private double dano(Cultivo c, Calendario cal, int mes) {
        if (c.esDescanso()) return 0;
        double maxHelada = ciclo(cal, c, mes).stream().mapToDouble(MesClima::probHelada).max().orElse(0);
        double helada = maxHelada * factor(c.toleraHelada(), 1.0, 0.5, 0.2);
        double sequia = (double) mesesSecos(c, cal, mes) / c.cicloMeses() * factor(c.agua(), 0.3, 0.6, 1.0);
        return (helada + sequia) / 2;
    }

    private static double factor(Nivel n, double baja, double media, double alta) {
        return switch (n) { case baja -> baja; case media -> media; case alta -> alta; };
    }

    private long mesesSecos(Cultivo c, Calendario cal, int mes) {
        return ciclo(cal, c, mes).stream().filter(m -> m.balanceHidricoMm() < reglas.balanceMesSecoMm()).count();
    }

    private static List<MesClima> ciclo(Calendario cal, Cultivo c, int mes) {
        int meses = Math.min(c.cicloMeses(), 12);
        return IntStream.range(0, meses).mapToObj(i -> cal.mes(mes + i)).toList();
    }

    /** SPECS_v2 §4.3 paso 6. Coordenadas: nunca "alta" (no validadas localmente). */
    private Confianza confianza(Calendario cal, boolean coordenada) {
        if (coordenada) {
            return new Confianza(NivelConfianza.media, NivelConfianza.media,
                    NivelConfianza.baja, NivelConfianza.sin_datos);
        }
        boolean anios = cal.anios() != null && cal.anios() >= reglas.aniosClimaAlta();
        return new Confianza(anios ? NivelConfianza.alta : NivelConfianza.media,
                NivelConfianza.alta, NivelConfianza.media, NivelConfianza.sin_datos);
    }

    /** Texto según el factor más débil (empate: agua, suelo, ingresos, riesgo). idioma: es | en. */
    public static String validar(Puntajes p, Cultivo segundo, String idioma) {
        String nombre = segundo.nombre();
        boolean en = "en".equals(idioma);
        double min = Math.min(Math.min(p.agua(), p.suelo()), Math.min(p.ingresos(), p.riesgo()));
        if (p.agua() == min) return en
                ? "Check there is enough water (rain or irrigation) for " + nombre + "."
                : "Confirma si hay agua suficiente (lluvia o riego) para " + nombre + ".";
        if (p.suelo() == min) return en
                ? "Ask an agronomist about your plot's soil before planting " + nombre + "."
                : "Consulta a un agronomo sobre el suelo de tu parcela antes de sembrar " + nombre + ".";
        if (p.ingresos() == min) return en
                ? "Check that seed and buyers for " + nombre + " exist in your area."
                : "Confirma si hay semilla y compradores de " + nombre + " en tu zona.";
        return en
                ? "Ask your neighbors about frost and drought in the " + nombre + " months."
                : "Pregunta a tus vecinos por heladas y sequias en los meses de " + nombre + ".";
    }

    private static boolean esCoordenada(Zona zona) { return REGION_COORDENADA.equals(zona.region()); }
}
