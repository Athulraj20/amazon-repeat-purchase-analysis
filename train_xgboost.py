"""Fit and evaluate a 90-day XGBoost repeat-purchase classifier."""
import argparse
from importlib.metadata import version
from pathlib import Path
import json

import joblib
import numpy as np
import pandas as pd
from sklearn.metrics import accuracy_score, average_precision_score, confusion_matrix
from xgboost import XGBClassifier

FEATURES = ["first_day_spend", "first_day_units", "first_day_distinct_products"]
TARGET = "returned_90d"

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv", type=Path, help="Path to shopper_model_split.csv")
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()
    data = pd.read_csv(args.csv)
    train = data.loc[data["data_split"].eq("train")]
    test = data.loc[data["data_split"].eq("test")]
    model = XGBClassifier(
        objective="binary:logistic",
        n_estimators=100,
        max_depth=2,
        learning_rate=0.05,
        min_child_weight=10,
        reg_lambda=5,
        eval_metric="logloss",
        random_state=42,
        n_jobs=2,
    )
    model.fit(train[FEATURES], train[TARGET])
    scores = model.predict_proba(test[FEATURES])[:, 1]
    actual = test[TARGET].to_numpy()
    budget = 101
    order = np.argsort(scores, kind="stable")
    spend_order = np.argsort(test["first_day_spend"].to_numpy(), kind="stable")
    count_nonreturners = int((actual == 0).sum())
    captured = int((actual[order[:budget]] == 0).sum())
    metrics = {
        "training_shoppers": len(train),
        "test_shoppers": len(test),
        "shortlist_budget": budget,
        "always_return_accuracy": float(actual.mean()),
        "xgboost_accuracy": accuracy_score(actual, scores >= 0.5),
        "xgboost_confusion_matrix": confusion_matrix(actual, scores >= 0.5, labels=[0, 1]).tolist(),
        "nonreturn_average_precision": average_precision_score(1 - actual, 1 - scores),
        "nonreturn_base_rate": count_nonreturners / len(test),
        "nonreturners_captured_xgboost": captured,
        "nonreturners_captured_spending_rule": int((actual[spend_order[:budget]] == 0).sum()),
        "xgboost_shortlist_nonreturn_rate": captured / budget,
        "xgboost_shortlist_lift": (captured / budget) / (count_nonreturners / len(test)),
    }
    args.output.mkdir(parents=True, exist_ok=True)
    native = args.output / "repeat_purchase_xgboost.json"
    snapshot = args.output / "repeat_purchase_xgboost.joblib"
    model.save_model(native)
    joblib.dump(model, snapshot)
    restored = XGBClassifier()
    restored.load_model(native)
    for saved in (restored, joblib.load(snapshot)):
        np.testing.assert_allclose(saved.predict_proba(test[FEATURES])[:, 1], scores)
    versions = [f"{package}=={version(package)}" for package in ("xgboost", "joblib", "scikit-learn", "numpy", "pandas")]
    (args.output / "requirements.txt").write_text("\n".join(versions) + "\n", encoding="utf-8")
    result = json.dumps(metrics, indent=2)
    (args.output / "metrics.json").write_text(result + "\n", encoding="utf-8")
    print(result)

if __name__ == "__main__":
    main()
