import type { APIRoute, GetStaticPaths } from 'astro';
import terrain from '../../../../terreno3d/index.html?raw';
import three from '../../../../terreno3d/three.module.js?raw';
import license from '../../../../terreno3d/THREE-LICENSE.txt?raw';

const assets = [
  { asset: 'index.html', body: terrain, mimeType: 'text/html' },
  { asset: 'three.module.js', body: three, mimeType: 'text/javascript' },
  { asset: 'THREE-LICENSE.txt', body: license, mimeType: 'text/plain' },
];

export const getStaticPaths = (() => assets.map(({ asset, ...props }) => ({
  params: { asset },
  props,
}))) satisfies GetStaticPaths;

export const GET: APIRoute = ({ props }) => new Response(props.body, {
  headers: { 'Content-Type': props.mimeType + '; charset=utf-8' },
});
