import React, { Component, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { Html, OrbitControls } from '@react-three/drei';
import * as THREE from 'three';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

const MODES = ['normal', 'helada', 'agua'];
const MODE_LABELS = { normal: 'Normal', helada: 'Frost', agua: 'Water' };
const BOTTOM = -1.82;
const SIZE = 8;
const SEGMENTS = 64;
const clamp = THREE.MathUtils.clamp;

/**
 * Bioma por zona piloto. Los valores salen de la climatología real de cada
 * paquete (lluvia anual vs ET0): la selva de Tingo María recibe ~1094 mm y el
 * valle del Huallaga ~614 mm con más demanda evaporativa, por eso el valle es
 * el más árido y la selva el más verde.
 */
/** Paleta de copas por estación: verde fresco, otoño cálido, invierno frío. */
const CANOPY_PALETTE = {
  spring: new THREE.Color('#4CAF50'),
  summer: new THREE.Color('#2E7D32'),
  autumn: new THREE.Color('#E67E22'),
  autumnDeep: new THREE.Color('#D35400'),
  winter: new THREE.Color('#8FA399'),
  snow: new THREE.Color('#CFD8DC'),
};

function canopyColor(aridity, snow, target) {
  const dry = clamp((aridity - .2) / .6, 0, 1);
  const cold = clamp((snow - .2) / .55, 0, 1);
  target.copy(CANOPY_PALETTE.spring).lerp(CANOPY_PALETTE.summer, .5);
  target.lerp(CANOPY_PALETTE.autumn, dry * .55);
  target.lerp(CANOPY_PALETTE.autumnDeep, dry * .45);
  target.lerp(CANOPY_PALETTE.winter, cold * .8);
  target.lerp(CANOPY_PALETTE.snow, cold * .35);
  return target;
}
const BIOMES = {
  sierra: { low: '#8a8f6d', high: '#c6cca4', summit: '#a7a493', rock: '#7c796b', snow: .82, snowLine: .52, aridity: .40, trees: 8, trunk: '#6b5f49', canopy: '#95a97c', conifer: true },
  valle: { low: '#8a8f4c', high: '#cdd189', summit: '#8b8264', rock: '#7b735d', snow: .10, snowLine: 1.95, aridity: .62, trees: 16, trunk: '#7a6848', canopy: '#a8b962', conifer: false },
  story: { low: '#4f8c46', high: '#93c26d', summit: '#8b917a', rock: '#6f6a57', snow: .95, snowLine: .48, aridity: .20, trees: 26, trunk: '#6a563c', canopy: '#63a457', conifer: false },
  selva: { low: '#2f6b35', high: '#63a34c', summit: '#3f6b40', rock: '#5a5f4a', snow: 0, snowLine: 9, aridity: .18, trees: 40, trunk: '#5c4931', canopy: '#54a154', conifer: false },
};
const DEFAULT_BIOME = BIOMES.sierra;
const FIELD_CENTERS = [-2.45, -.9, .95];
const CHANNEL_Z = 2.88;
const RESERVOIR = [-2.71, 2.76];
const WATERFALL_EXIT_X = 1.63;
const ISLAND_WIDTH_SCALE = 1.15;
const ISLAND_EDGES = [
  (t) => [-4 + 8 * t, -4],
  (t) => [4, -4 + 8 * t],
  (t) => [4 - 8 * t, 4],
  (t) => [-4, 4 - 8 * t],
];

const BACK_FIELDS = FIELD_CENTERS.slice(0, 2);

function isFarmSoil(x, z) {
  if (z >= .94 && z <= 2.63 && FIELD_CENTERS.some((center) => Math.abs(x - center) < .57)) return true;
  return z >= -2.74 && z <= -1.12 && BACK_FIELDS.some((center) => Math.abs(x - center) < .5);
}

function hillside(x, z) {
  const ridge = 3.15 * Math.exp(-((x + .45) ** 2 / 4.6 + (z + .45) ** 2 / 3.6));
  const peak = 1.18 * Math.exp(-((x - 1.6) ** 2 / 1.9 + (z + .8) ** 2 / 2.4));
  const texture = Math.sin(x * 3.1 + z) * Math.cos(z * 2.7) * .11;
  const slope = (ridge + peak) * 6;
  const terraces = (Math.floor(slope) + THREE.MathUtils.smoothstep(slope % 1, .22, .78)) / 6;
  return .18 + terraces * .72 + (ridge + peak) * .28 + texture;
}

function elevation(x, z) {
  let height = hillside(x, z);
  for (const [homeX, homeZ, scale] of HOMES) {
    const distance = Math.hypot(x - homeX, z - homeZ);
    const level = 1 - THREE.MathUtils.smoothstep(distance, .47 * scale, .69 * scale);
    height = THREE.MathUtils.lerp(height, hillside(homeX, homeZ), level);
  }
  return height;
}

function surfaceGrain(shader) {
  shader.vertexShader = shader.vertexShader
    .replace('#include <common>', '#include <common>\nvarying vec3 vGrainPosition;\nvarying vec3 vGrainNormal;')
    .replace('#include <beginnormal_vertex>', '#include <beginnormal_vertex>\nvGrainNormal = objectNormal;')
    .replace('#include <begin_vertex>', '#include <begin_vertex>\nvGrainPosition = position;');
  shader.fragmentShader = shader.fragmentShader
    .replace('#include <common>', '#include <common>\nvarying vec3 vGrainPosition;\nvarying vec3 vGrainNormal;')
    .replace('#include <color_fragment>', `#include <color_fragment>
      vec3 p = vGrainPosition;
      float grain = sin(p.x * 167.0 + p.z * 191.0) * cos(p.y * 119.0 - p.z * 157.0);
      grain *= 1.0 - smoothstep(0.08, 0.75, length(fwidth(p)) * 160.0);
      float band = sin(p.x * 48.0 + p.y * 17.0 + sin(p.z * 31.0)) * 0.045;
      float slope = 1.0 - clamp(normalize(vGrainNormal).y, 0.0, 1.0);
      float strata = sin(p.y * 92.0 + sin(p.x * 26.0) * 0.7) * 0.016;
      diffuseColor.rgb *= 1.0 + grain * 0.13 + band + strata;
      diffuseColor.rgb *= 1.0 - slope * 0.28;
      diffuseColor.rgb = mix(diffuseColor.rgb, diffuseColor.rgb * vec3(1.08, 1.02, 0.9), slope * 0.5);
    `);
}

/**
 * Cultivos por zona: sierra papa/mashua/oca (bajos), valle maíz/choclo (medios),
 * selva plátano/yuca (altos). Cambian color, altura y fruto.
 */
const CROP_SETS = {
  sierra: { leaf: ['#6f8f4a', '#48683a', '#8a9b52'], produce: ['#c9a75f', '#b5924b', '#9a8a4e'], stalk: .82, produceScale: 1 },
  valle: { leaf: ['#9ab84f', '#6c8f3c', '#b7c25c'], produce: ['#d8b34a', '#e0c257', '#c9a13e'], stalk: 1.16, produceScale: 1.22 },
  selva: { leaf: ['#3f8f43', '#2f6f38', '#5aa74d'], produce: ['#e2c14f', '#c9a83c', '#e8d06a'], stalk: 1.3, produceScale: 1.34 },
  story: { leaf: ['#7fae55', '#5d8a41', '#a3c169'], produce: ['#cfae55', '#b8924a', '#d9c46b'], stalk: 1, produceScale: 1 },
};

function growthStage(column, month) {
  return Math.min(2, Math.floor((column + (month - 1) % 3) / 3));
}

function Crops({ mode, data, month, reduced, region }) {
  const crop = CROP_SETS[region] ?? CROP_SETS.story;
  const leaves = useRef();
  const stalks = useRef();
  const produce = useRef();
  const material = useRef();
  const climateColor = useMemo(() => new THREE.Color(), []);
  const plants = useMemo(() => {
    const entries = [];
    for (const [field, center] of FIELD_CENTERS.entries()) {
      for (let row = 0; row < 5; row++) {
        for (let column = 0; column < 10; column++) {
          const x = center + (row - 2) * .21;
          const z = 1.08 + column * .163;
          const clearOfWater = z < CHANNEL_Z - .23 && Math.hypot(x - RESERVOIR[0], z - RESERVOIR[1]) > .49;
          if (Math.hypot(x, z) < 3.67 && clearOfWater && (field !== 2 || (row + column * 3) % 5 === 0)) entries.push({ x, z, field, column });
        }
      }
    }
    for (const [field, center] of BACK_FIELDS.entries()) {
      for (let row = 0; row < 4; row++) {
        for (let column = 0; column < 7; column++) {
          const x = center + (row - 1.5) * .22;
          const z = -2.52 + column * .19;
          if (Math.hypot(x, z) < 3.2) entries.push({ x, z, field: field === 0 ? 1 : 0, column, back: true });
        }
      }
    }
    return entries;
  }, []);
  useLayoutEffect(() => {
    const marker = new THREE.Object3D();
    const color = new THREE.Color();
    plants.forEach(({ x, z, field, column }, index) => {
      const stage = growthStage(column, month);
      const stageSize = [.38, .76, 1][stage];
      const height = ((field === 1 ? .32 : field === 2 ? .06 : .14) + (index % 5) * .014) * stageSize * crop.stalk;
      const vigor = (.81 + .23 * Math.sin(index * 2.41) ** 2) * stageSize;
      const y = elevation(x, z);
      marker.position.set(x, y + height * .5, z);
      marker.scale.set(.012, height, .012);
      marker.rotation.set(0, 0, 0);
      marker.updateMatrix();
      stalks.current.setMatrixAt(index, marker.matrix);
      for (let leaf = 0; leaf < 5; leaf++) {
        const angle = index * 2.4 + leaf * 2.399;
        const spread = (field === 1 ? .052 : .046) * stageSize;
        marker.position.set(x + Math.cos(angle) * spread, y + height * (.43 + leaf * .12), z - Math.sin(angle) * spread);
        marker.rotation.set(0, angle, .22 + leaf * .14, 'YXZ');
        marker.scale.set((field === 1 ? .084 : .098) * vigor, .013, (field === 1 ? .037 : .052) * vigor);
        marker.updateMatrix();
        const leafIndex = index * 5 + leaf;
        leaves.current.setMatrixAt(leafIndex, marker.matrix);
        leaves.current.setColorAt(leafIndex, color.set(crop.leaf[stage]).multiplyScalar(.85 + ((index + leaf) % 3) * .13));
      }
    });
    stalks.current.instanceMatrix.needsUpdate = true;
    leaves.current.instanceMatrix.needsUpdate = true;
    leaves.current.instanceColor.needsUpdate = true;
  }, [plants, month, crop]);
  const growing = useMemo(() => plants.filter(({ field }, index) => field !== 2 && index % 2 === 0), [plants]);
  useLayoutEffect(() => {
    const marker = new THREE.Object3D();
    const colors = new THREE.Color();
    growing.forEach(({ x, z, field, column }, index) => {
      const stage = growthStage(column, month);
      const bean = field === 1;
      const side = index % 2 ? -1 : 1;
      const patchX = x + side * (bean ? .062 : .071);
      marker.position.set(patchX, bean ? elevation(x, z) + (stage === 2 ? .22 : .145) + index % 3 * .018 : elevation(patchX, z + .032) + .015, z + .032);
      marker.rotation.set(.22, index * 1.2, side * .33);
      const maturity = stage === 2 ? 1.25 : stage === 1 && bean ? .55 : 0;
      marker.scale.set(...(bean ? [.016, .055, .017] : [.035, .024, .028])).multiplyScalar(maturity * crop.produceScale);
      marker.updateMatrix();
      produce.current.setMatrixAt(index, marker.matrix);
      produce.current.setColorAt(index, colors.set(bean && stage < 2 ? crop.leaf[2] : crop.produce[stage]));
    });
    produce.current.instanceMatrix.needsUpdate = true;
    produce.current.instanceColor.needsUpdate = true;
  }, [growing, month]);
  useFrame((_, delta) => {
    const season = month >= 6 && month <= 8 ? '#dce5ca' : month >= 3 && month <= 5 ? '#f0e7bf' : '#ffffff';
    climateColor.set(mode === 'helada' ? '#9ecaff' : mode === 'agua' && data?.balance_hidrico_mm < 0 ? '#cf863a' : season);
    material.current.color.lerp(climateColor, reduced ? 1 : 1 - Math.exp(-delta * 3.2));
  });
  return <>
    <instancedMesh ref={stalks} args={[undefined, undefined, plants.length]} castShadow frustumCulled={false}>
      <cylinderGeometry args={[.55, 1, 1, 5]} /><meshStandardMaterial color="#778b4b" />
    </instancedMesh>
    <instancedMesh ref={leaves} args={[undefined, undefined, plants.length * 5]} castShadow frustumCulled={false}>
      <sphereGeometry args={[1, 7, 4]} /><meshStandardMaterial ref={material} roughness={.8} />
    </instancedMesh>
    <instancedMesh ref={produce} args={[undefined, undefined, growing.length]} frustumCulled={false}>
      <icosahedronGeometry args={[1, 1]} /><meshStandardMaterial roughness={.84} />
    </instancedMesh>
  </>;
}

function islandPoint(x, z) {
  const angle = Math.atan2(z, x);
  const edge = ISLAND_WIDTH_SCALE * (1 + Math.sin(angle * 5 + .7) * .06 + Math.cos(angle * 3) * .045);
  return [x * Math.sqrt(1 - z * z / 32) * edge, z * Math.sqrt(1 - x * x / 32) * edge];
}

function WaterRibbon({ curve, width, fallStart = 1, bankHeight, dry = false, reduced }) {
  const falling = fallStart < 1;
  const gleam = useRef();
  const water = useMemo(() => ({
    time: { value: 0 }, strength: { value: 1 },
    fallStart: { value: fallStart }, spring: { value: falling ? 0 : 1 }, reservoir: { value: 0 },
  }), [fallStart, falling]);
  const geometry = useMemo(() => {
    const vertices = [];
    const uv = [];
    const indices = [];
    for (let i = 0; i <= 72; i++) {
      const t = i / 72;
      const point = curve.getPointAt(t);
      const tangent = curve.getTangentAt(t);
      const drop = falling ? THREE.MathUtils.smoothstep(t, fallStart - .045, fallStart + .055) : 0;
      const side = new THREE.Vector3(tangent.z, 0, -tangent.x).normalize();
      if (falling) side.lerp(new THREE.Vector3(1, 0, 0), drop).normalize();
      const sourceWidth = falling ? 1 : THREE.MathUtils.lerp(.28, 1, THREE.MathUtils.smoothstep(t, 0, .2));
      const halfWidth = width * (.5 + Math.sin(t * 22) * .045 + drop * (.18 + .33 * t)) * sourceWidth;
      const groundContact = !falling || t <= fallStart;
      const groundLift = groundContact ? Math.max(.018, point.y - bankHeight(point.x, point.z)) : 0;
      for (let across = 0; across <= 4; across++) {
        const u = across / 4;
        const vertex = point.clone().addScaledVector(side, halfWidth * (2 * u - 1));
        if (groundContact) vertex.y = bankHeight(vertex.x, vertex.z) + groundLift + Math.sin(u * Math.PI) * .008;
        vertices.push(...vertex.toArray());
        uv.push(u, t);
        if (i < 72 && across < 4) {
          const j = i * 5 + across;
          indices.push(j, j + 5, j + 1, j + 1, j + 5, j + 6);
        }
      }
    }
    if (falling) {
      const offset = vertices.length / 3;
      const start = Math.min(.99, fallStart + .025);
      for (let i = 0; i <= 32; i++) {
        const t = THREE.MathUtils.lerp(start, 1, i / 32);
        const point = curve.getPointAt(t);
        const depth = width * .53 * THREE.MathUtils.smoothstep(i, 0, 7);
        vertices.push(point.x, point.y, point.z - depth, point.x, point.y, point.z + depth);
        uv.push(0, t, 1, t);
        const j = offset + i * 2;
        if (i < 32) indices.push(j, j + 2, j + 1, j + 1, j + 2, j + 3);
      }
    }
    const ribbon = new THREE.BufferGeometry();
    ribbon.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
    ribbon.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
    ribbon.setIndex(indices);
    ribbon.computeVertexNormals();
    return ribbon;
  }, [curve, width, falling, fallStart, bankHeight]);
  const particles = useMemo(() => new Float32Array(48 * 3), []);
  const sample = useMemo(() => new THREE.Vector3(), []);
  useEffect(() => () => geometry.dispose(), [geometry]);
  useFrame(({ clock }, delta) => {
    const time = reduced ? 0 : clock.elapsedTime;
    water.time.value = time;
    water.strength.value = THREE.MathUtils.damp(water.strength.value, dry ? .76 : 1, 3, Math.min(delta, .05));
    const attribute = gleam.current.geometry.attributes.position;
    for (let i = 0; i < attribute.count; i++) {
      const t = (time * (falling ? .5 : .17) + (i * .618) % 1) % 1;
      curve.getPointAt(t, sample);
      const drop = falling ? THREE.MathUtils.smoothstep(t, fallStart, 1) : 0;
      attribute.setXYZ(i, sample.x + Math.sin(i * 12) * width * .44 * (1 + drop * .7), sample.y + .019, sample.z + drop * .15);
    }
    attribute.needsUpdate = true;
  });
  return <>
    <mesh geometry={geometry}><WaterMaterial uniforms={water} /></mesh>
    <points ref={gleam} frustumCulled={false}>
      <bufferGeometry><bufferAttribute attach="attributes-position" args={[particles, 3]} /></bufferGeometry>
      <pointsMaterial color="#def7f2" size={falling ? .035 : .022} opacity={falling ? .78 : .55} transparent depthWrite={false} />
    </points>
    {falling && <group position={curve.getPointAt(1).toArray()}>
      {[-1, 0, 1].map((side) => <mesh key={side} position={[side * .12, -.07, Math.abs(side) * .07]} scale={[1.45, .43, 1]}>
        <icosahedronGeometry args={[.16, 1]} /><meshBasicMaterial color="#c1e4df" transparent opacity={.14} depthWrite={false} />
      </mesh>)}
    </group>}
  </>;
}

function WaterMaterial({ uniforms, opaque = false }) {
  return <shaderMaterial uniforms={uniforms} side={THREE.DoubleSide} transparent={!opaque} depthWrite={opaque}
        vertexShader={`
          varying vec2 vUv;
          varying vec3 vNormal;
          varying vec3 vView;
          void main() {
            vUv = uv;
            vec4 viewPosition = modelViewMatrix * vec4(position, 1.0);
            vNormal = normalMatrix * normal;
            vView = -viewPosition.xyz;
            gl_Position = projectionMatrix * viewPosition;
          }
        `}
        fragmentShader={`
          varying vec2 vUv;
          varying vec3 vNormal;
          varying vec3 vView;
          uniform float time;
          uniform float strength;
          uniform float fallStart;
          uniform float spring;
          uniform float reservoir;
          void main() {
            vec2 inlet = vUv - vec2(0.16, 0.73);
            float basinRadius = length(vUv - 0.5) * 2.0;
            float travel = mix(vUv.y, length(inlet) * 0.64 + vUv.x * 0.07, reservoir);
            float lane = vUv.x + 0.028 * sin(travel * 24.0 - time * 5.0);
            float streak = pow(0.5 + 0.5 * sin(lane * 60.0), 3.0);
            float flow = 0.5 + 0.5 * sin(vUv.y * 46.0 - time * 12.0 + lane * 18.0);
            float foam = clamp(streak * (0.38 + flow * 0.62) + smoothstep(0.79, 1.0, vUv.y) * 0.48, 0.0, 1.0);
            float drop = (1.0 - spring) * smoothstep(fallStart - 0.035, fallStart + 0.08, vUv.y);
            float ripples = pow(0.5 + 0.5 * sin(travel * 132.0 - time * mix(9.0, 4.0, reservoir) + sin(lane * 8.0) * 2.4), 5.0);
            float shallows = pow(clamp(mix(abs(vUv.x * 2.0 - 1.0), basinRadius, reservoir), 0.0, 1.0), 2.0);
            vec3 river = mix(vec3(0.055, 0.27, 0.31), vec3(0.24, 0.49, 0.44), shallows * 0.8);
            river += vec3(0.42, 0.60, 0.58) * ripples * (0.16 + streak * 0.2);
            vec3 color = mix(river, mix(vec3(0.23, 0.59, 0.67), vec3(0.87, 0.98, 0.97), foam), drop);
            vec3 viewDirection = normalize(vView);
            vec3 normal = normalize(vNormal) * (gl_FrontFacing ? 1.0 : -1.0);
            vec3 sunDirection = normalize(mat3(viewMatrix) * vec3(-6.0, 8.0, 4.0));
            vec3 halfVector = normalize(sunDirection + viewDirection);
            float ripple = sin(travel * 89.0 - time * 8.0 + lane * 14.0) * 0.045;
            float glint = pow(clamp(dot(normal, halfVector) + ripple, 0.0, 1.0), 28.0);
            float fresnel = pow(1.0 - clamp(dot(normal, viewDirection), 0.0, 1.0), 4.0);
            color += vec3(0.88, 0.96, 1.0) * (glint * 0.7 + fresnel * 0.24 + streak * flow * 0.12);
            float edge = smoothstep(0.0, 0.1, vUv.x) * smoothstep(0.0, 0.1, 1.0 - vUv.x);
            float mist = 1.0 - (1.0 - spring) * smoothstep(0.83, 1.0, vUv.y);
            float emergence = mix(1.0, smoothstep(0.0, 0.06, vUv.y), spring);
            gl_FragColor = vec4(color, mix(edge * mist * emergence * strength * mix(0.97, 0.63 + foam * 0.33, drop), 1.0, reservoir));
          }
        `} />;
}

function ReservoirWater({ reduced }) {
  const uniforms = useMemo(() => ({
    time: { value: 0 }, strength: { value: 1 },
    fallStart: { value: 1 }, spring: { value: 1 }, reservoir: { value: 1 },
  }), []);
  useFrame(({ clock }) => { uniforms.time.value = reduced ? 0 : clock.elapsedTime; });
  return <mesh position={[0, .151, 0]} rotation={[-Math.PI / 2, 0, 0]}>
    <circleGeometry args={[.257, 24]} />
    <WaterMaterial uniforms={uniforms} opaque />
  </mesh>;
}

function Irrigation({ terrain, mode, data, reduced }) {
  const { stream, outlet, fallStart, bankHeight } = useMemo(() => {
    const ground = new THREE.Mesh(terrain);
    const ray = new THREE.Raycaster(new THREE.Vector3(), new THREE.Vector3(0, -1, 0));
    const bankHeight = (x, z) => {
      ray.ray.origin.set(x, 8, z);
      return ray.intersectObject(ground, false)[0]?.point.y ?? elevation(x, z);
    };
    const followGround = (coordinates) => {
      const controls = coordinates.map(([x, z, lift = .025]) => new THREE.Vector3(x, lift, z));
      const plan = new THREE.CatmullRomCurve3(controls);
      return Array.from({ length: 100 }, (_, i) => {
        const point = plan.getPoint(i / 99);
        point.y += bankHeight(point.x, point.z);
        return point;
      });
    };
    const [lipX, lipZ] = islandPoint(WATERFALL_EXIT_X, 4);
    const streamPoints = [[-1.77, -1.72], [-2.02, -1.21], [-2.49, -.56], [-2.9, .02], [-3.03, .87], [-3.13, 1.54], [-3.02, 2.24], [...RESERVOIR, .155]];
    const channelPoints = [[...RESERVOIR, .165], [-2.39, CHANNEL_Z], [-1.5, CHANNEL_Z], [-.42, CHANNEL_Z], [.84, CHANNEL_Z], [1.22, 3.25], [lipX, lipZ - .035]];
    const channelVectors = followGround(channelPoints);
    const lip = channelVectors.at(-1);
    const channel = new THREE.CatmullRomCurve3(channelVectors);
    const outlet = new THREE.CatmullRomCurve3([
      ...channelVectors,
      new THREE.Vector3(lipX, lip.y + .01, lipZ + .105),
      new THREE.Vector3(lipX, lip.y - .18, lipZ + .25),
      new THREE.Vector3(lipX, -1.04, lipZ + .34),
      new THREE.Vector3(lipX - .06, -2.3, lipZ + .36),
      new THREE.Vector3(lipX - .12, -3.52, lipZ + .42),
    ], false, 'centripetal');
    return {
      stream: new THREE.CatmullRomCurve3(followGround(streamPoints)),
      outlet,
      fallStart: channel.getLength() / outlet.getLength(),
      bankHeight,
    };
  }, [terrain]);
  const dry = mode === 'agua' && data?.balance_hidrico_mm < 0;
  return <group>
    {/* Naciente: el agua brota de una boca en el cerro. */}
    <group position={[-1.77, elevation(-1.77, -1.72), -1.72]}>
      <mesh castShadow position={[-.1, .1, -.16]} rotation={[.22, .4, .18]} scale={[1.3, 1, .9]}>
        <dodecahedronGeometry args={[.26, 0]} /><meshStandardMaterial color="#4b473e" roughness={1} flatShading />
      </mesh>
      <mesh castShadow position={[.19, .07, -.2]} rotation={[.1, 1.1, -.2]} scale={[1, .78, .9]}>
        <dodecahedronGeometry args={[.19, 0]} /><meshStandardMaterial color="#555044" roughness={1} flatShading />
      </mesh>
      <mesh castShadow position={[.04, .16, -.34]} rotation={[.3, .2, .1]} scale={[1.1, .7, .8]}>
        <dodecahedronGeometry args={[.16, 0]} /><meshStandardMaterial color="#423f37" roughness={1} flatShading />
      </mesh>
      <mesh position={[.03, .06, -.24]} scale={[.62, .5, .5]}>
        <sphereGeometry args={[.16, 10, 8]} /><meshStandardMaterial color="#0b100e" roughness={1} />
      </mesh>
    </group>
    <WaterRibbon curve={stream} width={.18} bankHeight={bankHeight} dry={dry} reduced={reduced} />
    <WaterRibbon curve={outlet} width={.142} bankHeight={bankHeight} fallStart={fallStart} dry={dry} reduced={reduced} />
    {[[-1.76, -1.79, .16], [-1.87, -1.68, .11], [-1.66, -1.67, .09]].map(([x, z, size]) => (
      <mesh key={x} position={[x, bankHeight(x, z) + size * .13, z]} rotation={[.22, x, -.18]} scale={[1.25, .8, 1]} castShadow receiveShadow>
        <dodecahedronGeometry args={[size, 0]} />
        <meshStandardMaterial color="#4c5550" roughness={.72} flatShading />
      </mesh>
    ))}
    <group position={[RESERVOIR[0], elevation(...RESERVOIR), RESERVOIR[1]]}>
      <mesh position={[0, .012, 0]} receiveShadow><boxGeometry args={[.86, .05, .86]} /><meshStandardMaterial color="#4c4a41" roughness={1} /></mesh>
      <mesh position={[0, .055, 0]} castShadow><cylinderGeometry args={[.31, .29, .18, 12]} /><meshStandardMaterial color="#57564b" roughness={1} /></mesh>
      <ReservoirWater reduced={reduced} />
      <mesh position={[0, .15, 0]} rotation={[-Math.PI / 2, 0, 0]}><torusGeometry args={[.283, .037, 5, 12]} /><meshStandardMaterial color="#807c68" roughness={1} /></mesh>
      <mesh castShadow position={[.3, .09, .17]} rotation={[0, .62, 0]}><boxGeometry args={[.16, .07, .045]} /><meshStandardMaterial color="#6b6455" roughness={1} /></mesh>
      <group position={[-.42, .05, .26]} rotation={[0, .6, 0]}>
        <mesh castShadow position={[0, .055, 0]}><cylinderGeometry args={[.058, .046, .11, 10]} /><meshStandardMaterial color="#8a7a55" roughness={1} /></mesh>
        <mesh position={[0, .118, 0]} rotation={[Math.PI / 2, 0, 0]}><torusGeometry args={[.045, .007, 4, 10]} /><meshStandardMaterial color="#5f5340" /></mesh>
      </group>
    </group>
  </group>;
}

function CloudCluster({ position, scale = 1, rotation, winter }) {
  return <group position={position} scale={scale} rotation={rotation}>
    {[
      [-.43, -.02, .02, .36],
      [-.04, .12, -.06, .48],
      [.43, -.06, .01, .32],
      [.09, -.13, .29, .34],
    ].map(([x, y, z, radius]) => <mesh key={x} position={[x, y, z]} scale={[1.17, .82, .94]}>
      <icosahedronGeometry args={[radius, 1]} />
      <meshStandardMaterial color={winter ? '#ecf5ff' : '#fffdf6'} flatShading roughness={.96} />
    </mesh>)}
  </group>;
}

/** Nubes bajas alrededor de la isla. Las rocas sueltas del borde se eliminaron:
 *  el acantilado continuo de `buildTerrain` es el que sostiene la isla. */
function IslandEdge({ reduced, winter }) {
  const clouds = useRef();
  const stoneMeshes = useRef([]);
  const fragments = useMemo(() => {
    const variants = Array.from({ length: 3 }, (_, shape) => {
      const geometry = new THREE.IcosahedronGeometry(1, shape === 2 ? 1 : 0);
      const vertices = geometry.attributes.position;
      for (let i = 0; i < vertices.count; i++) {
        const x = vertices.getX(i);
        const y = vertices.getY(i);
        const z = vertices.getZ(i);
        const fracture = 1 + .24 * Math.sin(x * 7 + y * 9 + z * 11 + shape * 4);
        vertices.setXYZ(i, x * fracture + y * .24, Math.min(y * fracture, .52 + shape * .1), z * fracture);
      }
      geometry.computeVertexNormals();
      return { geometry, placements: [] };
    });
    ISLAND_EDGES.forEach((edge, side) => {
      const segments = 18;
      for (let index = 0; index < segments; index++) {
        const phase = index * 2.39 + side * 3.7;
        const t = (index + .5 + .28 * Math.sin(phase)) / segments;
        const [rawX, rawZ] = edge(t);
        if (side === 2 && Math.abs(rawX - WATERFALL_EXIT_X) < .9) continue;
        const [x, z] = islandPoint(rawX, rawZ);
        const [nextX, nextZ] = islandPoint(...edge(Math.min(1, t + .012)));
        const angle = Math.atan2(nextZ - z, nextX - x);
        const variation = (1 + Math.sin(phase * 1.91)) / 2;
        const shape = (index * 2 + side) % variants.length;
        variants[shape].placements.push({ x, z, angle, phase, variation, lower: false });
        if (variation > .2) {
          variants[(shape + 1) % variants.length].placements.push({ x, z, angle, phase, variation, lower: true });
        }
      }
    });
    return variants;
  }, []);
  useLayoutEffect(() => {
    const marker = new THREE.Object3D();
    const tint = new THREE.Color();
    fragments.forEach(({ placements }, shape) => {
      const mesh = stoneMeshes.current[shape];
      placements.forEach(({ x, z, angle, phase, variation, lower }, index) => {
        const radius = lower ? .93 + variation * .045 : .985 + variation * .018;
        const shift = lower ? .15 * Math.sin(phase) : 0;
        const rockX = x * radius + Math.cos(angle) * shift;
        const rockZ = z * radius + Math.sin(angle) * shift;
        const height = lower ? .42 + variation * .23 : .28 + variation * .14;
        const level = elevation(x, z) - (lower ? .57 + variation * .29 : .15 + variation * .10);
        marker.position.set(rockX, level, rockZ);
        marker.rotation.set(.18 * Math.sin(phase), -angle + .32 * Math.cos(phase), .23 * Math.cos(phase), 'YXZ');
        marker.scale.set(.29 + variation * .22, height, .23 + variation * .11);
        marker.updateMatrix();
        mesh.setMatrixAt(index, marker.matrix);
        mesh.setColorAt(index, tint.set(['#847761', '#948775', '#756d60'][shape]).multiplyScalar(.85 + variation * .21 - (lower ? .12 : 0)));
      });
      mesh.instanceMatrix.needsUpdate = true;
      mesh.instanceColor.needsUpdate = true;
    });
  }, [fragments]);
  useEffect(() => () => fragments.forEach(({ geometry }) => geometry.dispose()), [fragments]);
  useFrame(({ clock }) => {
    const time = reduced ? 0 : clock.elapsedTime;
    clouds.current.position.x = Math.sin(time * .14) * .21;
    clouds.current.position.z = Math.sin(time * .11) * .13;
  });
  return <>
    {fragments.map(({ geometry, placements }, index) => (
      <instancedMesh key={index} ref={(mesh) => { stoneMeshes.current[index] = mesh; }}
        args={[geometry, undefined, placements.length]} castShadow receiveShadow frustumCulled={false}>
        <meshStandardMaterial onBeforeCompile={surfaceGrain} roughness={1} flatShading />
      </instancedMesh>
    ))}
    <group ref={clouds}>
      {[[-3.1, -2.41, -.55], [-1.88, -2.94, 2.33], [2.46, -2.52, -1.95]].map(([x, y, z], index) => (
        <CloudCluster key={x} position={[x, y, z]} rotation={[0, index * 1.4, 0]} scale={1.16} winter={winter} />
      ))}
    </group>
  </>;
}

function islandEdgeAt(angle) {
  const [x, z] = islandPoint(Math.cos(angle) * 4, Math.sin(angle) * 4);
  const radius = Math.hypot(x, z) || 1;
  return { x, z, radius };
}

const rockGap = (a, b) => (a.size + b.size) * 2.7 + .24;

/**
 * Rocas flotantes: todas fuera del contorno (edge + margen + radio) y sin
 * solaparse entre sí (Poisson en 3D). Debajo del filo, nunca sobre el césped.
 */
function FloatingRocks({ reduced }) {
  const debrisSpots = useMemo(() => {
    const accepted = [];
    const random = (seed) => {
      const value = Math.sin(seed * 12.9898 + seed * seed * 0.0071) * 43758.5453;
      return value - Math.floor(value);
    };
    for (let attempt = 0; attempt < 420 && accepted.length < 26; attempt++) {
      const angle = random(attempt + 1) * Math.PI * 2;
      const size = .05 + random(attempt + 2.3) * .075;
      const edge = islandEdgeAt(angle);
      const margin = .34 + size * 3.1;
      const distance = edge.radius + margin;
      const x = (edge.x / edge.radius) * distance;
      const z = (edge.z / edge.radius) * distance;
      const y = -.62 - random(attempt + 4.7) * 1.9;
      const candidate = { x, y, z, size, angle, phase: random(attempt + 6.1) * Math.PI * 2 };
      if (accepted.some((rock) => Math.hypot(x - rock.x, y - rock.y, z - rock.z) < rockGap(rock, candidate))) continue;
      accepted.push(candidate);
    }
    return accepted;
  }, []);

  const boulders = useMemo(() => {
    return [3.34, -.32, 2.28, .79].map((angle, index) => {
      const edge = islandEdgeAt(angle);
      const size = .52 - index * .06;
      const distance = edge.radius + .5 + size * 1.9;
      return {
        x: (edge.x / edge.radius) * distance,
        z: (edge.z / edge.radius) * distance,
        y: -1.45 - index * .47,
        size,
        index,
      };
    });
  }, []);

  const rocks = useRef();
  const debris = useRef();
  const marker = useMemo(() => new THREE.Object3D(), []);
  useFrame(({ clock }) => {
    rocks.current?.children.forEach((rock, index) => {
      rock.position.y = boulders[index].y + (reduced ? 0 : Math.sin(clock.elapsedTime * .55 + index * 2) * .11);
    });
    if (!debris.current) return;
    const time = reduced ? 0 : clock.elapsedTime;
    debrisSpots.forEach((spot, index) => {
      const bob = reduced ? 0 : Math.sin(time * .5 + spot.phase) * .09;
      const orbit = reduced ? 0 : Math.sin(time * .22 + spot.phase) * .012;
      marker.position.set(spot.x * (1 + orbit), spot.y + bob, spot.z * (1 + orbit));
      marker.rotation.set(spot.angle + time * .12, spot.angle - time * .09, spot.angle * .6);
      marker.scale.set(spot.size, spot.size * 1.45, spot.size * .82);
      marker.updateMatrix();
      debris.current.setMatrixAt(index, marker.matrix);
    });
    debris.current.instanceMatrix.needsUpdate = true;
  });
  return <>
    <instancedMesh ref={debris} args={[undefined, undefined, debrisSpots.length]} castShadow frustumCulled={false}>
      <dodecahedronGeometry args={[1, 0]} /><meshStandardMaterial color="#6b6151" roughness={1} flatShading />
    </instancedMesh>
    <group ref={rocks}>
      {boulders.map(({ x, y, z, size, index }) => (
        <mesh key={index} position={[x, y, z]} rotation={[.14, index * 1.7, -.17]} scale={[size, size * 1.54, size * .88]}>
          <dodecahedronGeometry args={[1, 0]} />
          <meshStandardMaterial color={index % 2 ? '#494b49' : '#62635a'} flatShading roughness={1} />
        </mesh>
      ))}
    </group>
    <group>
      {Array.from({ length: 11 }, (_, index) => {
        const angle = index * 2.39996 + .35;
        const radius = 1.15 + (index % 4) * .28;
        const x = Math.cos(angle) * radius * 1.55;
        const z = Math.sin(angle) * radius * 1.55;
        const length = .42 + (index % 4) * .26;
        return <mesh key={'root' + index} castShadow
          position={[x, -2.02 - (index % 3) * .12 - length * .28, z]}
          rotation={[Math.PI + Math.sin(index * 1.7) * .16, angle, Math.cos(index * .9) * .16]}>
          <coneGeometry args={[.052 + (index % 3) * .018, length, 5]} />
          <meshStandardMaterial color={index % 2 ? '#3a2d21' : '#4b3a29'} roughness={1} flatShading />
        </mesh>;
      })}
    </group>
  </>;
}
function SeasonalEquipment({ month, reduced, working, task }) {
  const spray = useRef();
  const winter = task ? task === 'spraying' : month >= 6 && month <= 8;
  const spring = task ? task === 'tending' : month >= 9 && month <= 11;
  const summer = month === 12 || month <= 2;
  const droplets = useMemo(() => new Float32Array(36 * 3), []);
  useFrame(({ clock }) => {
    if (!spray.current) return;
    spray.current.visible = reduced || working.current;
    const attribute = spray.current.geometry.attributes.position;
    const time = reduced ? .35 : clock.elapsedTime * .85;
    for (let i = 0; i < attribute.count; i++) {
      const t = (time + i / attribute.count) % 1;
      attribute.setXYZ(i, .29 + t * .34, .18 + t * .12 - t * t * .29, .035 + Math.sin(i * 2.4) * t * .07);
    }
    attribute.needsUpdate = true;
    spray.current.geometry.setDrawRange(0, summer ? 36 : 24);
  });
  if (spring) return <mesh castShadow position={[.19, .18, .03]} rotation={[0, 0, -.3]}>
    <cylinderGeometry args={[.014, .014, .32, 6]} /><meshStandardMaterial color="#987548" />
  </mesh>;
  return <>
    {winter ? <>
      <mesh castShadow position={[0, .25, -.09]}><boxGeometry args={[.12, .16, .08]} /><meshStandardMaterial color="#b49154" /></mesh>
      <mesh position={[.2, .21, .028]} rotation={[0, 0, -Math.PI / 2]}><cylinderGeometry args={[.009, .009, .19, 6]} /><meshStandardMaterial color="#65674d" /></mesh>
    </> : <>
      <mesh castShadow position={[.13, .156, .035]}><cylinderGeometry args={[.055, .06, .085, 8]} /><meshStandardMaterial color="#4c8582" /></mesh>
      <mesh position={[.212, .174, .035]} rotation={[0, 0, -1.2]}><cylinderGeometry args={[.012, .015, .135, 6]} /><meshStandardMaterial color="#4c8582" /></mesh>
    </>}
    <points ref={spray} frustumCulled={false}>
      <bufferGeometry><bufferAttribute attach="attributes-position" args={[droplets, 3]} /></bufferGeometry>
      <pointsMaterial color={winter ? '#d7e5d8' : '#9adbdc'} size={.015} transparent opacity={.63} depthWrite={false} />
    </points>
  </>;
}

function SummitRocks({ winter }) {
  return <group>
    {[
      [-.7, -.46, .23], [-.37, -.68, .30], [-.12, -.42, .18],
      [.24, -.81, .22], [-.72, -.94, .15], [.75, -.82, .18],
    ].map(([x, z, size], index) => (
      <group key={x} position={[x, elevation(x, z) + size * .24, z]} rotation={[.16, index * 1.2, -.17]}>
        <mesh scale={[1.15, .8, .85]} castShadow receiveShadow>
          <dodecahedronGeometry args={[size, 0]} />
          <meshStandardMaterial color={index % 2 ? '#85888c' : '#636a71'} roughness={.94} flatShading />
        </mesh>
        {(winter || index === 1) && <mesh position={[.01, size * .47, 0]} scale={[.86, .36, .71]}>
          <dodecahedronGeometry args={[size, 0]} />
          <meshStandardMaterial color="#edf4f7" roughness={.86} flatShading />
        </mesh>}
      </group>
    ))}
  </group>;
}

function SummitClouds({ reduced, winter }) {
  const clouds = useRef();
  useFrame(({ clock }) => {
    clouds.current.position.x = reduced ? 0 : Math.sin(clock.elapsedTime * .18) * .45;
    clouds.current.position.z = reduced ? 0 : Math.cos(clock.elapsedTime * .15) * .22;
  });
  return <group ref={clouds}>
    {[[-1.8, 3.2, -1.5], [.7, 3.45, -1.65], [1.62, 2.78, -.92], [-2.7, 2.28, -2.9], [.3, 3.12, -3.6], [2.6, 2.58, -3.2]].map(([x, y, z], index) => (
      <CloudCluster key={x} position={[x, y + .22, z]} rotation={[0, index * .9, 0]} scale={.62 + (index % 3) * .19} winter={winter} />
    ))}
  </group>;
}

function Farmer({ x, z, color, month, reduced, task, stationary = false }) {
  const body = useRef();
  const legs = useRef([]);
  const arms = useRef([]);
  const working = useRef(false);
  const workBlend = useRef(0);
  useFrame(({ clock }, delta) => {
    if (stationary) {
      const effort = reduced ? .5 : Math.sin(clock.elapsedTime * 2.4 + x) * .5 + .5;
      body.current.position.set(x, elevation(x, z), z);
      body.current.rotation.y = Math.PI + x * .22;
      body.current.rotation.x = .28 + effort * .09;
      legs.current.forEach((leg, i) => { if (leg) leg.rotation.x = i ? -.16 : .16; });
      arms.current.forEach((arm, i) => { if (arm) arm.rotation.x = i ? -.52 + effort * .26 : -.34 + effort * .12; });
      working.current = true;
      workBlend.current = 1;
      return;
    }
    const time = reduced ? 0 : clock.elapsedTime + (x < 0 ? 0 : 2.6);
    const cycle = time % 9;
    const angle = (Math.floor(time / 9) + THREE.MathUtils.smoothstep(cycle, 0, 5.9)) * Math.PI * 2;
    const nextX = x + Math.sin(angle) * .087;
    const nextZ = z - Math.cos(angle) * .44;
    working.current = reduced || cycle >= 5.9;
    const dt = Math.min(delta, .05);
    workBlend.current = reduced ? 1 : THREE.MathUtils.damp(workBlend.current, Number(working.current), 5, dt);
    const effort = reduced ? 0 : Math.sin(time * (month >= 6 && month <= 8 ? 4.2 : 3));
    const stride = reduced ? 0 : Math.sin(time * 10) * (1 - workBlend.current);
    body.current.position.set(nextX, elevation(nextX, nextZ) + Math.abs(stride) * .014, nextZ);
    const direction = working.current ? (x < 0 ? -1.15 : .95) : Math.atan2(Math.cos(angle) * .087, Math.sin(angle) * .44);
    const turn = Math.atan2(Math.sin(direction - body.current.rotation.y), Math.cos(direction - body.current.rotation.y));
    body.current.rotation.y += reduced ? turn : turn * (1 - Math.exp(-dt * 6));
    body.current.rotation.x = workBlend.current * (.23 + effort * .10);
    legs.current.forEach((leg, i) => { if (leg) leg.rotation.x = stride * (i ? -.44 : .44) + workBlend.current * .10; });
    arms.current.forEach((arm, i) => {
      if (!arm) return;
      arm.rotation.x = stride * (i ? .34 : -.34) + workBlend.current * (i ? -.43 + effort * .28 : -.19);
    });
  });
  return <group ref={body} position={[x, elevation(x, z), z]}>
    {[-.044, .044].map((leg, index) => <group key={leg} ref={(node) => { legs.current[index] = node; }} position={[leg, .188, 0]}>
      <mesh castShadow position={[0, -.077, 0]} scale={[1, 1, .82]}><cylinderGeometry args={[.037, .025, .16, 7]} /><meshStandardMaterial color="#57493c" roughness={1} /></mesh>
      <mesh castShadow position={[0, -.163, .016]} scale={[.88, .68, 1.38]}><icosahedronGeometry args={[.037, 1]} /><meshStandardMaterial color="#302b24" /></mesh>
    </group>)}
    <mesh castShadow position={[0, .252, 0]} scale={[1, 1, .63]}><cylinderGeometry args={[.087, .065, .142, 8]} /><meshStandardMaterial color={color} roughness={1} /></mesh>
    <mesh castShadow position={[0, .176, 0]} scale={[1, 1, .68]}><cylinderGeometry args={[.064, .086, .055, 8]} /><meshStandardMaterial color={color} roughness={1} /></mesh>
    <mesh position={[0, .208, .002]} scale={[1, 1, .7]}><cylinderGeometry args={[.07, .07, .022, 8]} /><meshStandardMaterial color="#473426" /></mesh>
    <mesh position={[0, .207, .052]}><boxGeometry args={[.022, .018, .008]} /><meshStandardMaterial color="#b89a62" /></mesh>
    <mesh position={[0, .275, .041]} scale={[1, 1, .2]}><coneGeometry args={[.043, .077, 4]} /><meshStandardMaterial color="#e0c79c" /></mesh>
    {[-.078, .078].map((arm, index) => <group key={arm} ref={(node) => { arms.current[index] = node; }} position={[arm, .31, .006]} rotation={[0, 0, Math.sign(arm) * .25]}>
      <mesh castShadow position={[0, -.046, 0]}><cylinderGeometry args={[.029, .022, .088, 6]} /><meshStandardMaterial color="#d6bb90" roughness={1} /></mesh>
      <mesh position={[0, -.101, .009]} scale={[.87, 1.25, .76]}><icosahedronGeometry args={[.021, 1]} /><meshStandardMaterial color="#b3845d" /></mesh>
    </group>)}
    <mesh position={[0, .326, 0]}><cylinderGeometry args={[.023, .024, .035, 7]} /><meshStandardMaterial color="#b3845d" /></mesh>
    <mesh castShadow position={[0, .372, -.014]} scale={[1.08, 1.12, .93]}><icosahedronGeometry args={[.052, 1]} /><meshStandardMaterial color="#3d2e25" roughness={1} /></mesh>
    <mesh castShadow position={[0, .368, .008]} scale={[.9, 1.12, .91]}><icosahedronGeometry args={[.051, 1]} /><meshStandardMaterial color="#b3845d" roughness={.89} /></mesh>
    <mesh position={[0, .351, .047]} scale={[1.35, .35, .35]}><icosahedronGeometry args={[.023, 1]} /><meshStandardMaterial color="#463126" /></mesh>
    <mesh position={[0, .359, .047]}><sphereGeometry args={[.014, 6, 4]} /><meshStandardMaterial color="#bd8d68" /></mesh>
    {[-.019, .019].map((side) => <mesh key={side} position={[side, .372, .046]}><sphereGeometry args={[.006, 5, 4]} /><meshBasicMaterial color="#31291f" /></mesh>)}
    <mesh castShadow position={[0, .414, 0]}><cylinderGeometry args={[.081, .091, .012, 12]} /><meshStandardMaterial color="#b59a67" roughness={1} /></mesh>
    <mesh castShadow position={[0, .435, 0]}><cylinderGeometry args={[.039, .051, .035, 10]} /><meshStandardMaterial color="#c2a471" roughness={1} /></mesh>
    <SeasonalEquipment month={month} reduced={reduced} working={working} task={task} />
  </group>;
}

const HOMES = [[2.77, 1.36, 1], [2.93, -.91, .8], [1.67, -2.79, .9], [2.82, -2.18, .69]];
const SHEEP_PENS = [
  { bounds: [2.4, 2.85, .27, .82], sheep: [[2.62, .55]] },
  { bounds: [2.87, 3.46, -.13, .81], sheep: [[3.08, .15], [3.18, .56]] },
];

function AnimalPens() {
  const fences = useMemo(() => SHEEP_PENS.map(({ bounds: [left, right, back, front] }) => {
    const corners = [[left, back], [right, back], [right, front], [left, front]];
    const posts = corners.map(([x, z]) => [x, z]);
    const rails = [];
    corners.forEach(([x, z], index) => {
      const [endX, endZ] = corners[(index + 1) % corners.length];
      const count = Math.ceil(Math.hypot(endX - x, endZ - z) / .22);
      for (let segment = 0; segment < count; segment++) {
        const t = segment / count;
        const next = (segment + 1) / count;
        const startX = THREE.MathUtils.lerp(x, endX, t);
        const startZ = THREE.MathUtils.lerp(z, endZ, t);
        const nextX = THREE.MathUtils.lerp(x, endX, next);
        const nextZ = THREE.MathUtils.lerp(z, endZ, next);
        if (segment > 0) posts.push([startX, startZ]);
        for (const height of [.08, .163]) {
          const start = new THREE.Vector3(startX, elevation(startX, startZ) + height, startZ);
          const end = new THREE.Vector3(nextX, elevation(nextX, nextZ) + height, nextZ);
          const direction = end.clone().sub(start);
          rails.push({ position: start.lerp(end, .5), rotation: new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), direction.clone().normalize()), length: direction.length() });
        }
      }
    });
    return { posts, rails };
  }), []);
  return SHEEP_PENS.map(({ sheep }, index) => <group key={index}>
    {fences[index].posts.map(([x, z]) => <mesh key={x + ':' + z} castShadow position={[x, elevation(x, z) + .11, z]}>
      <boxGeometry args={[.032, .235, .034]} /><meshStandardMaterial color="#75583e" roughness={1} />
    </mesh>)}
    {fences[index].rails.map(({ position, rotation, length }, rail) => <mesh key={rail} position={position} quaternion={rotation}>
      <boxGeometry args={[.024, length, .027]} /><meshStandardMaterial color={rail % 2 ? '#926f4a' : '#816044'} roughness={1} />
    </mesh>)}
    {sheep.map(([x, z], sheepIndex) => (
      <group key={x} position={[x, elevation(x, z), z]} rotation={[0, .5 + sheepIndex * 2, 0]} scale={.82}>
        <mesh castShadow position={[0, .156, 0]} scale={[1.45, .9, .82]}><icosahedronGeometry args={[.108, 2]} /><meshStandardMaterial color="#d8cbb0" roughness={1} flatShading /></mesh>
        <mesh castShadow position={[.155, .177, 0]} scale={[1.22, .86, .9]}><sphereGeometry args={[.06, 7, 6]} /><meshStandardMaterial color="#52463d" /></mesh>
        {[-.075, .075].flatMap((legX) => [-.063, .063].map((legZ) =>
          <mesh key={legX + ':' + legZ} position={[legX, .066, legZ]}><cylinderGeometry args={[.012, .016, .13, 5]} /><meshStandardMaterial color="#594d42" /></mesh>
        ))}
      </group>
    ))}
  </group>);
}

function ThatchedHouse({ x, z, scale, index }) {
  return <group position={[x, elevation(x, z) - .095 * scale, z]} scale={scale} rotation={[0, -.15 + index * .37, 0]}>
    <mesh castShadow position={[0, .12, 0]}><boxGeometry args={[.65, .27, .53]} /><meshStandardMaterial onBeforeCompile={surfaceGrain} color="#756451" roughness={1} /></mesh>
    <mesh castShadow position={[0, .3, 0]}><boxGeometry args={[.61, .31, .49]} /><meshStandardMaterial onBeforeCompile={surfaceGrain} color="#b79872" roughness={1} /></mesh>
    <mesh castShadow position={[0, .59, 0]} rotation={[0, Math.PI / 4, 0]} scale={[1, 1, .87]}>
      <coneGeometry args={[.56, .36, 4]} /><meshStandardMaterial onBeforeCompile={surfaceGrain} color="#ae8b48" roughness={1} />
    </mesh>
    {[.02, .10, .18].map((height) => <mesh key={height} position={[0, .425 + height, 0]} rotation={[Math.PI / 2, 0, Math.PI / 4]} scale={[1, .87, 1]}>
      <torusGeometry args={[.525 - height * 1.55, .016, 4, 4]} /><meshStandardMaterial color="#c19f59" roughness={1} />
    </mesh>)}
    <mesh position={[.055, .206, .25]}><boxGeometry args={[.129, .23, .016]} /><meshStandardMaterial color="#433328" /></mesh>
    <mesh position={[-.146, .31, .25]}><boxGeometry args={[.10, .085, .017]} /><meshStandardMaterial color="#504132" /></mesh>
  </group>;
}

/** Llama de pie, low-poly. */
function Llama({ x, z, scale = 1, rotation = 0, tone = '#c8b393' }) {
  const y = elevation(x, z);
  return <group position={[x, y, z]} rotation={[0, rotation, 0]} scale={scale}>
    <mesh castShadow position={[0, .3, 0]} rotation={[0, 0, Math.PI / 2]} scale={[1, 1, .82]}>
      <cylinderGeometry args={[.085, .085, .3, 8]} /><meshStandardMaterial color={tone} roughness={.95} flatShading />
    </mesh>
    <mesh castShadow position={[.15, .46, 0]} rotation={[0, 0, -.22]}>
      <cylinderGeometry args={[.038, .05, .26, 7]} /><meshStandardMaterial color={tone} roughness={.95} />
    </mesh>
    <mesh castShadow position={[.19, .6, 0]} scale={[1.25, .85, .8]}>
      <icosahedronGeometry args={[.058, 1]} /><meshStandardMaterial color={tone} roughness={.95} flatShading />
    </mesh>
    {[[.09, -.09], [.09, .09], [-.09, -.09], [-.09, .09]].map(([dx, dz]) => (
      <mesh key={dx + ':' + dz} position={[dx, .12, dz]}><cylinderGeometry args={[.019, .015, .24, 5]} /><meshStandardMaterial color="#8d7a5e" /></mesh>
    ))}
    {[-.028, .028].map((dz) => <mesh key={dz} position={[.19, .66, dz]} rotation={[0, 0, -.12]}><coneGeometry args={[.016, .05, 5]} /><meshStandardMaterial color="#b7a281" /></mesh>)}
  </group>;
}

/** Gallinas sueltas cerca de las casas. */
function Chickens({ spots }) {
  return <>
    {spots.map(([x, z, rotation], index) => {
      const y = elevation(x, z);
      const tone = ['#f2ece0', '#c08a4a', '#e6dcc8', '#8d5c3a'][index % 4];
      return <group key={x + ':' + z} position={[x, y, z]} rotation={[0, rotation, 0]} scale={.9 + (index % 3) * .12}>
        <mesh castShadow position={[0, .05, 0]} scale={[1.15, .9, .9]}><icosahedronGeometry args={[.042, 1]} /><meshStandardMaterial color={tone} roughness={.95} flatShading /></mesh>
        <mesh castShadow position={[.045, .085, 0]}><sphereGeometry args={[.024, 7, 5]} /><meshStandardMaterial color={tone} roughness={.9} /></mesh>
        <mesh position={[.062, .1, 0]} rotation={[0, 0, -.4]}><coneGeometry args={[.008, .022, 4]} /><meshStandardMaterial color="#d9a13c" /></mesh>
      </group>;
    })}
  </>;
}

/** Árboles del fondo: material compartido y estacional. */
const GROVE_SPOTS = [
  [-3.03, -1.23], [-3.29, -.71], [-3.43, -.27], [3.42, -1.37], [-3.52, 1.12], [-3.58, 1.62],
  [.62, -3.02], [-2.5, -2.83], [-1.8, -3.08], [-1.1, -3.43], [-.42, -3.24], [-.18, -3.04], [2.47, -2.86],
];

function Grove({ aridity, snow, reduced }) {
  const target = useMemo(() => new THREE.Color(), []);
  const material = useMemo(
    () => new THREE.MeshStandardMaterial({ color: '#4CAF50', roughness: 1, metalness: 0, flatShading: true }),
    []
  );
  useEffect(() => () => material.dispose(), [material]);
  useFrame((_, delta) => {
    canopyColor(aridity, snow, target);
    material.color.lerp(target, reduced ? 1 : 1 - Math.exp(-Math.min(delta, .05) * 2.4));
  });
  return <>
    {GROVE_SPOTS.map(([x, z], index) => {
      const scale = .75 + (index % 4) * .14;
      return <group key={x} position={[x, elevation(x, z), z]} scale={scale}>
        <mesh castShadow position={[0, .18, 0]}>
          <cylinderGeometry args={[.035, .057, .37, 5]} /><meshStandardMaterial color="#6a563c" />
        </mesh>
        <mesh castShadow position={[0, .48, 0]} scale={[.8 + (index % 3) * .12, 1.1 + (index % 4) * .15, .83]} material={material}>
          <icosahedronGeometry args={[.26, 1]} />
        </mesh>
      </group>;
    })}
  </>;
}
function FarmDetails({ terrain, mode, data, month, reduced, region, aridity, snow }) {
  const trail = useMemo(() => {
    const vertices = [];
    const colors = [];
    const tint = new THREE.Color();
    const strips = 4;
    const segments = 144;
    for (let step = 0; step <= segments; step++) {
      const z = -2.79 + step * 6 / segments;
      const x = 2.13 + Math.sin(z * 1.17) * .14 - Math.max(0, z - 1.6) * .21;
      const halfWidth = .14 + Math.sin(step * .13) * .024;
      for (let strip = 0; strip <= strips; strip++) {
        const lane = x + (strip / strips * 2 - 1) * halfWidth;
        vertices.push(lane, elevation(lane, z) + .068, z);
        tint.set(strip === 0 || strip === strips ? '#857457' : strip === 2 ? '#9a815e' : '#b19772');
        tint.multiplyScalar(.92 + Math.sin(step * 2.7 + strip * 4) ** 2 * .13);
        colors.push(tint.r, tint.g, tint.b);
      }
    }
    const indices = [];
    for (let step = 0; step < segments; step++) {
      for (let strip = 0; strip < strips; strip++) {
        const a = step * (strips + 1) + strip;
        const b = a + strips + 1;
        indices.push(a, b, a + 1, a + 1, b, b + 1);
      }
    }
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
    geometry.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
    geometry.setIndex(indices);
    geometry.computeVertexNormals();
    return geometry;
  }, []);
  useEffect(() => () => trail.dispose(), [trail]);
  return (
    <>
      <Irrigation terrain={terrain} mode={mode} data={data} reduced={reduced} />
      <Farmer x={-2.56} z={1.36} color="#ae6c42" month={month} reduced={reduced} task="tending" stationary />
      <Farmer x={-.84} z={2.02} color="#526584" month={month} reduced={reduced} task="spraying" stationary />
      <Farmer x={.94} z={1.44} color="#6d7d43" month={month} reduced={reduced} task="watering" stationary />
      <Farmer x={-1.86} z={-1.78} color="#8a5a3c" month={month} reduced={reduced} />
      <Llama x={-1.55} z={-2.7} rotation={1.9} scale={1.05} />
      <Llama x={-1.95} z={-2.42} rotation={-.8} scale={.95} tone='#a9885f' />
      <Chickens spots={[[2.44, .95, .4], [2.62, 1.08, 2.1], [2.34, 1.16, 1.2], [1.02, -2.5, .8], [1.18, -2.34, 2.6]]} />
      <AnimalPens />
      <mesh geometry={trail} receiveShadow>
        <meshStandardMaterial onBeforeCompile={surfaceGrain} vertexColors roughness={1} side={THREE.DoubleSide} />
      </mesh>
      {HOMES.map(([x, z, scale], index) => <ThatchedHouse key={x} x={x} z={z} scale={scale} index={index} />)}
      {Array.from({ length: 12 }, (_, index) => {
        const x = -2.27 + index * .145;
        const z = -2.42 + Math.sin(index * .18) * .24;
        return <mesh key={x} castShadow position={[x, elevation(x, z) + .04, z]} rotation={[0, index * .77, .16]} scale={[1.36, .68 + index % 3 * .15, .94]}>
          <dodecahedronGeometry args={[.095, 0]} /><meshStandardMaterial color={index % 2 ? '#817768' : '#665f54'} roughness={1} />
        </mesh>;
      })}
      <Grove aridity={aridity} snow={snow} reduced={reduced} />
      {[[-1.35, -.97], [-.67, -.57], [-.32, -.97], [.45, -1.15], [.58, -.73], [-.93, -.3], [-1.7, -2.04], [-1.28, -2.34], [-.81, -2.67], [.23, -2.88], [1.51, -2.31], [2, -2.11]].map(([x, z], index) => (
        <mesh castShadow key={x} position={[x, elevation(x, z) + .046, z]} rotation={[.2, index * 1.4, 0]} scale={[1.4, .65, .9]}>
          <dodecahedronGeometry args={[.13 + index % 3 * .045, 0]} /><meshStandardMaterial color={index % 2 ? '#837d69' : '#686757'} roughness={1} flatShading />
        </mesh>
      ))}
    </>
  );
}

function buildTerrain() {
  const top = new THREE.PlaneGeometry(SIZE, SIZE, SEGMENTS, SEGMENTS);
  top.rotateX(-Math.PI / 2);
  const positions = top.attributes.position;
  const palette = new Float32Array(positions.count * 3);
  for (let i = 0; i < positions.count; i++) {
    const [x, z] = islandPoint(positions.getX(i), positions.getZ(i));
    positions.setXYZ(i, x, elevation(x, z), z);
  }
  top.setAttribute('color', new THREE.BufferAttribute(palette, 3));
  top.computeVertexNormals();

  const vertices = [];
  const colors = [];
  const shade = new THREE.Color();
  function triangle(a, b, c, tint) {
    vertices.push(...a, ...b, ...c);
    const grain = .86 + .13 * Math.sin(a[0] * 15 + a[2] * 27) ** 2 + .08 * Math.cos(a[1] * 32 + b[2] * 8);
    shade.set(tint).multiplyScalar(grain);
    for (let i = 0; i < 3; i++) colors.push(shade.r, shade.g, shade.b);
  }
  for (const edge of ISLAND_EDGES) {
    for (let i = 0; i < SEGMENTS; i++) {
      const [x, z] = islandPoint(...edge(i / SEGMENTS));
      const [nx, nz] = islandPoint(...edge((i + 1) / SEGMENTS));
      const depth = BOTTOM - (Math.sin(x * 1.6 + z) + 1) * .15;
      const nextDepth = BOTTOM - (Math.sin(nx * 1.6 + nz) + 1) * .15;
      const levels = [elevation(x, z), -.15, -.46, -.93, depth];
      const next = [elevation(nx, nz), -.15, -.46, -.93, nextDepth];
      const taper = [1, 1.005, .96, .78, .51];
      for (let layer = 0; layer < 4; layer++) {
        const a = [x * taper[layer], levels[layer], z * taper[layer]];
        const b = [nx * taper[layer], next[layer], nz * taper[layer]];
        const c = [x * taper[layer + 1], levels[layer + 1], z * taper[layer + 1]];
        const d = [nx * taper[layer + 1], next[layer + 1], nz * taper[layer + 1]];
        const tint = ['#58402a', '#433126', '#565854', '#3a3d3b'][layer];
        triangle(a, c, b, tint);
        triangle(b, c, d, tint);
      }
      triangle([x * .51, depth, z * .51], [nx * .51, nextDepth, nz * .51], [0, -2.48, 0], '#303333');
    }
  }
  const walls = new THREE.BufferGeometry();
  walls.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
  walls.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
  walls.computeVertexNormals();
  return { top, walls };
}

function useReducedMotion() {
  const [reduced, setReduced] = useState(false);
  useEffect(() => {
    const media = matchMedia('(prefers-reduced-motion: reduce)');
    const update = () => setReduced(media.matches);
    update();
    media.addEventListener('change', update);
    return () => media.removeEventListener('change', update);
  }, []);
  return reduced;
}

function usePageProgress(target, externalProgress, onLayerChange) {
  const progress = useRef(0);
  useEffect(() => {
    if (Number.isFinite(externalProgress)) {
      progress.current = clamp(externalProgress, 0, 1);
      onLayerChange(progress.current < .34 ? 'normal' : progress.current < .67 ? 'helada' : 'agua');
      return;
    }
    gsap.registerPlugin(ScrollTrigger);
    const element = typeof target === 'string' ? document.querySelector(target) : target?.current;
    const update = (trigger) => {
      progress.current = trigger.progress;
      onLayerChange(trigger.progress < .34 ? 'normal' : trigger.progress < .67 ? 'helada' : 'agua');
    };
    const trigger = ScrollTrigger.create({
      trigger: element || document.documentElement,
      start: 'top top',
      end: 'bottom bottom',
      onUpdate: update,
      onRefresh: update,
    });
    update(trigger);
    let frame = 0;
    const observer = new ResizeObserver(() => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => trigger.refresh());
    });
    observer.observe(document.documentElement);
    if (element) observer.observe(element);
    return () => {
      observer.disconnect();
      cancelAnimationFrame(frame);
      trigger.kill();
    };
  }, [target, externalProgress, onLayerChange]);
  return progress;
}

function Frost({ active, reduced }) {
  const points = useRef();
  const material = useRef();
  const particles = useMemo(() => {
    const positions = new Float32Array(180 * 3);
    for (let i = 0; i < 180; i++) {
      positions[i * 3] = Math.sin(i * 127.1) * 3.9;
      positions[i * 3 + 1] = 3.4 + (Math.sin(i * 311.7) + 1) * 1.6;
      positions[i * 3 + 2] = Math.cos(i * 73.3) * 3.9;
    }
    return positions;
  }, []);
  useFrame((_, delta) => {
    const dt = Math.min(delta, .05);
    const target = active ? .8 : 0;
    const opacity = material.current.uniforms.opacity;
    opacity.value = reduced ? target : THREE.MathUtils.damp(opacity.value, target, 3, dt);
    points.current.visible = opacity.value > .005;
    if (reduced || !points.current.visible) return;
    const attribute = points.current.geometry.attributes.position;
    for (let i = 0; i < attribute.count; i++) {
      const x = attribute.getX(i);
      const z = attribute.getZ(i);
      let y = attribute.getY(i) - dt * (.38 + (i % 7) * .055);
      if (y < elevation(x, z) + .08) y = 5.8;
      attribute.setY(i, y);
    }
    attribute.needsUpdate = true;
  });
  return (
    <points ref={points} frustumCulled={false}>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" args={[particles, 3]} />
      </bufferGeometry>
      <shaderMaterial ref={material} transparent depthWrite={false}
        uniforms={{ opacity: { value: 0 } }}
        vertexShader={`
          void main() {
            vec4 viewPosition = modelViewMatrix * vec4(position, 1.0);
            gl_PointSize = clamp(38.0 / max(-viewPosition.z, 0.1), 1.0, 4.0);
            gl_Position = projectionMatrix * viewPosition;
          }
        `}
        fragmentShader={`
          uniform float opacity;
          void main() {
            float radius = length(gl_PointCoord - 0.5);
            float edge = 1.0 - smoothstep(0.12, 0.5, radius);
            gl_FragColor = vec4(0.84, 0.94, 1.0, edge * opacity);
          }
        `} />
    </points>
  );
}

/**
 * Foto real de la prueba de campo "clavada" en la isla, como un letrero junto
 * al campo. Se monta una vez y solo cambia su visibilidad con el scroll.
 */
function PhotoCard({ x, z, src, label, caption, hidden = true }) {
  return (
    <group position={[x, elevation(x, z) + .02, z]} visible={!hidden}>
      <mesh position={[0, .2, 0]}>
        <cylinderGeometry args={[.012, .012, .4, 6]} />
        <meshBasicMaterial color="#e6f4c6" />
      </mesh>
      <Html position={[0, .42, 0]} center distanceFactor={3.2} zIndexRange={[18, 0]}
        style={{ pointerEvents: 'none', opacity: hidden ? 0 : 1, transform: hidden ? 'translateY(14px) scale(.94)' : 'none', transition: 'opacity .45s, transform .6s cubic-bezier(.32,.72,0,1)' }}>
        <figure style={{ margin: 0, width: 150, padding: 6, background: '#09090be6', border: '1px solid #ffffff26', borderRadius: 12, boxShadow: '0 14px 34px #000a', backdropFilter: 'blur(10px)' }}>
          <img src={src} alt="" width="138" height="184" loading="lazy" decoding="async"
            style={{ display: 'block', width: 138, height: 184, objectFit: 'cover', borderRadius: 8 }} />
          <figcaption style={{ padding: '7px 3px 2px', font: '10px/1.35 ui-monospace, monospace', color: '#f1f6e9' }}>
            <span style={{ display: 'block', color: '#a9e08c', fontSize: 8.5, letterSpacing: '.08em', textTransform: 'uppercase', marginBottom: 2 }}>{label}</span>
            {caption}
          </figcaption>
        </figure>
      </Html>
    </group>
  );
}

function Hotspot({ x, z, label, value, source, hidden = false, detail = false, compact = false }) {
  const height = compact ? .34 : .65;
  return (
    <group position={[x, elevation(x, z) + .06, z]} visible={!hidden}>
      <mesh position={[0, height * .42, 0]}>
        <cylinderGeometry args={[.008, .008, height * .84, 6]} />
        <meshBasicMaterial color="#e6f4c6" />
      </mesh>
      <mesh>
        <sphereGeometry args={[.065, 10, 8]} />
        <meshBasicMaterial color="#e6f4c6" />
      </mesh>
      <Html position={[0, height, 0]} center distanceFactor={compact ? undefined : 12} occlude={!detail} zIndexRange={[20, 0]} style={{ pointerEvents: 'none', opacity: hidden ? 0 : 1, transition: 'opacity .35s' }}>
        <div style={{ color: '#f1f6e9', background: '#09090bdb', backdropFilter: 'blur(12px)', border: '1px solid #ffffff1a', borderRadius: 9, padding: '9px 12px', minWidth: 135, font: '12px ui-monospace, monospace', fontVariantNumeric: 'tabular-nums', whiteSpace: 'nowrap' }}>
          <span style={{ display: 'block', color: '#bccfb8', fontSize: 10, marginBottom: 3 }}>{label}</span>
          <strong style={{ fontSize: 14 }}>{value}</strong>
          {source && <span style={{ display: 'block', color: '#8f978a', fontSize: 9, marginTop: 4, letterSpacing: '.04em' }}>{source}</span>}
        </div>
      </Html>
    </group>
  );
}

function Vegetation({ region, treeRegion, aridity, snow, reduced }) {
  // Posiciones fijas por bioma: al scrollear no aparece ni desaparece un árbol.
  const biome = BIOMES[treeRegion] ?? BIOMES[region] ?? DEFAULT_BIOME;
  const trunks = useRef();
  const canopies = useRef();
  const sway = useRef(0);
  const target = useMemo(() => new THREE.Color(), []);
  const canopyMaterial = useMemo(
    () => new THREE.MeshStandardMaterial({ color: '#4CAF50', roughness: .9, metalness: 0, flatShading: true }),
    []
  );
  useEffect(() => () => canopyMaterial.dispose(), [canopyMaterial]);

  const trees = useMemo(() => {
    const random = (n) => { const value = Math.sin(n * 12.9898) * 43758.5453; return value - Math.floor(value); };
    const planted = [];
    for (let i = 0; i < 260 && planted.length < biome.trees; i++) {
      const x = (random(i + 1) - .5) * 6.6;
      const z = (random(i + 7.3) - .5) * 6.6;
      if (Math.hypot(x, z) > 3.45) continue;
      if (isFarmSoil(x, z)) continue;
      if (z > CHANNEL_Z - .34) continue;
      if (Math.hypot(x - RESERVOIR[0], z - RESERVOIR[1]) < .66) continue;
      if (HOMES.some(([homeX, homeZ, scale]) => Math.hypot(x - homeX, z - homeZ) < .62 * scale + .2)) continue;
      if (SHEEP_PENS.some(({ bounds: [left, right, back, front] }) => x > left - .18 && x < right + .18 && z > back - .18 && z < front + .18)) continue;
      const y = elevation(x, z);
      if (y > biome.snowLine + .95) continue;
      planted.push({ x, z, y, scale: .68 + random(i + 3.1) * .62, yaw: random(i + 5.7) * Math.PI * 2 });
    }
    return planted;
  }, [biome]);

  useLayoutEffect(() => {
    if (!trunks.current || !canopies.current) return;
    const marker = new THREE.Object3D();
    trees.forEach((tree, index) => {
      const shape = biome.conifer ? [.74, 1.5, .74] : [1.16, .86, 1.16];
      const growth = .94 + .08 * Math.sin(index * 1.7);
      marker.position.set(tree.x, tree.y + .16 * tree.scale, tree.z);
      marker.rotation.set(0, tree.yaw, 0);
      marker.scale.setScalar(tree.scale * growth);
      marker.updateMatrix();
      trunks.current.setMatrixAt(index, marker.matrix);
      marker.position.y = tree.y + (biome.conifer ? .44 : .36) * tree.scale;
      marker.scale.set(shape[0], shape[1], shape[2]).multiplyScalar(tree.scale * growth);
      marker.updateMatrix();
      canopies.current.setMatrixAt(index, marker.matrix);
    });
    trunks.current.instanceMatrix.needsUpdate = true;
    canopies.current.instanceMatrix.needsUpdate = true;
  }, [trees, biome]);

  useFrame(({ clock }, delta) => {
    if (!canopies.current) return;
    canopyColor(aridity, snow, target);
    const dt = Math.min(delta, .05);
    canopyMaterial.color.lerp(target, reduced ? 1 : 1 - Math.exp(-dt * 2.4));
    if (reduced) return;
    sway.current += dt;
    const breeze = Math.sin(sway.current * .9) * .012;
    canopies.current.rotation.z = breeze;
    canopies.current.rotation.x = breeze * .45;
  });

  if (!trees.length) return null;
  return (
    <group>
      <instancedMesh ref={trunks} args={[undefined, undefined, trees.length]} castShadow receiveShadow frustumCulled={false}>
        <cylinderGeometry args={[.016, .026, .34, 6]} />
        <meshStandardMaterial color={biome.trunk} roughness={.92} flatShading />
      </instancedMesh>
      <instancedMesh ref={canopies} args={[undefined, undefined, trees.length]} material={canopyMaterial} castShadow receiveShadow frustumCulled={false}>
        <icosahedronGeometry args={[.19, 1]} />
      </instancedMesh>
    </group>
  );
}
function Diorama({ hotspots, fieldPhotos, progress, mode, climate, month, data, reduced, zoom, editorialLayout, fieldJourney, onEnterFields, wideFieldView, onZoomOut, wideIslandView, onWidenIslandView, onIslandInteract }) {
  // El aspecto del terreno lo manda la zona + el mes (datos reales).
  const biome = BIOMES[climate?.region] ?? DEFAULT_BIOME;
  const frost = clamp(climate?.frost ?? (mode === 'helada' ? .65 : .08), 0, 1);
  const et = Number.isFinite(climate?.et) && climate.et > 0 ? climate.et : 100;
  const balance = Number.isFinite(climate?.water) ? climate.water : -30;
  const deficit = clamp(Math.max(0, -balance) / et, 0, 1);
  const aridity = Number.isFinite(climate?.aridity)
    ? clamp(climate.aridity, 0, 1)
    : clamp(biome.aridity + .35 * (deficit - .5), 0, 1);
  const snow = Number.isFinite(climate?.snow)
    ? clamp(climate.snow, 0, 1)
    : clamp(biome.snow * (.45 + .55 * frost), 0, 1);
  const visualMode = aridity > .62 ? 'agua' : snow > .45 ? 'helada' : 'normal';
  const [inspect, setInspect] = useState(false);
  const inspection = useRef(false);
  const group = useRef();
  const surface = useRef();
  const rock = useRef();
  const controls = useRef();
  const cameraRig = useMemo(() => ({
    blend: 0,
    route: 0,
    pullback: 0,
    position: new THREE.Vector3(10, 8.5, 12),
    target: new THREE.Vector3(),
    field: new THREE.Vector3(),
  }), []);
  const touring = fieldJourney !== null;
  useEffect(() => {
    const tween = gsap.to(cameraRig, { blend: Number(touring), duration: reduced ? 0 : 1.25, ease: 'power2.inOut', overwrite: 'auto' });
    return () => tween.kill();
  }, [cameraRig, touring, reduced]);
  useEffect(() => {
    const tween = gsap.to(cameraRig, { pullback: Number(wideFieldView), duration: reduced ? 0 : .65, ease: 'power2.inOut', overwrite: 'auto' });
    return () => tween.kill();
  }, [cameraRig, wideFieldView, reduced]);
  useEffect(() => {
    if (fieldJourney === null) return;
    const tween = gsap.to(cameraRig, { route: fieldJourney, duration: reduced ? 0 : .32, ease: 'power2.out', overwrite: 'auto' });
    return () => tween.kill();
  }, [cameraRig, fieldJourney, reduced]);
  const { camera, gl } = useThree();
  const tilt = useRef();
  const dragging = useRef(false);
  const cursor = useRef({ x: 0, y: 0 });
  const { top, walls } = useMemo(buildTerrain, []);
  useEffect(() => {
    if (!editorialLayout) return;
    const canvas = gl.domElement;
    const ray = new THREE.Raycaster();
    const pointer = new THREE.Vector2();
    const hitsIsland = (event, bounds) => {
      pointer.set((event.clientX - bounds.left) / bounds.width * 2 - 1, 1 - (event.clientY - bounds.top) / bounds.height * 2);
      ray.setFromCamera(pointer, camera);
      return ray.intersectObjects([surface.current, rock.current], false).length > 0;
    };
    const pointerDown = (event) => {
      if (onIslandInteract && hitsIsland(event, canvas.getBoundingClientRect())) onIslandInteract();
    };
    // La rueda NUNCA se captura en el canvas: el scroll siempre mueve la
    // página, aunque el cursor esté sobre la isla. El 3D solo sigue al scroll.
    canvas.addEventListener('pointerdown', pointerDown);
    return () => {
      canvas.removeEventListener('pointerdown', pointerDown);
    };
  }, [camera, gl, editorialLayout, onIslandInteract]);
  const palette = useMemo(() => {
    const values = new Float32Array(top.attributes.position.count * 3);
    const color = new THREE.Color();
    const low = new THREE.Color(biome.low);
    const high = new THREE.Color(biome.high);
    const summit = new THREE.Color(biome.summit);
    const snowColor = new THREE.Color('#e8f4ff');
    const aridColor = new THREE.Color('#bf8b46');
    const lushColor = new THREE.Color('#2c7538');
    const dirt = new THREE.Color('#694a32');
    for (let i = 0; i < top.attributes.position.count; i++) {
      const height = top.attributes.position.getY(i);
      const x = top.attributes.position.getX(i);
      const z = top.attributes.position.getZ(i);
      const band = (Math.sin(x * 8 + z * 2) + 1) * .065;
      color.copy(low).lerp(high, clamp(height / 3.5 + band, 0, 1));
      const field = (Math.floor((x + 4) / 1.2) + Math.floor((z + 4) / .8)) % 3;
      if (height < 1.4) color.multiplyScalar([.73, 1.07, .89][field]);
      color.lerp(aridColor, aridity * clamp(1 - height / 2.9, 0, 1) * .62);
      if (biome.aridity < .3) color.lerp(lushColor, (1 - aridity) * clamp(1 - height / 2.6, 0, 1) * .45);
      color.lerp(summit, clamp((height - 1.65) / 1.9, 0, .85));
      color.lerp(snowColor, snow * clamp((height - biome.snowLine) / Math.max(.35, 3 - biome.snowLine), 0, 1));
      if (isFarmSoil(x, z)) {
        const furrow = .79 + .2 * Math.cos((x + 2.45) * 29.9) ** 2;
        color.copy(dirt).multiplyScalar(furrow);
        color.lerp(snowColor, snow * .55);
        color.lerp(aridColor, aridity * .3);
      }
      const grain = .91 + Math.sin(x * 29 + z * 13) * Math.cos(z * 31 - x * 10) * .065 + Math.sin(x * 12 - z * 11) * .055;
      color.multiplyScalar(grain);
      color.toArray(values, i * 3);
    }
    return values;
  }, [top, biome, aridity, snow]);
  const initialized = useRef(false);
  useEffect(() => {
    if (!initialized.current) {
      top.attributes.color.array.set(palette);
      top.attributes.color.needsUpdate = true;
      initialized.current = true;
    }
  }, [palette, top]);
  useEffect(() => {
    const move = (event) => {
      if (event.pointerType === 'touch') return;
      cursor.current = { x: event.clientX / innerWidth * 2 - 1, y: event.clientY / innerHeight * 2 - 1 };
    };
    const reset = () => { cursor.current = { x: 0, y: 0 }; };
    window.addEventListener('pointermove', move, { passive: true });
    window.addEventListener('blur', reset);
    document.documentElement.addEventListener('pointerleave', reset);
    return () => {
      window.removeEventListener('pointermove', move);
      window.removeEventListener('blur', reset);
      document.documentElement.removeEventListener('pointerleave', reset);
    };
  }, []);
  useEffect(() => () => { top.dispose(); walls.dispose(); }, [top, walls]);

  useFrame((state, delta) => {
    const dt = Math.min(delta, .05);
    const p = reduced ? 0 : progress.current;
    const blend = cameraRig.blend;
    const follow = !reduced && !dragging.current && blend < .015;
    tilt.current.rotation.x = THREE.MathUtils.damp(tilt.current.rotation.x, follow ? cursor.current.y * .065 : 0, 4, dt);
    tilt.current.rotation.z = THREE.MathUtils.damp(tilt.current.rotation.z, follow ? -cursor.current.x * .065 : 0, 4, dt);
    group.current.rotation.y = THREE.MathUtils.damp(group.current.rotation.y, touring ? 0 : -.18 + p * Math.PI * 1.7, 3, dt);
    const wide = state.size.width > 760;
    const bob = reduced ? 0 : Math.sin(state.clock.elapsedTime * .65) * .08;
    group.current.position.y = (bob - (onEnterFields && !wide ? 1.5 : 0)) * (1 - blend);
    group.current.position.x = onEnterFields && wide ? 1.5 * (1 - blend) : 0;
    const framing = onEnterFields && wide ? -3.8 * (1 - blend) : 0;
    if (Math.abs(camera.filmOffset - framing) > .002) {
      camera.filmOffset = framing;
      camera.updateProjectionMatrix();
    }
    const scale = onEnterFields ? Math.min(wide ? 1.13 : 1.05, camera.aspect * 1.53) : Math.min(state.viewport.width / 10.5, state.viewport.height / 8.4, 1.58);
    const islandScale = wideIslandView ? .81 : 1;
    const targetScale = scale * (1 + Math.sin(p * Math.PI * 3) * .15) * zoom.current * islandScale;
    const nextScale = reduced ? targetScale : THREE.MathUtils.damp(group.current.scale.x, targetScale, 5, dt);
    group.current.scale.setScalar(THREE.MathUtils.lerp(nextScale, 1, blend));
    if (onEnterFields && controls.current) {
      if (blend < .005 && !touring) {
        controls.current.enabled = true;
        cameraRig.position.copy(camera.position);
        cameraRig.target.copy(controls.current.target);
      } else {
        controls.current.enabled = false;
        const route = clamp(cameraRig.route, 0, 2);
        const field = Math.min(Math.floor(route), 1);
        const x = THREE.MathUtils.lerp(FIELD_CENTERS[field], FIELD_CENTERS[field + 1], route - field);
        const y = elevation(x, 2.05);
        const pullback = cameraRig.pullback;
        cameraRig.field.set(x + .54, y + 1.55 + 1.25 * pullback, 5.02 + 2.15 * pullback);
        camera.position.copy(cameraRig.position).lerp(cameraRig.field, blend);
        cameraRig.field.set(x, y + .18, 1.78 + (wide ? 0 : 1.65 * pullback));
        controls.current.target.copy(cameraRig.target).lerp(cameraRig.field, blend);
        camera.lookAt(controls.current.target);
      }
    }
    if (editorialLayout && !onEnterFields) {
      const closeEnough = nextScale / (scale * (1 + Math.sin(p * Math.PI * 3) * .15)) >= (inspection.current ? 1.13 : 1.22);
      if (closeEnough !== inspection.current) {
        inspection.current = closeEnough;
        setInspect(closeEnough);
      }
    }
    const attribute = top.attributes.color;
    const alpha = reduced ? 1 : 1 - Math.exp(-3.5 * dt);
    let changed = false;
    for (let i = 0; i < palette.length; i++) {
      const difference = palette[i] - attribute.array[i];
      if (Math.abs(difference) > .0001) {
        attribute.array[i] += difference * alpha;
        changed = true;
      }
    }
    attribute.needsUpdate = changed;
  });
  const frostValue = Number.isFinite(data?.prob_helada) ? Math.round(clamp(data.prob_helada, 0, 1) * 100) + '%' : 'Data pending';
  const waterValue = Number.isFinite(data?.balance_hidrico_mm) ? data.balance_hidrico_mm + ' mm' : 'Data pending';
  const droughtValue = Number.isFinite(data?.sequia) ? Math.round(clamp(data.sequia, 0, 1) * 100) + '% deficit' : 'Data pending';
  const altitude = Number.isFinite(data?.elevacion_m) ? data.elevacion_m.toLocaleString('en-US') + ' m' : '3,200 m · pilot';
  const validMonth = Number.isInteger(month) && month >= 1 && month <= 12;
  const monthLabel = validMonth ? new Intl.DateTimeFormat('en', { month: 'long', timeZone: 'UTC' }).format(new Date(Date.UTC(2026, month - 1, 1))) : '';
  return (
    <>
      <ambientLight intensity={.24} />
      <hemisphereLight args={['#f2ffd6', '#3b3028', 1.2]} />
      <directionalLight castShadow position={[-6, 8, 4]} intensity={2.45} color="#ffe0b3"
        shadow-mapSize={[1536, 1536]} shadow-camera-left={-8} shadow-camera-right={8}
        shadow-camera-top={8} shadow-camera-bottom={-8} shadow-camera-far={28}
        shadow-normalBias={.025} shadow-bias={-.0002} shadow-radius={3} />
      <directionalLight position={[6, 4, -5]} intensity={1.15} color="#a9cefa" />
      <group ref={tilt}>
        <group ref={group}>
          <mesh ref={surface} geometry={top} receiveShadow castShadow>
            <meshStandardMaterial onBeforeCompile={surfaceGrain} vertexColors roughness={.88} />
          </mesh>
          <mesh ref={rock} geometry={walls} receiveShadow>
            <meshStandardMaterial onBeforeCompile={surfaceGrain} vertexColors roughness={1} side={THREE.DoubleSide} />
          </mesh>
          <Frost active={snow > .3} reduced={reduced} />
          <Crops mode={visualMode} data={data} month={month} reduced={reduced} region={climate?.region} />
          <FarmDetails terrain={top} mode={visualMode} data={data} month={month} reduced={reduced} region={climate?.region} aridity={aridity} snow={snow} />
          <Vegetation region={climate?.region} treeRegion={climate?.treeRegion} aridity={aridity} snow={snow} reduced={reduced} />
          <FloatingRocks reduced={reduced} />
          <IslandEdge reduced={reduced} winter={snow > .45} />
          <SummitRocks winter={snow > .45} />
          <SummitClouds reduced={reduced} winter={snow > .45} />
          {!onEnterFields && <Hotspot x={-1.1} z={-.9} label="Zone elevation" value={altitude} />}
          {!onEnterFields && !inspect && (!editorialLayout || snow > .45 || aridity > .62) && <Hotspot x={2.2} z={1.45} label={snow > .45 ? 'Frost probability · ' + monthLabel : aridity > .62 ? 'Water deficit · ' + monthLabel : 'Procedural relief'} value={snow > .45 ? frostValue : aridity > .62 ? waterValue : 'Andes · Huánuco'} />}
          {fieldPhotos?.map((photo) => <PhotoCard key={photo.id} x={photo.x} z={photo.z} src={photo.src} label={photo.label} caption={photo.caption} hidden={photo.hidden} />)}
          {hotspots?.map((spot) => <Hotspot key={spot.id} detail x={spot.x} z={spot.z} label={spot.label} value={spot.value} source={spot.source} hidden={spot.hidden} />)}
          {inspect && !onEnterFields && <>
            <Hotspot detail x={-1.25} z={2.7} label={'Frost · ' + monthLabel} value={frostValue} />
            <Hotspot detail x={2.05} z={1.05} label={'Water balance · ' + monthLabel} value={waterValue} />
            <Hotspot detail x={.1} z={-.4} label={'Drought risk · ' + monthLabel} value={droughtValue} />
          </>}
        </group>
      </group>
      <OrbitControls ref={controls} makeDefault enableZoom={false} enablePan={false} enableDamping dampingFactor={.07}
        minPolarAngle={Math.PI * .32} maxPolarAngle={Math.PI * .32} rotateSpeed={.65}
        onStart={() => { dragging.current = true; }} onEnd={() => { dragging.current = false; }}
        touches={{ ONE: editorialLayout ? -1 : THREE.TOUCH.ROTATE }} />
    </>
  );
}

/**
 * Avisa una sola vez cuando el canvas ya pintó sus primeros frames: los
 * shaders están compilados y la isla es visible. El loader espera esta señal.
 */
function FirstFrames({ onReady, frames = 3 }) {
  const count = useRef(0);
  useFrame(() => {
    if (count.current > frames) return;
    count.current += 1;
    if (count.current === frames) onReady?.();
  });
  return null;
}

class TerrainBoundary extends Component {
  state = { failed: false };
  static getDerivedStateFromError() { return { failed: true }; }
  componentDidCatch() { this.props.onFail?.(); }
  render() {
    if (this.state.failed) return <p role="status" style={{ padding: 24 }}>3D rendering is unavailable on this device.</p>;
    return this.props.children;
  }
}

/**
 * Standalone Astro island: <MuyuyTerrain client:only="react" />.
 * mode: normal | helada | agua. Omit it to use the manual/scroll selector.
 * scrollProgress: optional 0–1 value, suitable for GSAP ScrollTrigger onUpdate.
 * scrollTarget: optional CSS selector or React ref defining the scroll story.
 * data: { elevacion_m, prob_helada (0–1), balance_hidrico_mm } for the supplied month.
 * Missing climate values produce an illustrative color palette and pending labels.
 * fixed defaults to true; use fixed={false} to place the canvas in a parent layout.
 */
export default function MuyuyTerrain({
  mode,
  climate,
  onModeChange,
  scrollProgress,
  scrollTarget,
  data,
  month = 6,
  showControls = true,
  fixed = true,
  motionEnabled,
  editorialLayout = false,
  fieldJourney = null,
  onEnterFields,
  wideFieldView = false,
  onZoomOut,
  wideIslandView = false,
  onWidenIslandView,
  onIslandInteract,
  onReady,
  /** Etiquetas de datos reales ancladas a la isla: [{ id, x, z, label, value, source }]. */
  hotspots,
  /** Fotos reales del campo dentro del recorrido: [{ id, x, z, src, label, caption, hidden }]. */
  fieldPhotos,
  className = '',
  style,
}) {
  const [manual, setManual] = useState('scroll');
  const zoom = useRef(1);
  const [scrollMode, setScrollMode] = useState('normal');
  const progress = usePageProgress(scrollTarget, scrollProgress, setScrollMode);
  const systemReduced = useReducedMotion();
  const reduced = motionEnabled === undefined ? systemReduced : !motionEnabled;
  const controlled = MODES.includes(mode);
  const activeMode = controlled ? mode : manual === 'scroll' ? scrollMode : manual;
  const selectMode = (next) => {
    setManual(next);
    onModeChange?.(next === 'scroll' ? scrollMode : next);
  };
  return (
    <section className={`muyuy-terrain ${editorialLayout ? 'muyuy-editorial' : ''} ${className}`} aria-label="Muyuy topographic diorama"
      style={{ position: fixed ? 'fixed' : 'relative', inset: fixed ? 0 : undefined, zIndex: 0, width: '100%', height: '100svh', color: '#eff5e8', background: '#09090B', ...style }}>
      <style>{`
        .muyuy-terrain button { transition: transform 180ms cubic-bezier(.32,.72,0,1), background-color 180ms; }
        .muyuy-terrain button:active:not(:disabled) { transform: scale(.98); }
        .muyuy-terrain button:focus-visible { outline: 2px solid #d7eca1; outline-offset: 4px; }
        .muyuy-terrain button:disabled { opacity: .55; cursor: default !important; }
        .muyuy-editorial .muyuy-viewport { position: absolute; inset: 0 0 0 28%; }
        .muyuy-terrain .muyuy-viewport.muyuy-field-viewport { position: absolute; inset: 0; }
        .muyuy-editorial .muyuy-canvas canvas { cursor: grab; touch-action: pan-y !important; }
        .muyuy-editorial .muyuy-canvas canvas:active { cursor: grabbing; }
        @media (max-width: 760px) {
          .muyuy-editorial .muyuy-viewport { inset: 46% 0 0; }
        }
        @media (prefers-reduced-motion: reduce) { .muyuy-terrain button { transition: none; } }
      `}</style>
      <TerrainBoundary onFail={onReady}>
        <div className={onEnterFields ? 'muyuy-viewport muyuy-field-viewport' : 'muyuy-viewport'} style={editorialLayout ? undefined : { width: '100%', height: '100%' }}>
        <Canvas shadows className="muyuy-canvas" camera={{ position: [10, 8.5, 12], fov: 39, near: .1, far: 80 }} dpr={[1, 1.5]}
          gl={{ antialias: true, alpha: true, powerPreference: 'low-power' }} style={{ touchAction: 'pan-y' }}>
          <Diorama hotspots={hotspots} fieldPhotos={fieldPhotos} progress={progress} mode={activeMode} climate={climate} month={month} data={data} reduced={reduced} zoom={zoom} editorialLayout={editorialLayout} fieldJourney={fieldJourney} onEnterFields={onEnterFields} wideFieldView={wideFieldView} onZoomOut={onZoomOut} wideIslandView={wideIslandView} onWidenIslandView={onWidenIslandView} onIslandInteract={onIslandInteract} />
          <FirstFrames onReady={onReady} />
        </Canvas>
        </div>
      </TerrainBoundary>
      {showControls && (
        <fieldset style={{ position: 'absolute', zIndex: 25, bottom: 24, left: '50%', transform: 'translateX(-50%)', display: 'flex', gap: 5, padding: 8, border: '1px solid #ffffff1a', borderRadius: 13, background: '#09090bdb', backdropFilter: 'blur(16px)', maxWidth: '95%', flexWrap: 'wrap', justifyContent: 'center' }}>
          <legend style={{ font: '11px system-ui', padding: '0 6px' }}>Terrain layer</legend>
          {['scroll', ...MODES].map((option) => {
            const selected = controlled ? option === mode : option === manual;
            return <button key={option} type="button" aria-pressed={selected} disabled={controlled && !onModeChange}
              onClick={() => selectMode(option)}
              style={{ font: '600 12px system-ui', border: '1px solid #9aaf7966', borderRadius: 7, padding: '9px 12px', cursor: 'pointer', color: selected ? '#1d3020' : '#edf4df', background: selected ? '#d7eca1' : 'transparent' }}>
              {option === 'scroll' ? 'Follow scroll' : MODE_LABELS[option]}
            </button>;
          })}
        </fieldset>
      )}
      <span style={{ position: 'absolute', top: 18, left: 20, font: '12px system-ui', color: '#d6e2ce', pointerEvents: 'none' }}>Drag to explore · Scroll to change layers</span>
    </section>
  );
}

