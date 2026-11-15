/**
 * Paisaje sonoro andino generado en el navegador con Web Audio: viento, el río
 * de la isla, un bordón grave y notas sueltas de "quena" en pentatónica menor.
 * No descarga ningún archivo (0 KB) y no tiene licencias de terceros.
 *
 * Solo arranca tras un clic del visitante (los navegadores bloquean el audio
 * automático). `setRiver(0..1)` sube el río cuando la cámara entra a los campos.
 */
const PENTATONIC = [440, 523.25, 587.33, 659.25, 783.99, 880]; // La menor pentatónica
const VOLUME = 0.55;

export function createAmbient() {
  const AudioContextClass = window.AudioContext || window.webkitAudioContext;
  if (!AudioContextClass) return null;
  const ctx = new AudioContextClass();
  const master = ctx.createGain();
  master.gain.value = 0;
  master.connect(ctx.destination);

  // Ruido blanco en bucle: base del viento y del agua.
  const noiseBuffer = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate);
  const samples = noiseBuffer.getChannelData(0);
  for (let i = 0; i < samples.length; i++) samples[i] = Math.random() * 2 - 1;
  const noise = () => {
    const source = ctx.createBufferSource();
    source.buffer = noiseBuffer;
    source.loop = true;
    source.start();
    return source;
  };
  const lfo = (frequency, depth, target) => {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.frequency.value = frequency;
    gain.gain.value = depth;
    osc.connect(gain).connect(target);
    osc.start();
  };

  // Viento: ruido grave que respira lento.
  const windFilter = ctx.createBiquadFilter();
  windFilter.type = 'lowpass';
  windFilter.frequency.value = 420;
  windFilter.Q.value = 1.4;
  const windGain = ctx.createGain();
  windGain.gain.value = 0.07;
  noise().connect(windFilter).connect(windGain).connect(master);
  lfo(0.06, 260, windFilter.frequency);
  lfo(0.045, 0.035, windGain.gain);

  // Río: ruido brillante y suave.
  const riverFilter = ctx.createBiquadFilter();
  riverFilter.type = 'bandpass';
  riverFilter.frequency.value = 1500;
  riverFilter.Q.value = 0.6;
  const riverGain = ctx.createGain();
  riverGain.gain.value = 0.012;
  noise().connect(riverFilter).connect(riverGain).connect(master);
  lfo(0.3, 300, riverFilter.frequency);

  // Bordón: La y Mi graves, casi imperceptibles.
  for (const [frequency, level] of [[110, 0.018], [164.81, 0.01]]) {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.frequency.value = frequency;
    gain.gain.value = level;
    osc.connect(gain).connect(master);
    osc.start();
    lfo(0.08 + Math.random() * 0.05, level * 0.5, gain.gain);
  }

  // Eco para las notas de quena.
  const delay = ctx.createDelay(2);
  delay.delayTime.value = 0.42;
  const feedback = ctx.createGain();
  feedback.gain.value = 0.38;
  const echoFilter = ctx.createBiquadFilter();
  echoFilter.type = 'lowpass';
  echoFilter.frequency.value = 1800;
  delay.connect(echoFilter).connect(feedback).connect(delay);
  echoFilter.connect(master);

  const quena = (frequency, start, length) => {
    const osc = ctx.createOscillator();
    const breath = ctx.createOscillator();
    const breathGain = ctx.createGain();
    const gain = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.value = frequency;
    breath.type = 'triangle';
    breath.frequency.value = frequency * 2;
    breathGain.gain.value = 0.18;
    // Vibrato que entra tarde, como un soplo humano.
    const vibrato = ctx.createOscillator();
    const vibratoDepth = ctx.createGain();
    vibrato.frequency.value = 5.2;
    vibratoDepth.gain.setValueAtTime(0, start);
    vibratoDepth.gain.linearRampToValueAtTime(frequency * 0.006, start + length * 0.5);
    vibrato.connect(vibratoDepth).connect(osc.frequency);
    gain.gain.setValueAtTime(0, start);
    gain.gain.linearRampToValueAtTime(0.03, start + 0.25);
    gain.gain.setTargetAtTime(0, start + length, 0.45);
    osc.connect(gain);
    breath.connect(breathGain).connect(gain);
    gain.connect(master);
    gain.connect(delay);
    const end = start + length + 3;
    for (const node of [osc, breath, vibrato]) { node.start(start); node.stop(end); }
  };

  let timer = null;
  const phrase = () => {
    const now = ctx.currentTime + 0.1;
    let index = Math.floor(Math.random() * PENTATONIC.length);
    const notes = 1 + Math.floor(Math.random() * 3);
    let at = now;
    for (let n = 0; n < notes; n++) {
      const length = 0.7 + Math.random() * 1.1;
      quena(PENTATONIC[index], at, length);
      at += length + 0.15;
      index = Math.max(0, Math.min(PENTATONIC.length - 1, index + (Math.random() < 0.5 ? -1 : 1)));
    }
    timer = setTimeout(phrase, 5000 + Math.random() * 6000);
  };

  return {
    async play() {
      await ctx.resume();
      master.gain.cancelScheduledValues(ctx.currentTime);
      master.gain.setTargetAtTime(VOLUME, ctx.currentTime, 0.8);
      clearTimeout(timer);
      timer = setTimeout(phrase, 1800);
    },
    pause() {
      clearTimeout(timer);
      master.gain.cancelScheduledValues(ctx.currentTime);
      master.gain.setTargetAtTime(0, ctx.currentTime, 0.25);
      setTimeout(() => { if (master.gain.value < 0.01) ctx.suspend(); }, 1200);
    },
    setRiver(level) {
      riverGain.gain.setTargetAtTime(0.012 + level * 0.03, ctx.currentTime, 1.2);
    },
    close() { clearTimeout(timer); ctx.close(); },
  };
}
