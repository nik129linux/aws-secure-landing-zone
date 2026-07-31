# Runbook — GuardDuty finding triage

**Scope:** single-account lab, GuardDuty detector in `us-east-1` only.
**Audience:** me, at 2am, tired, with an alert on screen.
**Status:** sections 1-3 complete. Sections 4-7 pending (see bottom).

If a step here does not tell you what to do next, it is wrong and should be rewritten.

---

## 1. Is this finding real?

**Always the first question. Never investigate before answering it.**

Sample findings are generated on purpose with `create-sample-findings` to test the detection
pipeline. They look identical to real findings in the console, so the check has to be explicit.

**How to tell:**

```bash
aws guardduty get-findings \
  --detector-id <DETECTOR_ID> \
  --region us-east-1 \
  --finding-ids <FINDING_ID> \
  --query 'Findings[].Service.AdditionalInfo.Value'
```

If the returned JSON contains `"sample": true`, the finding is synthetic.

Secondary tell, useful in the console where you cannot run a query: every field is filled with
placeholder text — `GeneratedFindingProcessName`, `ami-99999999`, `i-99999999`, and the IP
`198.51.100.0`, which is a reserved documentation address that cannot exist on the internet.

**Action:**

| Result | What you do |
|---|---|
| `sample: true` | **Close it. Do not investigate.** Note it as a pipeline test, not an event. |
| No `sample` field | Real finding. Continue to section 2. |

⚠ **Do not build the habit of relying on this check.** Real findings have no `sample` field at all,
so this test disappears the day it matters most. It filters test noise; it does not triage. The
check that always works is section 3.

---

## 2. The five fields you actually read

A GuardDuty finding is ~200 lines of JSON. In a real queue you read five fields and decide. Process
lineage, network interfaces, tags and PIDs get opened **only after** you decide to investigate.

```bash
aws guardduty get-findings \
  --detector-id <DETECTOR_ID> \
  --region us-east-1 \
  --finding-ids <FINDING_ID> \
  --query 'Findings[].{sev:Severity,type:Type,title:Title,res:Resource.ResourceType,count:Service.Count}'
```

Read them in this order:

1. **`Severity`** — 1.0-3.9 low, 4.0-6.9 medium, 7.0-8.9 high. Decides queue position, nothing else.
2. **`Type`** — the structured name. **The first word is the attacker's intent:** `Recon` (looking
   around), `Discovery` (mapping what exists), `Execution` (running something), `Persistence`
   (staying in), `PrivilegeEscalation`, `DefenseEvasion`, `Impact` (doing damage),
   `UnauthorizedAccess`, `Backdoor`, `Policy`. That first word tells you which stage of an attack
   you are looking at before you read anything else.
3. **`Title`** — one sentence in plain English. Faster than parsing the type.
4. **`Resource.ResourceType`** — what was touched: `Instance`, `AccessKey`, `S3Object`,
   `Container`, `EKSCluster`, `RDSDBInstance`. Feeds section 3 directly.
5. **`Service.Count`** plus `EventFirstSeen` / `EventLastSeen` — one event or a burst? One root
   console login in this account generated ~90 CloudTrail events (measured on Day 15), so a Count of
   1 and a Count of 90 are different situations, not the same alert repeated.

**Severity note worth remembering:** `Persistence:Runtime/SuspiciousCommand` scores 2.0 while
`Execution:Runtime/NewBinaryExecuted` scores 5.0. "Suspicious" is an indication; "executed a
newly created binary" is an observed behaviour. **Suspected weighs less than confirmed** — that gap
is what orders the queue when 30 alerts are waiting.

---

## 3. Does this resource even exist in my account?

**The cheapest check in security, and it survives into production.**

Before investigating anything, ask whether the resource type in the finding exists here at all.

```bash
aws ecs list-clusters       --region us-east-1 --query 'clusterArns'
aws eks list-clusters       --region us-east-1 --query 'clusters'
aws ec2 describe-instances  --region us-east-1 \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]' --output text
aws s3 ls
```

**Current inventory, verified 2026-07-31:**

| Resource type | Present |
|---|---|
| ECS clusters | none |
| EKS clusters | none |
| EC2 instances | 1 (`<INSTANCE_ID>`, **stopped**) |
| S3 buckets | 4 (Day 18 inventory) |
| IAM users | `nic-lab` + root |

**How to read a mismatch:**

- Finding references a resource type that **does not exist here** → either the finding is synthetic,
  or **someone created infrastructure I do not know about**, which is a far more serious problem than
  the original alert. Verify existence before dismissing.
- Finding references an EC2 instance while the only instance is **stopped** → same logic. A stopped
  instance cannot execute a binary.

This is the check that made the sample findings obvious without ever reading `sample: true`: the
generated findings target Containers, Kubernetes clusters and RDS instances, and **none of those
exist in this account.**

Keep this table current. A runbook whose inventory is stale gives confidently wrong answers.

---

## 4. Corroborate against this account's own history

**A finding without a baseline is an opinion.** GuardDuty tells you something is unusual; only your
own event history tells you what "usual" was.

The baseline is `_private/day19-output/normalized.jsonl` — 1,203 real CloudTrail events flattened by
`python/security-utils/cloudtrail_normalize.py` into seven fields. Four of them map one-to-one onto a
GuardDuty finding:

| Baseline field (Day 19) | GuardDuty field |
|---|---|
| `actor` | `Resource.AccessKeyDetails.UserName` / `.UserType` |
| `source_ip` | `Service.Action.AwsApiCallAction.RemoteIpDetails.IpAddressV4` |
| `event_name` | `Service.Action.AwsApiCallAction.Api` |
| `error_code` | `Service.Action.AwsApiCallAction.ErrorCode` |

**Three questions, three commands.**

**a) Has this principal ever done anything here?**

```bash
jq -r 'select(.actor|test("<PRINCIPAL>";"i"))
       | [.time,.event_name,.source_ip,.outcome] | @tsv' normalized.jsonl
```

**b) Is this source IP one of mine?**

```bash
jq -r .source_ip normalized.jsonl | sort | uniq -c | sort -rn
```

**c) Is this API call normal for this actor?**

```bash
jq -r 'select(.actor|test("<PRINCIPAL>";"i")) | .event_name' normalized.jsonl \
  | sort | uniq -c | sort -rn
```

**Known baseline, measured 2026-07-29 over the 2026-07-15 → 07-24 window:**

| Fact | Value |
|---|---|
| Total events | 1,203 |
| Distinct principals | 6 |
| Human principal | `arn:aws:iam::<ACCOUNT_ID>:user/nic-lab` — 53 events (4.4%) |
| Service noise | `cloudtrail.amazonaws.com` reading its own bucket — 789 events (65%) |
| **Root events** | **0** |
| Human source IPs | 3 distinct — `<IP_A>` (28) · `<IP_B>` (24) · `<IP_C>` (1). Two residential ISP (CO), one datacenter/VPN range. Real values in `_private/`, redacted here. |

**Two conclusions that change triage decisions:**

1. **Zero root events in the baseline.** So a real `Policy:IAMUser/RootCredentialUsage` finding has
   no precedent in this account at all → **escalate, do not close.** The absence is the signal.
2. **My own access comes from at least three IPs**, and `<IP_B>` resolves to a datacenter or
   VPN range rather than a residential ISP. A future "unusual ASN / unusual location" finding may
   well be me. Confirm which of these three are mine before escalating a geo-based finding.

⚠ **Baseline limits, stated honestly:** two days, one region, 1,203 events, and it ends 2026-07-24.
It is a starting point, not proof. Absence of an event in this window does not mean it never
happened — it means it did not happen *here, then*. Re-run the normalizer before leaning on it for
anything serious.

---

## 5. Decide, and write the reason

Three possible outcomes. Pick one, always write why.

| Verdict | When | Next action |
|---|---|---|
| **Benign** | Explained by known activity, verified in section 4 | Close with reason. If it will recur → section 6. |
| **Escalate** | Cannot explain it, or it contradicts the baseline | Hand off with the evidence already gathered |
| **Confirmed** | Baseline plus finding agree that something real happened | Containment first, then investigation |

**The written reason is the deliverable, not the closed ticket.** An analyst who closes alerts
without recorded reasoning produces nothing reviewable and cannot be audited later. Minimum fields:

```
Finding ID:
Type / Severity:
Verdict:
Evidence checked:      (which commands from sections 3-4, and what they returned)
Reason:                (one or two sentences, plain language)
Baseline window used:  (the normalizer output is dated — say which)
Decided by / when:
```

If the reason cannot be written in two sentences, the triage is not finished.

---

## 6. Contain or suppress

**Confirmed incident — order matters. Contain before investigating; evidence is worth less than
stopping the bleeding.**

1. **Revoke the credential.** Compromised access key → deactivate it, do not delete it (deleting
   destroys the audit trail). `aws iam update-access-key --status Inactive`.
2. **Isolate the compute.** Compromised instance → replace its security group with a deny-all rather
   than terminating. A terminated instance takes its memory and disk evidence with it.
3. **Preserve.** Snapshot the volume before changing anything you cannot undo.
4. **Only then investigate.**

**Known-benign recurring pattern — suppress it, so it never costs anyone time again.** GuardDuty
suppression rules archive matching findings automatically.

⚠ **Suppression is a loaded gun.** A rule that is too broad silently blinds the detector, and nobody
notices, because the symptom of an over-broad suppression rule is *silence* — which looks exactly
like safety. Every rule gets: an owner, a written justification, and a review date. Match on the
narrowest set of fields that works, never on `Type` alone.

---

## 7. Known limits of this setup

Stated plainly, because a runbook that hides its blind spots is worse than none.

1. **The detector is single-region; the CloudTrail trail is not.** GuardDuty runs in `us-east-1`
   only, while the Day 13 trail is multi-region. **Anything happening in any other region is
   invisible to detection**, even though it is being logged. Cost to close: one detector per region,
   at the same per-event rate — pennies. It is unclosed by choice, not by oversight, and it is the
   honest answer to "what is the weakness of your setup?"
2. **`FindingPublishingFrequency` is `SIX_HOURS`** (the default). This does not delay findings in the
   console or API, but it does delay export to EventBridge and S3 — which matters the moment any
   automated response is built on top.
3. **No automated response exists.** Nothing routes findings to email, Slack or a ticket. Detection
   today depends on a human opening the console. The Day 15 SNS alarm chain covers root usage and
   MFA-less console login specifically; GuardDuty findings are not wired to it.
4. **The baseline is stale by design.** See the limits note in section 4.
5. **This runbook has never been exercised against a real finding.** Every step here was validated on
   synthetic data. Treat the first real one as a test of the runbook as much as of the account.
