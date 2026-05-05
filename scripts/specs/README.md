# Per-tutorial build specifications

This directory holds **build specifications** for every tutorial page in
`content/tutorials/`. Each JSON file covers one of the 16 topic areas and
provides per-tutorial guidance (outline, R demo hint, key formulas,
pitfalls, cross-links) that is specific enough to execute consistently
with the rest of the site.

## Why specs exist

Filling 560+ tutorial pages across multiple sessions risks drift -- in
section structure, in example style, in tone, in code conventions. The
specs pin the key content decisions once, so that subsequent execution
passes can be mechanical: read the spec, render the nine-section
template, move on.

## File format

Each `<category>.json` follows this schema:

```jsonc
{
  "category": "probability",
  "category_title": "Probability Theory",
  "default_packages": ["stats", "ggplot2"],
  "tutorials": [
    {
      "slug": "kolmogorov-axioms",
      "title": "Kolmogorov's Axioms of Probability",
      "difficulty": "Intermediate",
      "extra_packages": [],
      "intro": "Axiomatic foundation for probability...",
      "theory": [
        "Three axioms: P(A) >= 0; P(Omega) = 1; countable additivity",
        "Probability space triple (Omega, F, P)",
        "Consequences: P(empty) = 0, P(A^c) = 1 - P(A)"
      ],
      "example": "Simulate a fair coin and verify additivity empirically",
      "r_demo": "replicate() to draw 1e5 coin flips; compare P(H or T) with P(H) + P(T)",
      "pitfalls": [
        "Confusing axiomatic probability with long-run frequency",
        "Forgetting disjointness when applying countable additivity"
      ],
      "related": ["sample-space-events", "conditional-probability"]
    }
  ]
}
```

### Field meanings

- `slug` -- basename of the page under `content/tutorials/<category>/`.
- `title` -- the H1 title (matches the frontmatter `title`).
- `difficulty` -- `"Beginner" | "Intermediate" | "Advanced"`.
- `extra_packages` -- packages in addition to `default_packages` that
  belong in the frontmatter.
- `intro` -- one-sentence hook for the Introduction section.
- `theory` -- 2-4 bullet points that anchor the Theory section's
  mathematical content. Formulas are inline; the execution pass
  converts to LaTeX.
- `example` -- one-sentence description of the worked example.
- `r_demo` -- one-sentence hint about what the R code should compute or
  simulate. The execution pass fleshes this out to a full runnable
  code block.
- `pitfalls` -- 2-3 items for the Practical Tips section.
- `related` -- array of other slugs (in the same or other categories)
  for cross-linking in Further reading.

## How to execute a spec

Given `scripts/specs/<category>.json`:

1. Read the JSON and iterate through `tutorials` in array order.
2. For each tutorial, open `content/tutorials/<category>/<slug>.md`
   (should exist as a stub from `generate_stubs.py`).
3. Replace the file with a complete nine-section tutorial, using the
   spec fields as anchors:
   - Frontmatter: merge `default_packages` + `extra_packages`,
     set `status = "complete"`, remove `draft = true`, set the
     `tags` from slug tokens and category-specific keywords.
   - Introduction: expand `intro` into a full paragraph.
   - Prerequisites: derive from `difficulty` and topic.
   - Theory: expand `theory` bullets into prose with LaTeX.
   - Assumptions: list method-specific assumptions with "how to
     verify in R" hints when applicable.
   - R Implementation: flesh out `r_demo` into a runnable code block.
   - Output & Results: annotate the expected output.
   - Interpretation: manuscript-style phrasing.
   - Practical Tips: use `pitfalls` plus additional best-practice items.
4. Commit after every 5-7 tutorials.
5. Push after the category completes.

The execution is close to mechanical once the spec is in hand. Quality
comes from the spec's breadth of topical coverage and the consistency of
the template; variation in tone across categories is expected but should
not leak into the section structure.

## Sanity checks during execution

After completing a category, verify:

```bash
# Zero stubs remaining in the category
grep -l 'status = "stub"' content/tutorials/<category>/*.md | wc -l
# -> should print 0

# All tutorials pass a rough length check (>1800 chars of non-code)
for f in content/tutorials/<category>/*.md; do
  chars=$(sed '/^```/,/^```/d' "$f" | wc -c)
  printf "%4d  %s\n" "$chars" "$f"
done
# -> all lines should show >= 1800
```

## Maintaining specs

When adding new tutorials:

1. Add the slug + title + hint to `scripts/curriculum/<category>.txt`.
2. Run `python3 scripts/generate_stubs.py` to produce the stub.
3. Add a full spec entry to `scripts/specs/<category>.json`.
4. Execute the spec to convert the stub to a complete tutorial.
