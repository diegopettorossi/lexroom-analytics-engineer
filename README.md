# Lexroom - Analytics Engineer case (dbt + DuckDB)

Lexroom is an AI platform for legal professionals in Italy, Germany, and Spain. Ask Me Anything (AMA) is its RAG Q&A module. Each answer is tagged with a legal area: civile, penale, tributario, lavoro, amministrativo, societario.

This dbt project (DuckDB) models a synthetic extract of AMA answers, thumbs feedback, users, and workspaces. The 90-day memo is [memo_first_90_days.md](memo_first_90_days.md). The repository is [diegopettorossi/lexroom-analytics-engineer](https://github.com/diegopettorossi/lexroom-analytics-engineer).

## Setup

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
dbt deps --profiles-dir .
dbt build --profiles-dir .
dbt docs generate --profiles-dir . && dbt docs serve --profiles-dir .
```

- Seeds in `seeds/` load into the `raw` schema of a local `lexroom.duckdb`. `dbt deps` needs network once: `dbt_utils` is pinned to git revision 1.3.0 because the package hub was unreachable.
- Answer queries are in [analyses/](analyses). `dbt compile --profiles-dir .`, then run the SQL in `target/compiled/`.
- `as_of_date` is Monday 2026-04-20, so the last completed week is w/c 13 Apr. The 8-week window runs from w/c 23 Feb. `dbt build --vars '{as_of_date: null}'` uses the run date. On today's date this extract is stale, so freshness warns and the windows are empty.



## Project structure

```
seeds/          raw_events_ama, raw_feedback_ama, raw_workspaces, raw_users
models/
  staging/      stg_ama_events, stg_ama_feedback, stg_workspaces, stg_users, stg_engineering_prs
  intermediate/ int_ama_event_enriched
  marts/        fct_ama_module_weekly (Q1, Q3), dim_workspace_risk (Q2),
                fct_pr_lead_time_weekly (bonus)
  exposures.yml
analyses/       q1_module_weekly, q1_module_quality_trend, q1_module_failure_reasons,
                q2_workspaces_at_risk, q3_north_star_trend
macros/         aqi.sql, as_of.sql, generate_schema_name.sql
tests/          answer reconciliation; weekly volume drop and raw freshness (warn)
```


| Model                    | Grain                                                                                          |
| ------------------------ | ---------------------------------------------------------------------------------------------- |
| `stg_ama_events`         | one AMA answer                                                                                 |
| `stg_ama_feedback`       | one feedback id                                                                                |
| `stg_workspaces`         | one workspace                                                                                  |
| `stg_users`              | one user. Roster only; not used in AQI or risk                                                 |
| `int_ama_event_enriched` | one AMA answer, with module, workspace, final rating, and thumbs-down reason                   |
| `fct_ama_module_weekly`  | one module per ISO week                                                                        |
| `dim_workspace_risk`     | one workspace. One score for the last 4 weeks against the 4 before; `as_of_date` is on the row |
| `stg_engineering_prs`    | one pull request. Bonus; adds lead time and merge week                                         |
| `fct_pr_lead_time_weekly` | one team per ISO week of merge. Bonus                                                         |

**Bonus: engineering health.** `fct_pr_lead_time_weekly` gives median and p90 hours from PR opened to merged. It is a proxy for DORA lead time for changes, which runs commit to production. Deployment frequency and change failure rate need deploy and incident data that is not in the extract. Team level only, with no per-author figures. Unmerged PRs (65 of 520) are excluded, and team-weeks under 5 merges are flagged `is_lead_time_reliable = false`. Built on the staging model `stg_engineering_prs`, which holds the derived lead time and merge week. Full definition: [fct_pr_lead_time_weekly.md](models/marts/engineering/fct_pr_lead_time_weekly.md).


Staging and intermediate are views. Marts are tables. About 11,000 answers rebuild in seconds, so nothing is incremental. On BigQuery I would make `fct_ama_module_weekly` incremental on `(module_tag, week_start)`, with a one-week lookback for late events and ratings. `dim_workspace_risk` stays a full rebuild.

Parameters are `vars` in `dbt_project.yml`. Example: `dbt build --vars '{slow_latency_ms: 4000}'`.


| What                               | Var                                                                        | Default                                                    |
| ---------------------------------- | -------------------------------------------------------------------------- | ---------------------------------------------------------- |
| AQI weights (must sum to 1)        | `aqi_weights`                                                              | satisfaction 0.50, grounded 0.25, fast 0.25                |
| Risk weights and full-alarm levels | `risk_signals`                                                             | usage decline 0.50 at 50%, satisfaction drop 0.50 at 20 pp |
| Risk tiers                         | `risk_tiers`                                                               | high 50, medium 25                                         |
| Slow answer / latency cap          | `slow_latency_ms`, `latency_valid_max_ms`                                  | 5000, 120000                                               |
| Windows                            | `period_weeks`, `weeks_window`                                             | 4, 8                                                       |
| Minimum volumes                    | `min_rated_for_signal`, `min_events_for_risk`, `min_rated_high_confidence` | 10, 20, 100                                                |
| Reference date                     | `as_of_date`                                                               | 2026-04-20; `null` uses the run date                       |
| Freshness and volume warnings      | `max_ingestion_lag_days`, `min_weekly_volume_ratio`                        | 2 days, 0.5                                                |


A `module_tag` outside civile, penale, tributario, lavoro, amministrativo, societario warns and is kept.

### Why these thresholds?

- Five seconds is about the 95th percentile of latencies once 28 rows at exactly 900000 ms are set aside. 120 seconds sits under that sentinel. Five answers at 45 seconds still count as slow.
- Ten ratings is the smallest base on which a 20-point satisfaction move is more than one or two votes.
- Twenty prior answers is a low floor on purpose: raising it changes who CS calls.
- One hundred ratings marks only the last two company weeks as low confidence.
- One signal at full alarm scores 50, which is the high tier.



## AMA Quality Index

Q1 and Q3 use this index. About 27% of answers are rated, so thumbs alone would describe the people who vote.

`AQI = 100 x (0.50 x satisfaction + 0.25 x grounded + 0.25 x fast)`

- **satisfaction**: thumbs up / rated answers. NULL when the period has no ratings.
- **grounded**: share of answers with at least one retrieved source.
- **fast**: share of non-cached answers with a trusted latency under 5s. NULL when the period has no trusted latency.

A missing component makes the index NULL. The weights are a judgment until they can be checked against tickets or churn.

## Answers

Each answer below is the question, the query, the result, then what to do with it.

### Q1. Weekly quality by module

> For each legal module, what is the weekly quality trend over the last 8 weeks? Where should the Product team focus?

- Weekly series: `analyses/q1_module_weekly.sql`
- Last 4 weeks against the 4 before: `analyses/q1_module_quality_trend.sql`
- Thumbs-down reasons, last 4 weeks: `analyses/q1_module_failure_reasons.sql`


| Module         | Last 4 weeks | Prior 4 weeks | Change |
| -------------- | ------------ | ------------- | ------ |
| amministrativo | 73.1         | 82.4          | -9.3   |
| societario     | 78.4         | 85.2          | -6.8   |
| tributario     | 79.4         | 84.8          | -5.4   |
| civile         | 81.0         | 86.3          | -5.3   |
| lavoro         | 80.9         | 84.3          | -3.4   |
| penale         | 85.1         | 87.1          | -2.0   |


Every module is down on the four-week cut. The weeks are not a steady decline. The last week is 102 answers and 20 ratings, and it moves the small modules:

- amministrativo falls each recent week: 85.2, 68.8, 63.1, 50.0, on 8, 5, 3, then 2 ratings.
- civile is about 40% of volume and stays near 80 until that week (67.4 on 8 ratings).
- tributario's last two weeks are 92.5 and 94.4 on 8 and 2 ratings, so −5.4 is not a trend.

**Where to focus.** civile, by volume. Then amministrativo and societario, which fell most (18 and 74 ratings in the last 4 weeks). Confirm the recent weeks are fully ingested before treating a module move as a product change.

Recent thumbs-down: civile is wrong_answer 23, incomplete 18, unspecified 14, hallucination 9. societario is next on wrong_answer and hallucination (9 and 8). A thumbs-down with no reason is `unspecified`.

### Q2. Workspaces with a deteriorating experience

> Which workspaces show signs of deteriorating experience? Define a risk score and justify the signals.

`analyses/q2_workspaces_at_risk.sql`. One row per workspace, last 4 weeks against the 4 before. Score 0 to 100:

- **Usage decline against the platform** (weight 0.50, full alarm at a 50% drop relative to the platform). Volume falls about 95% in this extract, so an absolute drop would flag almost every workspace.
- **Satisfaction drop** (weight 0.50, full alarm at 20 percentage points). Counted only when both periods have at least 10 ratings. On the mart this is a share: 0.46 means 46 percentage points.

A workspace with fewer than 20 answers in the prior period is not scored. High is 50 and above, medium is 25 to 50.

**Result.** 3 high, 6 medium, 27 low, 44 not scored.


| Workspace | Plan       | Score | Tier   | Why                                        |
| --------- | ---------- | ----- | ------ | ------------------------------------------ |
| ws_0051   | enterprise | 53.4  | high   | satisfaction down 46 pp                    |
| ws_0041   | enterprise | 50.8  | high   | satisfaction down 52 pp                    |
| ws_0003   | pro        | 50.0  | high   | usage down 61% on 38 prior answers         |
| ws_0034   | pro        | 46.2  | medium | usage down 46% on 22 prior answers         |
| ws_0076   | enterprise | 41.7  | medium | usage down 15% and satisfaction down 11 pp |
| ws_0029   | enterprise | 38.0  | medium | usage down 7% and satisfaction down 12 pp  |
| ws_0017   | enterprise | 36.3  | medium | usage down 6% and satisfaction down 12 pp  |
| ws_0074   | enterprise | 36.2  | medium | usage down 20% and satisfaction down 6 pp  |
| ws_0069   | pro        | 29.6  | medium | usage down 30% on 21 prior answers         |


**Where to focus.** The table is the call order. `ws_0003`, `ws_0034`, and `ws_0069` clear a tier on 38, 22, and 21 prior answers. The floor stays at 20 because raising it changes who CS calls.

### Q3. A North Star for AMA quality

> Propose one composite metric for AMA quality over time. Define it (formula, grain, window) and show the last 8 weeks.

`analyses/q3_north_star_trend.sql`. The metric is the AMA Quality Index above.

- **Formula:** `100 x (0.50 x satisfaction + 0.25 x grounded + 0.25 x fast)`. A missing component makes the week NULL.
- **Grain:** one number per company per ISO week, rebuilt from answer counts. Module scores are not averaged.
- **Window:** the last 8 completed weeks. A week with fewer than 100 rated answers is low confidence.

**Result.** 83.6 (w/c 23 Feb), 86.7, 86.6, 85.4, 81.6, 79.8, 81.0, 72.3 (w/c 13 Apr). It peaks in early March and then falls. The last two weeks are under 100 ratings, so the final −8.7 should be read with that.

## Data issues


| Issue                                      | Count | Handling                                                               |
| ------------------------------------------ | ----- | ---------------------------------------------------------------------- |
| Duplicate events, identical rows           | 5     | Collapsed in `stg_ama_events`. Warn on the raw seed; error above 100.  |
| Module tag case and accents                | ~165  | Lowercased; accents and non-letters stripped.                          |
| Typo `civil`                               | 86    | Mapped to `civile`. Any other unknown tag warns and is kept.           |
| Negative latency and 900000 ms             | 61    | Kept. `is_valid_latency = false`, so latency metrics skip them.        |
| Duplicate feedback ids                     | 15    | Collapsed in `stg_ama_feedback`. Warn on the raw seed; error above 50. |
| Several ratings on one answer              | 15    | Latest rating wins.                                                    |
| `thumbs` of 2, -2, and 0                   | 16    | Sign of the value. 0 becomes NULL. `thumbs_raw` warns.                 |
| Feedback with no matching answer           | 50    | Dropped at the join. Warn.                                             |
| Events with no matching workspace          | 8     | Kept in module metrics, dropped from the risk mart. Warn.              |
| Users with no matching workspace           | 3     | Kept on `stg_users`. Warn. Unused in the scores.                       |
| Soft-deleted users                         | 26    | Kept. No deletion timestamp, so unused as churn.                       |
| Blank country                              | 3     | `unknown`.                                                             |
| Events before workspace `signup_date`      | 597   | Left as-is. Question for Engineering.                                  |
| Thumbs-down with no reason                 | 178   | Kept as `reason_tag = unspecified`.                                    |
| Volume, ~1,900 answers/week mid-Feb to 102 | —     | Left as-is. See below.                                                 |


Volume falls about 95%, and active workspaces from 67 to 33. That looks like an extract or ingestion gap, which is why Q2 compares each workspace with the platform. Engineering should confirm the recent weeks are complete before anyone acts on these numbers.

## Tests

Source defects stay `warn`, so the build still produces the marts. `store_failures` writes the offending rows to the `dq` schema.

- Raw duplicate ids warn, and error past a volume threshold. Staged keys error.
- Relationships warn: events to workspaces, feedback to events, users to workspaces.
- `equal_rowcount` and a unique `event_id`: the rating join neither fans out nor drops answers.
- `assert_mart_accounts_for_every_answer`: the module mart counts every staged answer once.
- `weekly_counts_are_consistent` and `risk_score_only_when_scored`.
- Two unit tests on the formula: a normal week is 62.5, a week with no ratings is NULL.
- `warn_weekly_volume_drop` and `warn_raw_freshness` mark an incomplete latest week. They do not fail the build.

Latest full build (`dbt build --full-refresh`): 61 pass, 7 warn (duplicate raw events and feedback, orphan events, orphan feedback, orphan users, thumbs outside 1/−1, volume drop), 0 errors.

## Trade-offs

- **One index, three inputs.** People who rate are a biased sample, so grounding and speed are on every answer. Weights stay 0.50 / 0.25 / 0.25 until an external signal exists.
- **One tag rewrite.** `civil` becomes `civile`. A phantom module on the Q1 table is worse than one documented mapping. Any new unknown tag warns.
- **Risk is relative to the platform**, for the reason in Q2. Satisfaction counts only when both periods have at least 10 ratings.
- **Q1 and Q3 share** `fct_ama_module_weekly`**.** The weekly series reads `quality_index` from that mart. Q3 and the 4-week comparison re-aggregate the counts and call the same `aqi` macro, so module rates are never averaged into the company number. Failure reasons are a separate query.
- **PR lead time is a proxy.** `fct_pr_lead_time_weekly` measures PR opened to merged, not commit to production, so it misses pre-PR time and merge-to-deploy time. Deployment frequency and change failure rate are left out because the extract has no deploy or incident data.
- **Team level, not per engineer.** Per-author lead time would turn a health metric into a ranking that invites gaming, so the mart has no author column. The seed's `author_id` is kept out on purpose.
- **Small teams are flagged, not hidden.** A team-week with fewer than 5 merges keeps its row and gets `is_lead_time_reliable = false`. Dropping those rows would hide real signal in a small team.
- **Users stay out of the scores.** `is_deleted` has no date, so it cannot explain a weekly drop. The model is there for roster questions and the orphan-workspace warning.



## What I would do next

1. Ask Engineering about the volume drop, what `signup_date` means, and the 900000 ms latency marker.
2. Review `min_events_for_risk` with CS, then check the risk list against renewals.
3. Calibrate the AQI weights against an external signal.
4. Replace the seeds with BigQuery sources and `loaded_at_field` freshness.



## How I used AI

Cursor, with the LLM routing based on task complexity:

- **Claude Sonnet** (complex work): project boilerplate, deep exploratory analysis and product decisions
- **Claude Haiku** (non-trivial work): tests, documentation, and review passes.
- **Grok** (trivial edits): wording, formatting, and short README changes.

