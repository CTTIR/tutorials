/*
 * Zoom + pan controls for the static decision tree.
 *
 * Wraps the Mermaid-rendered diagram in a scrollable viewport and exposes
 * zoom in/out/reset/fit/fullscreen buttons plus Ctrl+wheel zoom and
 * click-drag panning. Designed to be resilient to Mermaid's asynchronous
 * render -- we wait for the <svg> to appear inside the viewport before
 * wiring up transform handlers.
 */

(function () {
  'use strict';

  const MIN = 0.4;
  const MAX = 3;
  const STEP = 0.15;

  const viewport = document.getElementById('dt-diagram-viewport');
  if (!viewport) return;

  const toolbar = document.querySelector('.dt-zoom-toolbar');
  const readout = toolbar ? toolbar.querySelector('.dt-zoom-readout') : null;

  let scale = 1;
  let panning = false;
  let startX = 0, startY = 0, startScrollL = 0, startScrollT = 0;

  function getMermaid() {
    return viewport.querySelector('.mermaid');
  }

  function applyScale() {
    const m = getMermaid();
    if (!m) return;
    m.style.transform = `scale(${scale})`;
    if (readout) readout.textContent = `${Math.round(scale * 100)}%`;
  }

  function zoomTo(next, anchor) {
    const clamped = Math.max(MIN, Math.min(MAX, next));
    if (clamped === scale) return;

    // Keep the anchor point stable within the viewport when zooming.
    if (anchor) {
      const rect = viewport.getBoundingClientRect();
      const ax = anchor.clientX - rect.left + viewport.scrollLeft;
      const ay = anchor.clientY - rect.top + viewport.scrollTop;
      const ratio = clamped / scale;
      viewport.scrollLeft = ax * ratio - (anchor.clientX - rect.left);
      viewport.scrollTop = ay * ratio - (anchor.clientY - rect.top);
    }

    scale = clamped;
    applyScale();
  }

  function fit() {
    const m = getMermaid();
    const svg = m && m.querySelector('svg');
    if (!svg) return;
    const svgWidth = svg.getBoundingClientRect().width / scale;
    const viewportWidth = viewport.clientWidth - 32; // account for padding
    if (svgWidth > 0) {
      const next = Math.max(MIN, Math.min(MAX, viewportWidth / svgWidth));
      scale = next;
      applyScale();
      viewport.scrollLeft = 0;
      viewport.scrollTop = 0;
    }
  }

  function reset() {
    scale = 1;
    applyScale();
    viewport.scrollLeft = 0;
    viewport.scrollTop = 0;
  }

  function toggleFullscreen() {
    viewport.classList.toggle('is-fullscreen');
  }

  // Toolbar button handlers
  if (toolbar) {
    toolbar.addEventListener('click', (ev) => {
      const btn = ev.target.closest('[data-dt-zoom]');
      if (!btn) return;
      const action = btn.getAttribute('data-dt-zoom');
      if (action === 'in')         zoomTo(scale + STEP);
      else if (action === 'out')   zoomTo(scale - STEP);
      else if (action === 'reset') reset();
      else if (action === 'fit')   fit();
      else if (action === 'fullscreen') toggleFullscreen();
    });
  }

  // Ctrl + wheel zoom (keeps cursor position stable)
  viewport.addEventListener('wheel', (ev) => {
    if (!ev.ctrlKey) return;
    ev.preventDefault();
    const delta = ev.deltaY < 0 ? STEP : -STEP;
    zoomTo(scale + delta, ev);
  }, { passive: false });

  // Click-drag panning (pointer events handle mouse + touch)
  viewport.addEventListener('pointerdown', (ev) => {
    // Don't start panning on clicks that target a node link
    if (ev.target.closest('a')) return;
    panning = true;
    viewport.setPointerCapture(ev.pointerId);
    startX = ev.clientX;
    startY = ev.clientY;
    startScrollL = viewport.scrollLeft;
    startScrollT = viewport.scrollTop;
  });

  viewport.addEventListener('pointermove', (ev) => {
    if (!panning) return;
    viewport.scrollLeft = startScrollL - (ev.clientX - startX);
    viewport.scrollTop = startScrollT - (ev.clientY - startY);
  });

  function endPan(ev) {
    if (!panning) return;
    panning = false;
    try { viewport.releasePointerCapture(ev.pointerId); } catch (_) {}
  }
  viewport.addEventListener('pointerup', endPan);
  viewport.addEventListener('pointercancel', endPan);

  // Keyboard shortcuts while viewport is focused
  viewport.setAttribute('tabindex', '0');
  viewport.addEventListener('keydown', (ev) => {
    if (ev.key === '+' || ev.key === '=') { zoomTo(scale + STEP); ev.preventDefault(); }
    else if (ev.key === '-') { zoomTo(scale - STEP); ev.preventDefault(); }
    else if (ev.key === '0') { reset(); ev.preventDefault(); }
    else if (ev.key === 'Escape' && viewport.classList.contains('is-fullscreen')) {
      toggleFullscreen();
    }
  });

  // Wait for Mermaid to finish rendering before applying the initial scale.
  function waitForMermaid(attempt) {
    const m = getMermaid();
    if (m && m.querySelector('svg')) {
      applyScale();
      return;
    }
    if (attempt > 40) return;
    setTimeout(() => waitForMermaid(attempt + 1), 150);
  }

  waitForMermaid(0);
})();
