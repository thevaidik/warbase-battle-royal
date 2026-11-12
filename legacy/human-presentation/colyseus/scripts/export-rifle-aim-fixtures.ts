import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { sampleAimedPose } from '../src/animated-hitboxes.js';

type PoseFrame = ReadonlyArray<readonly [number, number, number]>;
type PoseData = { bones: string[] };

const poseDataPath = fileURLToPath(new URL('../src/data/soldier_hit_poses.json', import.meta.url));
const { bones } = JSON.parse(readFileSync(poseDataPath, 'utf8')) as PoseData;
const animations = ['firing', 'firing walk'] as const;
const phases = [0.1, 0.2] as const;
const pitches = [-0.3, 0.0, 0.3] as const;

function outputPath(args: string[]): string {
	for (let index = 0; index < args.length; index++) {
		if (args[index] === '--out' && args[index + 1]) return resolve(args[index + 1]);
		if (args[index].startsWith('--out=')) return resolve(args[index].slice('--out='.length));
	}
	throw new Error('Usage: node --import tsx scripts/export-rifle-aim-fixtures.ts --out /tmp/warbase-rifle-aim-fixtures.json');
}

function main(): void {
	const cases: Array<{ animation: string; phase: number; pitch: number; points: PoseFrame }> = [];
	for (const animation of animations) {
		for (const phase of phases) {
			for (const pitch of pitches) {
				const points = sampleAimedPose(animation, phase, pitch);
				if (!points || points.length !== bones.length) {
					throw new Error(`No complete aimed pose for ${animation} phase=${phase} pitch=${pitch}`);
				}
				cases.push({ animation, phase, pitch, points });
			}
		}
	}
	const document = { version: 1, bones, cases };
	const path = outputPath(process.argv.slice(2));
	writeFileSync(path, `${JSON.stringify(document, null, 2)}\n`);
	console.log(`Wrote ${cases.length} aimed-rifle cases (${bones.length} bones each) to ${path}`);
}

try {
	main();
} catch (error) {
	console.error(error instanceof Error ? error.message : error);
	process.exitCode = 1;
}
