"""
Evalúa modelos de Groq para las explicaciones de Muyuy con el MISMO prompt que ExplicadorGroq.java
y los paquetes reales (API en producción). Uso:

    GROQ_API_KEY=... python scripts/eval_groq.py [--reps 2] [--api https://muyuy-bk.rdev7.net.pe]

Métricas automáticas por modelo:
  ok_json     respuesta JSON válida con 'explicaciones'
  cobertura   % de ids devueltos exactamente (ni faltan ni sobran)
  fiel        % de textos que nombran un cultivo de SU rotación y ninguno ajeno (no alucina cultivos)
  sin_cifras  % de textos sin cifras técnicas (puntajes, decimales, %); los meses del dato sí valen
  helada      % de textos que mencionan helada/frío en zonas con meses de helada (usa el clima)
  practica    % de prácticas comunes cuyo texto explica una desventaja
  palabras    promedio de palabras por texto (objetivo 2 frases cortas ≈ 20-45)
  latencia, tokens de entrada/salida (incluye razonamiento) y costo estimado.
Juez: dos modelos distintos califican a ciegas 1-5 exactitud agronómica, fidelidad a los datos y claridad.
"""
import argparse, json, os, re, statistics, sys, time, unicodedata, urllib.request, urllib.error

sys.stdout.reconfigure(encoding="utf-8")
URL = "https://api.groq.com/openai/v1/chat/completions"
KEY = os.environ.get("GROQ_API_KEY", "").strip()
ZONAS = ["huanuco-sierra", "huanuco-valle", "huanuco-selva", "global-demo"]

# USD por 1M tokens (entrada, salida). Aproximados; ver groq.com/pricing.
PRECIOS = {"openai/gpt-oss-120b": (0.15, 0.60), "openai/gpt-oss-20b": (0.075, 0.30), "qwen/qwen3.8-27b": (0.80, 4.00)}   # preview: puede retirarse sin aviso

CANDIDATOS = [
    ("gpt-oss-120b · low", "openai/gpt-oss-120b", {"reasoning_effort": "low"}),
    ("gpt-oss-120b · medium", "openai/gpt-oss-120b", {"reasoning_effort": "medium"}),
    ("gpt-oss-20b · low", "openai/gpt-oss-20b", {"reasoning_effort": "low"}),
    ("gpt-oss-20b · medium", "openai/gpt-oss-20b", {"reasoning_effort": "medium"}),
    ("qwen3.8-27b · default", "qwen/qwen3.8-27b", {"reasoning_format": "hidden"}),
    ("qwen3.8-27b · none", "qwen/qwen3.8-27b", {"reasoning_effort": "none"}),
]
JUECES = ["openai/gpt-oss-120b", "qwen/qwen3.8-27b"]


def norm(s):
    return "".join(c for c in unicodedata.normalize("NFD", s.lower()) if unicodedata.category(c) != "Mn")


def http(url, body=None, timeout=120):
    req = urllib.request.Request(url, data=json.dumps(body).encode() if body else None,
                                 headers={"Authorization": f"Bearer {KEY}", "Content-Type": "application/json",
                                          "User-Agent": "muyuy-eval"})
    if url.startswith("file:"): req = urllib.request.Request(url)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))


def chat(modelo, extra, sistema, usuario, max_tokens):
    body = {"model": modelo, "temperature": 0.2, "max_tokens": max_tokens,
            "response_format": {"type": "json_object"},
            "messages": [{"role": "system", "content": sistema}, {"role": "user", "content": usuario}], **extra}
    for intento in range(6):
        t0 = time.time()
        try:
            d = http(URL, body)
            return d, time.time() - t0, None
        except urllib.error.HTTPError as e:
            msg = e.read().decode("utf-8", "replace")[:300]
            if e.code == 429:
                time.sleep(min(60, 8 * (intento + 1))); continue
            return None, time.time() - t0, f"{e.code} {msg}"
        except Exception as e:
            return None, time.time() - t0, str(e)
    return None, 0, "429 persistente"


# ---- prompt idéntico a ExplicadorGroq.java ----
def sistema():
    return ("Eres un extensionista agrícola que explica rotaciones de cultivo a pequeños agricultores. "
            "Escribe en español sencillo, sin tecnicismos. Para CADA rotación escribe 2 frases cortas: por qué ese orden de cultivos "
            "ayuda (suelo, agua, plagas, ingresos) y qué cuidado tener según el clima dado. "
            "Usa SOLO los datos que recibes; no inventes cifras, precios ni variedades. No cambies la recomendación. "
            "Responde únicamente un JSON con la forma {\"explicaciones\": {\"<id>\": \"<texto>\"}} "
            "con una entrada por cada id recibido.")


def fmt(x):
    return repr(float(x))  # Java imprime 0.7 / 1.0


def datos(n):
    cal, zona, cult = n["calendario"], n["zona"], {c["id"]: c for c in n["cultivos"]}
    hel = ",".join(str(m["mes"]) for m in cal if m["prob_helada"] >= 0.3)
    sec = ",".join(str(m["mes"]) for m in cal if m["balance_hidrico_mm"] < 0)
    lluvia = round(sum(m["lluvia_mm"] for m in cal))

    def desc(cid):
        c = cult.get(cid)
        if not c: return cid
        return c["nombre"] + " (" + c["familia"] + (", fija nitrógeno" if c["fija_nitrogeno"] else "") + (", cubre el suelo" if c["cobertura"] else "") + ")"

    s = (f"Zona: {zona['nombre']} ({zona['elevacion_m']} m). Lluvia anual: {lluvia} mm. "
         f"Meses con riesgo de helada: {hel or 'ninguno'}. Meses secos: {sec or 'ninguno'}. "
         "Siembra en el mes 10. Puntajes de 0 a 1 (riesgo: 1 = seguro).\n\nRotaciones:\n")
    for r in n["rotaciones"]:
        p = r["puntajes"]
        s += (f"- id: {r['id']} | {' -> '.join(desc(c) for c in r['secuencia'])} | agua {fmt(p['agua'])}, suelo {fmt(p['suelo'])}, "
              f"ingresos {fmt(p['ingresos'])}, riesgo {fmt(p['riesgo'])}")
        if r["es_practica_comun"]: s += " | es la práctica actual de la zona (explica su desventaja)"
        s += "\n"
    return s, bool(hel)


# ---- métricas ----
def claves_cultivo(c):
    n = norm(c["nombre"])
    toks = [t for t in re.split(r"[^a-z]+", n) if len(t) >= 4]
    return set(toks[:1]) | {n}


def evaluar(n, texto_json, hay_helada, catalogo):
    rot = n["rotaciones"]
    m = {"ok_json": 0, "cobertura": 0.0, "fiel": 0.0, "sin_cifras": 0.0, "helada": None, "practica": None, "palabras": 0.0}
    try:
        ex = json.loads(texto_json)["explicaciones"]
        assert isinstance(ex, dict)
    except Exception:
        return m, {}
    m["ok_json"] = 1
    ids = [r["id"] for r in rot]
    m["cobertura"] = sum(1 for i in ids if isinstance(ex.get(i), str) and ex[i].strip()) / len(ids) * (1 if set(ex) <= set(ids) else 0.9)
    fieles, cifras, hel, prac, pal = [], [], [], [], []
    for r in rot:
        t = ex.get(r["id"])
        if not isinstance(t, str) or not t.strip():
            fieles.append(0); cifras.append(0); continue
        nt = norm(t)
        propios = {c for c in r["secuencia"] if c != "descanso"}
        kp = set().union(*[claves_cultivo(catalogo[c]) for c in propios if c in catalogo]) if propios else set()
        nombra_propio = any(k in nt for k in kp) or not propios
        # 'maíz' de maiz_amilaceo no cuenta como maiz_duro: se ignoran las claves compartidas con la rotación
        ajenos = [c for c, v in catalogo.items() if c not in r["secuencia"] and c != "descanso"
                  and any(re.search(r"\b" + re.escape(k) + r"\b", nt) for k in claves_cultivo(v) - kp)]
        fieles.append(1 if nombra_propio and not ajenos else 0)
        cifras.append(0 if re.search(r"\d[.,]\d|%|\b0[.,]|puntaje", t) else 1)   # meses del dato sí valen
        if hay_helada: hel.append(1 if re.search(r"helad|frio|escarcha", nt) else 0)
        if r["es_practica_comun"]: prac.append(1 if re.search(r"desventaj|agota|cansa|empobrec|plaga|enfermedad|pierde|menos|bajo|riesgo|repetir|mismo", nt) else 0)
        pal.append(len(t.split()))
    m["fiel"] = statistics.mean(fieles)
    m["sin_cifras"] = statistics.mean(cifras)
    m["helada"] = statistics.mean(hel) if hel else None
    m["practica"] = statistics.mean(prac) if prac else None
    m["palabras"] = statistics.mean(pal) if pal else 0
    return m, ex


JUEZ_SIS = ("Eres un agrónomo experto en agricultura andina y evaluador estricto. Recibes los DATOS que se dieron a un asistente "
            "y sus EXPLICACIONES para pequeños agricultores. Califica de 1 a 5 (5 = excelente): "
            "exactitud (lo agronómico es correcto: leguminosas fijan nitrógeno, no repetir familia, cuidado con heladas/sequía según los meses dados), "
            "fidelidad (no contradice ni inventa datos, cifras, precios o variedades; respeta la recomendación), "
            "claridad (frases cortas y útiles para un agricultor sin estudios técnicos). "
            "Responde solo JSON {\"exactitud\":n,\"fidelidad\":n,\"claridad\":n,\"comentario\":\"<1 frase>\"}.")


def juzgar(juez, datos_txt, ex):
    u = "DATOS:\n" + datos_txt + "\nEXPLICACIONES:\n" + json.dumps(ex, ensure_ascii=False, indent=0)
    extra = {"reasoning_effort": "low"} if "gpt-oss" in juez else {}
    d, _, err = chat(juez, extra, JUEZ_SIS, u, 1500)
    if not d: return None
    try:
        j = json.loads(d["choices"][0]["message"]["content"])
        return {k: float(j[k]) for k in ("exactitud", "fidelidad", "claridad")} | {"comentario": j.get("comentario", "")}
    except Exception:
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reps", type=int, default=2)
    ap.add_argument("--api", default="https://muyuy-bk.rdev7.net.pe")
    ap.add_argument("--out", default="scripts/eval_groq_resultados.json")
    a = ap.parse_args()
    if not KEY: sys.exit("Falta GROQ_API_KEY")

    paquetes = {z: http(f"{a.api}/api/paquete/{z}")["paquete"]["nucleo"] for z in ZONAS}
    catalogo = {c["id"]: c for z in paquetes.values() for c in z["cultivos"]}
    with open("data/cultivos.json", encoding="utf-8") as f:
        for c in json.load(f): catalogo.setdefault(c["id"], c)

    resultados = {}
    for etiqueta, modelo, extra in CANDIDATOS:
        filas, muestras = [], {}
        for rep in range(a.reps):
            for z, n in paquetes.items():
                txt, hay_hel = datos(n)
                d, lat, err = chat(modelo, extra, sistema(), txt, 150 * len(n["rotaciones"]) + 200)
                if not d:
                    print(f"  {etiqueta} {z} rep{rep}: ERROR {err}")
                    filas.append({"ok_json": 0, "cobertura": 0, "fiel": 0, "sin_cifras": 0, "palabras": 0, "lat": lat,
                                  "tin": 0, "tout": 0, "error": err}); continue
                u = d.get("usage", {})
                cont = d["choices"][0]["message"].get("content") or ""
                m, ex = evaluar(n, cont, hay_hel, catalogo)
                m |= {"lat": lat, "tin": u.get("prompt_tokens", 0), "tout": u.get("completion_tokens", 0),
                      "fin": d["choices"][0].get("finish_reason")}
                if rep == 0 and ex:
                    muestras[z] = ex
                    for juez in JUECES:
                        j = juzgar(juez, txt, ex)
                        if j: m.setdefault("jueces", {})[juez] = j
                filas.append(m)
                print(f"  {etiqueta:22} {z:15} rep{rep} json={m['ok_json']} cob={m['cobertura']:.2f} fiel={m['fiel']:.2f} "
                      f"lat={lat:.1f}s out={m['tout']} fin={m.get('fin')}", flush=True)
                time.sleep(2)
        resultados[etiqueta] = {"modelo": modelo, "filas": filas, "muestras": muestras}

    with open(a.out, "w", encoding="utf-8") as f:
        json.dump(resultados, f, ensure_ascii=False, indent=1)

    # ---- resumen ----
    def prom(fs, k):
        v = [f[k] for f in fs if f.get(k) is not None]
        return statistics.mean(v) if v else float("nan")

    print("\n| Modelo | JSON ok | Cobertura | Fiel | Sin cifras | Helada | Práctica | Palabras | Juez exact. | Juez fidel. | Juez clar. | Latencia | Tokens salida/llamada | USD por 1000 regeneraciones (4 zonas) |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for et, r in resultados.items():
        fs = r["filas"]; pin, pout = PRECIOS.get(r["modelo"], (0, 0))
        js = [j for f in fs for j in f.get("jueces", {}).values()]
        jm = lambda k: statistics.mean(j[k] for j in js) if js else float("nan")
        costo = (prom(fs, "tin") * pin + prom(fs, "tout") * pout) / 1e6 * 4 * 1000
        print(f"| {et} | {prom(fs,'ok_json'):.0%} | {prom(fs,'cobertura'):.0%} | {prom(fs,'fiel'):.0%} | {prom(fs,'sin_cifras'):.0%} | "
              f"{prom(fs,'helada'):.0%} | {prom(fs,'practica'):.0%} | {prom(fs,'palabras'):.0f} | {jm('exactitud'):.1f} | {jm('fidelidad'):.1f} | "
              f"{jm('claridad'):.1f} | {prom(fs,'lat'):.1f}s | {prom(fs,'tout'):.0f} | ${costo:.2f} |")


if __name__ == "__main__":
    main()
