# Muyuy terrain for Flutter

Place `index.html` and `three.module.js` next to each other in the WebView assets and include the Three.js license in the app distribution. The script is bundled as a classic script so it can load from a local HTML asset without an ES module request or CDN. Enable JavaScript, open `index.html`, and call the global API after the page finishes loading:

```js
window.muyuy.cargarZona({
  zona: { id: "huanuco-sierra", elevacion_m: 3200 },
  calendario: [
    { mes: 6, prob_helada: 0.56, balance_hidrico_mm: -38, estres_calor: 0 }
  ]
});
window.muyuy.setMes(6);
window.muyuy.setCapa("helada");
```

Use month numbers 1–12 and layers `normal`, `helada` or `agua`. Open `index.html?demo=1` for the sample calendar and standalone controls. The relief is procedural and the sample values are illustrative.
