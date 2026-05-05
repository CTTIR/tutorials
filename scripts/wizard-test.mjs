/*
 * Wizard state-machine tests. Run with `node --test scripts/wizard-test.mjs`.
 *
 * Verifies:
 *   - every leaf in LEAVES is reachable from START
 *   - every leaf target in NODES exists in LEAVES
 *   - every `next` edge points to a defined NODE
 *   - every choice has a unique token within its parent node
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const src = readFileSync(resolve(__dirname, '..', 'js', 'wizard.js'), 'utf8');

const stripped = src.replace(/link\(([^)]*)\)/g, 'String($1)');
const mod = new Function(
  'window', 'document',
  `${stripped}\nreturn { NODES, LEAVES };`
)(
  { location: { pathname: '/', href: 'http://x/' }, history: { replaceState() {} } },
  { addEventListener() {}, getElementById() { return null; }, createElement() { return {}; }, activeElement: null }
);

const { NODES, LEAVES } = mod;

test('every leaf referenced by a choice exists in LEAVES', () => {
  for (const [nodeId, node] of Object.entries(NODES)) {
    for (const choice of node.choices) {
      if (choice.leaf) {
        assert.ok(LEAVES[choice.leaf], `Node ${nodeId} references missing leaf ${choice.leaf}`);
      }
    }
  }
});

test('every `next` choice points to a defined node', () => {
  for (const [nodeId, node] of Object.entries(NODES)) {
    for (const choice of node.choices) {
      if (choice.next) {
        assert.ok(NODES[choice.next], `Node ${nodeId} references missing node ${choice.next}`);
      }
    }
  }
});

test('every node either has choices or is a leaf', () => {
  for (const [nodeId, node] of Object.entries(NODES)) {
    assert.ok(Array.isArray(node.choices) && node.choices.length > 0,
      `Node ${nodeId} has no choices`);
    for (const choice of node.choices) {
      assert.ok(choice.next || choice.leaf, `Choice in ${nodeId} has neither next nor leaf`);
    }
  }
});

test('choice tokens are unique within each node', () => {
  for (const [nodeId, node] of Object.entries(NODES)) {
    const tokens = node.choices.map((c) => c.token);
    assert.strictEqual(new Set(tokens).size, tokens.length,
      `Duplicate tokens in node ${nodeId}`);
  }
});

test('every leaf is reachable from START', () => {
  const reachable = new Set();
  const queue = [{ nodeId: 'START', visited: new Set(['START']) }];
  while (queue.length) {
    const { nodeId, visited } = queue.shift();
    const node = NODES[nodeId];
    for (const choice of node.choices) {
      if (choice.leaf) reachable.add(choice.leaf);
      if (choice.next && !visited.has(choice.next)) {
        const nextVisited = new Set(visited);
        nextVisited.add(choice.next);
        queue.push({ nodeId: choice.next, visited: nextVisited });
      }
    }
  }
  for (const id of Object.keys(LEAVES)) {
    assert.ok(reachable.has(id), `Leaf ${id} is not reachable from START`);
  }
});

test('every leaf has a page URL and a rationale', () => {
  for (const [id, leaf] of Object.entries(LEAVES)) {
    assert.ok(leaf.name, `Leaf ${id} missing name`);
    assert.ok(leaf.page, `Leaf ${id} missing page`);
    assert.ok(leaf.rationale && leaf.rationale.length > 20, `Leaf ${id} missing rationale`);
  }
});
