import React, { Component, useLayoutEffect, useRef, useState } from 'react';
import { Canvas, useThree } from '@react-three/fiber';
import { OrbitControls } from '@react-three/drei';
import { Color, Object3D } from 'three';

const scenarios = [
  { name: 'Bajo', moisture: 32, growth: 0.69, soil: '#a27a48', leaves: ['#8a912c', '#9c9d36', '#747a2f'] },
  { name: 'Medio', moisture: 61, growth: 1, soil: '#805432', leaves: ['#4a8b36', '#68a446', '#337034'] },
  { name: 'Alto', moisture: 84, growth: 0.88, soil: '#5a402f', leaves: ['#54883b', '#639643', '#637b2b'] },
];

const rows = Array.from({ length: 8 }, (_, i) => -3.63 + i * 0.73);
const plants = rows.flatMap((x, row) => Array.from({ length: 12 }, (_, column) => ({
  x: x + Math.sin(row * 9 + column * 5) * 0.065,
  z: -2.88 + column * 0.5,
  size: 0.78 + (Math.cos(row * 5 + column * 17) + 1) * 0.2,
  angle: row * 1.5 + column * 2.4,
  shade: (row + column) % 3,
})));

function Corn({ scenario }) {
  const stems = useRef();
  const leaves = useRef();
  const tips = useRef();
  const invalidate = useThree((state) => state.invalidate);

  useLayoutEffect(() => {
    const marker = new Object3D();
    const color = new Color();

    plants.forEach(({ x, z, size, angle, shade }, index) => {
      const growth = size * scenario.growth;
      marker.position.set(x, 0.16 + growth * 0.37, z);
      marker.rotation.set(0, 0, 0);
      marker.scale.set(1, growth, 1);
      marker.updateMatrix();
      stems.current.setMatrixAt(index, marker.matrix);

      marker.position.y = 0.16 + growth * 0.78;
      marker.updateMatrix();
      tips.current.setMatrixAt(index, marker.matrix);

      for (let leaf = 0; leaf < 4; leaf++) {
        const direction = angle + leaf * Math.PI * 0.9;
        const offset = 0.13 * growth;
        marker.position.set(x + Math.cos(direction) * offset, 0.32 + leaf * 0.11 * growth, z - Math.sin(direction) * offset);
        marker.rotation.set(0, direction, (leaf - 1) * 0.13 + 0.38, 'YXZ');
        marker.scale.set(growth * 0.24, growth * 0.035, growth * 0.078);
        marker.updateMatrix();
        leaves.current.setMatrixAt(index * 4 + leaf, marker.matrix);
        leaves.current.setColorAt(index * 4 + leaf, color.set(scenario.leaves[(shade + leaf) % 3]));
      }
    });

    for (const mesh of [stems.current, leaves.current, tips.current]) {
      mesh.instanceMatrix.needsUpdate = true;
      if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
    }
    invalidate();
  }, [scenario, invalidate]);

  return (
    <>
      <instancedMesh ref={stems} args={[undefined, undefined, plants.length]} frustumCulled={false}>
        <cylinderGeometry args={[0.024, 0.033, 0.74, 5]} />
        <meshStandardMaterial color="#6e922d" roughness={0.95} />
      </instancedMesh>
      <instancedMesh ref={leaves} args={[undefined, undefined, plants.length * 4]} frustumCulled={false}>
        <sphereGeometry args={[1, 6, 3]} />
        <meshStandardMaterial roughness={0.82} />
      </instancedMesh>
      <instancedMesh ref={tips} args={[undefined, undefined, plants.length]} frustumCulled={false}>
        <coneGeometry args={[0.043, 0.16, 5]} />
        <meshStandardMaterial color="#dfb74e" />
      </instancedMesh>
    </>
  );
}

function Block({ position, size, color, rotation }) {
  return (
    <mesh position={position} rotation={rotation} receiveShadow castShadow>
      <boxGeometry args={size} />
      <meshStandardMaterial color={color} roughness={0.95} />
    </mesh>
  );
}

function Tree({ position, scale = 1, color }) {
  return (
    <group position={position} scale={scale}>
      <Block position={[0, 0.36, 0]} size={[0.17, 0.72, 0.17]} color="#755333" />
      {[[0, 0.95, 0, 0.57], [-0.23, 0.77, 0.1, 0.42], [0.29, 0.82, 0.08, 0.43], [0.04, 1.29, -0.07, 0.43]].map(([x, y, z, radius], i) => (
        <mesh key={i} position={[x, y, z]} scale={[1, 1.08, 0.88]} castShadow>
          <icosahedronGeometry args={[radius, 1]} />
          <meshStandardMaterial color={i === 0 ? '#476b34' : color} flatShading />
        </mesh>
      ))}
    </group>
  );
}

function Farm({ scenario, rotation }) {
  const viewport = useThree((state) => state.size);
  const camera = useThree((state) => state.camera);
  const invalidate = useThree((state) => state.invalidate);

  useLayoutEffect(() => {
    camera.zoom = Math.min(viewport.width / 13.2, viewport.height / 9.4);
    camera.updateProjectionMatrix();
    invalidate();
  }, [camera, viewport.width, viewport.height, invalidate]);

  return (
    <>
      <hemisphereLight args={['#fff7de', '#786647', 2.3]} />
      <directionalLight position={[-4, 10, 6]} intensity={2.1} color="#fff0cd" castShadow
        shadow-mapSize={[1024, 1024]} shadow-camera-left={-7} shadow-camera-right={7}
        shadow-camera-top={7} shadow-camera-bottom={-7} shadow-normalBias={0.03} />
      <group rotation={[0, rotation, 0]}>
        <Block position={[0, -0.54, 0]} size={[9.6, 0.7, 7.5]} color="#674831" />
        <Block position={[0, -0.16, 0]} size={[9.6, 0.22, 7.5]} color="#997247" />
        <Block position={[0, -0.035, 0]} size={[9.62, 0.085, 7.52]} color="#8a9d51" />
        <Block position={[-1.1, 0.045, -0.1]} size={[6.2, 0.11, 6.3]} color={scenario.soil} />
        {rows.map((x) => <Block key={x} position={[x, 0.115, -0.1]} size={[0.46, 0.11, 6.13]} color={scenario.soil} />)}
        <Corn scenario={scenario} />

        <Block position={[2.38, 0.03, 0]} size={[0.57, 0.055, 7.44]} color="#c4a772" />
        <Block position={[2.94, 0.02, 0.45]} size={[0.35, 0.05, 6.55]} color="#486c64" />
        <Block position={[2.94, 0.05, 0.45]} size={[0.23, 0.04, 6.5]} color="#609c95" />
        <Block position={[-1.1, 0.13, 2.99]} size={[6.12, 0.055, 0.07]} color="#455b53" />
        <Block position={[2.3, 0.13, 2.99]} size={[0.7, 0.055, 0.07]} color="#455b53" />

        <group position={[3.79, 0, -1.72]}>
          <Block position={[0, 0.38, 0]} size={[1.45, 0.76, 1.67]} color="#d7bc89" />
          <mesh position={[0, 0.95, 0]} rotation={[0, Math.PI / 4, 0]} castShadow>
            <coneGeometry args={[1.26, 0.57, 4]} />
            <meshStandardMaterial color="#a4583a" roughness={0.85} flatShading />
          </mesh>
          <Block position={[0, 0.3, 0.85]} size={[0.38, 0.61, 0.056]} color="#6b5040" />
          <Block position={[0.736, 0.46, 0.17]} size={[0.038, 0.27, 0.31]} color="#43584d" />
        </group>
        <Tree position={[3.98, 0, 1.85]} scale={1.11} color="#71964b" />
        <Tree position={[4.06, 0, 3.02]} scale={0.72} color="#759f55" />
        <Tree position={[-4.33, 0, -3.12]} scale={0.86} color="#789549" />
        <Tree position={[1.7, 0, -3.15]} scale={0.6} color="#749b4b" />

        <mesh position={[3.73, 0.34, 0.45]} castShadow>
          <cylinderGeometry args={[0.43, 0.43, 0.65, 18]} />
          <meshStandardMaterial color="#638982" />
        </mesh>
        <mesh position={[3.73, 0.68, 0.45]}>
          <cylinderGeometry args={[0.45, 0.45, 0.06, 18]} />
          <meshStandardMaterial color="#8db1a4" />
        </mesh>
      </group>
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, -0.91, 0]} receiveShadow>
        <planeGeometry args={[200, 200]} />
        <shadowMaterial opacity={0.2} />
      </mesh>
      <OrbitControls enablePan={false} enableZoom={false} minPolarAngle={0.5} maxPolarAngle={1.24} />
    </>
  );
}

function SceneUnavailable() {
  return <p className="scene-placeholder">La vista 3D no está disponible en este navegador. Puedes seguir comparando los niveles de riego.</p>;
}

class SceneBoundary extends Component {
  state = { failed: false };

  static getDerivedStateFromError() {
    return { failed: true };
  }

  render() {
    return this.state.failed ? <SceneUnavailable /> : this.props.children;
  }
}

export default function Escena3D() {
  const [selection, setSelection] = useState(1);
  const [rotation, setRotation] = useState(0);
  const scenario = scenarios[selection];

  return (
    <>
      <div className="scene">
        <SceneBoundary>
          <Canvas
            orthographic
            shadows
            dpr={[1, 1.5]}
            frameloop="demand"
            camera={{ position: [9, 7.3, 11], near: 0.1, far: 80 }}
            aria-label="Parcela de maíz en tres dimensiones"
          >
            <Farm scenario={scenario} rotation={rotation} />
          </Canvas>
        </SceneBoundary>
        <div className="scene-tools">
          <span>Arrastra para girar</span>
          <button type="button" aria-label="Girar parcela a la izquierda" onClick={() => setRotation((angle) => angle - Math.PI / 4)}>↶</button>
          <button type="button" aria-label="Girar parcela a la derecha" onClick={() => setRotation((angle) => angle + Math.PI / 4)}>↷</button>
        </div>
      </div>
      <div className="demo-controls">
        <fieldset>
          <legend>Nivel de riego</legend>
          <div className="segments">
            {scenarios.map(({ name }, index) => (
              <label key={name}>
                <input type="radio" name="irrigation" checked={selection === index} onChange={() => setSelection(index)} />
                <span>{name}</span>
              </label>
            ))}
          </div>
        </fieldset>
        <div className="moisture" aria-live="polite">
          <span>Humedad simulada</span>
          <strong>{scenario.moisture}<small>%</small></strong>
        </div>
      </div>
    </>
  );
}
