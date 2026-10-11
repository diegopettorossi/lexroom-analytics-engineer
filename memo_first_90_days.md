# First 90 days as Lexroom's first Analytics Engineer

Lexroom has no analytics function and a small team, so one wrong number in front of the CTO costs more than a late one. My job is to find the few numbers the company argues about, make those trustworthy, and say no to the rest.

## Days 1-30: establish what is true

- Spend 30 minutes with each team that uses data: Product, Customer Success (CS), Sales, and Engineering. Ask which decision they make every week and which number they trust today. Their answers set the order of work.
- Ask Engineering two things. First, whether the drop in AMA answers (from about 1,900 a week in mid-February to 102 in the latest week) is a data ingestion gap or real usage. Second, about the field defects I find in the raw events, such as invalid latency values and events dated before their workspace signed up. Nothing about churn or quality goes to the CTO until the first question is answered.
- Set up dbt on BigQuery with separate dev and prod datasets, and run CI on every pull request.
- Ship a first AMA quality view, by module and by workspace, to Product and CS. It flags the latest weeks as possibly incomplete until Engineering confirms the volume question.

## Days 31-60: make what people use hard to break

- Pause new models until the existing ones are trusted. Add keys, relationship tests, a reconciliation to raw row counts, and a freshness check to the models people already read.
- Agree a written schema for AMA events (required fields, types, allowed values) with Engineering, drafted from the defects found in month one. CI then checks each Engineering pull request against it.
- Build one usage table with one row per workspace per week, plus workspace and user attributes. Anything that does not fit that shape waits.
- Review the workspace risk list with CS, account by account. Remove any signal that does not change which accounts CS contacts.

## Days 61-90: connect to revenue and set the next quarter

- Define an "active" workspace with Sales and CS. My starting proposal is at least one AMA question in a calendar month, tightened using renewal history. Then build a usage summary for Sales. Join CRM or billing data only after the definition is agreed.
- Using renewal dates from Sales or billing, check whether the risk flags predicted which accounts did not renew, and remove signals that predicted nothing. With few renewals in the window, I would report the result as indicative, not proven.
- Deliver a short backlog, plus a written list of the requests I declined and why.

**By day 90:** the quality view and risk list are tested and refreshed daily, the schema is checked in CI, "active" has an agreed definition, and every team knows which number to use for its decision.

## How I would work

- **Three trust tiers.** Company-level and customer-facing models (the quality index, the CS risk list, anything the CTO sees) get full tests, a daily freshness target, and an alert when they break. Team dashboards get the same tests, with failures sent to a team channel. Exploratory models come with no guarantees, and their dbt descriptions say so.
- **Clear ownership.** Engineering owns the event schema. Each team owns the definitions of the metrics it uses. Analytics owns the SQL and the tests. A bad raw row becomes a ticket for the team that produces the data, not a patch inside a model.
- **Visible quality.** Once a month I send each team one line: test pass rate, data freshness, and open source defects.
- **Fewer requests, not more tools.** Before anyone adds a BI tool, I would publish a small set of certified models, each with a one-sentence description of what one row represents. I would also keep a "which number do I use" page and hold regular office hours.

## What I would not do

- Adopt a BI tool or semantic layer before the core definitions are agreed. It would only lock in today's disagreements.
- Rewrite the event pipeline. I would specify what each event must contain, and Engineering would make the change.
- Build a streaming pipeline, unless the team conversations reveal a decision that needs data faster than daily.
- Take on an open queue of one-off requests. Requests go on one list, ranked weekly with the team leads.

## Main risks

1. **Definition disputes that look like data problems.** Terms like "active" and "quality" will mean different things to each team. Name one owner per definition in week one.
2. **Silent pipeline changes.** A dropped field or a half-empty week looks exactly like a product trend. Treat any unexplained volume change as an incident, not a finding.
3. **Small samples read as trends.** Show the sample size next to every rate, and hide scores based on too few ratings.
4. **Becoming the only person who pulls numbers.** Self-service, office hours, and an engineer reviewing models from week one reduce this risk.
5. **Acting on a wrong risk score.** A false high-risk flag makes CS contact a healthy client. Validate the list against CS's knowledge and renewal history before it drives outreach.
6. **Client data in legal work.** Client questions are confidential and covered by GDPR. Analytics should not need question or answer text. Pseudonymize user identifiers, keep access narrow, and log who queries raw content.
