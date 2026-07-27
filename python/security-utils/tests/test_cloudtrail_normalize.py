import gzip
import json
from cloudtrail_normalize import extract_actor, normalize_record, run


def test_iam_user():
    event = {
        "eventTime": "2026-07-15T03:15:12Z",
        "eventName": "GetUser",
        "sourceIPAddress": "203.0.113.10",
        "userIdentity": {
            "type": "IAMUser",
            "arn": "arn:aws:iam::123456789012:user/nic-lab",
        },
        "requestParameters": {"userName": "nic-lab"},
    }
    row = normalize_record(event)
    assert row["actor"] == "arn:aws:iam::123456789012:user/nic-lab"
    assert row["event_name"] == "GetUser"
    assert row["resource"] == "nic-lab"
    assert row["outcome"] == "success"


def test_failure_event_sets_outcome_and_keeps_code():
    event = {
        "eventTime": "2026-07-15T03:15:12Z",
        "eventName": "GetBucketPolicy",
        "userIdentity": {
            "type": "IAMUser",
            "arn": "arn:aws:iam::123456789012:user/nic-lab",
        },
        "errorCode": "AccessDenied",
    }
    row = normalize_record(event)
    assert row["outcome"] == "failure"
    assert row["error_code"] == "AccessDenied"


def test_assumed_role_actor_is_the_role_not_the_session():
    identity = {
        "type": "AssumedRole",
        "sessionContext": {
            "sessionIssuer": {"arn": "arn:aws:iam::123456789012:role/lab-role"}
        },
    }
    assert extract_actor(identity) == "arn:aws:iam::123456789012:role/lab-role"


def test_root_actor():
    assert extract_actor({"type": "Root"}) == "root"


def test_unknown_identity_type_does_not_crash():
    assert extract_actor({"type": "Banana"}) == "unknown:Banana"


def test_malformed_event_is_skipped_not_fatal():
    # no userIdentity at all -> unusable -> None, and no exception
    assert normalize_record({"eventTime": "2026-07-15T03:15:12Z"}) is None
    # not even a dict
    assert normalize_record("garbage") is None


def test_run_skips_bad_records_and_keeps_going(tmp_path):
    good = {
        "eventTime": "2026-07-15T03:15:12Z",
        "eventName": "GetUser",
        "userIdentity": {"type": "Root"},
    }
    bad = {"eventName": "NoTimestampNoIdentity"}

    log = tmp_path / "test.json.gz"
    with gzip.open(log, "wt") as f:
        json.dump({"Records": [good, bad]}, f)

    rows = run(str(tmp_path / "*.json.gz"))

    # one good row survives, the broken one is dropped, run completes
    assert len(rows) == 1
    assert rows[0]["actor"] == "root"
