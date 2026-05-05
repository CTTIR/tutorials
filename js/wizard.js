/*
 * Statistical Test Decision Assistant -- vanilla JS state machine.
 *
 * Every question node specifies a `prompt`, an optional `why` (criterion
 * explanation), and an array of `choices`. A choice routes either to
 * another question node (`next`) or to a leaf (`leaf`). Leaves resolve to
 * a method page with a short rationale.
 */

const BASE = (() => {
  const p = window.location.pathname;
  const i = p.indexOf('/decision-tree/');
  return i >= 0 ? p.slice(0, i + 1) : '/';
})();

// Quarto renders each .qmd to a sibling .html file, so link targets need
// an explicit ".html" suffix (not a trailing slash as under Hugo).
const link = (slug) => `${BASE}decision-tree/${slug}.html`;

const LEAVES = {
  independent_t:       { name: 'Independent-samples t-test', page: link('differences/central-tendency/independent-t-test'),
                         rationale: 'Two independent groups, continuous outcome, approximately normal. Welch\u2019s variant is the default when variances differ.' },
  paired_t:            { name: 'Paired-samples t-test', page: link('differences/central-tendency/paired-t-test'),
                         rationale: 'Two dependent observations per unit, continuous outcome with approximately normal differences.' },
  mann_whitney:        { name: 'Mann-Whitney U test', page: link('differences/central-tendency/mann-whitney-u'),
                         rationale: 'Two independent groups, ordinal outcome or non-normal continuous outcome; compares distributions via ranks.' },
  wilcoxon_signed:     { name: 'Wilcoxon signed-rank test', page: link('differences/central-tendency/wilcoxon-signed-rank'),
                         rationale: 'Two dependent observations per unit, ordinal or non-normal continuous differences.' },
  sign_test:           { name: 'Sign test', page: link('differences/central-tendency/sign-test'),
                         rationale: 'Paired observations where only the direction of difference is meaningful.' },
  one_way_anova:       { name: 'One-way ANOVA', page: link('differences/central-tendency/one-way-anova'),
                         rationale: 'One between-subjects factor with three or more independent groups, continuous outcome.' },
  factorial_anova:     { name: 'Factorial ANOVA', page: link('differences/central-tendency/factorial-anova'),
                         rationale: 'Two or more between-subjects factors, continuous outcome, interest in main effects and interactions.' },
  rm_anova_one:        { name: 'One-way repeated-measures ANOVA', page: link('differences/central-tendency/rm-anova-one-way'),
                         rationale: 'Single within-subjects factor, continuous outcome measured at three or more occasions.' },
  rm_anova_factorial:  { name: 'Factorial / mixed repeated-measures ANOVA', page: link('differences/central-tendency/rm-anova-factorial'),
                         rationale: 'Repeated measures combined with a between-subjects factor or multiple within factors.' },
  kruskal_wallis:      { name: 'Kruskal-Wallis test', page: link('differences/central-tendency/kruskal-wallis'),
                         rationale: 'Three or more independent groups, ordinal outcome or non-normal continuous outcome.' },
  friedman:            { name: 'Friedman test', page: link('differences/central-tendency/friedman'),
                         rationale: 'Three or more dependent measurements per unit, ordinal or non-normal continuous outcome.' },
  variances:           { name: 'Variance comparison test', page: link('differences/variances'),
                         rationale: 'Chi-squared variance test, F-test for two variances, or Levene\u2019s test depending on design.' },
  binomial:            { name: 'Binomial test', page: link('differences/proportions/binomial-test'),
                         rationale: 'Single dichotomous variable compared to an expected proportion.' },
  chi_gof:             { name: 'Chi-squared goodness-of-fit', page: link('differences/proportions/chi-square-goodness-of-fit'),
                         rationale: 'Single categorical variable compared to an expected distribution.' },
  chi_contingency:     { name: 'Chi-squared contingency test', page: link('associations/chi-square-contingency'),
                         rationale: 'Association between two nominal variables; includes Fisher\u2019s exact test for small cells.' },
  spearman:            { name: 'Spearman rank correlation', page: link('associations/spearman-correlation'),
                         rationale: 'Monotonic association between two ordinal or non-normal continuous variables.' },
  pearson:             { name: 'Pearson correlation', page: link('associations/pearson-correlation'),
                         rationale: 'Linear association between two continuous, approximately bivariate-normal variables.' },
  kendall:             { name: 'Kendall\u2019s tau', page: link('associations/kendall-tau'),
                         rationale: 'Rank association for small samples or many tied ranks; more robust than Spearman in those cases.' },
  simple_lr:           { name: 'Simple linear regression', page: link('associations/simple-linear-regression'),
                         rationale: 'Directed linear relationship from one continuous predictor to one continuous outcome.' },
  multiple_lr:         { name: 'Multiple linear regression', page: link('associations/multiple-regression'),
                         rationale: 'Continuous outcome predicted by two or more predictors; controls for covariates.' },
  logistic:            { name: 'Binary logistic regression', page: link('associations/logistic-regression'),
                         rationale: 'Dichotomous outcome predicted by one or more variables; returns odds ratios.' },
  ordinal_logistic:    { name: 'Ordinal logistic regression', page: link('associations/ordinal-logistic-regression'),
                         rationale: 'Ordered categorical outcome; proportional-odds model.' },
  multinomial_logistic:{ name: 'Multinomial logistic regression', page: link('associations/multinomial-logistic-regression'),
                         rationale: 'Unordered categorical outcome with three or more levels.' },
  factor_analysis:     { name: 'Exploratory factor analysis', page: link('interdependence/factor-analysis'),
                         rationale: 'Reduce a set of observed variables to a smaller number of latent factors.' },
  hierarchical_clust:  { name: 'Hierarchical cluster analysis', page: link('interdependence/cluster-analysis'),
                         rationale: 'Group cases using Ward, single, complete, or average linkage; suitable for mixed or small samples.' },
  kmeans_clust:        { name: 'K-means clustering', page: link('interdependence/cluster-analysis'),
                         rationale: 'Partition metric data into k clusters; efficient for large samples.' },
  twostep_clust:       { name: 'Two-step clustering', page: link('interdependence/cluster-analysis'),
                         rationale: 'Handles mixed-type variables and very large datasets via a pre-clustering step.' }
};

const NODES = {
  START: {
    prompt: 'Do you have a concrete, theory-driven question, or are you exploring structure?',
    why: 'A concrete question compares or relates known variables (dependence analysis). An exploratory question reduces variables or groups cases without prespecified outcomes (interdependence analysis).',
    choices: [
      { label: 'Concrete (test a specific hypothesis)', next: 'Q2', token: 'concrete' },
      { label: 'Exploratory (discover structure)', next: 'Q_INT', token: 'exploratory' }
    ]
  },
  Q_INT: {
    prompt: 'Do you want to reduce the number of variables or group your cases?',
    why: 'Variable reduction replaces many observed variables with fewer latent dimensions (factor analysis). Case grouping partitions rows into homogeneous subsets (cluster analysis).',
    choices: [
      { label: 'Reduce variables', leaf: 'factor_analysis', token: 'reduce' },
      { label: 'Group cases', next: 'Q_CLUSTER', token: 'group' }
    ]
  },
  Q_CLUSTER: {
    prompt: 'What is the scale level and sample size?',
    why: 'Mixed or small samples favour hierarchical clustering. Metric data with larger samples favour k-means. Mixed types with very large samples favour a two-step approach.',
    choices: [
      { label: 'Mixed types / small sample', leaf: 'hierarchical_clust', token: 'mixed-small' },
      { label: 'Metric / large sample', leaf: 'kmeans_clust', token: 'metric-large' },
      { label: 'Mixed types / very large sample', leaf: 'twostep_clust', token: 'mixed-xl' }
    ]
  },
  Q2: {
    prompt: 'Are you asking about differences between groups or associations between variables?',
    why: 'Differences compare distributions across groups. Associations quantify how variables move together.',
    choices: [
      { label: 'Differences between groups', next: 'Q_D1', token: 'differences' },
      { label: 'Associations between variables', next: 'Q_A1', token: 'associations' }
    ]
  },
  Q_D1: {
    prompt: 'What kind of difference are you interested in?',
    why: 'Central tendency compares means or medians. Variance comparisons test spread. Proportion tests compare frequencies against expectations.',
    choices: [
      { label: 'Central tendency (means or medians)', next: 'Q_D2', token: 'central' },
      { label: 'Variances', leaf: 'variances', token: 'variance' },
      { label: 'Proportions / frequencies', next: 'Q_DPROP', token: 'proportions' }
    ]
  },
  Q_D2: {
    prompt: 'What is the scale level of your outcome variable?',
    why: 'Metric outcomes support parametric tests when assumptions hold. Ordinal or non-normal outcomes route to rank-based alternatives.',
    choices: [
      { label: 'Interval / ratio (metric)', next: 'Q_D3', token: 'metric' },
      { label: 'Ordinal', next: 'Q_D6', token: 'ordinal' },
      { label: 'Nominal (counts / categorical)', next: 'Q_DPROP', token: 'nominal' }
    ]
  },
  Q_D3: {
    prompt: 'How many groups are you comparing?',
    why: 'Two-group tests are t-tests and their rank analogues. Three-or-more groups require ANOVA-family or non-parametric omnibus tests.',
    choices: [
      { label: 'Exactly 2 groups', next: 'Q_D4', token: '2-groups' },
      { label: 'More than 2 groups', next: 'Q_D5', token: '3plus-groups' }
    ]
  },
  Q_D4: {
    prompt: 'Independent or paired, and is the outcome approximately normal?',
    why: 'Independence determines whether residuals are independent or within-unit. Normality (or a large enough sample for the CLT) justifies a parametric test; otherwise use a rank alternative.',
    choices: [
      { label: 'Independent, normal, equal variances', leaf: 'independent_t', token: 'indep-norm-eq' },
      { label: 'Independent, normal, unequal variances (Welch)', leaf: 'independent_t', token: 'indep-norm-uneq' },
      { label: 'Independent, non-normal', leaf: 'mann_whitney', token: 'indep-nonnorm' },
      { label: 'Paired, differences normal', leaf: 'paired_t', token: 'paired-norm' },
      { label: 'Paired, non-normal', leaf: 'wilcoxon_signed', token: 'paired-nonnorm' },
      { label: 'Paired, only direction of difference meaningful', leaf: 'sign_test', token: 'paired-sign' }
    ]
  },
  Q_D5: {
    prompt: 'How many factors, which design, and is the outcome approximately normal?',
    why: 'Factor count and repeated-measures structure select among the ANOVA family. Non-normal continuous outcomes or ordinal outcomes route to Kruskal-Wallis or Friedman.',
    choices: [
      { label: '1 between-subjects factor, normal', leaf: 'one_way_anova', token: '1fac-indep-norm' },
      { label: '2+ between-subjects factors, normal', leaf: 'factorial_anova', token: 'mfac-indep-norm' },
      { label: '1 within-subjects factor, normal', leaf: 'rm_anova_one', token: '1fac-rm-norm' },
      { label: 'Repeated measures + between factor', leaf: 'rm_anova_factorial', token: 'mix-rm-norm' },
      { label: 'Independent, non-normal or ordinal', leaf: 'kruskal_wallis', token: 'indep-nonnorm' },
      { label: 'Paired / repeated, non-normal or ordinal', leaf: 'friedman', token: 'paired-nonnorm' }
    ]
  },
  Q_D6: {
    prompt: 'How many groups are you comparing, and are they independent or paired?',
    why: 'Ordinal outcomes route directly to rank-based procedures; structure of the groups determines which.',
    choices: [
      { label: '2 independent groups', leaf: 'mann_whitney', token: '2-indep' },
      { label: '2 paired groups', leaf: 'wilcoxon_signed', token: '2-paired' },
      { label: '>2 independent groups', leaf: 'kruskal_wallis', token: 'kplus-indep' },
      { label: '>2 paired / repeated groups', leaf: 'friedman', token: 'kplus-paired' }
    ]
  },
  Q_DPROP: {
    prompt: 'What kind of frequency check do you need?',
    why: 'A single proportion vs. an expected value uses the binomial test. A categorical variable vs. an expected distribution uses chi-squared goodness-of-fit.',
    choices: [
      { label: 'Dichotomous variable vs. expected proportion', leaf: 'binomial', token: 'binomial' },
      { label: 'Categorical variable vs. expected distribution', leaf: 'chi_gof', token: 'chi-gof' }
    ]
  },
  Q_A1: {
    prompt: 'How many variables are involved?',
    why: 'Two variables use correlation or simple regression. More than two variables require multivariable models.',
    choices: [
      { label: '2 variables', next: 'Q_A2', token: '2-vars' },
      { label: 'More than 2 variables (one DV, several IVs)', next: 'Q_A5', token: 'many-vars' }
    ]
  },
  Q_A2: {
    prompt: 'What are the scale levels of the two variables?',
    why: 'Scale level and linearity determine whether to use chi-squared, rank correlations, Pearson, or simple regression.',
    choices: [
      { label: 'Both nominal', leaf: 'chi_contingency', token: 'nom-nom' },
      { label: 'Both ordinal', leaf: 'spearman', token: 'ord-ord' },
      { label: 'Ordinal + interval', leaf: 'spearman', token: 'ord-int' },
      { label: 'Both interval, linear, bivariate normal', leaf: 'pearson', token: 'int-pearson' },
      { label: 'Both interval, directed (IV \u2192 DV)', leaf: 'simple_lr', token: 'int-slr' },
      { label: 'Both interval, non-normal or small n', leaf: 'kendall', token: 'int-kendall' }
    ]
  },
  Q_A5: {
    prompt: 'What is the scale level of the outcome (DV)?',
    why: 'A continuous DV with multiple predictors uses multiple regression. Categorical DVs use logistic-family regressions.',
    choices: [
      { label: 'Interval / ratio', leaf: 'multiple_lr', token: 'int-dv' },
      { label: 'Dichotomous', leaf: 'logistic', token: 'bin-dv' },
      { label: 'Ordinal', leaf: 'ordinal_logistic', token: 'ord-dv' },
      { label: 'Nominal (>2 categories)', leaf: 'multinomial_logistic', token: 'nom-dv' }
    ]
  }
};

const STATE = {
  history: []
};

function currentNodeId() {
  if (STATE.history.length === 0) return 'START';
  const last = STATE.history[STATE.history.length - 1];
  return last.next || 'START';
}

function currentLeafId() {
  if (STATE.history.length === 0) return null;
  return STATE.history[STATE.history.length - 1].leaf || null;
}

function pathToken() {
  return STATE.history.map((h) => h.token).join('.');
}

function encodeURL() {
  const token = pathToken();
  const url = new URL(window.location.href);
  if (token) url.searchParams.set('path', token);
  else url.searchParams.delete('path');
  window.history.replaceState({}, '', url.toString());
}

function decodeURL() {
  const url = new URL(window.location.href);
  const token = url.searchParams.get('path');
  if (!token) return;
  const tokens = token.split('.');
  let node = 'START';
  for (const tok of tokens) {
    const n = NODES[node];
    if (!n) return;
    const choice = n.choices.find((c) => c.token === tok);
    if (!choice) return;
    STATE.history.push({
      from: node,
      token: choice.token,
      label: choice.label,
      next: choice.next,
      leaf: choice.leaf
    });
    if (choice.leaf) return;
    node = choice.next;
  }
}

function escapeHTML(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[c]));
}

function renderBreadcrumb(root) {
  const crumb = document.createElement('div');
  crumb.className = 'wiz-breadcrumb';
  crumb.setAttribute('aria-label', 'Decision path so far');
  if (STATE.history.length === 0) {
    crumb.textContent = 'Start';
  } else {
    const items = STATE.history.map((h, i) =>
      `<span class="wiz-breadcrumb-item">${escapeHTML(h.label)}</span>` +
      (i < STATE.history.length - 1 ? '<span class="wiz-breadcrumb-sep">\u203A</span>' : '')
    );
    crumb.innerHTML = 'Start <span class="wiz-breadcrumb-sep">\u203A</span>' + items.join('');
  }
  root.appendChild(crumb);
}

function renderQuestion(root, node) {
  const q = document.createElement('h2');
  q.className = 'wiz-question';
  q.id = 'wiz-question-heading';
  q.textContent = node.prompt;
  root.appendChild(q);

  if (node.why) {
    const why = document.createElement('details');
    why.className = 'wiz-why';
    why.innerHTML = `<summary>Why this branch?</summary>
      <div class="wiz-why-body">${escapeHTML(node.why)}</div>`;
    root.appendChild(why);
  }

  const list = document.createElement('div');
  list.className = 'wiz-choices';
  list.setAttribute('role', 'radiogroup');
  list.setAttribute('aria-labelledby', 'wiz-question-heading');

  node.choices.forEach((choice, idx) => {
    const label = document.createElement('label');
    label.className = 'wiz-choice';
    label.innerHTML = `
      <input type="radio" name="wiz-choice" value="${idx}">
      <span class="wiz-choice-label">${escapeHTML(choice.label)}</span>`;
    label.addEventListener('click', () => selectChoice(choice, label));
    list.appendChild(label);
  });

  root.appendChild(list);
  const firstInput = list.querySelector('input[type="radio"]');
  if (firstInput) firstInput.focus();
}

function renderLeaf(root, leafId) {
  const leaf = LEAVES[leafId];
  if (!leaf) return;

  const box = document.createElement('div');
  box.className = 'wiz-leaf';
  box.setAttribute('role', 'region');
  box.setAttribute('aria-live', 'polite');
  box.innerHTML = `
    <h3>Recommended test: ${escapeHTML(leaf.name)}</h3>
    <p>${escapeHTML(leaf.rationale)}</p>
    <p><a href="${leaf.page}">Open the full method page \u2192</a></p>
    <div class="wiz-path">Path: ${escapeHTML(pathToken())}</div>`;
  root.appendChild(box);
}

function renderControls(root) {
  const bar = document.createElement('div');
  bar.className = 'wiz-controls';
  bar.innerHTML = `
    <button class="wiz-btn" id="wiz-back" ${STATE.history.length === 0 ? 'disabled' : ''}>\u2190 Back</button>
    <button class="wiz-btn" id="wiz-reset">Start over</button>`;
  root.appendChild(bar);

  document.getElementById('wiz-back').addEventListener('click', () => {
    if (STATE.history.length === 0) return;
    STATE.history.pop();
    encodeURL();
    render();
  });
  document.getElementById('wiz-reset').addEventListener('click', () => {
    STATE.history = [];
    encodeURL();
    render();
  });
}

function selectChoice(choice, labelEl) {
  const input = labelEl.querySelector('input[type="radio"]');
  input.checked = true;
  const nodeId = currentNodeId();
  STATE.history.push({
    from: nodeId,
    token: choice.token,
    label: choice.label,
    next: choice.next,
    leaf: choice.leaf
  });
  encodeURL();
  render();
}

function render() {
  const root = document.getElementById('wizard-root');
  if (!root) return;
  root.innerHTML = '';

  renderBreadcrumb(root);

  const leafId = currentLeafId();
  if (leafId) {
    renderLeaf(root, leafId);
    renderControls(root);
    return;
  }

  const nodeId = currentNodeId();
  const node = NODES[nodeId];
  if (!node) {
    root.innerHTML = '<p>Internal error: unknown node.</p>';
    return;
  }
  renderQuestion(root, node);
  renderControls(root);
}

function keyboardHandler(ev) {
  if (!document.getElementById('wizard-root')) return;
  const radios = Array.from(document.querySelectorAll('#wizard-root input[type="radio"]'));
  if (radios.length === 0) return;
  const focused = document.activeElement;
  let idx = radios.indexOf(focused);

  if (ev.key === 'ArrowDown' || ev.key === 'ArrowRight') {
    ev.preventDefault();
    idx = (idx + 1) % radios.length;
    radios[idx].focus();
  } else if (ev.key === 'ArrowUp' || ev.key === 'ArrowLeft') {
    ev.preventDefault();
    idx = (idx <= 0 ? radios.length : idx) - 1;
    radios[idx].focus();
  } else if (ev.key === 'Enter' && idx >= 0) {
    ev.preventDefault();
    radios[idx].closest('label').click();
  }
}

document.addEventListener('DOMContentLoaded', () => {
  decodeURL();
  render();
  document.addEventListener('keydown', keyboardHandler);
});

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { NODES, LEAVES };
}
